{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.module.bruno;
  bruno-wrapped = pkgs.symlinkJoin {
    name = "bruno-wrapped";
    paths = [ pkgs.bruno ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/bruno --add-flags "--no-sandbox"
    '';
  };
in {
  options.module.bruno = {
    enable = mkEnableOption "bruno";
  };

  config = mkIf cfg.enable {
    home.packages = [ bruno-wrapped ];
  };
}
