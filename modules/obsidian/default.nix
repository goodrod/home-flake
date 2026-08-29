{ config, pkgs, lib, inputs, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.obsidian;
in {
  options.module.obsidian = {
    enable = mkEnableOption "obsidian";
  };

  config = mkIf settings.enable {
    programs.obsidian.enable = true;
  };
}
