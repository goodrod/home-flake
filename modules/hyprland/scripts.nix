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
    # and records which window sent it, so a hotkey can jump to it later.
    # Daemon-agnostic: this sees the raw Notify call before swaync/dunst/etc
    # ever handles it.
    #
    # app name alone isn't enough: CLI tools like notify-send report their own
    # name ("notify-send"), not whatever shell/terminal invoked them. The
    # sender-pid hint gives the actual PID that made the call, so we walk its
    # process ancestry (pid -> parent -> ...) to find a window. That walk has
    # to happen HERE, immediately, while the sender is still alive: a CLI like
    # notify-send exits within milliseconds, so by the time a hotkey is
    # pressed later `ps` can no longer see it or its parents at all.
    set -euo pipefail
    state_file="''${XDG_RUNTIME_DIR:-/tmp}/hypr-last-notif-app"

    stdbuf -oL dbus-monitor --session "interface='org.freedesktop.Notifications',member='Notify'" |
      stdbuf -oL awk '
        /^method call|^signal|^error / {
          state = ($0 ~ /member=Notify/) ? 1 : 0
          app = ""; pid = ""; wantpid = 0
          next
        }
        state==1 && app=="" {
          if (match($0, /^ *string "(.*)"$/, a)) { app = a[1] }
          next
        }
        state==1 && app!="" {
          if ($0 ~ /string "sender-pid"/) { wantpid = 1; next }
          if (wantpid==1) {
            if (match($0, /(int64|uint32|int32) *([0-9]+)/, a)) { pid = a[2] }
            wantpid = 0
            if (pid != "") { print app "\t" pid; fflush(); state = 0 }
          }
        }
      ' |
      while IFS=$'\t' read -r app pid; do
        [ -z "$app" ] && continue

        # Collect the whole ancestor chain via ps FIRST, as fast as possible:
        # a CLI sender like notify-send can exit within milliseconds of
        # making its call, and the hyprctl clients -j lookup below is slow
        # enough (forks hyprctl, serializes every window) that by the time
        # we'd get to it the sender (and even its parent) may already be
        # gone, making `ps` on it useless. Collecting pids up front and
        # matching against the window list afterwards sidesteps that: the
        # window's own pid is long-lived regardless of how slow the lookup is.
        pids="$pid"
        cur="$pid"
        if [ -n "$cur" ]; then
          for _ in $(seq 1 15); do
            parent=$(ps -o ppid= -p "$cur" 2>/dev/null | tr -d ' ') || true
            [ -z "$parent" ] || [ "$parent" = "1" ] && break
            pids="$pids $parent"
            cur="$parent"
          done
        fi

        resolved_pid=""
        if [ -n "$pids" ]; then
          clients_json=$(hyprctl clients -j)
          for p in $pids; do
            if jq -e --arg p "$p" 'any(.[]; (.pid|tostring)==$p)' <<< "$clients_json" >/dev/null; then
              resolved_pid="$p"
              break
            fi
          done
        fi

        printf "%s\t%s\n" "$app" "$resolved_pid" > "$state_file"
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

    IFS=$'\t' read -r app resolved_pid < "$state_file" || true
    clients_json=$(hyprctl clients -j)
    addr=""

    if [ -n "$resolved_pid" ]; then
      addr=$(jq -r --arg p "$resolved_pid" '[.[] | select((.pid|tostring)==$p)] | .[0].address // empty' <<< "$clients_json")
    fi

    if [ -z "$addr" ]; then
      app_lower=$(tr '[:upper:]' '[:lower:]' <<< "$app")
      addr=$(jq -r --arg a "$app_lower" '
        [.[] | . as $w
          | (($w.class // "") | ascii_downcase) as $cl
          | (($w.initialClass // "") | ascii_downcase) as $icl
          | (($w.title // "") | ascii_downcase) as $tl
          | select(($cl|contains($a)) or ($a|contains($cl)) or ($icl|contains($a)) or ($tl|contains($a)))
        ] | .[0].address // empty
      ' <<< "$clients_json")
    fi

    if [ -n "$addr" ]; then
      hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })"
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
