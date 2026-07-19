{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (types) attrsOf submodule int str listOf;

  tasks = config.module.taskWorkspaces.tasks;
  ids = map (t: t.id) (lib.attrValues tasks);
  workspaceIds = map (ws: ws.id) (lib.attrValues config.module.workspaces.entries);
  reservedGridIds = lib.concatMap (n: [ (n * 10) (n * 10 + 1) ]) (lib.range 1 10); # 10,11,20,21,...,100,101
in
{
  options.module.taskWorkspaces = {
    tasks = mkOption {
      description = ''
        Task workspace definitions keyed by task name. Each gets a dedicated
        Hyprland workspace id (>= 200, own id space - see assertions) and an
        ordered list of raw exec command strings. Commands are NOT
        auto-launched at startup; they run only when the launch/jump script
        (bound to SUPER+T via the picker) determines the workspace is empty.
        Each command is wrapped with the "[workspace <id>]" exec-dispatcher
        prefix at script-generation time (Nix), not authored by the user.
      '';
      default = { };
      type = attrsOf (submodule {
        options = {
          id = mkOption {
            type = int;
            description = "Numeric workspace id. Must be >= 200 and unique (own space, distinct from module.workspaces.entries' 10-90 and the generic 1-10 keybind grid's 10-101).";
          };
          icon = mkOption {
            type = str;
            description = "Glyph shown in the waybar task-workspaces widget and the picker.";
          };
          apps = mkOption {
            type = listOf str;
            description = "Ordered list of raw exec command strings launched (in order) when the task isn't already running.";
          };
        };
      });
    };
  };

  config.assertions = [
    {
      assertion = lib.length (lib.unique ids) == lib.length ids;
      message = "module.taskWorkspaces.tasks: ids must be unique (got ${toString ids}).";
    }
    {
      assertion = lib.all (id: id >= 200) ids;
      message = "module.taskWorkspaces.tasks: ids must be >= 200 (10-101 is claimed by module.workspaces + the generic SUPER+0..9/SHIFT+0..9 keybind grid).";
    }
    {
      assertion = lib.all (id: !(lib.elem id workspaceIds) && !(lib.elem id reservedGridIds)) ids;
      message = "module.taskWorkspaces.tasks: id collides with module.workspaces.entries or the generic keybind grid.";
    }
  ];
}
