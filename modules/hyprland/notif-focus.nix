{ config, pkgs, lib, ... }:
let
  option = config.module.hyprland;
  scripts = import ./notif-focus-scripts.nix { inherit pkgs; };
in
{
  config = lib.mkIf option.enable {
    # hiPrio: libnotify lands in the same profile and owns bin/notify-send too,
    # the wrapper has to win that collision to actually shadow it
    home.packages = [ pkgs.dbus (lib.hiPrio scripts.notifySendWrapper) ];

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
