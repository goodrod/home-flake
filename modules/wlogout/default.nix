{ config, pkgs, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types mkIf;
  inherit (types) path str;
  cfg = config.module.wlogout;
  lockCmd = if config.module.hyprland.lockscreen == "swaylock" then "swaylock -f" else "hyprlock";
  layoutFile = builtins.replaceStrings ["@lockCmd@"] [lockCmd]
    (builtins.readFile "${cfg.config-source-directory}/layout");
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

  config = mkIf cfg.enable {
    home.packages = [ pkgs.wlogout ];
    home.file."${cfg.config-output-directory}/layout".text = layoutFile;
    home.file."${cfg.config-output-directory}/style.css".source = "${cfg.config-source-directory}/style.css";
    home.file."${cfg.config-output-directory}/icons" = {
      source = "${cfg.config-source-directory}/icons";
      recursive = true;
    };
  };
}
