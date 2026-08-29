# Starter for a home-manager module. Copy this directory to modules/<name>/,
# replace "placeholder" throughout, and add ./<name> to the imports list in
# modules/default.nix - nothing loads a module until it is listed there.
{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  settings = config.module.placeholder;
in
{
  options.module.placeholder = {
    enable = mkEnableOption "placeholder";
  };

  config = mkIf settings.enable { };
}
