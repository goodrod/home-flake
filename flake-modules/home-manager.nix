{
  inputs,
  ...
}: {
  flake.homeModules.default = import ../modules;
  flake.overlays.default = final: prev: {
    hyprland = inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.hyprland;
    xdg-desktop-portal-hyprland = inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    hyprlauncher = inputs.hyprlauncher.packages.${prev.stdenv.hostPlatform.system}.default;
    ashell = inputs.ashell.packages.${prev.stdenv.hostPlatform.system}.default;
    custom-nvim = inputs.nvim.packages.${prev.stdenv.system}.nvim;
  };
}
