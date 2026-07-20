{ pkgs }:
let
  inherit (pkgs) writeScript;
in
{
  notifAppWatcher = writeScript "notif-app-watcher.sh" ''
    #!/usr/bin/env bash
    # Eavesdrops org.freedesktop.Notifications.Notify calls on the session bus
    # and records which window sent it, so a hotkey can jump to it later.
    # Daemon-agnostic: this sees the raw Notify call before swaync/dunst/etc
    # ever handles it.
    #
    # app name alone isn't enough: CLI tools like notify-send report their own
    # name ("notify-send"), not whatever shell/terminal invoked them. The
    # sender-pid hint gives the actual PID that made the call, so we'd like to
    # walk its process ancestry (pid -> parent -> ...) to find a window. But
    # that race is unwinnable in practice: notify-send is a synchronous glib
    # dbus call that returns and exits essentially instantly, while this
    # daemon only sees the event after it's relayed through dbus-monitor and
    # an awk pipe, by which point `ps` on the sender pid already finds
    # nothing (confirmed empirically, not hypothetical). So the bash wrapper
    # around notify-send (see modules/bash) stamps an "x-shell-pid" hint with
    # the *interactive shell's* pid, which stays alive indefinitely, and we
    # prefer that as the ancestry-walk starting point when present.
    set -euo pipefail
    state_file="''${XDG_RUNTIME_DIR:-/tmp}/hypr-last-notif-app"

    stdbuf -oL dbus-monitor --session "interface='org.freedesktop.Notifications',member='Notify'" |
      stdbuf -oL awk '
        /^method call|^signal|^error / {
          state = ($0 ~ /member=Notify/) ? 1 : 0
          app = ""; senderpid = ""; shellpid = ""; wantfield = ""
          next
        }
        state==1 && app=="" {
          if (match($0, /^ *string "(.*)"$/, a)) { app = a[1] }
          next
        }
        state==1 && app!="" {
          if ($0 ~ /string "sender-pid"/) { wantfield = "sender"; next }
          if ($0 ~ /string "x-shell-pid"/) { wantfield = "shell"; next }
          if (wantfield != "") {
            if (match($0, /(int64|uint32|int32) *([0-9]+)/, a)) {
              if (wantfield == "sender") { senderpid = a[2] } else { shellpid = a[2] }
            }
            wantfield = ""
            next
          }
          if ($0 ~ /^ *int32 /) {
            print app "\t" senderpid "\t" shellpid
            fflush()
            state = 0
          }
        }
      ' |
      while IFS=$'\t' read -r app senderpid shellpid; do
        [ -z "$app" ] && continue

        # Prefer x-shell-pid (guaranteed still alive) over sender-pid (often
        # already reaped by the time we get here) as the ancestry-walk start.
        start_pid="$senderpid"
        [ -n "$shellpid" ] && start_pid="$shellpid"

        # Collect the whole ancestor chain via ps FIRST, as fast as possible:
        # a CLI sender like notify-send can exit within milliseconds of
        # making its call, and the hyprctl clients -j lookup below is slow
        # enough (forks hyprctl, serializes every window) that by the time
        # we'd get to it the sender (and even its parent) may already be
        # gone, making `ps` on it useless. Collecting pids up front and
        # matching against the window list afterwards sidesteps that: the
        # window's own pid is long-lived regardless of how slow the lookup is.
        pids="$start_pid"
        cur="$start_pid"
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
}
