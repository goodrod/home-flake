{
  description = "Home-manager config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    nvim = {
      url = "github:goodrod/nvim";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    hyprlauncher = {
      url = "github:hyprwm/hyprlauncher";
      inputs.hyprtoolkit.follows = "hyprland/hyprland-guiutils/hyprtoolkit";
      inputs.aquamarine.follows = "hyprland/aquamarine";
      inputs.hyprgraphics.follows = "hyprland/hyprgraphics";
      inputs.hyprlang.follows = "hyprland/hyprlang";
      inputs.hyprutils.follows = "hyprland/hyprutils";
      inputs.hyprwayland-scanner.follows = "hyprland/hyprwayland-scanner";
      inputs.hyprwire.follows = "hyprland/hyprwire";
    };

    hyprpaper = {
      url = "github:hyprwm/hyprpaper";
      inputs.hyprtoolkit.follows = "hyprland/hyprland-guiutils/hyprtoolkit";
      inputs.aquamarine.follows = "hyprland/aquamarine";
      inputs.hyprgraphics.follows = "hyprland/hyprgraphics";
      inputs.hyprlang.follows = "hyprland/hyprlang";
      inputs.hyprutils.follows = "hyprland/hyprutils";
      inputs.hyprwayland-scanner.follows = "hyprland/hyprwayland-scanner";
      inputs.hyprwire.follows = "hyprland/hyprwire";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ashell.url = "github:MalpenZibo/ashell";

    import-tree.url = "github:vic/import-tree";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; }
    (inputs.import-tree ./flake-modules);
}
