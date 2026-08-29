{ config, pkgs, lib, inputs, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.module.bluetooth;
in {
  options.module.bluetooth = {
    enable = mkEnableOption "bluetooth";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ blueman bluetuith ];
  };
}
