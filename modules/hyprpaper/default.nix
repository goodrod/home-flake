{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption mkEnableOption types mkIf optional concatStringsSep;
  cfg = config.module.hyprpaper;
  monitors = config.module.hyprland.monitors;
  wallpaperPath = "${config.home.homeDirectory}/${cfg.wallpaper-output-directory}/${cfg.wallpaper}";
  enabledMonitors =
    map (m: m.name) (lib.filter (m: m.enable) (lib.attrValues monitors));
  wallpaperBlocks =
    if enabledMonitors == []
    then ''
      wallpaper {
        path = ${wallpaperPath}
        fit_mode = cover
      }
    ''
    else concatStringsSep "\n" (map (m: ''
      wallpaper {
        monitor = ${m}
        path = ${wallpaperPath}
        fit_mode = cover
      }
    '') enabledMonitors);
in {
  options.module.hyprpaper = {
    enable = mkEnableOption "hyprpaper";

    wallpaper = mkOption {
      type = types.str;
      default = "wallpaper.png";
      description = "Filename of the wallpaper to use from the wallpaper directory.";
    };

    wallpaper-source-directory = mkOption {
      default = ./wallpapers;
      type = types.path;
      description = "Path to the directory containing wallpapers.";
    };

    wallpaper-output-directory = mkOption {
      default = ".config/hyprpaper/wallpapers";
      type = types.str;
      description = "Output directory relative to home for wallpapers.";
    };
  };

  config = mkIf cfg.enable {
    home.file."${cfg.wallpaper-output-directory}" = {
      source = "${cfg.wallpaper-source-directory}";
      recursive = true;
    };
    xdg.configFile."hypr/hyprpaper.conf".text = ''
      splash = false
      ipc = off
      preload = ${wallpaperPath}
      ${wallpaperBlocks}
    '';
    home.packages = [ pkgs.hyprpaper ];
    module.hyprland.startup-commands = lib.mkAfter [ "hyprpaper &" ];
  };
}
