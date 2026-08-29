{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.bluetooth;
in {
  options.module.bluetooth = {
    enable = mkEnableOption "bluetooth";
  };

  config = mkIf settings.enable {
    home.packages = with pkgs; [ blueman bluetuith ];
  };
}
