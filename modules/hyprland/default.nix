{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  # Shorter name to access final settings a
  # user of hello.nix module HAS ACTUALLY SET.
  # cfg is a typical convention.
  inherit (lib) mkOption mkEnableOption types mkIf;
  inherit (types) path str bool listOf;
  option = config.module.hyprland;
  toggleWindowScript = pkgs.writeScript "toggle-window.sh" ''
    #!/usr/bin/env bash
    pgrep fuzzel && pkill fuzzel && exit 0
    if hyprctl clients | grep -q "toggle-window"; then
        hyprctl dispatch closewindow class:toggle-window
    else
        alacritty --class=toggle-window -e bash -c "$@"
    fi
  '';
  toggleMenu = pkgs.writeScript "toggle-menu.sh" ''
    #!/usr/bin/env bash
    pgrep fuzzel && pkill fuzzel && exit 0
    if hyprctl clients | grep -q "toggle-window"; then
        hyprctl dispatch closewindow class:toggle-window
    else
        fuzzel
    fi
  '';
  parseHotkeysScript = pkgs.writeScript "parseHotkeys.sh" ''
    #!/usr/bin/env bash

    hyprctl binds -j | jq -r '
      .[] |
      .description as $desc |
      .key as $key |
      .modmask as $mask |
      .dispatcher as $dispatcher |
      .arg as $arg |

      (
        (if $desc == "" then "<no description>" else $desc end) as $dsc |
        (
          (
            (
              (if ($mask / 1) % 2    >= 1 then ["Shift"] else [] end) +
              (if ($mask / 2) % 2    >= 1 then ["Lock"]  else [] end) +
              (if ($mask / 4) % 2    >= 1 then ["Mod1"]  else [] end) +
              (if ($mask / 8) % 2    >= 1 then ["Ctrl"]  else [] end) +
              (if ($mask / 16) % 2   >= 1 then ["Mod3"]  else [] end) +
              (if ($mask / 32) % 2   >= 1 then ["Mod5"]  else [] end) +
              (if ($mask / 64) % 2   >= 1 then ["Super"]  else [] end)
            ) | join("+")
          ) + (if $key != "" then "+" + $key else "" end) as $hotkey |

          [$dsc, $hotkey, ($dispatcher + " " + $arg)]
        )
      ) | @tsv
    ' | awk -F'\t' '{
      desc = sprintf("%-50s", $1)
      key  = sprintf("%-25s", $2)
      cmd  = (length($3) > 50) ? substr($3, 1, 47) "..." : $3
      printf "%s    %s    %s\n", desc, key, cmd
    }'
  '';
in {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
  ];

  options.module.hyprland = {
    # Option declarations.
    # Declare what settings a user of this module module can set.
    # Usually this includes a global "enable" option which defaults to false.
    enable = mkEnableOption "hyprland";
    startup-commands = mkOption {
      type = listOf str;
      default = [];
    };
    monitors = {
      left = {
        enable = mkOption {
          type = bool;
          default = false;
        };
        name = mkOption {
          type = str;
          description = "Left monitor";
          default = "";
        };
        settings = mkOption {
          type = str;
          description = "Settings for monitor, e.g. 2560x1440@144,0x0,1.0";
          default = "preferred,0x0,1.0";
        };
      };
      middle = {
        enable = mkOption {
          type = bool;
          default = false;
        };
        name = mkOption {
          type = str;
          description = "Middle monitor";
          default = "DP-3";
        };
        settings = mkOption {
          type = str;
          description = "Settings for monitor, e.g. 2560x1440@144,0x0,1.0";
          default = "preferred,0x0,1.0";
        };
      };
      right = {
        enable = mkOption {
          type = bool;
          default = false;
        };
        name = mkOption {
          type = str;
          description = "Right monitor";
          default = "HDMI-A-2";
        };
        settings = mkOption {
          type = str;
          description = "Settings for monitor, e.g. 2560x1440@144,0x0,1.0";
          default = "preferred,2560x0,1.0";
        };
      };
    };
  };

  config = mkIf option.enable {
    #nn Option definitions.
    # Define what other settings, services and resources should be active.
    # Usually these depend on whether a user of this module chose to "enable" it
    # using the "option" above.
    # Options for modules imported in "imports" can be set here.
    home.pointerCursor = {
      # gtk.enable = true;
      # x11.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 16;
    };

    gtk = {
      enable = true;
      theme = {
        package = pkgs.flat-remix-gtk;
        name = "Flat-Remix-GTK-Grey-Darkest";
      };
      iconTheme = {
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
      };

      font = {
        name = "Sans";
        size = 11;
      };
    };
    wayland.windowManager.hyprland = {
      enable = true;
      sourceFirst = true;
      systemd.enable = true;
      xwayland.enable = true;
      package =
        pkgs.hyprland;
      portalPackage =
        pkgs.xdg-desktop-portal-hyprland;
      settings = {
        exec-once = option.startup-commands;
        monitor = mkMerge [
          (mkIf (option.monitors.left.enable)
            ["${option.monitors.left.name},${option.monitors.left.settings}"])
          (mkIf (option.monitors.middle.enable) [
            "${option.monitors.middle.name},${option.monitors.middle.settings}"
          ])
          (mkIf (option.monitors.right.enable) [
            "${option.monitors.right.name},${option.monitors.right.settings}"
          ])
          ["Unknown-1,disable"]
        ];
        ecosystem.no_update_news = true;
        debug.disable_logs = false;
        "$terminal" = "alacritty";
        "$menu" = "fuzzel";
        "$monitor-1" = "${option.monitors.left.name}";
        "$monitor-2" = "${option.monitors.middle.name}";
        "$monitor-3" = "${option.monitors.right.name}";
        "$mainMod" = "SUPER";

        "$browserRegexp" = "firefox_firefox|firefox|Chromium|vivaldi-stable|Mullvad Browser|google-chrome|Google-chrome";
        "$chatRegexp" = "discord|vesktop|Slack|.*teams.*|.*outlook.*";
        "$terminalRegexp" = "Alacritty";
        "$productivityRegexp" = "everdo|obsidian";
        "$musicRegexp" = ".*Spotify.*";
        "$gamingRegexp" = "steam";
        "$settingsRegexp" = "com.saivert.pwvucontrol";
        "$devtoolRegexp" = "com.saivert.pwvucontrol|bruno|DBeaver";
        "$mailRegexp" = "chrome-mail.google.com.*|chrome-calendar.google.com.*";
        "$programmingRegexp" = "code-url-handler|jetbrains-rider|jetbrains-idea|Godot|kiro";
        windowrule = [
          "tag +jb, match:class ^jetbrains-.+$,match:float true"
          #"stay_focused on, match:tag jb"
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
          "group set always,match:tag devtool"
          "workspace 20 silent,match:tag music"
          "group set always,match:tag music"
          "workspace 30 silent,match:tag gaming"
          "group set always,match:tag gaming"
          "workspace 40 silent,match:tag mail"
          "group set always,match:tag mail"
          "workspace 50 silent,match:tag productivity"
          "group set always,match:tag productivity"
          "workspace 60 silent,match:tag chat"
          "group set always,match:tag chat"
          "workspace 70 silent,match:tag coding"
          "group set always,match:tag coding"
          "workspace 80 silent,match:tag term"
          "group set always,match:tag term"
          "workspace 90 silent,match:tag browser"
          "group set always,match:tag browser"
          "group set always"
          "float on,match:class toggle-window"
          "pin on,match:class toggle-window"
          "size monitor_w*0.50 monitor_h*0.50,match:class toggle-window"
          "move monitor_w*0.25 monitor_h*0.25,match:class toggle-window"
          "size monitor_w*0.50 monitor_h*0.50,match:tag jb,match:float true"
          "move monitor_w*0.25 monitor_h*0.25,match:tag jb,match:float true"
        ];
        ecosystem = {no_donation_nag = true;};
        group = {
          groupbar = {
            enabled = true;
            height = 22;
            font_size = 11;
            font_family = "JetBrains Mono";
            font_weight_active = "bold";
            font_weight_inactive = "normal";

            render_titles = true;
            text_offset = 1;
            text_color = "0xff181825";
            text_color_inactive = "0x99cdd6f4";
            text_color_locked_active = "0xff181825";
            text_color_locked_inactive = "0x99cdd6f4";

            gradients = true;
            rounding = 6;
            gradient_rounding = 6;
            round_only_edges = true;
            gradient_round_only_edges = true;

            indicator_gap = -22;
            indicator_height = 22;
            gaps_in = 3;
            gaps_out = 3;
            keep_upper_gap = true;

            scrolling = true;
            stacked = false;

            # palette
            "col.active" = "rgba(89dcebff) rgba(cba6f7ff) 90deg";
            "col.inactive" = "rgba(404A60dd) rgba(404A60dd) 90deg";
            "col.locked_active" = "rgba(DDC062ff) rgba(FF9F81ff) 90deg";
            "col.locked_inactive" = "rgba(DDC062aa) rgba(FF9F81aa) 90deg";
          };
        };

        general = {
          gaps_in = 3;
          gaps_out = 8;
          border_size = 2;
          "col.active_border" = "rgba(cdd6f4ee) rgba(89dcebee) 45deg";
          "col.inactive_border" = "rgba(404A60aa)";
          resize_on_border = false;
          allow_tearing = false;
          layout = "master";
        };

        master = {orientation = "left";};

        cursor = {no_hardware_cursors = true;};

        decoration = {
          rounding = 10;
          active_opacity = 1.0;
          inactive_opacity = 1.0;

          blur = {
            enabled = true;
            size = 3;
            passes = 1;
            vibrancy = 0.1696;
          };
        };

        animations = {
          enabled = true;
          bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
          animation = [
            "windows, 1, 3, myBezier"
            "windowsOut, 1, 3, default, popin 80%"
            "border, 1, 1, default"
            "borderangle, 1, 3, default"
            "fade, 1, 1, default"
            "workspaces, 1, 3, default"
          ];
        };

        master = {new_status = "master";};

        misc = {
          force_default_wallpaper = 0;
          disable_hyprland_logo = false;
        };

        input = {
          kb_layout = "se";
          kb_variant = "";
          kb_model = "";
          kb_options = "";
          kb_rules = "";
          follow_mouse = 2;
          float_switch_override_focus = 0;
          sensitivity = 0; # -1.0 - 1.0, 0 means no modification.

          touchpad = {natural_scroll = false;};
        };

        env = [
          "LIBVA_DRIVER_NAME,nvidia"
          "XDG_SESSION_TYPE,wayland"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
          "XCURSOR_SIZE,24"
          "HYPRCURSOR_SIZE,24"
        ];
        bindd = [
          "$mainMod, I, Remove master, layoutmsg, removemaster"
          "$mainMod, space, Launch terminal, exec, $terminal"
          "$mainMod ALT, space, Launch terminal, exec, [workspace unset] $terminal"
          "$mainMod, Tab, Change group active, changegroupactive, f"
          "$mainMod SHIFT, Tab, Change group active, changegroupactive, b"
          "$mainMod CTRL, Tab, Toggle lock on active group, lockactivegroup, toggle"
          "$mainMod, C, Kill active window, killactive,"
          "$mainMod, L, Make window leave group to the right, exec, hyprctl dispatch moveoutofgroup; hyprctl dispatch movewindow r; hyprctl dispatch togglegroup; hyprctl dispatch movefocus l"
          "$mainMod SHIFT, L, Lock screen, exec, playerctl -a pause; hyprlock"
          "$mainMod, J, Make window to the right join group, exec, hyprctl dispatch movefocus r; hyprctl dispatch moveintogroup l; hyprctl dispatch focuswindow previous"
          "$mainMod, F12, Exit Hyprland, exit,"
          "$mainMod, F, Open file manager, exec, $fileManager"
          "$mainMod SHIFT, F, Toggle floating, togglefloating,"
          "$mainMod, D, Toggle menu, exec, ${toggleMenu}"
          "$mainMod, escape, Toggle window, exec, ${toggleWindowScript} :;"
          "$mainMod, B, Toggle Bluetooth, exec, ${toggleWindowScript} bluetuith"
          "$mainMod, s, Toggle Spotify player, exec, ${toggleWindowScript} spotify_player"
          "$mainMod, V, Toggle Pulse audio mixer, exec, ${toggleWindowScript} pulsemixer"
          "$mainMod, P, Toggle htop, exec, ${toggleWindowScript} htop"
          "$mainMod, G, Toggle ChatGPT, exec, ${toggleWindowScript} chatgpt"
          ''$mainMod, O, Open my notes in obsidian, exec,  xdg-open "obsidian://open?vault=my-notes"''
          ''
            $mainMod, H, Toggle window, exec, ${toggleWindowScript} "${parseHotkeysScript} | fzf"''
          ''
            $mainMod, F7, Take screenshot, exec, grim -g "$(slurp)" - | swappy -f -''
          ''
            $mainMod, F8, Toggle record region to clipboard, exec, sh -c 'pidf=/tmp/wf-recorder-clip.pid; outdir=$HOME/Videos; mkdir -p "$outdir"; if [ -s "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; then kill -INT "$(cat "$pidf")"; exit; fi; f="$outdir/recording-$(date +%F_%H-%M-%S).mp4"; wf-recorder -g "$(slurp)" -f "$f" & pid=$!; echo "$pid" > "$pidf"; wait "$pid"; rm -f "$pidf"; printf "file://%s\n" "$(realpath "$f")" | wl-copy --type text/uri-list' ''
          "$mainMod ALT, D, Execute command, exec, bash -c"
          "$mainMod, P, Toggle pseudo mode, pseudo, # dwindle"
          "$mainMod, A, Toggle fullscreen, fullscreen, 2"
          "$mainMod, code:69, Focus monitor $monitor-1, focusmonitor, $monitor-1"
          "$mainMod, code:70, Focus monitor $monitor-2, focusmonitor, $monitor-2"
          "$mainMod, code:71, Focus monitor $monitor-3, focusmonitor, $monitor-3"
          "$mainMod SHIFT, left, Move window l, movewindow, l"
          "$mainMod SHIFT, right, Move window r, movewindow, r"
          "$mainMod SHIFT, up, Move window u, movewindow, u"
          "$mainMod SHIFT, down, Move window d, movewindow, d"
          "$mainMod, left, Move focus l, movefocus, l"
          "$mainMod, right, Move focus r, movefocus, r"
          "$mainMod, up, Move focus u, movefocus, u"
          "$mainMod, down, Move focus d, movefocus, d"
          "$mainMod ALT, 1, Toggle special WS 1, togglespecialworkspace, 1"
          "$mainMod ALT, 2, Toggle special WS 2, togglespecialworkspace, 2"
          "$mainMod ALT, 3, Toggle special WS 3, togglespecialworkspace, 3"
          "$mainMod ALT, 4, Toggle special WS 4, togglespecialworkspace, 4"
          "$mainMod ALT, 5, Toggle special WS 5, togglespecialworkspace, 5"
          "$mainMod ALT, 6, Toggle special WS 6, togglespecialworkspace, 6"
          "$mainMod ALT, 7, Toggle special WS 7, togglespecialworkspace, 7"
          "$mainMod ALT, 8, Toggle special WS 8, togglespecialworkspace, 8"
          "$mainMod ALT, 9, Toggle special WS 9, togglespecialworkspace, 9"
          "$mainMod ALT, 0, Toggle special WS 0, togglespecialworkspace, 0"
          "$mainMod ALT CTRL, 1, Move to WS special:1, movetoworkspace, special:1"
          "$mainMod ALT CTRL, 2, Move to WS special:2, movetoworkspace, special:2"
          "$mainMod ALT CTRL, 3, Move to WS special:3, movetoworkspace, special:3"
          "$mainMod ALT CTRL, 4, Move to WS special:4, movetoworkspace, special:4"
          "$mainMod ALT CTRL, 5, Move to WS special:5, movetoworkspace, special:5"
          "$mainMod ALT CTRL, 6, Move to WS special:6, movetoworkspace, special:6"
          "$mainMod ALT CTRL, 7, Move to WS special:7, movetoworkspace, special:7"
          "$mainMod ALT CTRL, 8, Move to WS special:8, movetoworkspace, special:8"
          "$mainMod ALT CTRL, 9, Move to WS special:9, movetoworkspace, special:9"
          "$mainMod ALT CTRL, 0, Move to WS special:0, movetoworkspace, special:0"
          "$mainMod, 1, Focus WS 10 on current monitor, focusworkspaceoncurrentmonitor, 10"
          "$mainMod, 2, Focus WS 20 on current monitor, focusworkspaceoncurrentmonitor, 20"
          "$mainMod, 3, Focus WS 30 on current monitor, focusworkspaceoncurrentmonitor, 30"
          "$mainMod, 4, Focus WS 40 on current monitor, focusworkspaceoncurrentmonitor, 40"
          "$mainMod, 5, Focus WS 50 on current monitor, focusworkspaceoncurrentmonitor, 50"
          "$mainMod, 6, Focus WS 60 on current monitor, focusworkspaceoncurrentmonitor, 60"
          "$mainMod, 7, Focus WS 70 on current monitor, focusworkspaceoncurrentmonitor, 70"
          "$mainMod, 8, Focus WS 80 on current monitor, focusworkspaceoncurrentmonitor, 80"
          "$mainMod, 9, Focus WS 90 on current monitor, focusworkspaceoncurrentmonitor, 90"
          "$mainMod, 0, Focus WS 100 on current monitor, focusworkspaceoncurrentmonitor, 100"
          "$mainMod CTRL, 1, Move to WS 10, movetoworkspacesilent, 10"
          "$mainMod CTRL, 2, Move to WS 20, movetoworkspacesilent, 20"
          "$mainMod CTRL, 3, Move to WS 30, movetoworkspacesilent, 30"
          "$mainMod CTRL, 4, Move to WS 40, movetoworkspacesilent, 40"
          "$mainMod CTRL, 5, Move to WS 50, movetoworkspacesilent, 50"
          "$mainMod CTRL, 6, Move to WS 60, movetoworkspacesilent, 60"
          "$mainMod CTRL, 7, Move to WS 70, movetoworkspacesilent, 70"
          "$mainMod CTRL, 8, Move to WS 80, movetoworkspacesilent, 80"
          "$mainMod CTRL, 9, Move to WS 90, movetoworkspacesilent, 90"
          "$mainMod CTRL, 0, Move to WS 100, movetoworkspacesilent, 100"
          "$mainMod SHIFT, 1, Focus WS 11 on current monitor, focusworkspaceoncurrentmonitor, 11"
          "$mainMod SHIFT, 2, Focus WS 21 on current monitor, focusworkspaceoncurrentmonitor, 21"
          "$mainMod SHIFT, 3, Focus WS 31 on current monitor, focusworkspaceoncurrentmonitor, 31"
          "$mainMod SHIFT, 4, Focus WS 41 on current monitor, focusworkspaceoncurrentmonitor, 41"
          "$mainMod SHIFT, 5, Focus WS 51 on current monitor, focusworkspaceoncurrentmonitor, 51"
          "$mainMod SHIFT, 6, Focus WS 61 on current monitor, focusworkspaceoncurrentmonitor, 61"
          "$mainMod SHIFT, 7, Focus WS 71 on current monitor, focusworkspaceoncurrentmonitor, 71"
          "$mainMod SHIFT, 8, Focus WS 81 on current monitor, focusworkspaceoncurrentmonitor, 81"
          "$mainMod SHIFT, 9, Focus WS 91 on current monitor, focusworkspaceoncurrentmonitor, 91"
          "$mainMod SHIFT, 0, Focus WS 101 on current monitor, focusworkspaceoncurrentmonitor, 101"
          "$mainMod SHIFT CTRL, 1, Move to WS 11, movetoworkspacesilent, 11"
          "$mainMod SHIFT CTRL, 2, Move to WS 21, movetoworkspacesilent, 21"
          "$mainMod SHIFT CTRL, 3, Move to WS 31, movetoworkspacesilent, 31"
          "$mainMod SHIFT CTRL, 4, Move to WS 41, movetoworkspacesilent, 41"
          "$mainMod SHIFT CTRL, 5, Move to WS 51, movetoworkspacesilent, 51"
          "$mainMod SHIFT CTRL, 6, Move to WS 61, movetoworkspacesilent, 61"
          "$mainMod SHIFT CTRL, 7, Move to WS 71, movetoworkspacesilent, 71"
          "$mainMod SHIFT CTRL, 8, Move to WS 81, movetoworkspacesilent, 81"
          "$mainMod SHIFT CTRL, 9, Move to WS 91, movetoworkspacesilent, 91"
          "$mainMod SHIFT CTRL, 0, Move to WS 101, movetoworkspacesilent, 101"
          "$mainMod SHIFT CTRL, C, Execute command, exec, bash -c"
        ];
        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
      };
    };
    programs.hyprlock = {
      enable = true;
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
    services = {
      hypridle.enable = false;
      hyprpaper.enable = lib.mkDefault false;
    };
    home.packages = with pkgs; [
      hyprlauncher
      papirus-icon-theme
      playerctl
    ];

    programs.waybar.enable = true;

    home.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      HYPERLAND_LOG_WLR = "1";
    };
  };
}
