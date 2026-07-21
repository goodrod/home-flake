import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth

Item {
  id: controlCenter

  readonly property color islandBg: "#141313"
  readonly property color chipBg: "#49454F"
  readonly property color chipHoverBg: Qt.lighter(chipBg, 1.25)
  readonly property color textColor: "#DEE2E6"
  readonly property color mutedTextColor: "#CAC4D0"
  readonly property color accentColor: "#D0BCFF"
  readonly property color accentTextColor: "#381E72"
  readonly property color iconBadgeBg: "#4A4458"
  readonly property color iconBadgeFg: "#E8DEF8"
  readonly property color notifAreaBg: "#211F26"
  readonly property int barHeight: 50

  property var toasts: []
  property var history: []
  property bool dnd: false
  property bool shown: false
  property var targetScreen: Quickshell.screens[0]
  readonly property int count: history.length

  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property bool airplaneModeOn: !Networking.wifiEnabled && (!btAdapter || !btAdapter.enabled)

  property real brightnessValue: 0
  property bool brightnessAvailable: false

  property string userAtHost: ""

  signal requestSessionScreen()

  function toggle() {
    shown = !shown;
  }
  function close() {
    shown = false;
  }
  function toggleDnd() {
    dnd = !dnd;
  }

  function dismissToast(id) {
    toasts = toasts.filter((t) => t.id !== id);
  }
  function closeNotification(entry) {
    if (entry.wrapped) entry.wrapped.dismiss();
    history = history.filter((h) => h.id !== entry.id);
    toasts = toasts.filter((t) => t.id !== entry.id);
  }
  function clearAll() {
    for (const h of history) {
      if (h.wrapped) h.wrapped.dismiss();
    }
    history = [];
    toasts = [];
  }

  function toggleAirplaneMode() {
    if (airplaneModeOn) {
      Networking.wifiEnabled = true;
      if (btAdapter) btAdapter.enabled = true;
    } else {
      Networking.wifiEnabled = false;
      if (btAdapter) btAdapter.enabled = false;
    }
  }

  function setBrightness(v) {
    brightnessValue = v;
    const pct = Math.round(v * 100);
    brightnessSetProc.command = ["brightnessctl", "-c", "backlight", "-m", "s", pct + "%"];
    brightnessSetProc.running = true;
  }

  Process {
    id: userAtHostProc
    command: ["sh", "-c", "echo \"$(whoami)@$(hostname)\""]
    stdout: StdioCollector {
      onStreamFinished: controlCenter.userAtHost = this.text.trim()
    }
  }
  Component.onCompleted: userAtHostProc.running = true

  NotificationServer {
    id: server
    bodySupported: true
    imageSupported: true

    onNotification: (n) => {
      n.tracked = true;
      const entry = {
        id: n.id,
        summary: n.summary || "",
        body: n.body || "",
        wrapped: n
      };
      history = [entry, ...history];
      if (!controlCenter.dnd) {
        toasts = [entry, ...toasts];
        const timeout = n.expireTimeout > 0 ? n.expireTimeout : 5000;
        const timer = dismissTimerComponent.createObject(controlCenter, { notifId: entry.id, interval: timeout });
        timer.start();
      }
      n.closed.connect(() => {
        history = history.filter((h) => h.id !== entry.id);
        toasts = toasts.filter((t) => t.id !== entry.id);
      });
    }
  }

  Component {
    id: dismissTimerComponent
    Timer {
      property var notifId
      repeat: false
      onTriggered: {
        controlCenter.toasts = controlCenter.toasts.filter((t) => t.id !== notifId);
        destroy();
      }
    }
  }

  Process {
    id: brightnessGetProc
    command: ["brightnessctl", "-c", "backlight", "-m", "i"]
    stdout: StdioCollector {
      onStreamFinished: {
        const line = this.text.trim();
        const parts = line.split(",");
        if (parts.length < 4 || parts[1] !== "backlight") {
          controlCenter.brightnessAvailable = false;
          return;
        }
        const pct = parseInt(parts[3], 10);
        if (isNaN(pct)) {
          controlCenter.brightnessAvailable = false;
          return;
        }
        controlCenter.brightnessAvailable = true;
        controlCenter.brightnessValue = pct / 100;
      }
    }
    onExited: (exitCode) => {
      if (exitCode !== 0) controlCenter.brightnessAvailable = false;
    }
  }
  Timer {
    interval: 2000
    running: controlCenter.shown
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!brightnessGetProc.running) brightnessGetProc.running = true
  }
  Process { id: brightnessSetProc }

  component IconButton: Rectangle {
    id: iconBtnRoot
    property string glyph: ""
    property int glyphSize: 13
    signal clicked()

    width: 28
    height: 28
    radius: 8
    color: mouseArea.containsMouse ? controlCenter.chipHoverBg : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
      anchors.centerIn: parent
      text: iconBtnRoot.glyph
      font.pixelSize: iconBtnRoot.glyphSize
      color: controlCenter.textColor
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      onClicked: iconBtnRoot.clicked()
    }
  }

  component ToggleTile: Rectangle {
    id: tileRoot
    property string glyph: ""
    property string label: ""
    property string status: ""
    property bool active: false
    signal clicked()

    height: 56
    radius: 14
    color: controlCenter.chipBg

    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: 10
      spacing: 10

      Rectangle {
        width: 34
        height: 34
        radius: 12
        anchors.verticalCenter: parent.verticalCenter
        color: tileRoot.active ? controlCenter.accentColor : controlCenter.iconBadgeBg
        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
          anchors.centerIn: parent
          text: tileRoot.glyph
          font.pixelSize: 16
          color: tileRoot.active ? controlCenter.accentTextColor : controlCenter.iconBadgeFg
        }
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: tileRoot.width - 34 - 10 - 10 - 10
        spacing: 2

        Text {
          width: parent.width
          text: tileRoot.label
          font.pixelSize: 13
          font.bold: true
          color: controlCenter.textColor
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: tileRoot.status
          font.pixelSize: 11
          color: controlCenter.mutedTextColor
          elide: Text.ElideRight
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: tileRoot.clicked()
    }
  }

  component SliderRow: Item {
    id: sliderRoot
    property string icon: ""
    property real value: 0
    property bool sliderEnabled: true
    signal moved(real val)

    height: 22

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 20
      text: sliderRoot.icon
      color: controlCenter.mutedTextColor
      font.pixelSize: 14
    }

    Rectangle {
      id: track
      anchors.left: parent.left
      anchors.leftMargin: 28
      anchors.right: pctText.left
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      height: 6
      radius: 3
      color: controlCenter.chipBg
      opacity: sliderRoot.sliderEnabled ? 1 : 0.4

      Rectangle {
        width: track.width * Math.max(0, Math.min(1, sliderRoot.value))
        height: parent.height
        radius: 3
        color: controlCenter.accentColor
      }

      MouseArea {
        anchors.fill: parent
        enabled: sliderRoot.sliderEnabled
        onPressed: (mouse) => sliderRoot.moved(Math.max(0, Math.min(1, mouse.x / track.width)))
        onPositionChanged: (mouse) => {
          if (pressed) sliderRoot.moved(Math.max(0, Math.min(1, mouse.x / track.width)));
        }
      }
    }

    Text {
      id: pctText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: 36
      horizontalAlignment: Text.AlignRight
      text: Math.round(sliderRoot.value * 100) + "%"
      color: controlCenter.textColor
      font.pixelSize: 12
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      screen: modelData
      color: "transparent"
      visible: controlCenter.toasts.length > 0
      WlrLayershell.namespace: "quickshell:notification-popups"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      anchors { top: true; right: true }
      margins.top: controlCenter.barHeight + 10
      margins.right: 14
      implicitWidth: 340
      implicitHeight: toastColumn.implicitHeight + 20

      Column {
        id: toastColumn
        x: 10
        y: 10
        width: parent.width - 20
        spacing: 8

        Repeater {
          model: controlCenter.toasts
          delegate: Rectangle {
            width: toastColumn.width
            height: toastContent.implicitHeight + 20
            radius: 14
            color: controlCenter.islandBg

            Column {
              id: toastContent
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
              spacing: 4

              Item {
                width: parent.width
                height: Math.max(summaryText.implicitHeight, 16)

                Text {
                  id: summaryText
                  anchors { left: parent.left; right: closeIcon.left; rightMargin: 8 }
                  text: modelData.summary
                  color: controlCenter.textColor
                  font.bold: true
                  font.pixelSize: 14
                  elide: Text.ElideRight
                }

                Text {
                  id: closeIcon
                  anchors.right: parent.right
                  text: "✕"
                  color: controlCenter.mutedTextColor
                  font.pixelSize: 12

                  MouseArea {
                    anchors.fill: parent
                    onClicked: controlCenter.dismissToast(modelData.id)
                  }
                }
              }

              Text {
                width: parent.width
                visible: modelData.body.length > 0
                text: modelData.body
                color: controlCenter.mutedTextColor
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }
  }

  PanelWindow {
    id: ccWindow
    screen: controlCenter.targetScreen
    visible: controlCenter.shown
    color: "transparent"
    WlrLayershell.namespace: "quickshell:notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: controlCenter.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    HyprlandFocusGrab {
      windows: [ccWindow]
      active: controlCenter.shown
      onCleared: controlCenter.close()
    }

    MouseArea {
      anchors.fill: parent
      onClicked: controlCenter.close()
    }

    FocusScope {
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      anchors.topMargin: controlCenter.barHeight + 10
      anchors.bottomMargin: 14
      anchors.rightMargin: 14
      width: 420
      focus: controlCenter.shown

      Keys.onEscapePressed: controlCenter.close()

      Rectangle {
        anchors.fill: parent
        radius: 18
        color: controlCenter.islandBg
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        MouseArea { anchors.fill: parent }

        Column {
          id: headerBlock
          anchors { top: parent.top; left: parent.left; right: parent.right; margins: 20 }
          spacing: 12

          Item {
            width: parent.width
            height: 20

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: controlCenter.userAtHost
              color: controlCenter.mutedTextColor
              font.pixelSize: 12
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 4

              IconButton {
                glyph: "\uF021"
                onClicked: Quickshell.reload(true)
              }

              IconButton {
                glyph: "⏻"
                onClicked: {
                  controlCenter.requestSessionScreen();
                  controlCenter.close();
                }
              }
            }
          }

          Row {
            id: toggleRow1
            width: parent.width
            spacing: 8

            ToggleTile {
              width: (toggleRow1.width - toggleRow1.spacing) / 2
              glyph: "\uF1EB"
              label: "Wifi"
              status: Networking.wifiEnabled ? "On" : "Off"
              active: Networking.wifiEnabled
              onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            }

            ToggleTile {
              width: (toggleRow1.width - toggleRow1.spacing) / 2
              glyph: "\uF293"
              label: "Bluetooth"
              status: (controlCenter.btAdapter && controlCenter.btAdapter.enabled) ? "On" : "Off"
              active: controlCenter.btAdapter && controlCenter.btAdapter.enabled
              onClicked: if (controlCenter.btAdapter) controlCenter.btAdapter.enabled = !controlCenter.btAdapter.enabled
            }
          }

          Row {
            id: toggleRow2
            width: parent.width
            spacing: 8

            ToggleTile {
              id: audioTile
              width: (toggleRow2.width - toggleRow2.spacing) / 2
              readonly property var sink: Pipewire.defaultAudioSink
              glyph: "\uF025"
              label: "Audio"
              status: {
                if (!sink || !sink.audio) return "--";
                if (sink.audio.muted) return "Muted";
                return Math.round(sink.audio.volume * 100) + "%";
              }
              active: audioTile.sink && audioTile.sink.audio && !audioTile.sink.audio.muted
              onClicked: {
                const s = Pipewire.defaultAudioSink;
                if (s && s.audio) s.audio.muted = !s.audio.muted;
              }
            }

            ToggleTile {
              width: (toggleRow2.width - toggleRow2.spacing) / 2
              glyph: "\uF072"
              label: "Airplane Mode"
              status: controlCenter.airplaneModeOn ? "On" : "Off"
              active: controlCenter.airplaneModeOn
              onClicked: controlCenter.toggleAirplaneMode()
            }
          }
        }

        Rectangle {
          id: slidersAreaBg
          anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 20 }
          height: slidersBlock.implicitHeight + 24
          radius: 14
          color: controlCenter.notifAreaBg
        }

        Column {
          id: slidersBlock
          anchors { bottom: slidersAreaBg.bottom; left: slidersAreaBg.left; right: slidersAreaBg.right; margins: 12 }
          spacing: 8

          SliderRow {
            width: parent.width
            icon: "\uF028"
            value: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.volume : 0
            onMoved: (v) => {
              const sink = Pipewire.defaultAudioSink;
              if (sink && sink.audio) sink.audio.volume = v;
            }
          }

          SliderRow {
            width: parent.width
            visible: controlCenter.brightnessAvailable
            icon: "\uF185"
            value: controlCenter.brightnessValue
            onMoved: (v) => controlCenter.setBrightness(v)
          }
        }

        Rectangle {
          id: notifArea
          anchors {
            top: headerBlock.bottom
            bottom: slidersAreaBg.top
            left: parent.left
            right: parent.right
            topMargin: 12
            bottomMargin: 12
            leftMargin: 20
            rightMargin: 20
          }
          radius: 14
          color: controlCenter.notifAreaBg
        }

        Item {
          id: notifCountRow
          anchors { bottom: notifArea.bottom; left: notifArea.left; right: notifArea.right; margins: 10 }
          height: 28

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: controlCenter.count + " Notifications"
            color: controlCenter.mutedTextColor
            font.pixelSize: 12
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            IconButton {
              glyph: "✕"
              onClicked: controlCenter.clearAll()
            }

            IconButton {
              glyph: controlCenter.dnd ? "\uF1F6" : "\uF476"
              onClicked: controlCenter.toggleDnd()
            }
          }
        }

        Item {
          visible: controlCenter.history.length === 0
          anchors {
            top: notifArea.top
            bottom: notifCountRow.top
            left: notifArea.left
            right: notifArea.right
          }

          Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "\u{F0A93}"
              color: controlCenter.mutedTextColor
              font.pixelSize: 40
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "No notifications"
              color: controlCenter.mutedTextColor
              font.pixelSize: 13
            }
          }
        }

        ListView {
          anchors {
            top: notifArea.top
            bottom: notifCountRow.top
            left: notifArea.left
            right: notifArea.right
            margins: 10
          }
          clip: true
          spacing: 8
          visible: controlCenter.history.length > 0
          model: controlCenter.history

          delegate: Rectangle {
            width: ListView.view.width
            height: entryContent.implicitHeight + 20
            radius: 12
            color: controlCenter.chipBg

            Column {
              id: entryContent
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
              spacing: 4

              Item {
                width: parent.width
                height: Math.max(entrySummary.implicitHeight, 16)

                Text {
                  id: entrySummary
                  anchors { left: parent.left; right: entryClose.left; rightMargin: 8 }
                  text: modelData.summary
                  color: controlCenter.textColor
                  font.bold: true
                  font.pixelSize: 13
                  elide: Text.ElideRight
                }

                Text {
                  id: entryClose
                  anchors.right: parent.right
                  text: "✕"
                  color: controlCenter.mutedTextColor
                  font.pixelSize: 12

                  MouseArea {
                    anchors.fill: parent
                    onClicked: controlCenter.closeNotification(modelData)
                  }
                }
              }

              Text {
                width: parent.width
                visible: modelData.body.length > 0
                text: modelData.body
                color: controlCenter.mutedTextColor
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }
  }
}
