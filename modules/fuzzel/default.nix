{ config, pkgs, lib, inputs, ... }:
with lib;
let
  # Shorter name to access final settings a
  # user of hello.nix module HAS ACTUALLY SET.
  # cfg is a typical convention.
  cfg = config.module.fuzzel;
in {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
  ];

  options.module.fuzzel = {
    # Option declarations.
    # Declare what settings a user of this module module can set.
    # Usually this includes a global "enable" option which defaults to false.
    enable = mkEnableOption "fuzzel";
  };

  config = mkIf cfg.enable {
    # Option definitions.
    # Define what other settings, services and resources should be active.
    # Usually these depend on whether a user of this module chose to "enable" it
    # using the "option" above.
    # Options for modules imported in "imports" can be set here.
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "Hack Nerd Font:size=12"; # Monospaced font
          width = 50; # Width option
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
