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

    module.hyprland.luaConfig = lib.mkOrder 200 ''
      -- ══════════════════════════════════════
      -- Decoration & Animations
      -- ══════════════════════════════════════
      hl.config({
        decoration = {
          rounding = 10,
          active_opacity = 1.0,
          inactive_opacity = 1.0,
          blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
          },
        },
        animations = {
          enabled = true,
        },
      })

      hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
      hl.curve("easeOutQuart", { type = "bezier", points = { {0.25, 1.0}, {0.5, 1.0} } })

      hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "easeOutQuart" })
      hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "easeOutQuart", style = "popin 80%" })
      hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "easeOutQuart" })
      hl.animation({ leaf = "borderangle", enabled = true, speed = 4, bezier = "easeOutQuart" })
      hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "easeOutQuart" })
      hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOutQuart" })
    '';
  };
}
