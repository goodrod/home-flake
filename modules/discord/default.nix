{ config, pkgs, lib, inputs, ... }:
with lib;
let
  cfg = config.module.discord;
in {
  options.module.discord = {
    enable = mkEnableOption "discord";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ discord ];
  };
}
