{ pkgs }:
let
  inherit (pkgs) writeScript;
in
{
  cycleAllColWidths = writeScript "cycle-all-col-widths.sh" ''
    #!/usr/bin/env bash
    widths=(0.333 0.5 0.667 1.0)
    state_file="/tmp/hypr-col-width-idx"
    idx=$(cat "$state_file" 2>/dev/null || echo 0)
    if [[ "$1" == "prev" ]]; then
      idx=$(( (idx - 1 + ''${#widths[@]}) % ''${#widths[@]} ))
    else
      idx=$(( (idx + 1) % ''${#widths[@]} ))
    fi
    echo "$idx" > "$state_file"
    addr=$(hyprctl activewindow -j | jq -r '.address')
    hyprctl dispatch "hl.dsp.layout(\"colresize all ''${widths[$idx]}\")"
    hyprctl dispatch "hl.dsp.focus({window=\"address:$addr\"})"
  '';
  toggleWindow = writeScript "toggle-window.sh" ''
    #!/usr/bin/env bash
    pgrep fuzzel && pkill fuzzel && exit 0
    if hyprctl clients | grep -q "toggle-window"; then
        hyprctl dispatch closewindow class:toggle-window
    else
        alacritty --class=toggle-window -e bash -c "$@"
    fi
  '';

  toggleMenu = writeScript "toggle-menu.sh" ''
    #!/usr/bin/env bash
    pgrep fuzzel && pkill fuzzel && exit 0
    if hyprctl clients | grep -q "toggle-window"; then
        hyprctl dispatch closewindow class:toggle-window
    else
        fuzzel
    fi
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
