{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.module.swaync;
in {
  options.module.swaync = {
    enable = mkEnableOption "swaync";
  };

  config = mkIf cfg.enable {
    services.swaync = {
      enable = true;
      settings = {
        positionX = "right";
        positionY = "top";
        control-center-margin-top = 5;
        control-center-margin-bottom = 20;
        control-center-margin-right = 5;
        notification-icon-size = 64;
        notification-body-image-height = 100;
        notification-body-image-width = 200;
        timeout = 10;
        timeout-low = 5;
        timeout-critical = 0;
        fit-to-screen = false;
        control-center-width = 500;
        control-center-height = 1033;
        notification-window-width = 500;
        keyboard-shortcuts = true;
        image-visibility = "when-available";
        transition-time = 50;
        hide-on-clear = false;
        hide-on-action = true;
        script-fail-notify = true;
        widgets = [ "buttons-grid" "volume" "backlight" "mpris" ];
        widget-config = {
          title = {
            text = "Notification Center";
            clear-all-button = true;
            button-text = "󰆴 Clear";
          };
          dnd.text = "Do Not Disturb";
          label = {
            max-lines = 1;
            text = "Notification Center";
          };
          mpris = {
            image-size = 100;
            image-radius = 0;
            blacklist = [ "kew" "firefox" ];
          };
          volume.label = "󰕾";
          backlight.label = "󰃟";
          buttons-grid.actions = [
            { label = "󰖩"; command = "kitty --hold -e nmtui"; }
            { label = "󰂯"; command = "blueman-manager"; }
            { label = "󰕾"; command = "pactl set-sink-mute @DEFAULT_SINK@ toggle"; type = "toggle"; }
            { label = "󰍬"; command = "pactl set-source-mute @DEFAULT_SOURCE@ toggle"; type = "toggle"; }
            { label = "󰆴"; command = "swaync-client -C"; }
          ];
        };
      };
      style = ''
        * {
            font-family: "CaskaydiaCove Nerd Font", "Font Awesome 6 Free";
            font-size: 15px;
            font-weight: bold;
        }

        .control-center .notification-row:focus,
        .control-center .notification-row:hover {
            opacity: 1;
            background: #4e5a72;
        }

        .notification-row {
            outline: none;
            margin: 0px;
            padding: 0px;
        }

        .notification {
            background: #404A60;
            border: 2px solid #98DEF2;
            border-radius: 4px;
            margin: 3px 0px;
        }

        .notification-content {
            background: transparent;
            padding: 4px;
        }

        .notification-default-action {
            margin: 0;
            padding: 8px;
            border-radius: 4px;
        }

        .close-button {
            background: #f38ba8;
            color: #181825;
            text-shadow: none;
            padding: 0px;
            border-radius: 4px;
            margin-top: 5px;
            margin-right: 5px;
        }

        .close-button:hover {
            box-shadow: none;
            background: #FF7B87;
            transition: all 0.15s ease-in-out;
            border: none;
        }

        .notification-action {
            border: 2px solid #98DEF2;
            border-top: none;
            border-radius: 4px;
        }

        .notification-default-action:hover,
        .notification-action:hover {
            color: #cdd6f4;
            background: #4e5a72;
        }

        .notification-default-action:not(:only-child) {
            border-bottom-left-radius: 4px;
            border-bottom-right-radius: 4px;
        }

        .notification-action:first-child {
            border-bottom-left-radius: 4px;
            background: #353d4f;
        }

        .notification-action:last-child {
            border-bottom-right-radius: 4px;
            background: #353d4f;
        }

        .inline-reply {
            margin-top: 8px;
        }

        .inline-reply-entry {
            background: #353d4f;
            color: #D8DEE9;
            caret-color: #D8DEE9;
            border: 1px solid rgba(255, 255, 255, 0.15);
            border-radius: 4px;
        }

        .inline-reply-button {
            margin-left: 4px;
            background: #404A60;
            border: 1px solid rgba(255, 255, 255, 0.15);
            border-radius: 4px;
            color: #D8DEE9;
        }

        .inline-reply-button:disabled {
            background: initial;
            color: rgb(150, 150, 150);
            border: 1px solid transparent;
        }

        .inline-reply-button:hover {
            background: #4e5a72;
        }

        .image {
            border-radius: 4px;
            margin-right: 10px;
        }

        .summary {
            font-size: 16px;
            font-weight: 700;
            background: transparent;
            color: #A3BE8C;
            text-shadow: none;
        }

        .time {
            font-size: 16px;
            font-weight: 700;
            background: transparent;
            color: #D8DEE9;
            text-shadow: none;
            margin-right: 18px;
        }

        .body {
            font-size: 15px;
            font-weight: 400;
            background: transparent;
            color: #D8DEE9;
            text-shadow: none;
        }

        .control-center {
            background: #404A60;
            border: 2px solid #98DEF2;
            border-radius: 4px;
        }

        .control-center-list {
            background: transparent;
        }

        .control-center-list-placeholder {
            opacity: 0.5;
        }

        .floating-notifications {
            background: transparent;
        }

        .blank-window {
            background: alpha(black, 0.0);
        }

        .widget-title {
            color: #cdd6f4;
            background: #353d4f;
            padding: 5px 10px;
            margin: 10px 10px 5px 10px;
            font-size: 1.5rem;
            border-radius: 4px;
        }

        .widget-title>button {
            font-size: 1rem;
            color: #D8DEE9;
            text-shadow: none;
            background: #404A60;
            box-shadow: none;
            border-radius: 4px;
        }

        .widget-title>button:hover {
            background: #f38ba8;
            color: #181825;
        }

        .widget-dnd {
            background: #353d4f;
            padding: 5px 10px;
            margin: 5px 10px;
            border-radius: 4px;
            font-size: large;
            color: #cdd6f4;
        }

        .widget-dnd>switch {
            border-radius: 4px;
            background: #89dceb;
        }

        .widget-dnd>switch:checked {
            background: #f38ba8;
            border: 1px solid #98DEF2;
        }

        .widget-dnd>switch slider,
        .widget-dnd>switch:checked slider {
            background: #181825;
            border-radius: 4px;
        }

        .widget-label {
            margin: 10px 10px 5px 10px;
        }

        .widget-label>label {
            font-size: 1rem;
            color: #D8DEE9;
        }

        .widget-mpris {
            color: #D8DEE9;
            background: #353d4f;
            padding: 5px 10px;
            margin: 5px 10px 5px 10px;
            border-radius: 4px;
            box-shadow: none;
        }

        .widget-mpris>box>button {
            border-radius: 4px;
        }

        .widget-mpris-player {
            padding: 5px 10px;
            margin: 10px;
            border-radius: 4px;
            box-shadow: none;
        }

        .widget-mpris-title {
            font-weight: 700;
            font-size: 1.25rem;
        }

        .widget-mpris-subtitle {
            font-size: 1.1rem;
        }

        .widget-mpris-album-art {
            border-radius: 4px;
        }

        .widget-buttons-grid {
            font-size: 18px;
            padding: 5px 2px;
            margin: 10px 10px 5px 10px;
            border-radius: 4px;
            background: #353d4f;
        }

        .widget-buttons-grid>flowbox>flowboxchild>button {
            margin: 3px;
            padding: 0px 0px;
            background: #89dceb;
            border-radius: 4px;
            color: #181825;
        }

        .widget-buttons-grid>flowbox>flowboxchild>button:hover {
            background: #A3BE8C;
            color: #181825;
        }

        .widget-buttons-grid>flowbox>flowboxchild>button:checked {
            background: #FF7B87;
            color: #181825;
        }

        .widget-menubar>box>.menu-button-bar>button {
            border: none;
            background: transparent;
        }

        .topbar-buttons>button {
            border: none;
            background: transparent;
        }

        .widget-volume {
            background: #353d4f;
            padding: 5px;
            margin: 5px 10px;
            border-radius: 4px;
            font-size: 2rem;
            color: #89dceb;
        }

        .widget-backlight {
            background: #353d4f;
            padding: 5px;
            margin: 5px 10px;
            border-radius: 4px;
            font-size: 2rem;
            color: #cdd6f4;
        }
      '';
    };
  };
}
