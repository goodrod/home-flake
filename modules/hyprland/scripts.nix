{ pkgs }:
let
  inherit (pkgs) writeScript;
in
{
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

  notifAppWatcher = writeScript "notif-app-watcher.sh" ''
    #!/usr/bin/env bash
    # Eavesdrops org.freedesktop.Notifications.Notify calls on the session bus
    # and records the sending app's name, so a hotkey can jump to it later.
    # Daemon-agnostic: this sees the raw Notify call before swaync/dunst/etc
    # ever handles it.
    set -euo pipefail
    state_file="''${XDG_RUNTIME_DIR:-/tmp}/hypr-last-notif-app"

    stdbuf -oL dbus-monitor --session "interface='org.freedesktop.Notifications',member='Notify'" |
      stdbuf -oL awk '
        /member=Notify/ { want=1; next }
        want==1 {
          if (match($0, /^ *string "(.*)"$/, arr)) { print arr[1]; fflush(); }
          want=0
        }
      ' |
      while IFS= read -r app; do
        [ -n "$app" ] && printf "%s" "$app" > "$state_file"
      done
  '';

  focusLastNotifApp = writeScript "focus-last-notif-app.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    state_file="''${XDG_RUNTIME_DIR:-/tmp}/hypr-last-notif-app"

    if [ ! -s "$state_file" ]; then
      notify-send "Focus last notifier" "No notification seen yet"
      exit 0
    fi

    app=$(cat "$state_file")
    app_lower=$(tr '[:upper:]' '[:lower:]' <<< "$app")

    addr=$(hyprctl clients -j | jq -r --arg a "$app_lower" '
      [.[] | select(
        ((.class // "") | ascii_downcase | contains($a)) or
        ($a | contains((.class // "") | ascii_downcase)) or
        ((.initialClass // "") | ascii_downcase | contains($a)) or
        ((.title // "") | ascii_downcase | contains($a))
      )] | .[0].address // empty
    ')

    if [ -n "$addr" ]; then
      hyprctl dispatch focuswindow "address:$addr"
    else
      notify-send "Focus last notifier" "No window found for: $app"
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
