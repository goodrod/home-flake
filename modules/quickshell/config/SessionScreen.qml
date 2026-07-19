import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Session/logout screen, replacing wlogout for the bar's power button.
// Same four actions modules/wlogout's layout has (lock/shutdown/suspend/
// reboot), sshell-style presentation: full-screen dim, big keyboard-
// navigable buttons, focused one grows a rounder corner + bigger glyph.
PanelWindow {
  id: sessionScreen

  readonly property color chipBg: "#22222c"
  readonly property color textColor: "#d8d8e2"
  readonly property color mutedTextColor: "#9a9aab"
  readonly property color accentColor: "#6c7ce0"

  property bool shown: false
  visible: shown

  function toggle() {
    shown = !shown;
    if (shown) lockBtn.forceActiveFocus();
  }
  function close() {
    shown = false;
  }

  WlrLayershell.namespace: "quickshell:session"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  FileView {
    id: scriptsFile
    path: Qt.resolvedUrl("./scripts.json")
    watchChanges: true
    onFileChanged: reload()

    JsonAdapter {
      id: scriptsData
      property string lockCmd: ""
    }
  }

  Process { id: lockProc }
  Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
  Process { id: suspendProc; command: ["systemctl", "suspend"] }
  Process { id: rebootProc; command: ["systemctl", "reboot"] }

  component SessionButton: Rectangle {
    id: btnRoot
    property string glyph: ""
    property string label: ""
    signal activated()

    width: 140
    height: 140
    radius: activeFocus ? width / 3 : 20
    color: activeFocus ? "#6c7ce0" : "#22222c"

    Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

    Keys.onPressed: (event) => {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        btnRoot.activated();
        event.accepted = true;
      }
    }

    Column {
      anchors.centerIn: parent
      spacing: 12

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: btnRoot.glyph
        font.pixelSize: 40
        color: btnRoot.activeFocus ? "#ffffff" : "#d8d8e2"
        scale: btnRoot.activeFocus ? 1.15 : 1.0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: btnRoot.label
        font.pixelSize: 15
        font.bold: true
        color: btnRoot.activeFocus ? "#ffffff" : "#d8d8e2"
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: btnRoot.activated()
    }
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: sessionScreen.shown ? 0.6 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    MouseArea {
      anchors.fill: parent
      onClicked: sessionScreen.close()
    }
  }

  FocusScope {
    anchors.centerIn: parent
    width: content.width
    height: content.height
    focus: true

    Keys.onEscapePressed: sessionScreen.close()

    Column {
      id: content
      spacing: 30

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Session"
        font.pixelSize: 32
        font.bold: true
        color: "#d8d8e2"
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 20

        SessionButton {
          id: lockBtn
          glyph: "🔒"
          label: "Lock"
          KeyNavigation.right: shutdownBtn
          KeyNavigation.left: rebootBtn
          onActivated: {
            lockProc.command = ["sh", "-c", scriptsData.lockCmd];
            lockProc.running = true;
            sessionScreen.close();
          }
        }

        SessionButton {
          id: shutdownBtn
          glyph: "⏻"
          label: "Shutdown"
          KeyNavigation.left: lockBtn
          KeyNavigation.right: suspendBtn
          onActivated: {
            shutdownProc.running = true;
            sessionScreen.close();
          }
        }

        SessionButton {
          id: suspendBtn
          glyph: "🌙"
          label: "Suspend"
          KeyNavigation.left: shutdownBtn
          KeyNavigation.right: rebootBtn
          onActivated: {
            suspendProc.running = true;
            sessionScreen.close();
          }
        }

        SessionButton {
          id: rebootBtn
          glyph: "🔄"
          label: "Reboot"
          KeyNavigation.left: suspendBtn
          KeyNavigation.right: lockBtn
          onActivated: {
            rebootProc.running = true;
            sessionScreen.close();
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Arrow keys to navigate, Enter to select, Esc to cancel"
        font.pixelSize: 12
        color: "#9a9aab"
      }
    }
  }
}
