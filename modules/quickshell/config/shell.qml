//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Networking

ShellRoot {
  id: root

  readonly property color islandBg: "#141313"
  readonly property color chipBg: "#49454F"
  readonly property color chipHoverBg: Qt.lighter(chipBg, 1.25)
  readonly property color textColor: "#DEE2E6"
  readonly property color mutedTextColor: "#CAC4D0"
  readonly property color accentColor: "#D0BCFF"
  readonly property color accentTextColor: "#381E72"
  readonly property int islandHeight: 40
  readonly property int islandPadding: 16

  component Chip: Text {
    id: chipRoot
    property alias label: chipRoot.text
    color: root.textColor
    font.pixelSize: 14
  }

  component IconButton: Rectangle {
    id: btnRoot
    property string glyph: ""
    property int glyphSize: 16
    property alias hovered: mouseArea.containsMouse
    signal primaryClicked()
    signal secondaryClicked()
    signal wheelMoved(real delta)

    width: 34
    height: 34
    radius: 10
    color: mouseArea.containsMouse ? root.chipHoverBg : root.chipBg
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
      anchors.centerIn: parent
      text: btnRoot.glyph
      color: root.textColor
      font.pixelSize: btnRoot.glyphSize
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) btnRoot.secondaryClicked();
        else btnRoot.primaryClicked();
      }
      onWheel: (wheel) => btnRoot.wheelMoved(wheel.angleDelta.y)
    }
  }

  FileView {
    id: workspaceFile
    path: Qt.resolvedUrl("./workspaces.json")
    watchChanges: true
    onFileChanged: reload()

    JsonAdapter {
      id: workspaceData
      property var entries: []
    }
  }

  FileView {
    id: scriptsFile
    path: Qt.resolvedUrl("./scripts.json")
    watchChanges: true
    onFileChanged: reload()

    JsonAdapter {
      id: scriptsData
      property string taskStatus: ""
      property string taskPicker: ""
    }
  }

  function focusedWorkspaceId() {
    return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
  }

  function mergedWorkspaceIds() {
    const ids = workspaceData.entries.map(e => e.id);
    const seen = new Set(ids);
    for (const w of Hyprland.workspaces.values) {
      if (w.id < 200 && !seen.has(w.id)) {
        seen.add(w.id);
        ids.push(w.id);
      }
    }
    ids.sort((a, b) => a - b);
    return ids;
  }

  function workspaceIcon(id) {
    for (const e of workspaceData.entries) {
      if (e.id === id) return e.icon;
      if (e.id + 1 === id) return e.shiftedIcon;
    }
    return "";
  }

  function activeTaskCount() {
    const trimmed = taskStatusText.trim();
    return trimmed.length === 0 ? 0 : trimmed.split(/\s+/).length;
  }

  function focusWorkspace(id) {
    focusProc.command = [
      "hyprctl", "dispatch",
      `hl.dsp.focus({workspace = ${id}, on_current_monitor = true})`
    ];
    focusProc.running = true;
  }

  Process { id: focusProc }

  SessionScreen { id: sessionScreen }

  ControlCenter {
    id: controlCenter
    onRequestSessionScreen: sessionScreen.toggle()
  }

  property string taskStatusText: ""
  property string taskStatusTooltip: ""

  Process {
    id: taskStatusProc
    command: scriptsData.taskStatus ? [scriptsData.taskStatus] : []
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(this.text);
          taskStatusText = data.text ?? "";
          taskStatusTooltip = data.tooltip ?? "";
        } catch (e) {}
      }
    }
  }
  Timer {
    interval: 3000
    running: scriptsData.taskStatus !== ""
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!taskStatusProc.running) taskStatusProc.running = true
  }
  Process { id: taskPickerProc; command: scriptsData.taskPicker ? [scriptsData.taskPicker] : [] }

  property real cpuPrevIdle: -1
  property real cpuPrevTotal: -1
  property int cpuUsage: 0
  property var cpuPerCoreUsage: []

  FileView {
    id: cpuFile
    path: "/proc/stat"
    blockLoading: true
    onLoaded: {
      const cpuPrevPerCore = cpuFile.prevPerCore;
      const lines = text().split("\n");

      const parseLine = (line) => {
        const parts = line.trim().split(/\s+/).slice(1).map(Number);
        const idle = parts[3] + (parts[4] || 0);
        const total = parts.reduce((a, b) => a + b, 0);
        return { idle, total };
      };

      const agg = parseLine(lines[0]);
      if (cpuPrevTotal >= 0) {
        const totalDelta = agg.total - cpuPrevTotal;
        const idleDelta = agg.idle - cpuPrevIdle;
        cpuUsage = totalDelta > 0 ? Math.round(100 * (1 - idleDelta / totalDelta)) : 0;
      }
      cpuPrevTotal = agg.total;
      cpuPrevIdle = agg.idle;

      const coreLines = lines.filter(l => /^cpu\d/.test(l));
      const newPerCore = [];
      const newPrevPerCore = [];
      for (let i = 0; i < coreLines.length; i++) {
        const c = parseLine(coreLines[i]);
        const prev = cpuPrevPerCore[i];
        let pct = 0;
        if (prev) {
          const totalDelta = c.total - prev.total;
          const idleDelta = c.idle - prev.idle;
          pct = totalDelta > 0 ? Math.round(100 * (1 - idleDelta / totalDelta)) : 0;
        }
        newPerCore.push(pct);
        newPrevPerCore.push(c);
      }
      cpuPerCoreUsage = newPerCore;
      cpuFile.prevPerCore = newPrevPerCore;
    }

    property var prevPerCore: []
  }
  Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: cpuFile.reload() }

  property real memUsedGb: 0

  FileView {
    id: memFile
    path: "/proc/meminfo"
    blockLoading: true
    onLoaded: {
      const lines = text().split("\n");
      let totalKb = 0, availKb = 0;
      for (const l of lines) {
        if (l.startsWith("MemTotal:")) totalKb = parseInt(l.split(/\s+/)[1]);
        else if (l.startsWith("MemAvailable:")) availKb = parseInt(l.split(/\s+/)[1]);
      }
      memUsedGb = (totalKb - availKb) / 1024 / 1024;
    }
  }
  Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: memFile.reload() }

  property real diskUsedGb: 0
  property real diskTotalGb: 0
  property int diskPercent: 0

  Process {
    id: diskProc
    command: ["df", "-k", "--output=used,size", "/"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = this.text.trim().split("\n");
        if (lines.length < 2) return;
        const parts = lines[1].trim().split(/\s+/).map(Number);
        const usedKb = parts[0], totalKb = parts[1];
        diskUsedGb = usedKb / 1024 / 1024;
        diskTotalGb = totalKb / 1024 / 1024;
        diskPercent = totalKb > 0 ? Math.round(100 * usedKb / totalKb) : 0;
      }
    }
  }
  Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!diskProc.running) diskProc.running = true }

  PwObjectTracker {
    objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
  }

  function connectedNetworkDevice() {
    const devices = Networking.devices.values;
    for (let i = 0; i < devices.length; i++) if (devices[i].connected) return devices[i];
    return null;
  }
  function connectedNetwork(device) {
    if (!device) return null;
    const nets = device.networks.values;
    for (let i = 0; i < nets.length; i++) if (nets[i].connected) return nets[i];
    return null;
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: bar
      property var modelData
      screen: modelData
      anchors { left: true; right: true; top: true }
      implicitHeight: 50
      color: "transparent"

      // Responsive breakpoints: on narrow screens the absolutely-anchored
      // islands (left tray, centered workspaces, right metrics) overlap.
      // Hide low-priority chips so the clusters shrink and stop colliding.
      // Row/Repeater drop !visible items from layout automatically.
      readonly property bool showMetrics: width >= 1500
      readonly property bool showNetwork: width >= 1200

      Rectangle {
        id: clockIsland
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: root.islandHeight
        width: clockChip.implicitWidth + root.islandPadding * 2
        radius: 16
        color: root.islandBg

        Chip {
          id: clockChip
          anchors.centerIn: parent
          label: Qt.formatDateTime(new Date(), "ddd dd MMM  HH:mm")

          Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: parent.label = Qt.formatDateTime(new Date(), "ddd dd MMM  HH:mm")
          }
        }
      }

      Rectangle {
        id: trayIsland
        anchors.left: clockIsland.right
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: root.islandHeight
        width: trayRow.implicitWidth + root.islandPadding * 2
        radius: 16
        color: root.islandBg

        Row {
          id: trayRow
          anchors.centerIn: parent
          spacing: 14

          Repeater {
            model: SystemTray.items
            delegate: Rectangle {
              id: trayDelegate
              width: 30
              height: 30
              radius: 15
              color: trayMouse.containsMouse ? root.chipHoverBg : root.chipBg
              Behavior on color { ColorAnimation { duration: 100 } }

              Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: modelData.icon
              }

              QsMenuAnchor {
                id: trayMenuAnchor
                anchor {
                  item: trayDelegate
                  gravity: Edges.Bottom | Edges.Right
                  edges: Edges.Bottom | Edges.Right
                }
              }

              MouseArea {
                id: trayMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                  if (mouse.button === Qt.RightButton) {
                    if (modelData.menu) {
                      trayMenuAnchor.menu = modelData.menu;
                      trayMenuAnchor.open();
                    } else {
                      modelData.secondaryActivate();
                    }
                  } else {
                    modelData.activate();
                  }
                }
              }
            }
          }
        }
      }

      Rectangle {
        id: workspacesIsland
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        height: root.islandHeight
        width: workspacesRow.implicitWidth + root.islandPadding * 2
        radius: 16
        color: root.islandBg

        Row {
          id: workspacesRow
          anchors.centerIn: parent
          spacing: 10

          Repeater {
            model: mergedWorkspaceIds()
            delegate: Rectangle {
              readonly property int wsId: modelData
              readonly property bool focused: wsId === focusedWorkspaceId()
              width: 32
              height: 32
              radius: 16
              color: focused ? root.accentColor : (wsMouse.containsMouse ? root.chipHoverBg : root.chipBg)
              Behavior on color { ColorAnimation { duration: 100 } }

              Text {
                anchors.centerIn: parent
                text: workspaceIcon(wsId)
                font.pixelSize: 16
                color: focused ? root.accentTextColor : root.mutedTextColor
              }

              MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                  const targetId = (mouse.button === Qt.RightButton) ? wsId + 1 : wsId;
                  focusWorkspace(targetId);
                }
              }
            }
          }
        }
      }

      Rectangle {
        visible: bar.showMetrics
        anchors.left: workspacesIsland.right
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: root.islandHeight
        width: tasksLabel.implicitWidth + root.islandPadding * 2
        radius: 16
        color: tasksMouse.containsMouse ? root.chipHoverBg : root.islandBg
        Behavior on color { ColorAnimation { duration: 100 } }

        Chip {
          id: tasksLabel
          anchors.centerIn: parent
          label: "Tasks: " + activeTaskCount()
        }

        MouseArea {
          id: tasksMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: taskPickerProc.running = true
        }
      }

      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: root.islandHeight
        width: rightRow.implicitWidth + root.islandPadding * 2
        radius: 16
        color: root.islandBg

        Row {
          id: rightRow
          anchors.centerIn: parent
          spacing: 20

          Chip {
            visible: bar.showNetwork
            anchors.verticalCenter: parent.verticalCenter
            readonly property var device: connectedNetworkDevice()
            readonly property var net: connectedNetwork(device)
            label: {
              if (!device) return "  Disconnected";
              if (device.type === DeviceType.Wifi) return "󰤨  " + (net ? net.name : device.name);
              return "󰅢  " + device.name;
            }
          }

          Chip {
            id: audioChip
            anchors.verticalCenter: parent.verticalCenter
            readonly property var sink: Pipewire.defaultAudioSink
            label: {
              if (!sink || !sink.audio) return "  --";
              const pct = Math.round(sink.audio.volume * 100);
              return (sink.audio.muted ? "󰖁 " : " ") + " " + pct + "%";
            }

            MouseArea {
              anchors.fill: parent
              onClicked: {
                const sink = Pipewire.defaultAudioSink;
                if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
              }
              onWheel: (wheel) => {
                const sink = Pipewire.defaultAudioSink;
                if (!sink || !sink.audio) return;
                const step = 0.05;
                const delta = wheel.angleDelta.y > 0 ? step : -step;
                sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta));
              }
            }
          }

          Chip {
            id: cpuChip
            visible: bar.showMetrics
            anchors.verticalCenter: parent.verticalCenter
            label: "  " + cpuUsage + "%"

            MouseArea {
              id: cpuHoverArea
              anchors.fill: parent
              hoverEnabled: true
            }
          }

          Chip {
            visible: bar.showMetrics
            anchors.verticalCenter: parent.verticalCenter
            label: "  " + memUsedGb.toFixed(1) + "G"
          }

          Chip {
            id: diskChip
            visible: bar.showMetrics
            anchors.verticalCenter: parent.verticalCenter
            label: "\u{F02CA}  " + diskPercent + "%"

            MouseArea {
              id: diskHoverArea
              anchors.fill: parent
              hoverEnabled: true
            }
          }

          Chip {
            anchors.verticalCenter: parent.verticalCenter
            readonly property var battery: UPower.displayDevice
            visible: battery && battery.isPresent
            label: {
              if (!battery || !battery.isPresent) return "";
              const icons = ["󰂎", "󰁼", "󰁿", "󰂁", "󰁹"];
              const pct = Math.round(battery.percentage * 100);
              const tier = Math.max(0, Math.min(icons.length - 1, Math.floor(pct / 25)));
              const charging = battery.state === UPowerDeviceState.Charging;
              return icons[tier] + "  " + (charging ? "󱐋 " : "") + pct + "%";
            }
          }

          Item {
            width: 22
            height: 22
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              anchors.fill: parent
              radius: 11
              color: bellMouse.containsMouse ? root.chipHoverBg : "transparent"
              Behavior on color { ColorAnimation { duration: 100 } }
            }

            Text {
              anchors.centerIn: parent
              text: ""
              font.pixelSize: 15
              color: root.textColor
            }

            Rectangle {
              visible: controlCenter.count > 0
              width: 14
              height: 14
              radius: 7
              color: root.accentColor
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.topMargin: -4
              anchors.rightMargin: -4

              Text {
                anchors.centerIn: parent
                text: controlCenter.count > 9 ? "9+" : controlCenter.count
                color: root.accentTextColor
                font.pixelSize: 8
                font.bold: true
              }
            }

            MouseArea {
              id: bellMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                controlCenter.targetScreen = modelData;
                controlCenter.toggle();
              }
            }
          }

        }
      }

      property real cpuChipCenterX: 0
      property real diskChipCenterX: 0

      Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
          bar.cpuChipCenterX = cpuChip.mapToItem(bar.contentItem, cpuChip.width / 2, 0).x;
          bar.diskChipCenterX = diskChip.mapToItem(bar.contentItem, diskChip.width / 2, 0).x;
        }
      }

      PanelWindow {
        id: cpuPopup
        screen: modelData
        visible: cpuHoverArea.containsMouse && cpuPerCoreUsage.length > 0
        color: "transparent"
        WlrLayershell.namespace: "quickshell:cpu-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true }
        margins.top: bar.implicitHeight + 6
        margins.left: Math.min(Math.max(8, bar.cpuChipCenterX - implicitWidth / 2), screen.width - implicitWidth - 8)
        implicitWidth: cpuPopupContent.implicitWidth + 24
        implicitHeight: cpuPopupContent.implicitHeight + 20

        Rectangle {
          anchors.fill: parent
          radius: 14
          color: root.islandBg

          Column {
            id: cpuPopupContent
            anchors.centerIn: parent
            spacing: 4

            Text {
              text: "CPU cores"
              color: root.textColor
              font.bold: true
              font.pixelSize: 13
            }

            Repeater {
              model: cpuPerCoreUsage
              delegate: Text {
                text: "Core " + index + ": " + modelData + "%"
                color: root.mutedTextColor
                font.pixelSize: 12
              }
            }
          }
        }
      }

      PanelWindow {
        id: diskPopup
        screen: modelData
        visible: diskHoverArea.containsMouse
        color: "transparent"
        WlrLayershell.namespace: "quickshell:disk-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true }
        margins.top: bar.implicitHeight + 6
        margins.left: Math.min(Math.max(8, bar.diskChipCenterX - implicitWidth / 2), screen.width - implicitWidth - 8)
        implicitWidth: diskPopupContent.implicitWidth + 24
        implicitHeight: diskPopupContent.implicitHeight + 20

        Rectangle {
          anchors.fill: parent
          radius: 14
          color: root.islandBg

          Column {
            id: diskPopupContent
            anchors.centerIn: parent
            spacing: 4

            Text {
              text: "Disk (/)"
              color: root.textColor
              font.bold: true
              font.pixelSize: 13
            }

            Text {
              text: diskUsedGb.toFixed(1) + " GB used of " + diskTotalGb.toFixed(1) + " GB"
              color: root.mutedTextColor
              font.pixelSize: 12
            }
          }
        }
      }
    }
  }
}
