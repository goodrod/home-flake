{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.fuzzel;
in {
  options.module.fuzzel = {
    enable = mkEnableOption "fuzzel";
  };

  config = mkIf settings.enable {
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "Hack Nerd Font:size=12"; # Monospaced font
          width = 50; # Width settings
          lines = 20;
          horizontal-pad = 20; # Horizontal padding
          vertical-pad = 8; # Vertical padding
          inner-pad = 5; # Inner padding
          dpi-aware = "yes";
        };
        border = {
          width = 2; # Border width
          radius = 10; # Border radius
        };
        colors = {
          # Matches the quickshell bar/control-center palette
          # (modules/quickshell/config/shell.qml).
          background = "#141313ff"; # islandBg
          text = "#DEE2E6ff"; # textColor
          prompt = "#D0BCFFff"; # accentColor
          placeholder = "#CAC4D0ff"; # mutedTextColor
          input = "#DEE2E6ff"; # textColor
          match = "#D0BCFFff"; # accentColor
          selection = "#D0BCFFff"; # accentColor
          selection-text = "#381E72ff"; # accentTextColor
          selection-match = "#381E72ff"; # accentTextColor
          counter = "#CAC4D0ff"; # mutedTextColor
          border = "#49454Fff"; # chipBg
        };
      };
    };
    xdg.desktopEntries.teams = {
      name = "Microsoft Teams";
      comment = "Microsoft Teams via Vivaldi";
      exec = ''
        ${pkgs.chromium}/bin/chromium-browser --app=https://teams.microsoft.com
      '';
      icon = "teams";
      terminal = false;
      categories = [ "Network" "Office" ];
    };

    xdg.desktopEntries.outlook = {
      name = "Outlook";
      comment = "Microsoft Outlook via Vivaldi";
      exec = ''
        ${pkgs.chromium}/bin/chromium-browser --app=https://outlook.office.com/mail
      '';
      icon = "outlook";
      terminal = false;
      categories = [ "Network" "Office" ];
    };
  };
}
