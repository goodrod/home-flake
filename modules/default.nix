{ pkgs, config, ... }:

{
  home.stateVersion = "23.11";

  imports = [
    ./bruno
    ./beekeeper-studio
    ./default-applications
    ./bluetooth
    ./discord
    ./game-development
    ./icon-fonts
    ./intellij
    ./kiro
    ./obsidian
    ./personal-apps
    ./spotify
    ./fuzzel
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
