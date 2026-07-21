{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.module.bruno;
  # Bruno's Electron single-instance lock lives in ~/.config/bruno as symlinks
  # (SingletonSocket/Lock/Cookie) whose socket target sits under /tmp. After a
  # reboot /tmp is cleared but the symlinks survive pointing at a dead socket;
  # Electron then tears down the main window mid-load, giving a blank screen
  # (ERR_FAILED on index.html). Remove the stale lock when its socket is gone.
  # Guarded on socket liveness so a genuinely running instance keeps its lock.
  clean-stale-lock = pkgs.writeShellScript "bruno-clean-stale-lock" ''
    dir="''${XDG_CONFIG_HOME:-$HOME/.config}/bruno"
    sock="$dir/SingletonSocket"
    if [ -L "$sock" ] && [ ! -S "$(readlink "$sock")" ]; then
      rm -f "$dir/SingletonLock" "$sock" "$dir/SingletonCookie"
    fi
  '';
  bruno-wrapped = pkgs.symlinkJoin {
    name = "bruno-wrapped";
    paths = [ pkgs.bruno ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/bruno \
        --add-flags "--no-sandbox" \
        --run ${clean-stale-lock}
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
