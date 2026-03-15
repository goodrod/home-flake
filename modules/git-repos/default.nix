{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types mkIf concatStringsSep;
  option = config.module.git-repos;
  cloneScript = concatStringsSep "\n" (map (repo: ''
    if [ ! -d "$HOME/${repo.path}" ]; then
      mkdir -p "$HOME/$(dirname "${repo.path}")"
      ${pkgs.git}/bin/git clone ${repo.url} "$HOME/${repo.path}"
    fi
    ${lib.optionalString (repo.pushUrl != null) ''
      ${pkgs.git}/bin/git -C "$HOME/${repo.path}" remote set-url --push origin ${repo.pushUrl}
    ''}
    ${lib.optionalString (repo.link != null) ''
      if [ ! -e "$HOME/${repo.link}" ]; then
        ln -s "$HOME/${repo.path}" "$HOME/${repo.link}"
      fi
    ''}
  '') option.repos);
in {
  options.module.git-repos = {
    enable = mkEnableOption "git-repos";
    repos = mkOption {
      type = types.listOf (types.submodule {
        options = {
          url = mkOption { type = types.str; };
          path = mkOption { type = types.str; };
          pushUrl = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          link = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
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
