{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (types) attrsOf submodule nullOr int str bool;

  entries = config.module.workspaces.entries;
  ids = map (ws: ws.id) (lib.attrValues entries);
in
{
  options.module.workspaces = {
    # Options only - this module is pure shared data consumed by the quickshell
    # and hyprland modules. Each of those gates its own output on its own enable flag.

    entries = mkOption {
      description = ''
        Workspace definitions keyed by tag name. The key is used verbatim as the
        Hyprland window tag (e.g. "chat" -> tag "+chat") and must be unique. Drives
        both the quickshell workspace widget (icons + persistent list) and the Hyprland
        window tag/assignment rules.
      '';
      default = {
        devtool = {
          id = 10;
          icon = "󱁤";
          persistent = true;
          match.class = "com.saivert.pwvucontrol|bruno";
        };
        music = {
          id = 20;
          icon = "󰎆";
          persistent = true;
          match.title = ".*Spotify.*";
        };
        gaming = {
          id = 30;
          icon = "󰊗";
          persistent = true;
          match.class = "steam";
        };
        mail = {
          id = 40;
          icon = "󰇮";
          persistent = true;
          match.class = "chrome-mail.google.com.*|chrome-calendar.google.com.*";
        };
        productivity = {
          id = 50;
          icon = "󰠮";
          persistent = true;
          match.class = "everdo|obsidian";
        };
        chat = {
          id = 60;
          icon = "󰭹";
          match = {
            class = "discord|vesktop|Slack|.*teams.*|.*outlook.*|chrome-chat.google.com.*";
            initialTitle = "discord|vesktop|Slack|.*teams.*|.*outlook.*|chrome-chat.google.com.*";
          };
        };
        coding = {
          id = 70;
          icon = "󰅩";
          match.class = "code-url-handler|jetbrains-rider|jetbrains-idea|Godot|kiro";
        };
        term = {
          id = 80;
          icon = "󰆍";
          match.class = "Alacritty";
        };
        browser = {
          id = 90;
          icon = "󰈹";
          match.class = "firefox_firefox|firefox|Chromium|vivaldi-stable|Mullvad Browser|google-chrome|Google-chrome";
        };
      };
      type = attrsOf (submodule ({ ... }: {
        options = {
          id = mkOption {
            type = int;
            description = ''
              Numeric workspace id (N*10 convention, e.g. 10, 20, ...). Must be unique.
              The shifted variant id is id+1 (e.g. 11) and is derived automatically.
            '';
          };

          icon = mkOption {
            type = str;
            description = "Glyph shown for this workspace.";
          };

          shiftedIcon = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              Icon for the shifted (id+1) variant. null = auto-derive as `icon + " +"`.
              Set explicitly only if you want a different shifted glyph.
            '';
          };

          persistent = mkOption {
            type = bool;
            default = false;
            description = "Show this workspace even when empty (persistent-workspaces).";
          };

          match = mkOption {
            default = { };
            description = ''
              Hyprland match regexps. Any non-null/non-empty field produces one
              `hl.window_rule({ match = { <field> = <regexp> }, tag = "+<name>" })`.
              Leave all null for a bar-only workspace (e.g. a scratch ws) with no
              automatic window assignment.
            '';
            type = submodule {
              options = {
                class = mkOption {
                  type = nullOr str;
                  default = null;
                };
                title = mkOption {
                  type = nullOr str;
                  default = null;
                };
                initialTitle = mkOption {
                  type = nullOr str;
                  default = null;
                };
              };
            };
          };
        };
      }));
    };
  };

  config.assertions = [
    {
      assertion = lib.length (lib.unique ids) == lib.length ids;
      message = "module.workspaces.entries: workspace ids must be unique (got ids ${toString ids}).";
    }
  ];
}
