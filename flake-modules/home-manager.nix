{
  inputs,
  ...
}: let
  mkPkgs = system: import inputs.nixpkgs {inherit system;};

  hyprlandProfile = {...}: {
    module = {
      alacritty.enable = true;
      fuzzel.enable = true;
      wofi.enable = true;
      dunst.enable = true;
      default-home-dirs.enable = true;
      navi.enable = true;
      waybar.enable = true;
      hyprland.enable = true;
      obsidian.enable = false;
    };
  };

  mkHomeConfig = {username, hostProfile ? null, system ? "x86_64-linux"}:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = mkPkgs system;
      extraSpecialArgs = {inherit inputs;};
      modules =
        [
          inputs.self.homeModules.default
          hyprlandProfile
          inputs.nixvim.homeModules.nixvim
          {
            home.username = username;
            home.homeDirectory = "/home/${username}";
            home.stateVersion = "23.11";
          }
        ]
        ++ (
          if hostProfile != null
          then [hostProfile]
          else []
        );
    };
in {
  flake.homeModules.default = import ../modules;

  flake.homeConfigurations = {
    goodrod = mkHomeConfig {username = "goodrod";};
    calle = mkHomeConfig {username = "calle";};
    david = mkHomeConfig {username = "david";};
    david3 = mkHomeConfig {username = "david3";};
    test-user = mkHomeConfig {username = "test-user";};

    "goodrod@work" = mkHomeConfig {
      username = "goodrod";
      hostProfile = ../hosts/work/home.nix;
    };
    "goodrod@private" = mkHomeConfig {
      username = "goodrod";
      hostProfile = ../hosts/private/home.nix;
    };
  };
}
