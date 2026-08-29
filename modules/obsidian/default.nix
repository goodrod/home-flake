{ config, pkgs, lib, inputs, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.module.obsidian;
in {
  options.module.obsidian = {
    enable = mkEnableOption "obsidian";
  };

  config = mkIf cfg.enable {
    programs.obsidian.enable = true;
  };
}
