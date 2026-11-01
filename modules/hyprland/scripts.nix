{ pkgs }:
let
  inherit (pkgs) writeScript;
in
rec {
  toggleWindow = writeScript "toggle-window.sh" ''
    #!/usr/bin/env bash
    pgrep fuzzel && pkill fuzzel && exit 0
    if hyprctl clients | grep -q "toggle-window"; then
        hyprctl dispatch 'hl.dsp.window.close({ window = "class:toggle-window" })'
    else
        alacritty --class=toggle-window -e bash -c "$@"
    fi
  '';

  toggleMenu = writeScript "toggle-menu.sh" ''
    #!/usr/bin/env bash
    pgrep fuzzel && pkill fuzzel && exit 0
    fuzzel
  '';

  # Re-dispatches whatever fuzzel is about to exec so it opens on the
  # current workspace instead of wherever its window-rule tag would
  # normally route it (e.g. a browser -> its own tagged workspace).
  #
  # Originally used Hyprland's exec-time "[workspace unset]" prefix (same
  # trick as mod+CTRL+space's terminal bind), but that only affects the
  # window opened by the freshly spawned process - singleton apps (Firefox,
  # Chrome, etc) that are already running open their "new window" via IPC in
  # their EXISTING process, so the prefix never reached it (verified live).
  # Now sets the pending-move target (see pending-move.nix's window.open
  # hook) instead, which catches the window regardless of which process
  # created it. Lua-escapes the joined argv (backslash then double-quote,
  # same idiom as windowrules.nix's luaEscape) since this is a runtime value
  # Nix can't pre-escape.
  execCurrentWs = writeScript "exec-current-ws.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    ws=$(hyprctl activeworkspace -j | jq -r '.id')
    hyprctl eval "hl_pending_move_ws = $ws; hl_pending_move_until = os.time() + 5"
    escaped=$(printf '%s' "$*" | sed 's/\\/\\\\/g; s/"/\\"/g')
    hyprctl dispatch "hl.dsp.exec_cmd(\"$escaped\")"
  '';

  toggleMenuCurrentWs = writeScript "toggle-menu-current-ws.sh" ''
    #!/usr/bin/env bash
    pgrep fuzzel && pkill fuzzel && exit 0
    fuzzel --launch-prefix="${execCurrentWs}"
  '';

  # External script, not inline Lua: io.popen("hyprctl ...") from inside a
  # keybind callback deadlocks Hyprland against its own IPC thread (~5s hang, confirmed live).
  toggleNoShare = writeScript "toggle-no-share.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    addr=$(hyprctl activewindow -j | jq -r '.address // empty')
    [ -n "$addr" ] || exit 0
    target="address:$addr"
    current=$(hyprctl getprop "$target" no_screen_share)
    if [ "$current" = "true" ]; then
      hyprctl dispatch "hl.dsp.window.set_prop({ window = \"$target\", prop = \"no_screen_share\", value = \"false\" })"
      hyprctl dispatch "hl.dsp.window.set_prop({ window = \"$target\", prop = \"active_border_color\", value = \"rgba(cdd6f4ee)\" })"
      hyprctl dispatch "hl.dsp.window.set_prop({ window = \"$target\", prop = \"inactive_border_color\", value = \"rgba(404A60aa)\" })"
    else
      hyprctl dispatch "hl.dsp.window.set_prop({ window = \"$target\", prop = \"no_screen_share\", value = \"true\" })"
      hyprctl dispatch "hl.dsp.window.set_prop({ window = \"$target\", prop = \"active_border_color\", value = \"rgb(f38ba8)\" })"
      hyprctl dispatch "hl.dsp.window.set_prop({ window = \"$target\", prop = \"inactive_border_color\", value = \"rgba(f38ba888)\" })"
    fi
  '';

  # Resize every column and keep the grid flush with the screen.
  #
  # layoutmsg "colresize all" is the one colresize variant that returns before
  # the layout's own fit step, so it changes the widths while leaving the scroll
  # offset alone and the new columns end up straddling both screen edges. The
  # layout exposes no "snap to grid" message, and the only one that sets an
  # absolute offset is "fit active", which always anchors the FOCUSED column to
  # the left edge - i.e. it yanks the view over whenever the focused window
  # isn't the leftmost one.
  #
  # So pick the anchor ourselves: the column nearest the left edge, clamped so
  # the focused window still fits on screen and so we never scroll past the last
  # column (nothing in the layout clamps that end, it would just show a gap).
  # Focus it, anchor there, hand focus back. One --batch, so one frame.
  #
  # Positions come from hyprctl, which reports animation goals, not the
  # in-flight values - so this is safe to run while the previous resize is still
  # animating. External script rather than inline Lua for the reason above
  # toggleNoShare.
  snapColumns = writeScript "snap-columns.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    width="$1"
    # Optional workspace id. colresize/fit have no target of their own, they
    # act on whatever holds dispatch focus, so a caller wanting to resize a
    # workspace it is not focused on would have to move focus there first.
    # Given an id, the batch at the bottom borrows focus and hands it straight
    # back instead, so callers never move focus themselves.
    target_ws="''${2:-}"

    clients=$(hyprctl clients -j)
    focused=$(hyprctl activewindow -j)
    focus_addr=$(jq -r '.address // empty' <<< "$focused")

    # The window the resize is measured around: the focused one, unless a
    # different workspace was asked for.
    active="$focused"
    if [ -n "$target_ws" ] &&
       [ "$(jq -r '.workspace.id // empty' <<< "$focused")" != "$target_ws" ]; then
      # Stand in that workspace's last-focused window, so it is the one the
      # on-screen clamp below keeps visible. Fall back to its leftmost tiled
      # window when that address is gone, floating, or never existed.
      last=$(hyprctl workspaces -j |
        jq -r --argjson ws "$target_ws" '.[] | select(.id == $ws) | .lastwindow // empty')
      active=$(jq -c --argjson ws "$target_ws" --arg last "$last" '
        [ .[] | select(.workspace.id == $ws and .floating == false and .mapped == true) ] as $tiled
        | (first($tiled[] | select(.address == $last)) // $tiled[0]) // empty
      ' <<< "$clients")
    fi

    # nothing focused at all, or an empty target workspace: nothing to resize
    addr=$(jq -r '.address // empty' <<< "$active")
    [ -n "$addr" ] || exit 0

    anchor=$(jq -rn \
      --argjson monitors "$(hyprctl monitors -j)" \
      --argjson clients "$clients" \
      --argjson active "$active" \
      --argjson width "$width" '
      ($active.address) as $addr
      | ($monitors[] | select(.id == $active.monitor)) as $m
      | ($m.x + $m.reserved[0]) as $left
      | [ $clients[]
          | select(.workspace.id == $active.workspace.id and .floating == false and .mapped == true) ] as $tiled
      # one column per distinct x; windows stacked in a column share it
      | ($tiled | map(.at[0]) | unique) as $cols
      | ($cols | index($active.at[0])) as $focused
      | if $focused == null then $addr else
          ($cols | length) as $count
          | ((1 / $width) | floor) as $onscreen
          # the column sitting closest to the left edge right now: that is the
          # one the eye reads as "leftmost", so keep it there
          | ([ $cols | to_entries[] | {i: .key, d: (($left - .value) | fabs)} ]
             | min_by(.d) | .i) as $nearest
          # but never so far left that the focused window falls off the right
          # edge, and never past the tail, which would leave a gap
          | ([0, ($focused - $onscreen + 1)] | max) as $lo
          | ([$focused, ([0, ($count - $onscreen)] | max)] | min) as $hi
          | ([([$nearest, $lo] | max), $hi] | min) as $k
          # already the right column: leave focus alone, a column can hold
          # several stacked windows and we would land on the wrong one
          # (no apostrophes in here - the jq program is single-quoted)
          | if $k == $focused then $addr
            else ($tiled | map(select(.at[0] == $cols[$k])) | .[0].address) end
        end
    ' || true)
    # anything unexpected (floating window, empty workspace): still resize,
    # just anchor on the focused column
    [ -n "$anchor" ] || anchor="$addr"

    # Focus the anchor up front rather than between the two resizes: with a
    # target workspace the dispatches below would otherwise land on whatever
    # else held focus. Both colresize calls cover every column in the workspace
    # either way, so nothing is lost by reordering.
    batch=""
    if [ "$anchor" != "$focus_addr" ]; then
      batch="dispatch hl.dsp.focus({ window = \"address:$anchor\" }) ; "
    fi
    batch="''${batch}dispatch hl.dsp.layout(\"colresize all $width\")"
    batch="$batch ; dispatch hl.dsp.layout(\"fit active\")"
    batch="$batch ; dispatch hl.dsp.layout(\"colresize all $width\")"
    # Hand focus back. Nothing was focused to begin with: leave it on the anchor.
    if [ "$anchor" != "$focus_addr" ] && [ -n "$focus_addr" ]; then
      batch="$batch ; dispatch hl.dsp.focus({ window = \"address:$focus_addr\" })"
    fi
    hyprctl --batch "$batch" > /dev/null
  '';

  parseHotkeys = writeScript "parseHotkeys.sh" ''
    #!/usr/bin/env bash

    hyprctl binds -j | jq -r '
      .[] |
      .description as $desc |
      .key as $key |
      .modmask as $mask |
      .dispatcher as $dispatcher |
      .arg as $arg |

      (
        (if $desc == "" then "<no description>" else $desc end) as $dsc |
        (
          (
            (
              (if ($mask / 1) % 2    >= 1 then ["Shift"] else [] end) +
              (if ($mask / 2) % 2    >= 1 then ["Lock"]  else [] end) +
              (if ($mask / 4) % 2    >= 1 then ["Mod1"]  else [] end) +
              (if ($mask / 8) % 2    >= 1 then ["Ctrl"]  else [] end) +
              (if ($mask / 16) % 2   >= 1 then ["Mod3"]  else [] end) +
              (if ($mask / 32) % 2   >= 1 then ["Mod5"]  else [] end) +
              (if ($mask / 64) % 2   >= 1 then ["Super"]  else [] end)
            ) | join("+")
          ) + (if $key != "" then "+" + $key else "" end) as $hotkey |

          [$dsc, $hotkey, ($dispatcher + " " + $arg)]
        )
      ) | @tsv
    ' | awk -F'\t' '{
      desc = sprintf("%-50s", $1)
      key  = sprintf("%-25s", $2)
      cmd  = (length($3) > 50) ? substr($3, 1, 47) "..." : $3
      printf "%s    %s    %s\n", desc, key, cmd
    }'
  '';

  screenshot = writeScript "screenshot.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    case "''${1:-region}" in
      region) target=(-g "$(${pkgs.slurp}/bin/slurp)") ;;
      monitor) target=(-o "$(hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name')") ;;
      *) echo "usage: screenshot.sh [region|monitor]" >&2; exit 2 ;;
    esac
    dir="''${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
    mkdir -p "$dir"
    ${pkgs.grim}/bin/grim "''${target[@]}" - | ${pkgs.satty}/bin/satty --filename - \
      --output-filename "$dir/screenshot-%Y-%m-%d_%H-%M-%S.png" \
      --copy-command ${pkgs.wl-clipboard}/bin/wl-copy \
      --early-exit
  '';
}
