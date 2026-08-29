{ config, pkgs, lib, inputs, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.module.game-development;
in {
  options.module.game-development = {
    enable = mkEnableOption "game-development";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ godot blender aseprite ];
  };
}
