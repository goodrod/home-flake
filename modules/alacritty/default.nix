{ config, pkgs, lib, ... }:

let
  inherit (lib) mkOption mkEnableOption types mkIf;
  inherit (types) path str;
  option = config.module.alacritty;
in {
  options.module.alacritty = { enable = mkEnableOption "alacritty"; };

  config = mkIf option.enable {
    programs.alacritty = {
      enable = true;
      settings = {
        window.opacity = 0.8;
        # Without this, alacritty inherits Hyprland's own cwd (whatever the
        # login shell's cwd was when start-hyprland got exec'd), so every new
        # terminal opened up in ~/home-configs. Pin it to $HOME instead.
        general.working_directory = config.home.homeDirectory;
      };
    };
  };
}
