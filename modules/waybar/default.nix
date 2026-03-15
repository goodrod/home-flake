{ config, pkgs, lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types mkIf;
  inherit (types) path str;
  waybarConfig = config.module.waybar;
in {
  options.module.waybar = {
    enable = mkEnableOption "waybar";

    config-source-directory = mkOption {
      default = ./config;
      type = path;
      description =
        "Path to the directory containing the config files to output to the directory specified in the config-output-directory.";
    };

    config-output-directory = mkOption {
      default = ".config/waybar";
      type = str;
      description =
        "Path to the output directory where all config files located in the config-source-directory. Output is relative to your home directory.";
    };
  };

  config = mkIf waybarConfig.enable {
    fonts.fontconfig.enable = true;
    home.packages = with pkgs;
      [ waybar font-awesome ]
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
        position = "top";
        modules-left = [
          "custom/label#workspaces"
          "hyprland/workspaces"
          "custom/label#special-workspaces"
          "hyprland/workspaces#special"
        ];
        modules-center = [ "hyprland/window" ];
        modules-right = [
          "battery"
          "disk"
          "temperature"
          "memory"
          "cpu"
          "pulseaudio"
          "clock"
          "tray"
        ];
        "custom/label#workspaces" = {
          exec = "echo 'Workspaces:'";
          interval = 3600;
          return-type = "text";
        };
        "custom/label#special-workspaces" = {
          exec = pkgs.writeShellScript "special-ws" ''
                      [[ $(${pkgs.hyprland}/bin/hyprctl workspaces | grep -c 'special:') -gt 0 ]] && echo 'Special workspaces:' || echo 'No special workspaces';
            	'';
          interval = 5;
          return-type = "text";
        };
        "hyprland/workspaces" = {
          format = "{icon}";
          disable-scroll = true;
          all-outputs = true;
          show-special = false;
          move-to-monitor = true;
          persistent-workspaces = {
            "1" = [ ];
            "2" = [ ];
            "3" = [ ];
            "4" = [ ];
            "5" = [ ];
            "6" = [ ];
            "7" = [ ];
            "8" = [ ];
            "9" = [ ];
          };
          format-icons = {
            "1" = "¹";
            "2" = "²";
            "3" = "³";
            "4" = "⁴";
            "5" = "⁵";
            "6" = "⁶";
            "7" = "⁷";
            "8" = "⁸";
            "9" = "⁹";
            "12" = "¹ ⁽ᵃˡᵗ⁾";
            "22" = "² ⁽ᵃˡᵗ⁾";
            "32" = "³ ⁽ᵃˡᵗ⁾";
            "42" = "⁴ ⁽ᵃˡᵗ⁾";
            "52" = "⁵ ⁽ᵃˡᵗ⁾";
            "62" = "⁶ ⁽ᵃˡᵗ⁾";
            "72" = "⁷ ⁽ᵃˡᵗ⁾";
            "82" = "⁸ ⁽ᵃˡᵗ⁾";
            "92" = "⁹ ⁽ᵃˡᵗ⁾";
          };
        };
        "hyprland/workspaces#special" = {
          disable-scroll = true;
          all-outputs = true;
          show-special = true;
          format = "{name}";
          move-to-monitor = true;
          ignore-workspaces = [ "^[0-9]*$" ];
        };
        mpd = {
          server = "127.0.0.1";
          port = 6600;
          tooltip = false;
          exec-if = "pgrep mpd";
          format =
            "{stateIcon} {consumeIcon}{randomIcon}{artist} - {title} ({elapsedTime:%M:%S}/{totalTime:%M:%S}) ";
          format-disconnected = "";
          format-stopped = "";
          unknown-tag = "N/A";
          interval = 2;
          max-length = 60;
          consume-icons = { on = " "; };
          random-icons = {
            on = ''<span color="#f53c3c"></span> '';
            off = " ";
          };
          repeat-icons = { on = " "; };
          single-icons = { on = "1 "; };
          state-icons = {
            paused = "";
            playing = "";
          };
        };
        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "";
            deactivated = "";
          };
        };
        tray = { spacing = 10; };
        clock = {
          timezone = "Europe/Stockholm";
          format = "{:%H:%M %Z   - %a %b %d }";
          tooltip = false;
          on-click-right = "gsimplecal";
        };
        cpu = {
          format = "{usage}% ";
          on-click = "alacritty -e bash -ci htop --sort-key PERCENT_CPU";
        };
        memory = {
          format = "{}% ";
          on-click = "alacritty -e bash -ci htop --sort-key PERCENT_MEM";
        };
        temperature = {
          critical-threshold = 80;
          format = "{temperatureC}°C {icon}";
          format-icons = [ "" "" "" "" "" ];
        };
        backlight = {
          format = "{percent}% {icon}";
          format-icons = [ "" "" ];
        };
        battery = {
          tooltip = true;
          states = {
            good = 95;
            warning = 20;
            critical = 15;
          };
          format = "{capacity}% {icon}";
          format-charging = "{capacity}% ";
          format-plugged = "{capacity}% ";
          format-alt = "{time} {icon}";
          format-icons = [ "" "" "" "" "" ];
        };
        pulseaudio = {
          tooltip = false;
          format = "{volume}% {icon} {format_source}";
          format-bluetooth = "{volume}% {icon}  {format_source}";
          format-bluetooth-muted = " {icon}  {format_source}";
          format-muted = " {format_source}";
          format-source = "{volume}% ";
          format-source-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          on-click = "pwvucontrol";
        };
        disk = {
          interval = 30;
          format = "{specific_used:0.1f}/{specific_total:0.1f} GB ";
          unit = "GB";
        };
      };
    };
  };
}
