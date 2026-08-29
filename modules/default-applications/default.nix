{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.module.default-applications;
in {
  options.module.default-applications = {
    enable = mkEnableOption "default-applications";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      alacritty
      jq
      fuzzel
      jsonfmt
      killall
      git
      wget
      fzf
      nixfmt
      xwallpaper
      pavucontrol
      openssl
      wlr-randr
      wl-clipboard
      libnotify
      icu
      unzip
      traceroute
      htop
      atop
      slurp
      swappy
      grim
      wf-recorder
      ffmpeg
      fd
      tree
      pkgs.custom-nvim
      thunar
    ];
  };
}
