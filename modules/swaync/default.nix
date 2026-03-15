{ config, pkgs, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types mkIf;
  inherit (types) path str;
  cfg = config.module.swaync;
in {
  options.module.swaync = {
    enable = mkEnableOption "swaync";

    config-source-directory = mkOption {
      default = ./config;
      type = path;
      description = "Path to the directory containing swaync config files.";
    };

    config-output-directory = mkOption {
      default = ".config/swaync";
      type = str;
      description = "Output directory relative to home for swaync config.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.swaynotificationcenter ];
    home.file."${cfg.config-output-directory}" = {
      source = "${cfg.config-source-directory}";
      executable = false;
      recursive = true;
    };
  };
}
