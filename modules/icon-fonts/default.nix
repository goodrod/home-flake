{ config, pkgs, lib, inputs, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.module.icon-fonts;
in {
  options.module.icon-fonts = {
    enable = mkEnableOption "icon-fonts";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs;
      [ font-awesome ] ++ builtins.filter lib.attrsets.isDerivation
      (builtins.attrValues pkgs.nerd-fonts);
  };
}
