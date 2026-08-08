{ pkgs }:
let
  inherit (pkgs) writeScript writeShellScriptBin;

  # Quickshell owns the notification center, so clearing has to go through its
  # IPC. `qs` is only on PATH when the quickshell module is enabled, hence the
  # guard: with dunst/swaync instead, these are no-ops rather than errors.
  notifIpc = ''
    qs_notif_ipc() {
      command -v qs >/dev/null 2>&1 || return 0
      qs -c bar ipc call notifs "$@" >/dev/null 2>&1 || true
    }
    # Same call, but hands back what the IPC function returned.
    qs_notif_ipc_out() {
      command -v qs >/dev/null 2>&1 || return 0
      qs -c bar ipc call notifs "$@" 2>/dev/null || true
    }
  '';
in
{
  # Shadows libnotify's notify-send on PATH. Its whole job is to record the
  # caller's ancestor chain at send time, while every process in it is still
  # alive, and hand it to the watcher as a hint. The watcher can walk /proc
  # itself, but a bare `notify-send foo` exits a millisecond or two after its
  # dbus call, so that walk is a race the watcher can lose. Here there is no
  # race: $PPID is the caller and it cannot be gone while we run.
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

  notifCenterToggle = writeScript "notif-center-toggle.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    ${notifIpc}
    qs_notif_ipc toggle
  '';

  notifClearAll = writeScript "notif-clear-all.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    ${notifIpc}
    qs_notif_ipc clear
  '';

  # Walks the notification stack one entry per press: jump to the newest
  # notification whose sender still has a window, dismiss that one entry, and
  # let quickshell replay its text as a banner. The next press lands on the
  # next entry down. Entries whose sender is gone are skipped rather than
  # dismissed, so a press never destroys something you have not seen.
  #
  # With a notification id as $1 the walk is narrowed to that one entry: that
  # is how the notification center's own "jump to the marked entry" key gets
  # here, so the user picks the target instead of taking the top of the stack.
  #
  # Quickshell's history is the stack. The dbus watcher's state file is only
  # the fallback for when quickshell is not the notification daemon, and it
  # only ever remembers the single latest notification.
  focusLastNotifApp = writeScript "focus-last-notif-app.sh" ''
    #!/usr/bin/env bash
    set -euo pipefail
    ${notifIpc}
    state_file="''${XDG_RUNTIME_DIR:-/tmp}/hypr-last-notif-app"

    target_id="''${1:-}"
    case "$target_id" in
      ""|*[!0-9]*) target_id="" ;;
    esac

    clients_json=$(hyprctl clients -j)

    # "workspace id<tab>address" of the first pid in the chain that owns a
    # window. The chain runs nearest-ancestor first, so that is the closest
    # enclosing window (the terminal, not the login shell).
    resolve_by_pids() {
      [ -n "$1" ] || return 0
      jq -r --arg pids "$1" '
        [.[] | {p: (.pid|tostring), ws: (.workspace.id // ""), addr: (.address // "")}] as $wins
        | first(($pids | split(" "))[] | . as $p | ($wins[] | select(.p == $p)))
        | "\(.ws)\t\(.addr)"
      ' <<< "$clients_json"
    }

    # Fallback for senders that never identified a pid: match the dbus
    # app_name against window class/title.
    resolve_by_app() {
      local app_lower
      app_lower=$(tr '[:upper:]' '[:lower:]' <<< "$1")
      [ -n "$app_lower" ] || return 0
      jq -r --arg a "$app_lower" '
        [.[] | . as $w
          | (($w.class // "") | ascii_downcase) as $cl
          | (($w.initialClass // "") | ascii_downcase) as $icl
          | (($w.title // "") | ascii_downcase) as $tl
          | select(($cl|contains($a)) or ($a|contains($cl)) or ($icl|contains($a)) or ($tl|contains($a)))
        ] | .[0] | "\(.workspace.id // "")\t\(.address // "")"
      ' <<< "$clients_json"
    }

    focus_window() {
      hyprctl dispatch "hl.dsp.focus({ workspace = $1, on_current_monitor = true })"
      if [ -n "$2" ]; then
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$2\" })"
      fi
    }

    # Anything but a JSON array means quickshell is not answering (not
    # installed, not running, older config), so fall through to the watcher.
    entries=$(qs_notif_ipc_out list)
    if ! jq -e 'type == "array"' >/dev/null 2>&1 <<< "$entries"; then
      entries=""
    fi

    # A targeted jump only ever means something against quickshell's history,
    # so it never falls through to the watcher's single last-seen entry - that
    # would jump somewhere the user did not point at.
    if [ -n "$target_id" ]; then
      if [ -z "$entries" ]; then
        exit 0
      fi
      entries=$(jq -c --argjson id "$target_id" '[.[] | select(.id == $id)]' <<< "$entries")
      if [ "$(jq 'length' <<< "$entries")" -eq 0 ]; then
        qs_notif_ipc banner "Nothing to jump to" "That notification is already gone"
        exit 0
      fi
    fi

    if [ -n "$entries" ]; then
      total=$(jq 'length' <<< "$entries")

      if [ "$total" -eq 0 ]; then
        qs_notif_ipc banner "Nothing to jump to" ""
        exit 0
      fi

      i=0
      while [ "$i" -lt "$total" ]; do
        entry=$(jq -c ".[$i]" <<< "$entries")
        id=$(jq -r '.id' <<< "$entry")
        app=$(jq -r '.app // ""' <<< "$entry")
        pids=$(jq -r '.pids // [] | join(" ")' <<< "$entry")

        ws_id=""
        address=""
        IFS=$'\t' read -r ws_id address <<< "$(resolve_by_pids "$pids")" || true
        if [ -z "$ws_id" ]; then
          IFS=$'\t' read -r ws_id address <<< "$(resolve_by_app "$app")" || true
        fi

        if [ -n "$ws_id" ]; then
          focus_window "$ws_id" "$address"
          # Dismisses this one entry and flashes its text on the monitor you
          # just landed on, so the message survives the dismiss.
          qs_notif_ipc jumpedTo "$id"
          exit 0
        fi

        i=$((i + 1))
      done

      # A banner, not a notification: a notification here would itself join
      # the stack, and its sender (this script, spawned by Hyprland) owns no
      # window, so it could never be jumped to and cleared.
      if [ "$total" -eq 1 ]; then
        left="1 notification is left, its sender has no window open"
      else
        left="$total notifications are left, none of their senders have a window open"
      fi
      qs_notif_ipc banner "Nothing to jump to" "$left"
      exit 0
    fi

    # Fallback: no quickshell, so all we have is the watcher's last-seen entry.
    if [ ! -s "$state_file" ]; then
      notify-send "Focus last notifier" "No notification seen yet"
      exit 0
    fi

    IFS=$'\t' read -r app resolved_pid < "$state_file" || true
    ws_id=""
    address=""

    if [ -n "$resolved_pid" ]; then
      IFS=$'\t' read -r ws_id address <<< "$(resolve_by_pids "$resolved_pid")" || true
    fi
    if [ -z "$ws_id" ]; then
      IFS=$'\t' read -r ws_id address <<< "$(resolve_by_app "$app")" || true
    fi

    if [ -n "$ws_id" ]; then
      focus_window "$ws_id" "$address"
    else
      notify-send "Focus last notifier" "No window found for: $app"
    fi
  '';
}
