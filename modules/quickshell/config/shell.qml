import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

// First-slice quickshell bar: clock, tray, hyprland workspaces, power button.
// Deliberately does not yet cover notification/network/cpu/memory/pulseaudio -
// those stay on waybar until ported (see the quickshell module's plan notes).

ShellRoot {
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

  function workspaceIcon(id) {
    const entries = workspaceData.entries;
    for (let i = 0; i < entries.length; i++) {
      if (entries[i].id === id) return entries[i].icon;
      if (entries[i].id + 1 === id) return entries[i].shiftedIcon;
    }
    return "";
  }

  function focusWorkspace(id) {
    focusProc.command = [
      "hyprctl", "dispatch",
      `hl.dsp.focus({workspace = {id = ${id}}, on_current_monitor = true})`
    ];
    focusProc.running = true;
  }

  Process { id: focusProc }
  Process { id: powerProc; command: ["wlogout", "-b", "4"] }

  PanelWindow {
    anchors {
      left: true
      right: true
      top: true
    }
    implicitHeight: 32
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      color: "#181825"

      Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Text {
          id: clock
          color: "#cdd6f4"
          font.bold: true
          font.pixelSize: 14
          text: Qt.formatDateTime(new Date(), "ddd dd MMM  HH:mm")

          Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd dd MMM  HH:mm")
          }
        }

        Row {
          spacing: 6
          Repeater {
            model: SystemTray.items
            delegate: Image {
              width: 18
              height: 18
              source: modelData.icon
              MouseArea {
                anchors.fill: parent
                onClicked: modelData.activate()
              }
            }
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
          model: Hyprland.workspaces
          delegate: Rectangle {
            width: 26
            height: 22
            radius: 6
            color: modelData.id === (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1)
              ? "#cdd6f4" : "#404A60"

            Text {
              anchors.centerIn: parent
              text: workspaceIcon(modelData.id)
              color: modelData.id === (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1)
                ? "#181825" : "#D8DEE9"
            }

            MouseArea {
              anchors.fill: parent
              onClicked: focusWorkspace(modelData.id)
            }
          }
        }
      }

      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 22
        radius: 6
        color: "#f38ba8"

        Text {
          anchors.centerIn: parent
          text: "⏻"
          color: "#181825"
        }

        MouseArea {
          anchors.fill: parent
          onClicked: powerProc.running = true
        }
      }
    }
  }
}
