{ config, pkgs, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types mkIf;
  inherit (types) path str;
  cfg = config.module.wlogout;
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
    home.file."${cfg.config-output-directory}" = {
      source = "${cfg.config-source-directory}";
      executable = false;
      recursive = true;
    };
  };
}
