{ config, pkgs, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.intellij;
  intellij-wrapped = pkgs.symlinkJoin {
    name = "intellij-wrapped";
    paths = [ pkgs.jetbrains.idea ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/idea \
        --add-flags "-Dawt.toolkit.name=WLToolkit"
    '';
  };
in {
  options.module.intellij = {
    enable = mkEnableOption "intellij";
  };

  config = mkIf settings.enable {
    home.packages = [ intellij-wrapped ];
  };
}
