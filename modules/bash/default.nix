{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  option = config.module.bash;
in {
  options.module.bash = { enable = mkEnableOption "bash"; };

  config = mkIf option.enable {
    programs.bash = {
      enable = true;
      initExtra = ''
        eval "$(dircolors -b)"
        PROMPT_COLOR="1;32m"
        ((UID == 0)) && PROMPT_COLOR="1;31m"
        __title_prefix=""
        [ -n "$SSH_CONNECTION" ] && __title_prefix="\h:"
        PS1="\n\[\033[$PROMPT_COLOR\][\[\e]0;''${__title_prefix}\W\a\]\u@\h:\w]\$\[\033[0m\] "
      '';
      shellAliases = {
        ls = "ls --color=auto";
      };
    };
  };
}
