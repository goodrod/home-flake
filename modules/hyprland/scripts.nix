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
}
