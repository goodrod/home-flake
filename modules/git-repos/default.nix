{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types mkIf concatStringsSep;
  option = config.module.git-repos;
  cloneScript = concatStringsSep "\n" (map (repo: ''
    if [ ! -d "$HOME/${repo.path}" ]; then
      ${pkgs.git}/bin/git clone ${repo.url} "$HOME/${repo.path}"
    fi
  '') option.repos);
in {
  options.module.git-repos = {
    enable = mkEnableOption "git-repos";
    repos = mkOption {
      type = types.listOf (types.submodule {
        options = {
          url = mkOption { type = types.str; };
          path = mkOption { type = types.str; };
        };
      });
      default = [];
    };
  };

  config = mkIf option.enable {
    home.activation.cloneRepos = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${cloneScript}
    '';
  };
}
