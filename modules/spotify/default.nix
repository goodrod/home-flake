{ config, pkgs, lib, inputs, ... }:
with lib;
let
  cfg = config.module.spotify;
in {
  options.module.spotify = {
    enable = mkEnableOption "spotify";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ spotify spotify-player ];
  };
}
