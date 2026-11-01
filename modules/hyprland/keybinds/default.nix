{ config, lib, ... }:
let
  settings = config.module.hyprland;
in
{
  # Lua locals are only visible below their definition, so the fragments are
  # ordered: mainMod here, then columns.nix (core's focusMonitor calls its
  # clamp), then core.nix, tasks.nix and workspace-grid.nix.
  imports = [
    ./columns.nix
    ./core.nix
    ./tasks.nix
    ./workspace-grid.nix
  ];

  config = lib.mkIf settings.enable {
    module.hyprland.luaConfig = lib.mkOrder 280 ''
      -- ══════════════════════════════════════
      -- Keybinds
      -- ══════════════════════════════════════
      local mainMod = "SUPER"
    '';
  };
}
