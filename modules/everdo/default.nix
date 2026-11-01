{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.everdo;
in {
  options.module.everdo = {
    enable = mkEnableOption "everdo";
  };

  config = mkIf settings.enable {
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
