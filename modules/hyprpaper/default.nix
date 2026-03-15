{ config, pkgs, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types mkIf;
  inherit (types) path str;
  cfg = config.module.hyprpaper;
  wallpaperPath = "${config.home.homeDirectory}/${cfg.wallpaper-output-directory}/wallpaper.png";
in {
  options.module.hyprpaper = {
    enable = mkEnableOption "hyprpaper";

    wallpaper-source-directory = mkOption {
      default = ./wallpapers;
      type = path;
      description = "Path to the directory containing wallpapers.";
    };

    wallpaper-output-directory = mkOption {
      default = ".config/hyprpaper/wallpapers";
      type = str;
      description = "Output directory relative to home for wallpapers.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.hyprpaper ];
    home.file."${cfg.wallpaper-output-directory}" = {
      source = "${cfg.wallpaper-source-directory}";
      recursive = true;
    };
    home.file.".config/hypr/hyprpaper.conf".text = ''
      preload = ${wallpaperPath}
      wallpaper = ,${wallpaperPath}
      splash = false
    '';
  };
}
