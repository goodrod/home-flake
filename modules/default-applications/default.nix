{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.default-applications;
in {
  options.module.default-applications = {
    enable = mkEnableOption "default-applications";
  };

  config = mkIf settings.enable {
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
      ffmpeg
      fd
      tree
      pkgs.custom-nvim
      thunar
    ];
  };
}
