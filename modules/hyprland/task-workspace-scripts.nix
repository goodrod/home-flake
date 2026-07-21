{ pkgs, lib, config }:
let
  inherit (pkgs) writeScript;

  tasks = config.module.taskWorkspaces.tasks;

  # Lua-escape idiom (see windowrules.nix's luaEscape) - duplicated locally
  # per this repo's convention of no shared lib helpers between module files.
  luaEscape = lib.replaceStrings [ ''\'' ''"'' ] [ ''\\'' ''\"'' ];

  taskList = lib.sort (a: b: a.id < b.id)
    (lib.mapAttrsToList (name: t: t // { inherit name; }) tasks);

  # Everything already claimed by something static, so on-the-fly ad-hoc
  # task creation (which auto-allocates an id at runtime, see
  # taskLaunchOrFocus) never collides: predefined tasks, the app-category
  # workspaces, and the generic SUPER+0..9/SHIFT+0..9 keybind grid (10-101).
  reservedGridIds = lib.concatMap (n: [ (n * 10) (n * 10 + 1) ]) (lib.range 1 10);
  workspaceIds = map (ws: ws.id) (lib.attrValues config.module.workspaces.entries);
  reservedIdsSpace = lib.concatMapStringsSep " " toString
    (map (t: t.id) taskList ++ workspaceIds ++ reservedGridIds);

  idAssignLines = lib.concatMapStringsSep "\n    "
    (t: "[${t.name}]=${toString t.id}") taskList;

  # Sets the pending-move target (see pending-move.nix's window.open hook)
  # before each exec instead of using Hyprland's exec-time "[workspace N]"
  # prefix, which only affects the freshly spawned process's own window -
  # singleton apps (Firefox etc) open their "new window" via IPC in their
  # existing process, so the prefix never reaches it. Each app's eval call
  # renews the grace period, covering a task's whole app list.
  launchCaseLines = lib.concatMapStringsSep "\n"
    (t: ''
      ${t.name})
        ${lib.concatMapStringsSep "\n    " (cmd: ''
          hyprctl eval "hl_pending_move_ws = ${toString t.id}; hl_pending_move_until = os.time() + 5"
          hyprctl dispatch "hl.dsp.exec_cmd(\"${luaEscape cmd}\")"
        '') t.apps}
        ;;
    '') taskList;

  pickerPairs = lib.concatMapStringsSep " " (t:
    ''"${luaEscape t.icon}  ${t.name}" "${t.name}"''
  ) taskList;

  namesArr = lib.concatMapStringsSep " " (t: ''"${t.name}"'') taskList;
  idsArr   = lib.concatMapStringsSep " " (t: toString t.id) taskList;
  iconsArr = lib.concatMapStringsSep " " (t: ''"${luaEscape t.icon}"'') taskList;

  # Icon shown for ad-hoc (on-the-fly created) tasks, in both the picker and
  # the bar widget - ad-hoc tasks have no Nix-declared icon of their own.
  adhocIcon = "★";
in
rec {
  # Launch (or focus, or on-the-fly-create) a task workspace by name.
  #
  # Three cases:
  #  - name is a predefined task (module.taskWorkspaces.tasks): launch its
  #    apps if the workspace is empty, else just focus it.
  #  - name is a known ad-hoc task (recorded in the state file by a prior
  #    on-the-fly creation): just focus its workspace - there's no app list
  #    to (re)launch, the user populated it manually.
  #  - name is unrecognized: create a new ad-hoc task on the fly. Allocates
  #    a free id (>= 500, own space, never colliding with anything static -
  #    see reservedIdsSpace above), records name -> id in the state file,
  #    and focuses the (empty) new workspace. Never garbage collected -
  #    manual only, matching this feature's launch+jump-only, no-teardown
  #    design.
  taskLaunchOrFocus = writeScript "task-workspace-launch.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    task="''${1:-}"
    declare -A task_id=(
      ${idAssignLines}
    )
    id="''${task_id[$task]:-}"

    state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-task-workspaces.json"
    mkdir -p "$(dirname "$state_file")"
    [ -s "$state_file" ] || printf '{}' > "$state_file"

    is_predefined=1
    if [ -z "$id" ]; then
      is_predefined=0
      id=$(jq -r --arg n "$task" '.[$n] // empty' "$state_file")
    fi

    if [ -z "$id" ]; then
      taken=" ${reservedIdsSpace} $(jq -r '.[]' "$state_file" | tr '\n' ' ')"
      id=500
      while [[ "$taken" == *" $id "* ]]; do
        id=$((id + 1))
      done
      jq --arg n "$task" --argjson id "$id" '. + {($n): $id}' "$state_file" > "$state_file.tmp"
      mv "$state_file.tmp" "$state_file"
      notify-send "Task workspace" "Created: $task"
      hyprctl dispatch "hl.dsp.focus({workspace = $id, on_current_monitor = true})"
      exit 0
    fi

    if [ "$is_predefined" -eq 1 ] && ! hyprctl clients -j | jq -e --argjson id "$id" 'any(.[]; .workspace.id == $id)' >/dev/null; then
      case "$task" in
        ${launchCaseLines}
      esac
    fi

    hyprctl dispatch "hl.dsp.focus({workspace = $id, on_current_monitor = true})"
  '';

  # Fuzzel dmenu picker listing predefined + ad-hoc tasks, fuzzy-searchable
  # in one merged list (fuzzel's own dmenu input filtering does the fuzzy
  # matching). Typing a name that matches neither is passed through
  # unmodified by fuzzel (--only-match is NOT set) straight to
  # taskLaunchOrFocus, which is what creates it on the fly.
  #
  # Extracts the name column ourselves (bash-side, after the last tab)
  # rather than via fuzzel's --accept-nth: with --with-nth set alongside it,
  # --accept-nth was observed to sometimes return the literal, unresolved
  # "{1}" placeholder instead of the actual column value. --with-nth alone
  # (no --accept-nth) reliably returns the full raw input line, tabs
  # included, per fuzzel's own docs - so we just split that ourselves.
  taskPicker = writeScript "task-workspace-picker.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    pgrep fuzzel && pkill fuzzel && exit 0
    state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-task-workspaces.json"
    mkdir -p "$(dirname "$state_file")"
    [ -s "$state_file" ] || printf '{}' > "$state_file"

    selection=$(
      {
        # With no predefined tasks this prints one empty row - deliberate:
        # it's the preselected blank line you type a brand-new name over to
        # create a workspace on the fly (fuzzel returns the typed text when it
        # matches nothing). To create a name that DOES fuzzy-match an existing
        # task (e.g. "Test A" while "Test a feature" exists), press Shift+Enter
        # (fuzzel's execute-input) which returns the raw typed text verbatim.
        printf '%s\t%s\n' ${pickerPairs}
        jq -r 'to_entries[] | "${adhocIcon}  \(.key)\t\(.key)"' "$state_file"
      } | fuzzel --dmenu --with-nth=1 --placeholder="Task workspace  (Shift+Enter: create typed name)"
    ) || true
    task="''${selection##*$'\t'}"
    [ -n "$task" ] && exec ${taskLaunchOrFocus} "$task"
  '';

  # Resolve a task name to a workspace id (predefined, known ad-hoc, or
  # create a new ad-hoc one on the fly - same resolution as
  # taskLaunchOrFocus, duplicated locally rather than shelling out to it
  # since this needs the id back to move a window, not to launch/focus)
  # then move the currently focused window there. Doesn't follow for an
  # existing task - the window moves, focus stays put, matching this repo's
  # existing move-to-workspace binds (mainMod+CTRL+<n>). Freshly-created
  # ad-hoc tasks are the exception: they follow, since otherwise you'd have
  # no way to see the workspace you just made until a separate SUPER+T.
  taskMoveWindow = writeScript "task-workspace-move-window.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    task="''${1:-}"
    declare -A task_id=(
      ${idAssignLines}
    )
    id="''${task_id[$task]:-}"

    state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-task-workspaces.json"
    mkdir -p "$(dirname "$state_file")"
    [ -s "$state_file" ] || printf '{}' > "$state_file"

    if [ -z "$id" ]; then
      id=$(jq -r --arg n "$task" '.[$n] // empty' "$state_file")
    fi

    created=0
    if [ -z "$id" ]; then
      taken=" ${reservedIdsSpace} $(jq -r '.[]' "$state_file" | tr '\n' ' ')"
      id=500
      while [[ "$taken" == *" $id "* ]]; do
        id=$((id + 1))
      done
      jq --arg n "$task" --argjson id "$id" '. + {($n): $id}' "$state_file" > "$state_file.tmp"
      mv "$state_file.tmp" "$state_file"
      notify-send "Task workspace" "Created: $task"
      created=1
    fi

    if [ "$created" -eq 1 ]; then
      hyprctl dispatch "hl.dsp.window.move({workspace = $id, follow = true})"
    else
      hyprctl dispatch "hl.dsp.window.move({workspace = $id, follow = false})"
    fi
  '';

  # SUPER+SHIFT+T: same merged fuzzy picker as taskPicker, but moves the
  # currently focused window into whichever task workspace you pick instead
  # of launching/focusing it.
  taskMoveWindowPicker = writeScript "task-workspace-move-window-picker.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    pgrep fuzzel && pkill fuzzel && exit 0
    state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-task-workspaces.json"
    mkdir -p "$(dirname "$state_file")"
    [ -s "$state_file" ] || printf '{}' > "$state_file"

    selection=$(
      {
        printf '%s\t%s\n' ${pickerPairs}
        jq -r 'to_entries[] | "${adhocIcon}  \(.key)\t\(.key)"' "$state_file"
      } | fuzzel --dmenu --with-nth=1 --placeholder="Move window to task workspace  (Shift+Enter: create typed name)"
    ) || true
    task="''${selection##*$'\t'}"
    [ -n "$task" ] && exec ${taskMoveWindow} "$task"
  '';

  # SUPER+CTRL+T: pick an ad-hoc (on-the-fly created) task workspace to
  # forget. Predefined tasks aren't listed here - they're Nix-managed, not
  # something a runtime picker can remove. Closes every window still on that
  # workspace (confirming first if any are open) before forgetting the
  # name -> id mapping in the state file, so removal never leaves orphaned
  # windows behind on an unreachable-by-name workspace id.
  # --only-match: there's nothing sensible to "create" here, only pick from
  # what already exists.
  taskRemovePicker = writeScript "task-workspace-remove-picker.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    pgrep fuzzel && pkill fuzzel && exit 0
    state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-task-workspaces.json"
    mkdir -p "$(dirname "$state_file")"
    [ -s "$state_file" ] || printf '{}' > "$state_file"

    if [ "$(jq 'length' "$state_file")" -eq 0 ]; then
      notify-send "Task workspace" "No ad-hoc task workspaces to remove"
      exit 0
    fi

    task=$(jq -r 'keys[]' "$state_file" | fuzzel --dmenu --only-match --placeholder="Remove task workspace") || true
    [ -z "$task" ] && exit 0

    id=$(jq -r --arg n "$task" '.[$n]' "$state_file")

    clients_json=$(hyprctl clients -j)
    addrs=$(jq -r --argjson id "$id" '[.[] | select(.workspace.id == $id)] | .[].address' <<< "$clients_json")
    count=$(grep -c . <<< "$addrs" 2>/dev/null || true)

    if [ "$count" -gt 0 ]; then
      confirm=$(printf 'Yes\nNo' | fuzzel --dmenu --placeholder="Close $count window(s) in '$task' and remove it?") || true
      [ "$confirm" = "Yes" ] || exit 0
    fi

    while IFS= read -r addr; do
      [ -z "$addr" ] && continue
      hyprctl dispatch "hl.dsp.window.close({ window = \"address:$addr\" })"
    done <<< "$addrs"

    jq --arg n "$task" 'del(.[$n])' "$state_file" > "$state_file.tmp"
    mv "$state_file.tmp" "$state_file"
    notify-send "Task workspace" "Removed: $task"
  '';

  # Auto-forget hook (see task-workspace-cleanup.nix's workspace.active
  # listener): called with a workspace id whenever you navigate away from it.
  # No-ops unless that id is a currently-known ad-hoc task and it's actually
  # empty - predefined tasks are never touched since they're never recorded
  # in the state file. Keeps emptied ad-hoc tasks from lingering forever in
  # the picker/bar (previously "manual only" removal was the sole way to
  # forget one, even after every window on it was already closed by hand).
  taskForgetIfEmpty = writeScript "task-workspace-forget-if-empty.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    id="''${1:-}"
    [ -n "$id" ] || exit 0

    state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-task-workspaces.json"
    [ -s "$state_file" ] || exit 0

    name=$(jq -r --argjson id "$id" 'to_entries[] | select(.value == $id) | .key' "$state_file")
    [ -n "$name" ] || exit 0

    hyprctl clients -j | jq -e --argjson id "$id" 'any(.[]; .workspace.id == $id)' >/dev/null && exit 0

    jq --arg n "$name" 'del(.[$n])' "$state_file" > "$state_file.tmp"
    mv "$state_file.tmp" "$state_file"
    notify-send "Task workspace" "Forgot empty: $name"
  '';

  # Status text for the bar's task-workspaces widget: icons of currently-active
  # predefined + ad-hoc tasks, polled (see modules/quickshell's taskStatus).
  taskStatusScript = writeScript "task-workspace-status.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    clients_json=$(hyprctl clients -j)
    state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-task-workspaces.json"
    mkdir -p "$(dirname "$state_file")"
    [ -s "$state_file" ] || printf '{}' > "$state_file"

    names=(${namesArr})
    ids=(${idsArr})
    icons=(${iconsArr})

    active=()
    tooltip=()
    for i in "''${!names[@]}"; do
      id="''${ids[$i]}"
      if jq -e --argjson id "$id" 'any(.[]; .workspace.id == $id)' <<< "$clients_json" >/dev/null; then
        active+=("''${icons[$i]}")
        tooltip+=("''${names[$i]}: running")
      else
        tooltip+=("''${names[$i]}: idle")
      fi
    done

    while IFS=$'\t' read -r name id; do
      [ -z "$name" ] && continue
      if jq -e --argjson id "$id" 'any(.[]; .workspace.id == $id)' <<< "$clients_json" >/dev/null; then
        active+=("${adhocIcon}")
        tooltip+=("$name: running")
      else
        tooltip+=("$name: idle")
      fi
    done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$state_file")

    text=$(IFS=' '; echo "''${active[*]:-}")
    class=$([ "''${#active[@]}" -gt 0 ] && echo active || echo idle)

    jq -n --arg text "$text" --arg tooltip "$(printf '%s\n' "''${tooltip[@]}")" --arg class "$class" \
      '{text: $text, tooltip: $tooltip, class: $class}'
  '';

  inherit adhocIcon;
}
