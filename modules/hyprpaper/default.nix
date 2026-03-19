{ config, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types mkIf map;
  cfg = config.module.hyprpaper;
  wallpaperPath = "${config.home.homeDirectory}/${cfg.wallpaper-output-directory}/${cfg.wallpaper}";
in {
  options.module.hyprpaper = {
    enable = mkEnableOption "hyprpaper";

    wallpaper = mkOption {
      type = types.str;
      default = "wallpaper.png";
      description = "Filename of the wallpaper to use from the wallpaper directory.";
    };

    monitors = mkOption {
      default = [];
      type = types.listOf types.str;
      description = "List of monitor names to apply wallpaper to.";
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
    services.hyprpaper = {
      enable = true;
      settings = {
        splash = false;
        preload = [ wallpaperPath ];
        wallpaper = map (m: { monitor = m; path = wallpaperPath; }) cfg.monitors;
      };
    };
  };
}
