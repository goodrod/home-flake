{
  inputs,
  ...
}: {
  flake.homeModules.default = import ../modules;
  flake.overlays.default = final: prev: {
    hyprland = inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.hyprland;
    xdg-desktop-portal-hyprland = inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    hyprbars = inputs.hyprland-plugins.packages.${prev.stdenv.hostPlatform.system}.hyprbars;
    hyprlauncher = inputs.hyprlauncher.packages.${prev.stdenv.hostPlatform.system}.default;
    hyprpaper = inputs.hyprpaper.packages.${prev.stdenv.hostPlatform.system}.default;
    ashell = inputs.ashell.packages.${prev.stdenv.hostPlatform.system}.default;
    custom-nvim = inputs.nvim.packages.${prev.stdenv.system}.nvim;
    aseprite =
      (import inputs.nixpkgs-aseprite {
        system = prev.stdenv.hostPlatform.system;
        config.allowUnfreePredicate = pkg: builtins.elem (inputs.nixpkgs-aseprite.lib.getName pkg) [ "aseprite" ];
      }).aseprite;
  };
}
