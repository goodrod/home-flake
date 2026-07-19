{ config, lib, ... }:
let
  option = config.module.hyprland;
in
{
  config = lib.mkIf option.enable {
    module.hyprland.luaConfig = lib.mkOrder 250 ''
      -- ══════════════════════════════════════
      -- Pending window-workspace redirect
      -- ══════════════════════════════════════
      -- Hyprland's exec-time "[workspace N]" prefix only affects the window
      -- opened by the freshly spawned process. Singleton apps (Firefox,
      -- Chrome, etc) that are already running open a "new window" via IPC in
      -- their EXISTING process, so that prefix never applies to it (verified
      -- live: launching Firefox with an instance already running never
      -- landed the new window where the prefix asked). Instead: a script
      -- sets hl_pending_move_ws (via `hyprctl eval`, see
      -- task-workspace-scripts.nix / scripts.nix's execCurrentWs) right
      -- before firing the exec, and this hook redirects whatever window(s)
      -- open next, within a short grace period - handles multiple windows
      -- fired in quick succession (e.g. a task workspace launching several
      -- apps in one go), each renewing the grace period as it launches.
      hl_pending_move_ws = nil
      hl_pending_move_until = 0

      hl.on("window.open", function(win)
        if hl_pending_move_ws ~= nil and os.time() <= hl_pending_move_until then
          hl.dispatch(hl.dsp.window.move({ window = win, workspace = hl_pending_move_ws }))
          hl.dispatch(hl.dsp.focus({ window = win }))
        end
      end)
    '';
  };
}
