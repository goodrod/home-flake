{ config, pkgs, lib, ... }:
let
  option = config.module.hyprland;
  scripts = import ./scripts.nix { inherit pkgs; };
  lockCmd = if option.lockscreen == "swaylock" then "/usr/bin/swaylock" else "hyprlock";

  mon1 = option.monitors.left.name;
  mon2 = option.monitors.middle.name;
  mon3 = option.monitors.right.name;
in
{
  config = lib.mkIf option.enable {
    module.hyprland.luaConfig = lib.mkOrder 300 ''
      -- ══════════════════════════════════════
      -- Keybinds
      -- ══════════════════════════════════════
      local mainMod = "SUPER"

      -- Scrolling layout
      local colWidths = { 0.25, 0.333, 0.5, 1.0 }
      local colWidthIdx = 1
      local fitVisible = false
      hl.bind(mainMod .. " + Tab", hl.dsp.layout("move +col"), { description = "Scroll window forward" })
      hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.layout("move -col"), { description = "Scroll window backward" })
      hl.bind(mainMod .. " + I", hl.dsp.layout("colresize +conf"), { description = "Cycle column width" })
      hl.bind(mainMod .. " + SHIFT + I", hl.dsp.layout("colresize -conf"), { description = "Cycle column width back" })
      hl.bind(mainMod .. " + plus", hl.dsp.layout("fit visible"), { description = "Fit all visible columns" })
      hl.bind(mainMod .. " + SHIFT + plus", hl.dsp.layout("fit active"), { description = "Fit active column" })
      hl.bind(mainMod .. " + U", function()
        fitVisible = not fitVisible
        if fitVisible then
          hl.dispatch(hl.dsp.layout("fit visible"))
        else
          local w = hl.get_active_window()
          hl.dispatch(hl.dsp.layout("colresize all " .. colWidths[colWidthIdx]))
          if w ~= nil then hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address })) end
        end
      end, { description = "Toggle fit visible / normal column widths" })
      hl.bind(mainMod .. " + SHIFT + CTRL + left", hl.dsp.layout("swapcol l"), { description = "Swap column left" })
      hl.bind(mainMod .. " + SHIFT + CTRL + right", hl.dsp.layout("swapcol r"), { description = "Swap column right" })
      hl.bind(mainMod .. " + P", hl.dsp.layout("promote"), { description = "Promote to own column" })

      -- Launch / kill
      hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("alacritty"), { description = "Launch terminal" })
      hl.bind(mainMod .. " + ALT + space", hl.dsp.exec_cmd("[workspace unset] alacritty"), { description = "Launch terminal" })
      hl.bind(mainMod .. " + C", hl.dsp.window.close(), { description = "Close active window" })
      hl.bind(mainMod .. " + SHIFT + L", function()
        hl.dispatch(hl.dsp.exec_cmd("playerctl -a pause; ${lockCmd}"))
      end, { description = "Lock screen" })
      hl.bind(mainMod .. " + F12", hl.dsp.exit(), { description = "Exit Hyprland" })
      hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })

      -- App toggles
      hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("${scripts.toggleMenu}"), { description = "Toggle menu" })
      hl.bind(mainMod .. " + escape", hl.dsp.exec_cmd("${scripts.toggleWindow} :;"), { description = "Toggle window" })
      hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("${scripts.toggleWindow} bluetuith"), { description = "Toggle Bluetooth" })
      hl.bind(mainMod .. " + s", hl.dsp.exec_cmd("${scripts.toggleWindow} spotify_player"), { description = "Toggle Spotify player" })
      hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("${scripts.toggleWindow} pulsemixer"), { description = "Toggle Pulse audio mixer" })
      hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("${scripts.toggleWindow} htop"), { description = "Toggle htop" })
      hl.bind(mainMod .. " + G", hl.dsp.exec_cmd("${scripts.toggleWindow} chatgpt"), { description = "Toggle ChatGPT" })

      local function cycleColWidth(dir)
        fitVisible = false
        colWidthIdx = ((colWidthIdx - 1 + dir + #colWidths) % #colWidths) + 1
        local w = hl.get_active_window()
        hl.dispatch(hl.dsp.layout("colresize all " .. colWidths[colWidthIdx]))
        if w ~= nil then hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address })) end
      end
      hl.bind(mainMod .. " + O", function() cycleColWidth(1) end, { description = "Cycle all column widths forward" })
      hl.bind(mainMod .. " + SHIFT + O", function() cycleColWidth(-1) end, { description = "Cycle all column widths back" })
      hl.bind(mainMod .. " + H", hl.dsp.exec_cmd('${scripts.toggleWindow} "${scripts.parseHotkeys} | fzf"'), { description = "Toggle window" })

      -- Screenshot / recording
      hl.bind(mainMod .. " + F7", hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'), { description = "Take screenshot" })
      hl.bind(mainMod .. " + F8", hl.dsp.exec_cmd([[sh -c 'pidf=/tmp/wf-recorder-clip.pid; outdir=$HOME/Videos; mkdir -p "$outdir"; if [ -s "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; then kill -INT "$(cat "$pidf")"; exit; fi; f="$outdir/recording-$(date +%F_%H-%M-%S).mp4"; wf-recorder -g "$(slurp)" -f "$f" & pid=$!; echo "$pid" > "$pidf"; wait "$pid"; rm -f "$pidf"; printf "file://%s\n" "$(realpath "$f")" | wl-copy --type text/uri-list']]), { description = "Toggle record region to clipboard" })

      -- Fullscreen
      hl.bind(mainMod .. " + A", hl.dsp.window.fullscreen({mode = "fullscreen"}), { description = "Toggle fullscreen" })

      -- Monitor focus
      hl.bind(mainMod .. " + F3", hl.dsp.focus({monitor = "${mon1}"}), { description = "Focus monitor ${mon1}" })
      hl.bind(mainMod .. " + F4", hl.dsp.focus({monitor = "${mon2}"}), { description = "Focus monitor ${mon2}" })
      hl.bind(mainMod .. " + F5", hl.dsp.focus({monitor = "${mon3}"}), { description = "Focus monitor ${mon3}" })

      -- Move window
      hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.move({direction = "l"}), { description = "Move window l" })
      hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({direction = "r"}), { description = "Move window r" })
      hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.move({direction = "u"}), { description = "Move window u" })
      hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.move({direction = "d"}), { description = "Move window d" })

      -- Move focus
      hl.bind(mainMod .. " + left", hl.dsp.focus({direction = "l"}), { description = "Move focus l" })
      hl.bind(mainMod .. " + right", hl.dsp.focus({direction = "r"}), { description = "Move focus r" })
      hl.bind(mainMod .. " + up", hl.dsp.focus({direction = "u"}), { description = "Move focus u" })
      hl.bind(mainMod .. " + down", hl.dsp.focus({direction = "d"}), { description = "Move focus d" })

      -- Special workspaces (ALT + 0-9)
      ${lib.concatStringsSep "\n" (map (n: ''hl.bind(mainMod .. " + ALT + ${toString n}", hl.dsp.workspace.toggle_special("${toString n}"), { description = "Toggle special WS ${toString n}" })'') (lib.range 0 9))}

      -- Move to special workspaces (ALT + CTRL + 0-9)
      ${lib.concatStringsSep "\n" (map (n: ''hl.bind(mainMod .. " + ALT + CTRL + ${toString n}", hl.dsp.window.move({workspace = "special:${toString n}"}), { description = "Move to WS special:${toString n}" })'') (lib.range 0 9))}

      -- Workspaces (1-0 -> 10,20..100)
      ${lib.concatStringsSep "\n" (map (n:
        let ws = toString (n * 10); key = toString (lib.mod n 10);
        in ''hl.bind(mainMod .. " + ${key}", hl.dsp.focus({workspace = ${ws}, on_current_monitor = true}), { description = "Focus WS ${ws} on current monitor" })''
      ) (lib.range 1 10))}

      -- Move to workspaces (CTRL + 1-0 -> 10,20..100)
      ${lib.concatStringsSep "\n" (map (n:
        let ws = toString (n * 10); key = toString (lib.mod n 10);
        in ''hl.bind(mainMod .. " + CTRL + ${key}", hl.dsp.window.move({workspace = ${ws}, follow = false}), { description = "Move to WS ${ws}" })''
      ) (lib.range 1 10))}

      -- Shift workspaces (SHIFT + 1-0 -> 11,21..101)
      ${lib.concatStringsSep "\n" (map (n:
        let ws = toString (n * 10 + 1); key = toString (lib.mod n 10);
        in ''hl.bind(mainMod .. " + SHIFT + ${key}", hl.dsp.focus({workspace = ${ws}, on_current_monitor = true}), { description = "Focus WS ${ws} on current monitor" })''
      ) (lib.range 1 10))}

      -- Move to shift workspaces (SHIFT + CTRL + 1-0 -> 11,21..101)
      ${lib.concatStringsSep "\n" (map (n:
        let ws = toString (n * 10 + 1); key = toString (lib.mod n 10);
        in ''hl.bind(mainMod .. " + SHIFT + CTRL + ${key}", hl.dsp.window.move({workspace = ${ws}, follow = false}), { description = "Move to WS ${ws}" })''
      ) (lib.range 1 10))}

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
