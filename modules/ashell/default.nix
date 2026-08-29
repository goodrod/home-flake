{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.ashell;
in {
  options.module.ashell = {
    enable = mkEnableOption "ashell";
  };

  config = mkIf settings.enable {
    home.packages = [ pkgs.ashell ];
  };
}
