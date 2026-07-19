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

  # Merge the static QML config with the Nix-generated workspace data so the
  # whole thing can be copied out via a single home.file entry.
  mergedConfigDir = pkgs.runCommand "quickshell-bar-config" {} ''
    mkdir -p "$out"
    cp -r "${quickshellConfig.config-source-directory}/." "$out/"
    cp "${workspacesJson}" "$out/workspaces.json"
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
    home.packages = [pkgs.quickshell];

    home.file."${quickshellConfig.config-output-directory}" = {
      source = mergedConfigDir;
      executable = false;
      recursive = true;
    };

    systemd.user.services.quickshell = {
      Unit = {
        Description = "Quickshell bar";
        After = ["graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.quickshell}/bin/qs -c bar";
        Restart = "on-failure";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
