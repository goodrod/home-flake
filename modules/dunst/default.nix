{ config, pkgs, lib, inputs, ... }:
with lib;
let
  # Shorter name to access final settings a
  # user of hello.nix module HAS ACTUALLY SET.
  # cfg is a typical convention.
  cfg = config.module.dunst;
in {
  imports = [
    # Paths to other modules.
    # Compose this module out of smaller ones.
  ];

  options.module.dunst = {
    # Option declarations.
    # Declare what settings a user of this module module can set.
    # Usually this includes a global "enable" option which defaults to false.
    enable = mkEnableOption "dunst";
  };

  config = mkIf cfg.enable {
    # Option definitions.
    # Define what other settings, services and resources should be active.
    # Usually these depend on whether a user of this module chose to "enable" it
    # using the "option" above.
    # Options for modules imported in "imports" can be set here.
    services.dunst = {
      enable = true;
      iconTheme = {
        name = "Papirus";
        package = pkgs.papirus-icon-theme;
        size = "16x16";
      };
      settings = {
        global = {
          follow = "mouse";
          indicate_hidden = "yes";
          offset = "10x10";
          separator_height = 2;
          padding = 8;
          horizontal_padding = 8;
          text_icon_padding = 0;
          frame_width = 2;
          frame_color = "#cdd6f4";
          separator_color = "frame";
          sort = "yes";
          idle_threshold = 120;
          font = "CaskaydiaCove Nerd Font 10";
          line_height = 0;
          markup = "full";
          alignment = [ "left" ];
          vertical_alignment = "center";
          show_age_threshold = 60;
          word_wrap = "yes";
          stack_duplicates = "true";
          hide_duplicate_count = "false";
          show_indicators = "yes";
          min_icon_size = 0;
          max_icon_size = 64;

          corner_radius = 10;
          timeout = 5;
        };
        urgency_low = {
          background = "#404A60";
          foreground = "#D8DEE9";
        };

        urgency_normal = {
          background = "#404A60";
          foreground = "#D8DEE9";
        };

        urgency_critical = {
          background = "#404A60";
          foreground = "#D8DEE9";
          frame_color = "#f38ba8";
        };
      };
    };
  };
}
