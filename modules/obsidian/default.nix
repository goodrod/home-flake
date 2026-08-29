{ config, pkgs, lib, inputs, ... }:
with lib;
let
  cfg = config.module.obsidian;
in {
  options.module.obsidian = {
    enable = mkEnableOption "obsidian";
  };

  config = mkIf cfg.enable {
    programs.obsidian.enable = true;
  };
}
