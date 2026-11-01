{ config, lib, ... }:
let
  settings = config.module.hyprland;

  # Keys 1-9,0 -> workspaces 10,20..100, plus offset.
  gridBinds = mods: offset: mkBind:
    lib.concatStringsSep "\n" (map (n:
      let ws = toString (n * 10 + offset); key = toString (lib.mod n 10);
      in mkBind ''mainMod .. " + ${mods}${key}"'' ws
    ) (lib.range 1 10));

  focusBind = keyExpr: ws: ''hl.bind(${keyExpr}, hl.dsp.focus({workspace = ${ws}, on_current_monitor = true}), { description = "Focus WS ${ws} on current monitor" })'';
  moveBind = keyExpr: ws: ''hl.bind(${keyExpr}, hl.dsp.window.move({workspace = ${ws}, follow = false}), { description = "Move to WS ${ws}" })'';
in
{
  config = lib.mkIf (settings.enable && settings.features.workspaceGrid.enable) {
    module.hyprland.luaConfig = lib.mkOrder 320 ''
      -- Shifted workspaces, "+n" variant, id+1 (ALT + 1-0 -> 11,21..101)
      ${gridBinds "ALT + " 1 focusBind}

      -- Move to shifted workspaces (ALT + CTRL + 1-0 -> 11,21..101)
      ${gridBinds "ALT + CTRL + " 1 moveBind}

      -- Workspaces (1-0 -> 10,20..100)
      ${gridBinds "" 0 focusBind}

      -- Move to workspaces (CTRL + 1-0 -> 10,20..100)
      ${gridBinds "CTRL + " 0 moveBind}
    '';
  };
}
