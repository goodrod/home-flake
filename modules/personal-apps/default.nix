{ config, pkgs, lib, inputs, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.personal-apps;
in {
  options.module.personal-apps = {
    enable = mkEnableOption "personal-apps";
  };

  config = mkIf settings.enable {
    home.packages = with pkgs; [
      plantuml
      gsimplecal
      nodejs # needed by claude-code plugin hooks (e.g. caveman)
    ];
  };
}
