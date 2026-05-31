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
      '';
      profileExtra = ''
        export XAUTHORITY="$HOME/.Xauthority"
        [ -f "$XAUTHORITY" ] || touch "$XAUTHORITY"
        # Hyprland 0.54 starts XWayland without -auth; XWayland reads $XAUTHORITY
        # at launch. Seed a cookie ONCE before the session's XWayland starts.
        # Must be idempotent: profileExtra runs on every login shell, and
        # regenerating the cookie after XWayland is up clobbers the live server
        # cookie -> "Invalid MIT-MAGIC-COOKIE-1 key" for all X11 clients.
        if command -v xauth >/dev/null && command -v mcookie >/dev/null; then
          xauth -f "$XAUTHORITY" list :0 2>/dev/null | grep -q . \
            || xauth -f "$XAUTHORITY" add :0 . "$(mcookie)" 2>/dev/null || true
        fi
      '';
      shellAliases = {
        ls = "ls --color=auto";
      };
    };
  };
}
