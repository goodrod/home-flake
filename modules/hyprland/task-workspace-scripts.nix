{ pkgs, lib, tasks }:
let
  inherit (pkgs) writeScript;

  # Escape a string for embedding in a Lua double-quoted string (same idiom as
  # windowrules.nix's luaEscape - duplicated locally per this repo's convention
  # of no shared lib helpers between module files).
  luaEscape = lib.replaceStrings [ ''\'' ''"'' ] [ ''\\'' ''\"'' ];

  taskList = lib.sort (a: b: a.id < b.id)
    (lib.mapAttrsToList (name: t: t // { inherit name; }) tasks);

  idAssignLines = lib.concatMapStringsSep "\n    "
    (t: "[${t.name}]=${toString t.id}") taskList;

  launchCaseLines = lib.concatMapStringsSep "\n"
    (t: ''
      ${t.name})
        ${lib.concatMapStringsSep "\n    " (cmd:
          ''hyprctl dispatch "hl.dsp.exec_cmd(\"[workspace ${toString t.id}] ${luaEscape cmd}\")"''
        ) t.apps}
        ;;
    '') taskList;

  pickerPairs = lib.concatMapStringsSep " " (t:
    ''"${luaEscape t.icon}  ${t.name}" "${t.name}"''
  ) taskList;

  namesArr = lib.concatMapStringsSep " " (t: ''"${t.name}"'') taskList;
  idsArr   = lib.concatMapStringsSep " " (t: toString t.id) taskList;
  iconsArr = lib.concatMapStringsSep " " (t: ''"${luaEscape t.icon}"'') taskList;
in
rec {
  taskLaunchOrFocus = writeScript "task-workspace-launch.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    task="''${1:-}"
    declare -A task_id=(
      ${idAssignLines}
    )
    id="''${task_id[$task]:-}"
    if [ -z "$id" ]; then
      notify-send "Task workspace" "Unknown task: $task"
      exit 1
    fi

    if ! hyprctl clients -j | jq -e --argjson id "$id" 'any(.[]; .workspace.id == $id)' >/dev/null; then
      case "$task" in
        ${launchCaseLines}
      esac
    fi

    hyprctl dispatch "hl.dsp.focus({workspace = $id, on_current_monitor = true})"
  '';

  taskPicker = writeScript "task-workspace-picker.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    pgrep fuzzel && pkill fuzzel && exit 0
    selection=$(printf '%s\t%s\n' ${pickerPairs} \
      | fuzzel --dmenu --with-nth=1 --accept-nth=2 --placeholder="Task workspace")
    [ -n "$selection" ] && exec ${taskLaunchOrFocus} "$selection"
  '';

  taskWaybarStatus = writeScript "task-workspace-status.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    clients_json=$(hyprctl clients -j)
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

    text=$(IFS=' '; echo "''${active[*]:-}")
    class=$([ "''${#active[@]}" -gt 0 ] && echo active || echo idle)

    jq -n --arg text "$text" --arg tooltip "$(printf '%s\n' "''${tooltip[@]}")" --arg class "$class" \
      '{text: $text, tooltip: $tooltip, class: $class}'
  '';
}
