{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.module.ashell;
in {
  options.module.ashell = {
    enable = mkEnableOption "ashell";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.ashell ];
  };
}
