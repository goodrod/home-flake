{ config, pkgs, lib, inputs, ... }:
with lib;
let
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
