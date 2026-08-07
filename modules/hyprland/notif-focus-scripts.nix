{ pkgs }:
let
  inherit (pkgs) writeScript;
in
{
  notifAppWatcher = writeScript "notif-app-watcher.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    state_file="''${XDG_RUNTIME_DIR:-/tmp}/hypr-last-notif-app"

    stdbuf -oL dbus-monitor --session "interface='org.freedesktop.Notifications',member='Notify'" |
      stdbuf -oL ${pkgs.gawk}/bin/awk '
        # Walk the ancestor chain straight out of /proc, inside awk, the very
        # instant the pid is parsed. A CLI sender like notify-send exits within
        # a millisecond or two of its dbus call, so anything slower loses the
        # race and the chain is unrecoverable (a dead pid has no ppid to read).
        # An earlier version forked `ps` per level from the shell loop below;
        # that cost ~10ms per fork and reliably missed unhinted senders.
        # /proc reads here are fork-free and take microseconds.
        function ancestors(pid,   line, arr, p, i, out, f) {
          out = ""
          p = pid
          for (i = 0; i < 20; i++) {
            if (p == "" || p == "0" || p == "1") break
            out = out (out == "" ? "" : " ") p
            f = "/proc/" p "/stat"
            if ((getline line < f) <= 0) { close(f); break }
            close(f)
            # strip "pid (comm) " - comm may contain spaces and parens, so
            # lean on the greedy .* to land on the last ") " in the field
            sub(/^[0-9]+ \(.*\) /, "", line)
            split(line, arr, " ")
            p = arr[2]
          }
          return out
        }
        /^method call|^signal|^error / {
          state = ($0 ~ /member=Notify/) ? 1 : 0
          app = ""; senderchain = ""; shellchain = ""; wantfield = ""
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
              if (wantfield == "sender") { senderchain = ancestors(a[2]) }
              else { shellchain = ancestors(a[2]) }
            }
            wantfield = ""
            next
          }
          if ($0 ~ /^ *int32 /) {
            chain = shellchain
            if (senderchain != "") { chain = (chain == "" ? "" : chain " ") senderchain }
            print app "\t" chain
            fflush()
            state = 0
          }
        }
      ' |
      while IFS=$'\t' read -r app pids; do
        [ -z "$app" ] && continue

        # First pid in the chain that owns a window wins: the chain is ordered
        # nearest ancestor first, so that is the closest enclosing window.
        resolved_pid=""
        if [ -n "$pids" ]; then
          resolved_pid=$(hyprctl clients -j | jq -r --arg pids "$pids" '
            [.[] | .pid | tostring] as $win
            | first(($pids | split(" "))[] | select(. as $p | $win | index($p))) // ""
          ')
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
    ws_id=""
    address=""

    if [ -n "$resolved_pid" ]; then
      IFS=$'\t' read -r ws_id address <<< "$(jq -r --arg p "$resolved_pid" '
        [.[] | select((.pid|tostring)==$p)] | .[0] | "\(.workspace.id // "")\t\(.address // "")"
      ' <<< "$clients_json")"
    fi

    if [ -z "$ws_id" ]; then
      app_lower=$(tr '[:upper:]' '[:lower:]' <<< "$app")
      IFS=$'\t' read -r ws_id address <<< "$(jq -r --arg a "$app_lower" '
        [.[] | . as $w
          | (($w.class // "") | ascii_downcase) as $cl
          | (($w.initialClass // "") | ascii_downcase) as $icl
          | (($w.title // "") | ascii_downcase) as $tl
          | select(($cl|contains($a)) or ($a|contains($cl)) or ($icl|contains($a)) or ($tl|contains($a)))
        ] | .[0] | "\(.workspace.id // "")\t\(.address // "")"
      ' <<< "$clients_json")"
    fi

    if [ -n "$ws_id" ]; then
      hyprctl dispatch "hl.dsp.focus({ workspace = $ws_id, on_current_monitor = true })"
      if [ -n "$address" ]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$address\" })"
      fi
    else
      notify-send "Focus last notifier" "No window found for: $app"
    fi
  '';
}
