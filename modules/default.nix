{ pkgs, config, ... }:

{
  home.stateVersion = "23.11";

  imports = [
    ./default-applications
    ./bluetooth
    ./discord
    ./game-development
    ./icon-fonts
    ./kiro
    ./obsidian
    ./personal-apps
    ./spotify
    ./fuzzel
    ./wofi
    ./dunst
    ./default-home-dirs
    ./navi
    ./waybar
    ./wlogout
    ./swaync
    ./hyprpaper
    ./ashell
    ./alacritty
    ./hyprland
    ./bash
    ./git-repos
  ];
}
