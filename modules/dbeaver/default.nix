{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.module.dbeaver;
in {
  options.module.dbeaver = {
    enable = mkEnableOption "dbeaver";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.dbeaver-bin ];
  };
}
