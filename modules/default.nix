{
  pkgs,
  config,
  ...
}: {
  home.stateVersion = "26.05";

  imports = [
    ./bruno
    ./default-applications
    ./bluetooth
    ./discord
    ./everdo
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
    ./workspaces
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
