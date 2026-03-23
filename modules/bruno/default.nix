{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.module.bruno;
in {
  options.module.bruno = {
    enable = mkEnableOption "bruno";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.bruno ];
  };
}
