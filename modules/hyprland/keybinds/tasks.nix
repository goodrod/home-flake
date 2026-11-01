{ config, pkgs, lib, ... }:
let
  settings = config.module.hyprland;
  taskScripts = import ../task-workspace-scripts.nix { inherit pkgs lib config; };
in
{
  config = lib.mkIf (settings.enable && settings.features.taskWorkspaces.enable) {
    module.hyprland.luaConfig = lib.mkOrder 310 ''
      -- Task workspaces
      hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("${taskScripts.taskPicker}"), { description = "Task workspace picker" })
      hl.bind(mainMod .. " + CTRL + T", hl.dsp.exec_cmd("${taskScripts.taskMoveWindowPicker}"), { description = "Send focused window to a task workspace" })
      hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("${taskScripts.taskRemovePicker}"), { description = "Remove an ad-hoc task workspace" })
    '';
  };
}
