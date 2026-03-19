{ config, pkgs, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types mkIf concatMapStringsSep;
  cfg = config.module.hyprpaper;
  wallpaperPath = "${config.home.homeDirectory}/${cfg.wallpaper-output-directory}/wallpaper.png";
in {
  options.module.hyprpaper = {
    enable = mkEnableOption "hyprpaper";

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
    home.packages = [ pkgs.hyprpaper ];
    home.file."${cfg.wallpaper-output-directory}" = {
      source = "${cfg.wallpaper-source-directory}";
      recursive = true;
    };
    home.file.".config/hypr/hyprpaper.conf".text = ''
      preload = ${wallpaperPath}
      ${concatMapStringsSep "\n" (m: "wallpaper = ${m},${wallpaperPath}") cfg.monitors}
      splash = false
    '';
  };
}
