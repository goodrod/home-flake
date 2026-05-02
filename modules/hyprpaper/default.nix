{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption mkEnableOption mkAfter types mkIf optional concatStringsSep;
  cfg = config.module.hyprpaper;
  monitors = config.module.hyprland.monitors;
  wallpaperPath = "${config.home.homeDirectory}/${cfg.wallpaper-output-directory}/${cfg.wallpaper}";
  enabledMonitorNames =
    optional monitors.left.enable monitors.left.name
    ++ optional monitors.middle.enable monitors.middle.name
    ++ optional monitors.right.enable monitors.right.name;
  wallpaperLines =
    if enabledMonitorNames == []
    then "wallpaper = ,${wallpaperPath}"
    else concatStringsSep "\n" (map (m: "wallpaper = ${m},${wallpaperPath}") enabledMonitorNames);
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
      preload = ${wallpaperPath}
      ${wallpaperLines}
    '';
    home.packages = [ pkgs.hyprpaper ];
    module.hyprland.startup-commands = lib.mkAfter [ "hyprpaper &" ];
  };
}
