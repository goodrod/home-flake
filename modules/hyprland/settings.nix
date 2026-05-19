{ config, pkgs, lib, ... }:
let
  option = config.module.hyprland;
  scripts = import ./scripts.nix { inherit pkgs; };

  # Parse "preferred,0x0,1.0" into mode, position, scale
  parseMonitorSettings = name: settingsStr:
    let parts = lib.splitString "," settingsStr;
    in ''
      hl.monitor({
        output = "${name}",
        mode = "${builtins.elemAt parts 0}",
        position = "${builtins.elemAt parts 1}",
        scale = ${builtins.elemAt parts 2},
      })
    '';

  monitorLines = lib.concatStringsSep "\n" (
    lib.optional option.monitors.left.enable
      (parseMonitorSettings option.monitors.left.name option.monitors.left.settings)
    ++ lib.optional option.monitors.middle.enable
      (parseMonitorSettings option.monitors.middle.name option.monitors.middle.settings)
    ++ lib.optional option.monitors.right.enable
      (parseMonitorSettings option.monitors.right.name option.monitors.right.settings)
    ++ [ ''
      hl.monitor({
        output = "Unknown-1",
        disabled = true,
      })
    '' ]
  );

  startupLines = lib.concatStringsSep "\n" (
    map (cmd: ''  hl.dispatch(hl.dsp.exec_cmd("${cmd}"))'') option.startup-commands
  );
in
{
  config = lib.mkIf option.enable {
    module.hyprland.luaConfig = lib.mkOrder 100 ''
      -- ══════════════════════════════════════
      -- Monitors
      -- ══════════════════════════════════════
      ${monitorLines}

      -- ══════════════════════════════════════
      -- Environment variables
      -- ══════════════════════════════════════
      hl.env("LIBVA_DRIVER_NAME", "nvidia")
      hl.env("XDG_SESSION_TYPE", "wayland")
      hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
      hl.env("XCURSOR_SIZE", "24")
      hl.env("HYPRCURSOR_SIZE", "24")
      hl.env("XAUTHORITY", os.getenv("HOME") .. "/.Xauthority")

      -- ══════════════════════════════════════
      -- General config
      -- ══════════════════════════════════════
      hl.config({
        general = {
          gaps_in = 3,
          gaps_out = 8,
          border_size = 2,
          ["col.active_border"] = { colors = { "rgba(cdd6f4ee)", "rgba(89dcebee)" }, angle = 45 },
          ["col.inactive_border"] = "rgba(404A60aa)",
          resize_on_border = false,
          allow_tearing = false,
          layout = "scrolling",
        },
        scrolling = {
          column_width = 0.5,
          focus_fit_method = 1,
        },
        cursor = {
          no_hardware_cursors = true,
        },
        input = {
          kb_layout = "se",
          follow_mouse = 2,
          float_switch_override_focus = 0,
          sensitivity = 0,
          touchpad = {
            natural_scroll = false,
          },
        },
        misc = {
          force_default_wallpaper = -1,
        },
        ecosystem = {
          no_update_news = true,
          no_donation_nag = true,
        },
        debug = {
          disable_logs = false,
        },
      })

      -- ══════════════════════════════════════
      -- Autostart
      -- ══════════════════════════════════════
      hl.on("hyprland.start", function()
      ${startupLines}
      end)
    '';
  };
}
