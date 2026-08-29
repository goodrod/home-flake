{ config, pkgs, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types mkIf;
  inherit (types) path str;
  settings = config.module.wlogout;
  lockCmd = if config.module.hyprland.lockscreen == "swaylock" then "swaylock -f" else "hyprlock";
  layoutFile = builtins.replaceStrings ["@lockCmd@"] [lockCmd]
    (builtins.readFile "${settings.config-source-directory}/layout");
in {
  options.module.wlogout = {
    enable = mkEnableOption "wlogout";

    config-source-directory = mkOption {
      default = ./config;
      type = path;
      description = "Path to the directory containing wlogout config files.";
    };

    config-output-directory = mkOption {
      default = ".config/wlogout";
      type = str;
      description = "Output directory relative to home for wlogout config.";
    };
  };

  config = mkIf settings.enable {
    home.packages = [ pkgs.wlogout ];
    home.file."${settings.config-output-directory}/layout".text = layoutFile;
    home.file."${settings.config-output-directory}/style.css".source = "${settings.config-source-directory}/style.css";
    home.file."${settings.config-output-directory}/icons" = {
      source = "${settings.config-source-directory}/icons";
      recursive = true;
    };
  };
}
