{ config, pkgs, lib, inputs, ... }:
with lib;
let
  cfg = config.module.game-development;
in {
  options.module.game-development = {
    enable = mkEnableOption "game-development";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ godot blender aseprite ];
  };
}
