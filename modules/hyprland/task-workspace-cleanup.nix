{ config, pkgs, lib, ... }:
let
  option = config.module.hyprland;
  taskScripts = import ./task-workspace-scripts.nix { inherit pkgs lib config; };
in
{
  config = lib.mkIf option.enable {
    module.hyprland.luaConfig = lib.mkOrder 260 ''
      -- ══════════════════════════════════════
      -- Task workspace auto-forget
      -- ══════════════════════════════════════
      -- Ad-hoc task workspaces (see task-workspace-scripts.nix) are otherwise
      -- never garbage collected. Once you empty one out and leave it, forget
      -- it automatically instead of requiring a manual SUPER+SHIFT+T.
      -- hl.get_last_workspace() (called from inside this hook) reliably
      -- returns the workspace being switched away from - the history tracker
      -- backing it updates before user Lua hooks run.
      hl.on("workspace.active", function(ws)
        local prev = hl.get_last_workspace()
        if prev ~= nil and prev.id ~= ws.id then
          hl.dispatch(hl.dsp.exec_cmd("${taskScripts.taskForgetIfEmpty} " .. prev.id))
        end
      end)
    '';
  };
}
