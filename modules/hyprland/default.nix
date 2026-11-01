{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types mkIf concatStringsSep;
  inherit (types) str bool listOf lines attrsOf submodule nullOr int;
  settings = config.module.hyprland;
in
{
  imports = [
    ./appearance.nix
    ./keybinds
    ./windowrules.nix
    ./settings.nix
    ./lockscreen.nix
    ./notif-focus.nix
    ./pending-move.nix
    ./task-workspace-cleanup.nix
    ./exclusive-workspaces.nix
  ];

  options.module.hyprland = {
    enable = mkEnableOption "hyprland";

    autostart-from-tty = mkEnableOption ''
      starting Hyprland from the bash login shell on tty1, so a plain getty
      login lands in the desktop. Other ttys stay a shell to recover from'';

    # Off by default: the base module is the QoL every profile shares, and a
    # host opts into the workspace-heavy desktop pieces it actually uses.
    features = {
      taskWorkspaces.enable = mkEnableOption ''
        task workspaces: the SUPER+T pickers and the auto-forget of emptied
        ad-hoc ones'';
      categoryWorkspaces.enable = mkEnableOption ''
        the window tag and workspace assignment rules built from
        module.workspaces.entries'';
      workspaceGrid.enable = mkEnableOption ''
        the SUPER + 1-0 workspace focus and SUPER+CTRL + 1-0 move binds'';
      shiftedWorkspaces.enable = mkEnableOption ''
        the "+1" twin of every grid workspace (11, 21..101) on SUPER+ALT,
        and right-clicking a bar workspace to reach it'';
      columnTools.enable = mkEnableOption ''
        the scrolling-layout column tools: width cycling, the portrait
        full-width clamp, column swap/promote/fit and first/last column focus'';
    };
    keys = {
      screenshot = mkOption {
        type = str;
        default = "F7";
        description = "Key (with any extra modifiers) that, with SUPER, screenshots a region.";
      };
      screenshotMonitor = mkOption {
        type = str;
        default = "SHIFT + F7";
        description = "Key that, with SUPER, screenshots a whole monitor, picked with a click.";
      };
      record = mkOption {
        type = str;
        default = "F8";
        description = "Key that, with SUPER, starts or stops recording a region.";
      };
      exit = mkOption {
        type = str;
        default = "F12";
        example = "SHIFT + Delete";
        description = "Key that, with SUPER, exits Hyprland.";
      };
    };

    screenshot-editor-workspace = mkOption {
      type = nullOr int;
      default = null;
      example = 10;
      description = ''
        Workspace the screenshot editor (satty) opens on, in the background,
        so it never lands on top of a game or in a tiled layout and never
        pulls you away from one. null opens it on the current workspace.
      '';
    };

    lockscreen = mkOption {
      type = types.enum [ "hyprlock" "swaylock" ];
      default = "hyprlock";
      description = "Which lockscreen to use (hyprlock for NixOS, swaylock for Ubuntu)";
    };
    startup-commands = mkOption {
      type = listOf str;
      default = [];
    };
    monitors = mkOption {
      default = {};
      description = ''
        Monitors keyed by an arbitrary name. The attribute key is used as the
        Hyprland output name unless `name` is set explicitly. Declare as many as
        you like.
      '';
      type = attrsOf (submodule ({ name, ... }: {
        options = {
          enable = mkOption { type = bool; default = true; };
          name = mkOption {
            type = str;
            default = name;
            description = "Hyprland output name (e.g. \"DP-1\"). Defaults to the attribute key.";
          };
          settings = mkOption {
            type = str;
            default = "preferred,0x0,1.0";
            description = "Monitor settings as \"mode,position,scale\" (e.g. \"preferred,2560x0,1.0\").";
          };
          workspace = mkOption {
            type = nullOr int;
            default = null;
            description = "Default workspace number bound to this monitor (e.g. 10). null = no binding.";
          };
          pinnedWorkspaces = mkOption {
            type = listOf int;
            default = [ ];
            example = [ 10 ];
            description = ''
              Workspaces that always live on this monitor. Jumping to one
              (SUPER + its number, or the bar) goes to it here instead of
              pulling it onto the monitor you are on.
            '';
          };
          exclusiveWorkspace = mkOption {
            type = nullOr int;
            default = null;
            example = 10;
            description = ''
              While this workspace has windows, the monitor shows nothing
              else: switching it to another workspace bounces straight back.
              Must also be in pinnedWorkspaces.
            '';
          };
          focusKey = mkOption {
            type = nullOr str;
            default = null;
            description = "Key that focuses this monitor (e.g. \"F3\"). null = no focus bind.";
          };
        };
      }));
    };
    luaConfig = mkOption {
      type = lines;
      default = "";
      description = "Lua config fragments assembled into hyprland.lua";
    };
  };

  config = mkIf settings.enable {
    assertions = map (m: {
      assertion = m.exclusiveWorkspace == null || builtins.elem m.exclusiveWorkspace m.pinnedWorkspaces;
      message = "module.hyprland.monitors: exclusiveWorkspace ${toString m.exclusiveWorkspace} on ${m.name} must also be in its pinnedWorkspaces.";
    }) (builtins.attrValues settings.monitors);

    wayland.windowManager.hyprland = {
      enable = true;
      sourceFirst = true;
      systemd.enable = true;
      xwayland.enable = true;
      package = pkgs.hyprland;
      portalPackage = pkgs.xdg-desktop-portal-hyprland;
      plugins = [ ];
      extraConfig = "-- Real configuration lives in xdg.configFile \"hypr/hyprland.lua\"";
    };

    xdg.configFile."hypr/hyprland.lua".text = settings.luaConfig;

    programs.bash.profileExtra = mkIf settings.autostart-from-tty ''
      if [ -z "$WAYLAND_DISPLAY" ] && [ "''${XDG_VTNR:-}" = 1 ]; then
        exec start-hyprland
      fi
    '';

    services = {
      hypridle.enable = false;
      hyprpaper.enable = lib.mkDefault false;
    };

    home.packages = with pkgs; [
      hyprlauncher
      papirus-icon-theme
      playerctl
      slurp
      wf-recorder
      wl-clipboard
    ];

    home.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      HYPERLAND_LOG_WLR = "1";
    };
  };
}
