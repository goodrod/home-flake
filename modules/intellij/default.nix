{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.module.intellij;
in {
  options.module.intellij = {
    enable = mkEnableOption "intellij";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.jetbrains.idea ];
  };
}
