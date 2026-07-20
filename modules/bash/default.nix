{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  option = config.module.bash;
in {
  options.module.bash = {enable = mkEnableOption "bash";};

  config = mkIf option.enable {
    home.packages = with pkgs; [xauth util-linux];

    programs.bash = {
      enable = true;
      initExtra = ''
        eval "$(dircolors -b)"
        PROMPT_COLOR="1;32m"
        ((UID == 0)) && PROMPT_COLOR="1;31m"
        __title_prefix=""
        [ -n "$SSH_CONNECTION" ] && __title_prefix="\h:"
        PS1="\n\[\033[$PROMPT_COLOR\][\[\e]0;''${__title_prefix}\W\a\]\u@\h:\w]\$\[\033[0m\] "

        # mod+N (focus-last-notif-app) can't reliably find the terminal that
        # ran a plain `notify-send`: the CLI process exits before the
        # watcher daemon can walk its ancestry. Stamp our own (long-lived)
        # shell pid as a hint so the watcher can skip straight to it.
        notify-send() {
          command notify-send --hint=int:x-shell-pid:$$ "$@"
        }
      '';
      shellAliases = {
        ls = "ls --color=auto";
      };
    };
  };
}
