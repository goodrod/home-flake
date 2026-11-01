{ config, pkgs, lib, ... }:
let
  settings = config.module.hyprland;
  scripts = import ../scripts.nix { inherit pkgs; };
  notifFocusScripts = import ../notif-focus-scripts.nix { inherit pkgs; };
  lockCmd = if settings.lockscreen == "swaylock" then "/usr/bin/swaylock" else "hyprlock";

  monitorFocusLines = lib.concatStringsSep "\n      " (
    map (m: ''hl.bind(mainMod .. " + ${m.focusKey}", function() focusMonitor("${m.name}") end, { description = "Focus monitor ${m.name}" })'')
      (lib.filter (m: m.enable && m.focusKey != null) (lib.attrValues settings.monitors))
  );

  # clampToFullWidthIfPortrait is defined by columns.nix, see its comment on
  # why monitor focus drives it rather than a monitor.focused hook.
  clampAfterFocus = lib.optionalString settings.features.columnTools.enable
    "local w = hl.get_active_window()\n  clampToFullWidthIfPortrait(w and w.monitor)";
in
{
  config = lib.mkIf settings.enable {
    module.hyprland.luaConfig = lib.mkOrder 300 ''
      -- Scrolling layout
      hl.bind(mainMod .. " + Tab", hl.dsp.layout("move +col"), { description = "Scroll window forward" })
      hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.layout("move -col"), { description = "Scroll window backward" })
      hl.bind(mainMod .. " + U", hl.dsp.window.center(), { description = "Center focused window" })
      hl.bind(mainMod .. " + SHIFT + up",   hl.dsp.window.resize({ x = 0, y = -80, relative = true }), { description = "Shrink window height" })
      hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.resize({ x = 0, y = 80,  relative = true }), { description = "Grow window height" })

      -- Launch / kill
      hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("alacritty"), { description = "Launch terminal on console workspace" })
      hl.bind(mainMod .. " + CTRL + space", hl.dsp.exec_cmd("[workspace unset] alacritty"), { description = "Launch terminal on current workspace" })
      hl.bind(mainMod .. " + C", hl.dsp.window.close(), { description = "Close active window" })
      hl.bind(mainMod .. " + SHIFT + L", function()
        hl.dispatch(hl.dsp.exec_cmd("playerctl -a pause; ${lockCmd}"))
      end, { description = "Lock screen" })
      hl.bind(mainMod .. " + F12", hl.dsp.exit(), { description = "Exit Hyprland" })
      hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })

      -- App toggles
      hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("${scripts.toggleMenu}"), { description = "Toggle menu" })
      hl.bind(mainMod .. " + CTRL + D", hl.dsp.exec_cmd("${scripts.toggleMenuCurrentWs}"), { description = "Toggle menu, launch on current workspace" })
      hl.bind(mainMod .. " + escape", hl.dsp.exec_cmd("${scripts.toggleWindow} :;"), { description = "Toggle window" })
      hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("${scripts.toggleWindow} bluetuith"), { description = "Toggle Bluetooth" })
      hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("${scripts.toggleWindow} pulsemixer"), { description = "Toggle Pulse audio mixer" })
      hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("${scripts.toggleWindow} htop"), { description = "Toggle htop" })
      hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("${notifFocusScripts.focusLastNotifApp}"), { description = "Jump to newest notification and clear it, one per press" })
      hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("${notifFocusScripts.notifCenterToggle}"), { description = "Toggle notification center (k/l move, enter jump, x dismiss, c clear, esc close)" })
      hl.bind(mainMod .. " + CTRL + N", hl.dsp.exec_cmd("${notifFocusScripts.notifClearAll}"), { description = "Dismiss all notifications" })
      hl.bind(mainMod .. " + H", hl.dsp.exec_cmd('${scripts.toggleWindow} "${scripts.parseHotkeys} | fzf"'), { description = "Toggle window" })

      -- Screenshot / recording
      hl.bind(mainMod .. " + F7", hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'), { description = "Take screenshot" })
      hl.bind(mainMod .. " + F8", hl.dsp.exec_cmd([[sh -c 'pidf=/tmp/wf-recorder-clip.pid; outdir=$HOME/Videos; mkdir -p "$outdir"; if [ -s "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; then kill -INT "$(cat "$pidf")"; exit; fi; f="$outdir/recording-$(date +%F_%H-%M-%S).mp4"; wf-recorder -g "$(slurp)" -f "$f" & pid=$!; echo "$pid" > "$pidf"; wait "$pid"; rm -f "$pidf"; printf "file://%s\n" "$(realpath "$f")" | wl-copy --type text/uri-list']]), { description = "Toggle record region to clipboard" })

      -- Fullscreen
      hl.bind(mainMod .. " + A", hl.dsp.window.fullscreen({mode = "fullscreen"}), { description = "Toggle fullscreen" })

      -- Privacy
      local noShareDefaults = { discord = true, vesktop = true, Slack = true }
      hl.on("window.open", function(w)
        if w == nil or not noShareDefaults[w.class] then return end
        local target = "address:" .. w.address
        hl.dispatch(hl.dsp.window.set_prop({ window = target, prop = "no_screen_share", value = "true" }))
        hl.dispatch(hl.dsp.window.set_prop({ window = target, prop = "active_border_color", value = "rgb(f38ba8)" }))
        hl.dispatch(hl.dsp.window.set_prop({ window = target, prop = "inactive_border_color", value = "rgba(f38ba888)" }))
      end)
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("${scripts.toggleNoShare}"), { description = "Toggle screen-share exclusion for focused window" })

      -- Monitor focus
      local function focusMonitor(name)
        hl.dispatch(hl.dsp.focus({ monitor = name }))
        ${clampAfterFocus}
      end
      ${monitorFocusLines}

      -- Move window
      hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.move({direction = "l"}), { description = "Move window l" })
      hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({direction = "r"}), { description = "Move window r" })
      hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.move({direction = "u"}), { description = "Move window u" })
      hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.move({direction = "d"}), { description = "Move window d" })

      -- Move focus. The general focus({direction}) dispatcher falls back to a
      -- geometric nearest-window search that can cross monitors; the scrolling
      -- layout's own "focus" message wraps within the layout instead of
      -- jumping to a neighboring monitor.
      hl.bind(mainMod .. " + left", hl.dsp.layout("focus l"), { description = "Move focus l" })
      hl.bind(mainMod .. " + right", hl.dsp.layout("focus r"), { description = "Move focus r" })
      hl.bind(mainMod .. " + up", hl.dsp.layout("focus u"), { description = "Move focus u" })
      hl.bind(mainMod .. " + down", hl.dsp.layout("focus d"), { description = "Move focus d" })

      -- Execute command
      hl.bind(mainMod .. " + SHIFT + CTRL + C", hl.dsp.exec_cmd("bash -c"), { description = "Execute command" })

      -- Mouse binds
      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
      hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({direction = "r"}), { mouse = true })
      hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({direction = "l"}), { mouse = true })
    '';
  };
}
