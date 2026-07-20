import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
  id: sessionScreen

  readonly property color chipBg: "#49454F"
  readonly property color textColor: "#DEE2E6"
  readonly property color mutedTextColor: "#CAC4D0"
  readonly property color accentColor: "#D0BCFF"
  readonly property color accentTextColor: "#381E72"

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
    readonly property bool active: activeFocus || mouseArea.containsMouse
    signal activated()

    width: 150
    height: 150
    radius: active ? width / 3 : 20
    color: active ? sessionScreen.accentColor : sessionScreen.chipBg
    border.width: active ? 0 : 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    Behavior on color { ColorAnimation { duration: 150 } }

    Keys.onPressed: (event) => {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        btnRoot.activated();
        event.accepted = true;
      }
    }

    Column {
      anchors.centerIn: parent
      spacing: 14

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: btnRoot.glyph
        font.pixelSize: 44
        color: btnRoot.active ? sessionScreen.accentTextColor : sessionScreen.textColor
        scale: btnRoot.active ? 1.15 : 1.0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: btnRoot.label
        font.pixelSize: 16
        font.bold: true
        color: btnRoot.active ? sessionScreen.accentTextColor : sessionScreen.textColor
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      onClicked: btnRoot.activated()
    }
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: sessionScreen.shown ? 0.65 : 0
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
      spacing: 36

      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Session"
          font.pixelSize: 34
          font.bold: true
          color: sessionScreen.textColor
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 24

        SessionButton {
          id: lockBtn
          glyph: "⚿"
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
          glyph: "☾"
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
          glyph: "↻"
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
        text: "Arrow keys or mouse to navigate, Enter/click to select, Esc to cancel"
        font.pixelSize: 13
        color: sessionScreen.mutedTextColor
      }
    }
  }
}
