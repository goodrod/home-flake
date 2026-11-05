{ config, pkgs, lib, ... }:
let
  settings = config.module.hyprland;
  scripts = import ../scripts.nix { inherit pkgs; };
in
{
  config = lib.mkIf (settings.enable && settings.features.columnTools.enable) {
    module.hyprland.luaConfig = lib.mkOrder 290 ''
      -- Scrolling layout column tools
      local colWidths = { 0.25, 0.333, 0.5, 1.0 }
      local colWidthIdx = 1
      hl.bind(mainMod .. " + I", hl.dsp.layout("colresize +conf"), { description = "Cycle column width" })
      hl.bind(mainMod .. " + SHIFT + I", hl.dsp.layout("colresize -conf"), { description = "Cycle column width back" })
      hl.bind(mainMod .. " + plus", hl.dsp.layout("fit visible"), { description = "Fit all visible columns" })
      hl.bind(mainMod .. " + SHIFT + CTRL + left", hl.dsp.layout("swapcol l"), { description = "Swap column left" })
      hl.bind(mainMod .. " + SHIFT + CTRL + right", hl.dsp.layout("swapcol r"), { description = "Swap column right" })
      ${lib.optionalString (settings.keys.promote != null) ''hl.bind(mainMod .. " + ${settings.keys.promote}", hl.dsp.layout("promote"), { description = "Promote to own column" })''}

      -- mon.width/height are the panel-native (untransformed) pixel size, so
      -- swap them for 90/270 transforms to get the actual on-screen size.
      -- Needed to detect an ultrawide rotated to portrait ("standing up"),
      -- where no column width should end up narrower than the screen.
      local function effectiveMonitorSize(mon)
        local w, h = mon.width, mon.height
        if mon.transform % 2 == 1 then w, h = h, w end
        return w, h
      end

      local function colWidthsFor(activeWindow)
        local mon = activeWindow and activeWindow.monitor
        if mon then
          local w, h = effectiveMonitorSize(mon)
          if h > w then return { 1.0 } end
        end
        return colWidths
      end

      -- The resize itself, plus keeping the grid flush with the screen edge,
      -- lives in snap-columns.sh - it needs window geometry, and reading that
      -- from inside a keybind callback deadlocks Hyprland (see scripts.nix).
      -- The script restores focus itself.
      local function cycleColWidth(dir)
        local w = hl.get_active_window()
        local widths = colWidthsFor(w)
        colWidthIdx = ((colWidthIdx - 1 + dir + #widths) % #widths) + 1
        hl.dispatch(hl.dsp.exec_cmd("${scripts.snapColumns} " .. widths[colWidthIdx]))
      end
      -- Landing on a portrait monitor should snap any columns it already had
      -- (e.g. carried over from a landscape monitor) to full width, not just
      -- block the cycle going forward from here.
      local function clampToFullWidthIfPortrait(mon)
        if not mon then return end
        local w, h = effectiveMonitorSize(mon)
        if h > w then
          -- colresize has no monitor/workspace target of its own - it always
          -- acts on whatever window currently holds dispatch focus, and
          -- workspace.active fires for monitors that are not the focused one
          -- (moving a workspace onto this one from elsewhere). Name the
          -- workspace explicitly and let snap-columns.sh borrow focus and hand
          -- it straight back, rather than moving focus here and leaving it.
          local ws = mon.active_workspace
          if not ws then return end
          colWidthIdx = #colWidths
          -- Same script as the width cycle: a plain "colresize all 1.0" would
          -- leave the full-width column half off-screen with a slice of its
          -- neighbour showing.
          hl.dispatch(hl.dsp.exec_cmd("${scripts.snapColumns} 1.0 " .. ws.id))
        end
      end
      -- workspace.active: fires on an actual workspace switch (e.g. moving a
      -- workspace to this monitor, or switching workspaces on it).
      hl.on("workspace.active", function(ws) clampToFullWidthIfPortrait(ws and ws.monitor) end)
      -- The other case is moving input focus onto a monitor whose workspace was
      -- already active, which raises no workspace.active. Do NOT hook
      -- monitor.focused for it: that fires on a plain mouse hover as well
      -- (misc:mouse_move_focuses_monitor defaults to true), so the clamp ran on
      -- hover, and the focus snap-columns.sh borrows raised the event again and
      -- re-entered the hook - focus ping-ponged between the monitors until the
      -- pointer left. focusMonitor in core.nix calls the clamp instead, so only
      -- a deliberate focus change clamps.

      hl.bind(mainMod .. " + O", function() cycleColWidth(1) end, { description = "Cycle all column widths forward" })
      hl.bind(mainMod .. " + SHIFT + O", function() cycleColWidth(-1) end, { description = "Cycle all column widths back" })

      -- Jump to the first/last column of the workspace. The scrolling layout's
      -- own "focus leftmost"/"focus rightmost" messages mean leftmost/rightmost
      -- *currently on screen*, not first/last in the workspace (verified live),
      -- so pick the extreme by x ourselves. Floating windows are skipped: the
      -- pinned toggle-window popups (scripts.nix) sit outside the column strip
      -- and would otherwise win the comparison.
      local function focusEdgeColumn(edge)
        local ws = hl.get_active_workspace()
        if ws == nil then return end
        local best
        for _, w in ipairs(hl.get_workspace_windows(ws)) do
          if not w.floating and w.mapped then
            if best == nil
              or (edge == "first" and w.at.x < best.at.x)
              or (edge == "last" and w.at.x > best.at.x) then
              best = w
            end
          end
        end
        if best then hl.dispatch(hl.dsp.focus({ window = "address:" .. best.address })) end
      end
      hl.bind(mainMod .. " + home", function() focusEdgeColumn("first") end, { description = "Focus first window in workspace" })
      hl.bind(mainMod .. " + end", function() focusEdgeColumn("last") end, { description = "Focus last window in workspace" })
    '';
  };
}
