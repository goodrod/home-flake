{ pkgs, config, ... }:

{
  home.stateVersion = "23.11";

  imports = [
    ./default-applications
    ./obsidian
    ./fuzzel
    ./wofi
    ./dunst
    ./default-home-dirs
    ./navi
    ./waybar
    ./wlogout
    ./swaync
    ./ashell
    ./alacritty
    ./hyprland
    ./bash
    ./git-repos
  ];
}
