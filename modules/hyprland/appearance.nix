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
      plugin.hyprbars = {
        bar_height = 22;
        bar_color = "rgba(404A60dd)";
        bar_text_size = 11;
        bar_text_font = "JetBrains Mono";
        bar_text_align = "center";
        bar_part_of_window = true;
        bar_precedence_over_border = true;
        "col.text" = "0xffcdd6f4";
        "hyprbars-button" = [
          "rgb(ff4040), 12, 󰖭, hyprctl dispatch killactive"
          "rgb(eeee11), 12, , hyprctl dispatch fullscreen 1"
        ];
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
