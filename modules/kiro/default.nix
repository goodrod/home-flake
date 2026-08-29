{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.kiro;
in {
  options.module.kiro = {
    enable = mkEnableOption "kiro";
  };

  config = mkIf settings.enable {
    home.packages = with pkgs; [ kiro-fhs ];
  };
}
