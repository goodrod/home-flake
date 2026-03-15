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
        PROMPT_COLOR="1;32m"
        ((UID == 0)) && PROMPT_COLOR="1;31m"
        PS1="\n\[\033[$PROMPT_COLOR\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] "
      '';
    };
  };
}
