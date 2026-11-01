{ config, lib, ... }:
let
  settings = config.module.hyprland;

  # With category workspaces, only their numbers get keys; otherwise the
  # whole 1-0 grid does.
  categoryIds = map (ws: ws.id) (lib.attrValues config.module.workspaces.entries);
  hasKey = n: !settings.features.categoryWorkspaces.enable || lib.elem (n * 10) categoryIds;

  # Keys 1-9,0 -> workspaces 10,20..100, plus offset.
  gridBinds = mods: offset: mkBind:
    lib.concatStringsSep "\n" (map (n:
      let ws = toString (n * 10 + offset); key = toString (lib.mod n 10);
      in mkBind ''mainMod .. " + ${mods}${key}"'' ws
    ) (lib.filter hasKey (lib.range 1 10)));

  pinned = map toString (lib.concatMap (m: m.pinnedWorkspaces)
    (lib.filter (m: m.enable) (lib.attrValues settings.monitors)));

  focusBind = keyExpr: ws:
    if lib.elem ws pinned
    then ''hl.bind(${keyExpr}, hl.dsp.focus({workspace = ${ws}}), { description = "Focus WS ${ws} on its pinned monitor" })''
    else ''hl.bind(${keyExpr}, hl.dsp.focus({workspace = ${ws}, on_current_monitor = true}), { description = "Focus WS ${ws} on current monitor" })'';
  moveBind = keyExpr: ws: ''hl.bind(${keyExpr}, hl.dsp.window.move({workspace = ${ws}, follow = false}), { description = "Move to WS ${ws}" })'';
in
{
  config = lib.mkIf settings.enable {
    module.hyprland.luaConfig = lib.mkMerge [
      (lib.mkIf settings.features.shiftedWorkspaces.enable (lib.mkOrder 320 ''
        -- Shifted workspaces, "+n" variant, id+1 (ALT + 1-0 -> 11,21..101)
        ${gridBinds "ALT + " 1 focusBind}

        -- Move to shifted workspaces (ALT + CTRL + 1-0 -> 11,21..101)
        ${gridBinds "ALT + CTRL + " 1 moveBind}
      ''))
      (lib.mkIf settings.features.workspaceGrid.enable (lib.mkOrder 321 ''
        -- Workspaces (1-0 -> 10,20..100)
        ${gridBinds "" 0 focusBind}

        -- Move to workspaces (CTRL + 1-0 -> 10,20..100)
        ${gridBinds "CTRL + " 0 moveBind}
      ''))
    ];
  };
}
