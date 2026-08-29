{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.discord;
in {
  options.module.discord = {
    enable = mkEnableOption "discord";
  };

  config = mkIf settings.enable {
    home.packages = with pkgs; [ discord ];
  };
}
