{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.spotify;
in {
  options.module.spotify = {
    enable = mkEnableOption "spotify";
  };

  config = mkIf settings.enable {
    home.packages = with pkgs; [ spotify spotify-player ];
  };
}
