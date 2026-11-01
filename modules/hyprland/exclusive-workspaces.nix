{ config, lib, ... }:
let
  settings = config.module.hyprland;

  exclusive = lib.filter (m: m.enable && m.exclusiveWorkspace != null) (lib.attrValues settings.monitors);

  entries = lib.concatMapStringsSep ", " (m: ''["${m.name}"] = ${toString m.exclusiveWorkspace}'') exclusive;
in
{
  config = lib.mkIf (settings.enable && exclusive != [ ]) {
    module.hyprland.luaConfig = lib.mkOrder 270 ''
      -- ══════════════════════════════════════
      -- Exclusive workspaces
      -- ══════════════════════════════════════
      -- Bouncing back re-raises workspace.active for the exclusive workspace
      -- itself, which returns early, so this cannot loop.
      local exclusiveWorkspaces = { ${entries} }

      hl.on("workspace.active", function(ws)
        if ws == nil or ws.monitor == nil then return end
        local exclusiveId = exclusiveWorkspaces[ws.monitor.name]
        if exclusiveId == nil or ws.id == exclusiveId then return end
        local exclusiveWs = hl.get_workspace(exclusiveId)
        if exclusiveWs == nil or exclusiveWs.windows == 0 then return end
        hl.dispatch(hl.dsp.focus({ workspace = exclusiveId }))
      end)
    '';
  };
}
