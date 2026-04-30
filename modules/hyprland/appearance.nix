{ config, pkgs, lib, ... }:
let
  option = config.module.hyprland;
in
{
  config = lib.mkIf option.enable {
    home.pointerCursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 16;
    };

    gtk = {
      enable = true;
      theme = {
        package = pkgs.flat-remix-gtk;
        name = "Flat-Remix-GTK-Grey-Darkest";
      };
      iconTheme = {
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
      };
      font = {
        name = "Sans";
        size = 11;
      };
    };

    wayland.windowManager.hyprland.settings = {
      group = {
        group_on_movetoworkspace = true;
        groupbar = {
          enabled = true;
          height = 22;
          font_size = 11;
          font_family = "JetBrains Mono";
          font_weight_active = "bold";
          font_weight_inactive = "normal";

          render_titles = true;
          text_offset = 1;
          text_color = "0xff181825";
          text_color_inactive = "0x99cdd6f4";
          text_color_locked_active = "0xff181825";
          text_color_locked_inactive = "0x99cdd6f4";

          gradients = true;
          rounding = 6;
          gradient_rounding = 6;
          round_only_edges = true;
          gradient_round_only_edges = true;

          indicator_gap = -22;
          indicator_height = 22;
          gaps_in = 3;
          gaps_out = 3;
          keep_upper_gap = true;

          scrolling = true;
          stacked = false;

          "col.active" = "rgba(89dcebff) rgba(cba6f7ff) 90deg";
          "col.inactive" = "rgba(404A60dd) rgba(404A60dd) 90deg";
          "col.locked_active" = "rgba(DDC062ff) rgba(FF9F81ff) 90deg";
          "col.locked_inactive" = "rgba(DDC062aa) rgba(FF9F81aa) 90deg";
        };
      };

      decoration = {
        rounding = 10;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };
      };

      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 3, myBezier"
          "windowsOut, 1, 3, default, popin 80%"
          "border, 1, 1, default"
          "borderangle, 1, 3, default"
          "fade, 1, 1, default"
          "workspaces, 1, 3, default"
        ];
      };
    };
  };
}
