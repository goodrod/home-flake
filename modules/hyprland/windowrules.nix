{ config, lib, ... }:
let
  option = config.module.hyprland;
in
{
  config = lib.mkIf option.enable {
    wayland.windowManager.hyprland.settings = {
      "$browserRegexp" = "firefox_firefox|firefox|Chromium|vivaldi-stable|Mullvad Browser|google-chrome|Google-chrome";
      "$chatRegexp" = "discord|vesktop|Slack|.*teams.*|.*outlook.*|chrome-chat.google.com.*";
      "$terminalRegexp" = "Alacritty";
      "$productivityRegexp" = "everdo|obsidian";
      "$musicRegexp" = ".*Spotify.*";
      "$gamingRegexp" = "steam";
      "$settingsRegexp" = "com.saivert.pwvucontrol";
      "$devtoolRegexp" = "com.saivert.pwvucontrol|bruno";
      "$mailRegexp" = "chrome-mail.google.com.*|chrome-calendar.google.com.*";
      "$programmingRegexp" = "code-url-handler|jetbrains-rider|jetbrains-idea|Godot|kiro";

      windowrule = [
        "tag +jb, match:class ^jetbrains-.+$,match:float true"
        "no_focus on,match:class ^$,match:title ^$,match:xwayland true,match:float true,match:fullscreen false, match:pin false"
        "suppress_event maximize center, match:class .*"
        "tag +devtool,match:class $devtoolRegexp"
        "tag +mail,match:class $mailRegexp"
        "tag +music,match:title $musicRegexp"
        "tag +gaming,match:class $gamingRegexp"
        "tag +browser,match:class $browserRegexp"
        "tag +productivity,match:class $productivityRegexp"
        "tag +chat,match:class $chatRegexp"
        "tag +chat,match:initial_title $chatRegexp"
        "tag +coding,match:class $programmingRegexp"
        "tag +term,match:class $terminalRegexp"
        "workspace 10 silent,match:tag devtool"
        "workspace 20 silent,match:tag music"
        "workspace 30 silent,match:tag gaming"
        "workspace 40 silent,match:tag mail"
        "workspace 50 silent,match:tag productivity"
        "workspace 60 silent,match:tag chat"
        "workspace 70 silent,match:tag coding"
        "workspace 80 silent,match:tag term"
        "workspace 90 silent,match:tag browser"
        "float on,match:class toggle-window"
        "pin on,match:class toggle-window"
        "size monitor_w*0.50 monitor_h*0.50,match:class toggle-window"
        "move monitor_w*0.25 monitor_h*0.25,match:class toggle-window"
        "size monitor_w*0.50 monitor_h*0.50,match:tag jb,match:float true"
        "move monitor_w*0.25 monitor_h*0.25,match:tag jb,match:float true"
      ];

      workspace = lib.mkMerge [
        (lib.mkIf option.monitors.left.enable [
          "10, monitor:${option.monitors.left.name}, default:true"
        ])
        (lib.mkIf option.monitors.middle.enable [
          "20, monitor:${option.monitors.middle.name}, default:true"
        ])
        (lib.mkIf option.monitors.right.enable [
          "30, monitor:${option.monitors.right.name}, default:true"
        ])
      ];
    };
  };
}
