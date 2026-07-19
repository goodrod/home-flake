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

  # Re-dispatches whatever fuzzel is about to exec through Hyprland's
  # "[workspace unset]" exec prefix instead of letting fuzzel exec it
  # directly, so window-rule auto-routing (e.g. browser -> its own tagged
  # workspace) is bypassed and the app opens on the current workspace
  # instead - same trick already used for mod+CTRL+space's terminal bind.
  # Lua-escapes the joined argv (backslash then double-quote, same idiom as
  # windowrules.nix's luaEscape) since this is a runtime value Nix can't
  # pre-escape.
  execCurrentWs = writeScript "exec-current-ws.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    escaped=$(printf '%s' "$*" | sed 's/\\/\\\\/g; s/"/\\"/g')
    hyprctl dispatch "hl.dsp.exec_cmd(\"[workspace unset] $escaped\")"
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
