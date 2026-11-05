{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.game-development;
in {
  options.module.game-development = {
    enable = mkEnableOption "game-development";
  };

  config = mkIf settings.enable {
    home.packages = with pkgs; [ godot blender ];
  };
}
