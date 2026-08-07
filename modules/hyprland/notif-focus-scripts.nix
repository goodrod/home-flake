{ pkgs }:
let
  inherit (pkgs) writeScript writeShellScriptBin;
in
{
  # Shadows libnotify's notify-send on PATH. Records the caller's ancestor
  # chain at send time and hands it to the watcher as an x-pid-chain hint,
  # which is what lets mod+N map a notification back to a window. Capturing
  # here is exact: $PPID and its ancestors cannot be gone while we run,
  # whereas the sender itself is often dead by the time the watcher sees the
  # dbus message.
  notifySendWrapper = writeShellScriptBin "notify-send" ''
    real=${pkgs.libnotify}/bin/notify-send

    # caller already supplied a chain (or is the wrapper re-entering): pass through
    case " $* " in
      *" --hint=string:x-pid-chain:"*) exec "$real" "$@" ;;
    esac

    chain=""
    p=$PPID
    i=0
    while [ "$i" -lt 20 ]; do
      i=$((i + 1))
      case "$p" in ""|0|1) break ;; esac
      chain="''${chain:+$chain }$p"
      [ -r "/proc/$p/stat" ] || break
      line=$(< "/proc/$p/stat")
      # strip "pid (comm) ", comm may hold spaces and parens; then ppid is
      # the second remaining field (after state)
      rest=''${line##*') '}
      rest=''${rest#* }
      p=''${rest%% *}
    done

    if [ -n "$chain" ]; then
      exec "$real" --hint=string:x-pid-chain:"$chain" "$@"
    fi
    exec "$real" "$@"
  '';

  notifAppWatcher = writeScript "notif-app-watcher.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    state_file="''${XDG_RUNTIME_DIR:-/tmp}/hypr-last-notif-app"

    stdbuf -oL dbus-monitor --session "interface='org.freedesktop.Notifications',member='Notify'" |
      stdbuf -oL ${pkgs.gawk}/bin/awk '
        # Fallback chain for senders that skip the notify-send wrapper. Runs
        # inside awk, off /proc, the instant the pid is parsed: fork-free and
        # microseconds, which it has to be. A CLI sender exits a millisecond
        # or two after its dbus call and a dead pid has no ppid left to read,
        # so anything slower gets an unusable chain.
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
          app = ""; senderchain = ""; shellchain = ""; hintchain = ""; wantfield = ""
          next
        }
        state==1 && app=="" {
          if (match($0, /^ *string "(.*)"$/, a)) { app = a[1] }
          next
        }
        state==1 && app!="" {
          if ($0 ~ /string "x-pid-chain"/) { wantfield = "chain"; next }
          if ($0 ~ /string "sender-pid"/) { wantfield = "sender"; next }
          if ($0 ~ /string "x-shell-pid"/) { wantfield = "shell"; next }
          if (wantfield != "") {
            if (wantfield == "chain") {
              if (match($0, /string "(.*)"$/, a)) { hintchain = a[1] }
            } else if (match($0, /(int64|uint32|int32) *([0-9]+)/, a)) {
              if (wantfield == "sender") { senderchain = ancestors(a[2]) }
              else { shellchain = ancestors(a[2]) }
            }
            wantfield = ""
            next
          }
          if ($0 ~ /^ *int32 /) {
            # hinted chain first: captured by the notify-send wrapper while the
            # whole chain was alive, so it beats anything reconstructed here
            chain = hintchain
            if (shellchain != "") { chain = (chain == "" ? "" : chain " ") shellchain }
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
