{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOption mkEnableOption types mkIf;
  inherit (types) path str;
  waybarConfig = config.module.waybar;

  # Single source of truth for workspaces lives in module.workspaces.
  workspaces = config.module.workspaces.entries;

  # Sort by numeric id so the icon map and persistent list are deterministic
  # (independent of attr-key iteration order).
  sortedWs = lib.sort (a: b: a.id < b.id) (lib.attrValues workspaces);

  # "<id>" -> icon and "<id+1>" -> shifted icon (auto "icon +", or explicit override),
  # plus the "default" fallback.
  workspaceFormatIcons =
    lib.listToAttrs (lib.concatMap (ws: [
      { name = toString ws.id; value = ws.icon; }
      {
        name = toString (ws.id + 1);
        value = if ws.shiftedIcon != null then ws.shiftedIcon else ws.icon + " +";
      }
    ]) sortedWs)
    // { "default" = ""; };

  # Ints (waybar expects numbers here), in id order, only those flagged persistent.
  persistentWorkspaceIds = map (ws: ws.id) (lib.filter (ws: ws.persistent) sortedWs);
in {
  options.module.waybar = {
    enable = mkEnableOption "waybar";

    config-source-directory = mkOption {
      default = ./config;
      type = path;
      description = "Path to the directory containing the config files to output to the directory specified in the config-output-directory.";
    };

    config-output-directory = mkOption {
      default = ".config/waybar";
      type = str;
      description = "Path to the output directory where all config files located in the config-source-directory. Output is relative to your home directory.";
    };
  };

  config = mkIf waybarConfig.enable {
    fonts.fontconfig.enable = true;
    home.packages = with pkgs;
      [waybar font-awesome]
      ++ builtins.filter lib.attrsets.isDerivation
      (builtins.attrValues pkgs.nerd-fonts);
    home.file."${waybarConfig.config-output-directory}" = {
      source = "${waybarConfig.config-source-directory}";
      executable = false;
      recursive = true;
    };
    programs.waybar.enable = true;
    programs.waybar.settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 32;
        margin-left = 5;
        margin-right = 5;
        spacing = 0;
        margin-bottom = -4;
        modules-left = [
          "clock"
          "tray"
        ];
        modules-center = [
          "custom/notification"
          "hyprland/workspaces"
          "custom/power"
        ];
        modules-right = [
          "network"
          "battery"
          "pulseaudio"
          "cpu"
          "memory"
          "backlight"
        ];
        "custom/notification" = {
          tooltip = true;
          format = "{icon}";
          format-icons = {
            notification = "";
            none = "";
            dnd-notification = "";
            dnd-none = "";
            inhibited-notification = "";
            inhibited-none = "";
            dnd-inhibited-notification = "";
            dnd-inhibited-none = "";
          };
          return-type = "json";
          exec-if = "which swaync-client";
          exec = "swaync-client -swb";
          on-click = "swaync-client -t -sw";
          on-click-right = "swaync-client -d -sw";
          escape = true;
        };
        "custom/power" = {
          format = "⏻";
          on-click = "wlogout -b 4";
        };
        "hyprland/workspaces" = {
          disable-scroll = false;
          all-outputs = true;
          format = "{icon}";
          format-icons = workspaceFormatIcons;
          on-click = "hyprctl dispatch \"hl.dsp.focus({workspace = {id}, on_current_monitor = true})\"";
          persistent-workspaces = {
            "*" = persistentWorkspaceIds;
          };
        };
        network = {
          format-wifi = " 󰤨 {essid} ";
          format-ethernet = " 󰅢 {bandwidthDownBytes} ";
          tooltip-format = " 󰅧 {bandwidthUpBytes} 󰅢 {bandwidthDownBytes}";
          format-linked = " 󱘖 {ifname} (No IP) ";
          format-disconnected = "  Disconnected ";
          format-alt = " 󰤨 {signalStrength}% ";
          interval = 1;
        };
        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = " {icon} {capacity}% ";
          format-charging = " 󱐋{capacity}%";
          interval = 1;
          format-icons = ["󰂎" "󰁼" "󰁿" "󰂁" "󰁹"];
          tooltip = true;
        };
        pulseaudio = {
          format = "{icon}{volume}% ";
          format-muted = " 󰖁 0% ";
          format-icons = {
            headphone = "  ";
            hands-free = "  ";
            headset = "  ";
            phone = "  ";
            portable = "  ";
            car = "   ";
            default = [
              "  "
              "  "
              "  "
            ];
          };
          on-click-right = "pavucontrol -t 3";
          on-click = "pactl -- set-sink-mute 0 toggle";
          tooltip = true;
          tooltip-format = "{volume}%";
        };
        memory = {
          format = "  {used:0.1f}G ";
          tooltip = true;
          tooltip-format = "{used:0.2f}G/{total:0.2f}G";
        };
        cpu = {
          format = "  {usage}% ";
          tooltip = true;
        };
        clock = {
          interval = 1;
          timezone = "Europe/Stockholm";
          format = " {:%a %d %b  %H:%M} ";
          tooltip = true;
          tooltip-format = "{calendar}";
        };
        tray = {
          icon-size = 20;
          spacing = 6;
          show-passive-items = true;
        };
        backlight = {
          format = "{icon}{percent}% ";
          tooltip = true;
          tooltip-format = ": {percent}%";
          format-icons = [" 󰃞 " " 󰃝 " " 󰃟 " " 󰃠 "];
        };
      };
    };
  };
}
