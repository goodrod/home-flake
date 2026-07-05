{ config, lib, ... }:
let
  option = config.module.hyprland;

  workspaceRuleLines = lib.concatStringsSep "\n      " (
    map (m: ''hl.workspace_rule({ workspace = "${toString m.workspace}", monitor = "${m.name}", default = true })'')
      (lib.filter (m: m.enable && m.workspace != null) (lib.attrValues option.monitors))
  );

  # Single source of truth for workspaces lives in module.workspaces.
  workspaces = config.module.workspaces.entries;

  # Map Nix match-field name -> Hyprland Lua match key.
  matchFields = [
    { attr = "class"; lua = "class"; }
    { attr = "title"; lua = "title"; }
    { attr = "initialTitle"; lua = "initial_title"; }
  ];

  # Escape a regexp for embedding in a Lua double-quoted string.
  luaEscape = lib.replaceStrings [ ''\'' ''"'' ] [ ''\\'' ''\"'' ];

  hasMatch = ws: lib.any (f: let v = ws.match.${f.attr}; in v != null && v != "") matchFields;

  # Tag rules: one hl.window_rule per non-null/non-empty match field. Order-independent.
  tagRuleLines = lib.concatStringsSep "\n      " (
    lib.concatLists (lib.mapAttrsToList (tag: ws:
      lib.concatMap (f:
        let v = ws.match.${f.attr}; in
        if v == null || v == "" then [ ]
        else [ ''hl.window_rule({ match = { ${f.lua} = "${luaEscape v}" }, tag = "+${tag}" })'' ]
      ) matchFields
    ) workspaces)
  );

  # Assignment rules: tag -> workspace "<id> silent", in id order. Skip waybar-only
  # workspaces (no match fields), which have no tag to assign.
  wsList = lib.mapAttrsToList (tag: ws: ws // { _tagName = tag; }) workspaces;
  sortedWsWithNames = lib.sort (a: b: a.id < b.id) wsList;
  assignmentRuleLines = lib.concatStringsSep "\n      " (
    lib.concatMap (ws:
      if hasMatch ws
      then [ ''hl.window_rule({ match = { tag = "${ws._tagName}" }, workspace = "${toString ws.id} silent" })'' ]
      else [ ]
    ) sortedWsWithNames
  );
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
      ${tagRuleLines}

      -- Workspace assignments by tag
      ${assignmentRuleLines}

      -- Toggle window rules
      hl.window_rule({ match = { class = "toggle-window" }, float = true })
      hl.window_rule({ match = { class = "toggle-window" }, pin = true })
      hl.window_rule({ match = { class = "toggle-window" }, size = {"monitor_w*0.70", "monitor_h*0.70"} })
      hl.window_rule({ match = { class = "toggle-window" }, move = {"monitor_w*0.15", "monitor_h*0.15"} })

      -- Hide from screen sharing
      -- swaync popups are layer-shell surfaces (gtk_layer_set_namespace), not toplevel
      -- windows, so they need layer_rule/namespace, not window_rule/class.
      hl.layer_rule({ match = { namespace = "swaync-notification-window" }, no_screen_share = true })
      hl.layer_rule({ match = { namespace = "swaync-control-center" }, no_screen_share = true })
      -- discord/vesktop/Slack default to excluded; SUPER+SHIFT+S (keybinds.nix)
      -- can flip any window's exclusion, these included. See setNoShare there:
      -- a rule-based "tag" default would get continuously reasserted and fight
      -- the toggle, so the default is applied once on window open instead.

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
