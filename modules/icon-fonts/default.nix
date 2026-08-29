{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.icon-fonts;
in {
  options.module.icon-fonts = {
    enable = mkEnableOption "icon-fonts";
  };

  config = mkIf settings.enable {
    home.packages = with pkgs;
      [ font-awesome ] ++ builtins.filter lib.attrsets.isDerivation
      (builtins.attrValues pkgs.nerd-fonts);
  };
}
