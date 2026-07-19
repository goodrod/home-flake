{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOption mkEnableOption types mkIf;
  inherit (types) path str;
  quickshellConfig = config.module.quickshell;

  # Single source of truth for workspaces lives in module.workspaces (same
  # data waybar's workspaceFormatIcons/persistentWorkspaceIds derive from).
  workspaces = config.module.workspaces.entries;
  sortedWs = lib.sort (a: b: a.id < b.id) (lib.attrValues workspaces);

  workspaceEntries = map (ws: {
    inherit (ws) id icon persistent;
    shiftedIcon =
      if ws.shiftedIcon != null
      then ws.shiftedIcon
      else ws.icon + " +";
  }) sortedWs;

  workspacesJson = pkgs.writeText "quickshell-bar-workspaces.json" (builtins.toJSON {
    entries = workspaceEntries;
  });

  # Reuse the exact scripts modules/waybar's custom/task-workspaces module
  # runs, rather than re-deriving the active/idle-task logic in QML. The
  # quickshell bar only needs a count of active tasks (see shell.qml's
  # "Tasks: N" island), not per-task icons, so only the script paths
  # (status poller + fuzzel picker) get passed through.
  taskScripts = import ../hyprland/task-workspace-scripts.nix {
    inherit pkgs lib config;
  };

  scriptsJson = pkgs.writeText "quickshell-bar-scripts.json" (builtins.toJSON {
    taskStatus = "${taskScripts.taskWaybarStatus}";
    taskPicker = "${taskScripts.taskPicker}";
  });

  # Merge the static QML config with the Nix-generated data so the whole
  # thing can be copied out via a single home.file entry.
  mergedConfigDir = pkgs.runCommand "quickshell-bar-config" {} ''
    mkdir -p "$out"
    cp -r "${quickshellConfig.config-source-directory}/." "$out/"
    cp "${workspacesJson}" "$out/workspaces.json"
    cp "${scriptsJson}" "$out/scripts.json"
  '';
in {
  options.module.quickshell = {
    enable = mkEnableOption "quickshell";

    config-source-directory = mkOption {
      default = ./config;
      type = path;
      description = "Path to the directory containing the static QML config files (workspaces.json is generated and merged in on top).";
    };

    config-output-directory = mkOption {
      default = ".config/quickshell/bar";
      type = str;
      description = "Path to the output directory the config files are copied to. Output is relative to your home directory. Must match the `-c` name passed to `qs` (the systemd service uses `qs -c bar`).";
    };
  };

  config = mkIf quickshellConfig.enable {
    home.packages = [pkgs.quickshell pkgs.qt6Packages.qt6ct];

    home.file."${quickshellConfig.config-output-directory}" = {
      source = mergedConfigDir;
      executable = false;
      recursive = true;
    };

    # Tray context menus (QsMenuAnchor/SystemTrayItem.display) are native Qt
    # platform popups, so they ignore the QML bar's colors entirely - they
    # follow whatever Qt platform theme is configured. qt6ct + one of its
    # bundled dark color schemes gets them out of the default light style.
    home.file.".config/qt6ct/qt6ct.conf".text = ''
      [Appearance]
      custom_palette=true
      color_scheme_path=${pkgs.qt6Packages.qt6ct}/share/qt6ct/colors/darker.conf
      style=Fusion
    '';

    systemd.user.services.quickshell = {
      Unit = {
        Description = "Quickshell bar";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.quickshell}/bin/qs -c bar";
        Restart = "on-failure";
        Environment = ["QT_QPA_PLATFORMTHEME=qt6ct"];
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
