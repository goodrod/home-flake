{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkOption mkEnableOption types mkIf concatStringsSep;
  inherit (types) str bool listOf lines;
  option = config.module.hyprland;
in
{
  imports = [
    ./appearance.nix
    ./keybinds.nix
    ./windowrules.nix
    ./settings.nix
    ./lockscreen.nix
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
    monitors = {
      left = {
        enable = mkOption { type = bool; default = false; };
        name = mkOption { type = str; description = "Left monitor"; default = ""; };
        settings = mkOption { type = str; description = "Settings for monitor"; default = "preferred,0x0,1.0"; };
      };
      middle = {
        enable = mkOption { type = bool; default = false; };
        name = mkOption { type = str; description = "Middle monitor"; default = "DP-3"; };
        settings = mkOption { type = str; description = "Settings for monitor"; default = "preferred,0x0,1.0"; };
      };
      right = {
        enable = mkOption { type = bool; default = false; };
        name = mkOption { type = str; description = "Right monitor"; default = "HDMI-A-2"; };
        settings = mkOption { type = str; description = "Settings for monitor"; default = "preferred,2560x0,1.0"; };
      };
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

    programs.waybar.enable = true;

    home.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      HYPERLAND_LOG_WLR = "1";
    };
  };
}
