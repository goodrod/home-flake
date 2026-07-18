{ config, pkgs, lib, ... }:
let
  option = config.module.hyprland;
  scripts = import ./scripts.nix { inherit pkgs; };
in
{
  config = lib.mkIf option.enable {
    home.packages = [ pkgs.dbus ];

    systemd.user.services.hypr-notif-watcher = {
      Unit = {
        Description = "Track the app that sent the last desktop notification";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${scripts.notifAppWatcher}";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
