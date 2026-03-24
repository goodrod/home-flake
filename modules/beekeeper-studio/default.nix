{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.module.beekeeper-studio;
in {
  options.module.beekeeper-studio = {
    enable = mkEnableOption "beekeeper-studio";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.beekeeper-studio ];
  };
}
