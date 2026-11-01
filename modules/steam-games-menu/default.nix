{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.steam-games-menu;

  # Outside ~/.local/share/applications, which every boot entry sharing this
  # home reads: only a session that enables the module adds it to
  # XDG_DATA_DIRS, so its games never show up as dead entries elsewhere.
  dataDir = "${config.xdg.dataHome}/steam-games-menu";

  generator = pkgs.writeShellApplication {
    name = "steam-games-menu";
    runtimeInputs = with pkgs; [ coreutils findutils gnused ];
    text = builtins.readFile ./steam-games-menu.sh;
  };
in
{
  options.module.steam-games-menu = {
    enable = mkEnableOption "an app menu entry for every installed Steam game, kept in sync with the library";
  };

  config = mkIf settings.enable {
    xdg.systemDirs.data = [ dataDir ];

    systemd.user.services.steam-games-menu = {
      Unit.Description = "Write app menu entries for installed Steam games";
      Service = {
        Type = "oneshot";
        ExecStart = "${generator}/bin/steam-games-menu ${dataDir}";
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.paths.steam-games-menu = {
      Unit.Description = "Refresh Steam game menu entries when the library changes";
      Path.PathChanged = "${config.xdg.dataHome}/Steam/steamapps";
      Install.WantedBy = [ "default.target" ];
    };
  };
}
