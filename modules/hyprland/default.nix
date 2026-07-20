{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types mkIf concatStringsSep;
  inherit (types) str bool listOf lines attrsOf submodule nullOr int;
  option = config.module.hyprland;
in
{
  imports = [
    ./appearance.nix
    ./keybinds.nix
    ./windowrules.nix
    ./settings.nix
    ./lockscreen.nix
    ./notif-focus.nix
    ./pending-move.nix
    ./task-workspace-cleanup.nix
  ];

  options.module.hyprland = {
    enable = mkEnableOption "hyprland";
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

  config = mkIf option.enable {
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

    xdg.configFile."hypr/hyprland.lua".text = option.luaConfig;

    services = {
      hypridle.enable = false;
      hyprpaper.enable = lib.mkDefault false;
    };

    home.packages = with pkgs; [
      hyprlauncher
      papirus-icon-theme
      playerctl
    ];

    home.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      HYPERLAND_LOG_WLR = "1";
    };
  };
}
