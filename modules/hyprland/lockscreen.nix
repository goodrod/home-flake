{ config, lib, ... }:
let
  option = config.module.hyprland;
in
{
  config = lib.mkIf option.enable {
    programs.hyprlock = {
      enable = option.lockscreen == "hyprlock";
      settings = {
        background = {
          monitor = "";
          path = "screenshot";
          blur_passes = 4;
          blur_size = 10;
          brightness = 0.7;
        };
        input-field = {
          monitor = "";
          size = "280, 55";
          outline_thickness = 2;
          dots_size = 0.25;
          dots_spacing = 0.3;
          outer_color = "rgba(152, 222, 242, 0.4)";
          inner_color = "rgba(64, 74, 96, 0.3)";
          font_color = "rgba(205, 214, 244, 1.0)";
          fade_on_empty = true;
          placeholder_text = "<i>Password...</i>";
          rounding = 15;
          position = "0, -120";
          halign = "center";
          valign = "center";
        };
        label = [
          {
            monitor = "";
            text = "$TIME";
            font_size = 72;
            font_family = "Sans Bold";
            color = "rgba(205, 214, 244, 1.0)";
            shadow_passes = 2;
            shadow_size = 3;
            position = "0, 200";
            halign = "center";
            valign = "center";
          }
          {
            monitor = "";
            text = "cmd[update:60000] date +'%A, %d %B %Y'";
            font_size = 18;
            font_family = "Sans";
            color = "rgba(205, 214, 244, 0.8)";
            position = "0, 130";
            halign = "center";
            valign = "center";
          }
          {
            monitor = "";
            text = "Hi, $USER";
            font_size = 20;
            font_family = "Sans";
            color = "rgba(205, 214, 244, 0.6)";
            position = "0, -40";
            halign = "center";
            valign = "center";
          }
        ];
      };
    };

    xdg.configFile."swaylock/config" = lib.mkIf (option.lockscreen == "swaylock") {
      text = ''
        font=Sans
        font-size=20
        color=1a1b26
        indicator-radius=100
        indicator-thickness=7
        ring-color=98def2
        ring-ver-color=a6e3a1
        ring-wrong-color=f38ba8
        ring-clear-color=f9e2af
        key-hl-color=cdd6f4
        bs-hl-color=f38ba8
        line-color=00000000
        inside-color=1a1b26cc
        inside-ver-color=1a1b26cc
        inside-wrong-color=1a1b26cc
        inside-clear-color=1a1b26cc
        separator-color=00000000
        text-color=cdd6f4
        text-ver-color=cdd6f4
        text-wrong-color=f38ba8
        text-clear-color=f9e2af
      '';
    };
  };
}
