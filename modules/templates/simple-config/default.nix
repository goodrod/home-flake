# Starter for a module whose whole job is to drop a directory of config files
# into the home directory (see modules/navi for a live example). Copy this
# directory to modules/<name>/, replace "placeholder" throughout, and add
# ./<name> to the imports list in modules/default.nix.
{ config, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types mkIf;
  inherit (types) path str;
  settings = config.module.placeholder;
in
{
  options.module.placeholder = {
    enable = mkEnableOption "placeholder";

    config-source-directory = mkOption {
      default = ./config;
      type = path;
      description = "Directory of config files to copy into the home directory.";
    };

    config-output-directory = mkOption {
      default = ".config/placeholder";
      type = str;
      description = "Destination for those files, relative to the home directory.";
    };
  };

  config = mkIf settings.enable {
    home.file."${settings.config-output-directory}" = {
      source = "${settings.config-source-directory}";
      executable = false;
      recursive = true;
    };
  };
}
