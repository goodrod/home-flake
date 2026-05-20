{ config, pkgs, lib, inputs, ... }:
with lib;
let
  cfg = config.module.everdo;
in {
  options.module.everdo = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable everdo.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.everdo ];

    xdg.desktopEntries.everdo = {
      name = "Everdo";
      genericName = "GTD productivity app";
      comment = "A productivity app for GTD (Getting Things Done)";
      exec = "everdo --ozone-platform=wayland --no-sandbox %U";
      icon = "everdo";
      terminal = false;
      categories = [ "Office" ];
      startupNotify = true;
      settings = {
        StartupWMClass = "Everdo";
      };
    };
  };
}
