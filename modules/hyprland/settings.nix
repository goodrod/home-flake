{ config, pkgs, lib, ... }:
let
  option = config.module.hyprland;
in
{
  config = lib.mkIf option.enable {
    wayland.windowManager.hyprland.settings = {
      monitor = lib.mkMerge [
        (lib.mkIf option.monitors.left.enable
          ["${option.monitors.left.name},${option.monitors.left.settings}"])
        (lib.mkIf option.monitors.middle.enable [
          "${option.monitors.middle.name},${option.monitors.middle.settings}"
        ])
        (lib.mkIf option.monitors.right.enable [
          "${option.monitors.right.name},${option.monitors.right.settings}"
        ])
        ["Unknown-1,disable"]
      ];

      "$terminal" = "alacritty";
      "$menu" = "fuzzel";
      "$monitor-1" = "${option.monitors.left.name}";
      "$monitor-2" = "${option.monitors.middle.name}";
      "$monitor-3" = "${option.monitors.right.name}";
      "$mainMod" = "SUPER";

      general = {
        gaps_in = 3;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = "rgba(cdd6f4ee) rgba(89dcebee) 45deg";
        "col.inactive_border" = "rgba(404A60aa)";
        resize_on_border = false;
        allow_tearing = false;
        layout = "master";
      };

      master = {
        orientation = "left";
        new_status = "master";
      };

      cursor = { no_hardware_cursors = true; };

      input = {
        kb_layout = "se";
        kb_variant = "";
        kb_model = "";
        kb_options = "";
        kb_rules = "";
        follow_mouse = 2;
        float_switch_override_focus = 0;
        sensitivity = 0;
        touchpad = { natural_scroll = false; };
      };

      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
      ];

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = false;
      };

      ecosystem = {
        no_update_news = true;
        no_donation_nag = true;
      };

      debug.disable_logs = false;
    };
  };
}
