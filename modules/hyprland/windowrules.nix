{ config, lib, ... }:
let
  option = config.module.hyprland;

  workspaceRuleLines = lib.concatStringsSep "\n      " (
    map (m: ''hl.workspace_rule({ workspace = "${toString m.workspace}", monitor = "${m.name}", default = true })'')
      (lib.filter (m: m.enable && m.workspace != null) (lib.attrValues option.monitors))
  );

  browserRegexp = "firefox_firefox|firefox|Chromium|vivaldi-stable|Mullvad Browser|google-chrome|Google-chrome";
  chatRegexp = "discord|vesktop|Slack|.*teams.*|.*outlook.*|chrome-chat.google.com.*";
  terminalRegexp = "Alacritty";
  productivityRegexp = "everdo|obsidian";
  musicRegexp = ".*Spotify.*";
  gamingRegexp = "steam";
  settingsRegexp = "com.saivert.pwvucontrol";
  devtoolRegexp = "com.saivert.pwvucontrol|bruno";
  mailRegexp = "chrome-mail.google.com.*|chrome-calendar.google.com.*";
  programmingRegexp = "code-url-handler|jetbrains-rider|jetbrains-idea|Godot|kiro";
in
{
  config = lib.mkIf option.enable {
    module.hyprland.luaConfig = lib.mkOrder 400 ''
      -- ══════════════════════════════════════
      -- Window Rules
      -- ══════════════════════════════════════

      -- JetBrains floating popups
      hl.window_rule({ match = { class = "^jetbrains-.+$", float = true }, tag = "+jb" })

      -- Ignore empty xwayland windows
      hl.window_rule({ match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, no_focus = true })

      -- Suppress maximize/center for all
      hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize center" })

      -- Tags for app categories
      hl.window_rule({ match = { class = "${devtoolRegexp}" }, tag = "+devtool" })
      hl.window_rule({ match = { class = "${mailRegexp}" }, tag = "+mail" })
      hl.window_rule({ match = { title = "${musicRegexp}" }, tag = "+music" })
      hl.window_rule({ match = { class = "${gamingRegexp}" }, tag = "+gaming" })
      hl.window_rule({ match = { class = "${browserRegexp}" }, tag = "+browser" })
      hl.window_rule({ match = { class = "${productivityRegexp}" }, tag = "+productivity" })
      hl.window_rule({ match = { class = "${chatRegexp}" }, tag = "+chat" })
      hl.window_rule({ match = { initial_title = "${chatRegexp}" }, tag = "+chat" })
      hl.window_rule({ match = { class = "${programmingRegexp}" }, tag = "+coding" })
      hl.window_rule({ match = { class = "${terminalRegexp}" }, tag = "+term" })

      -- Workspace assignments by tag
      hl.window_rule({ match = { tag = "devtool" }, workspace = "10 silent" })
      hl.window_rule({ match = { tag = "music" }, workspace = "20 silent" })
      hl.window_rule({ match = { tag = "gaming" }, workspace = "30 silent" })
      hl.window_rule({ match = { tag = "mail" }, workspace = "40 silent" })
      hl.window_rule({ match = { tag = "productivity" }, workspace = "50 silent" })
      hl.window_rule({ match = { tag = "chat" }, workspace = "60 silent" })
      hl.window_rule({ match = { tag = "coding" }, workspace = "70 silent" })
      hl.window_rule({ match = { tag = "term" }, workspace = "80 silent" })
      hl.window_rule({ match = { tag = "browser" }, workspace = "90 silent" })

      -- Toggle window rules
      hl.window_rule({ match = { class = "toggle-window" }, float = true })
      hl.window_rule({ match = { class = "toggle-window" }, pin = true })
      hl.window_rule({ match = { class = "toggle-window" }, size = {"monitor_w*0.50", "monitor_h*0.50"} })
      hl.window_rule({ match = { class = "toggle-window" }, move = {"monitor_w*0.25", "monitor_h*0.25"} })

      -- JetBrains floating popup sizing
      hl.window_rule({ match = { tag = "jb", float = true }, size = {"monitor_w*0.50", "monitor_h*0.50"} })
      hl.window_rule({ match = { tag = "jb", float = true }, move = {"monitor_w*0.25", "monitor_h*0.25"} })

      -- ══════════════════════════════════════
      -- Workspace Rules (monitor binding)
      -- ══════════════════════════════════════
      ${workspaceRuleLines}
    '';
  };
}
