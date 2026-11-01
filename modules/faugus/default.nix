{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.faugus;

  # Faugus writes game shortcuts (and its Proton downloads) under
  # HOST_XDG_DATA_HOME. Pointing that at a dir only this session searches
  # keeps the shortcuts out of other boot entries sharing this home.
  dataDir = "${config.xdg.dataHome}/faugus";
in
{
  options.module.faugus = {
    enable = mkEnableOption "Faugus Launcher, for running Windows games and launchers through umu";
  };

  config = mkIf settings.enable {
    home.packages = [ pkgs.faugus-launcher ];
    home.sessionVariables.HOST_XDG_DATA_HOME = dataDir;
    xdg.systemDirs.data = [ dataDir ];
  };
}
