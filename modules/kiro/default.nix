{ config, pkgs, lib, inputs, ... }:
with lib;
let
  cfg = config.module.kiro;
in {
  options.module.kiro = {
    enable = mkEnableOption "kiro";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ kiro-fhs ];
  };
}
