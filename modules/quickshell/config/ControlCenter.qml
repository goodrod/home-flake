import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth

Item {
  id: controlCenter

  readonly property color islandBg: "#181825"
  readonly property color chipBg: "#22222c"
  readonly property color chipHoverBg: "#33333f"
  readonly property color textColor: "#d8d8e2"
  readonly property color mutedTextColor: "#9a9aab"
  readonly property color accentColor: "#6c7ce0"
  readonly property int barHeight: 50

  property var toasts: []
  property var history: []
  property bool dnd: false
  property bool shown: false
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
    brightnessSetProc.command = ["brightnessctl", "-m", "s", pct + "%"];
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
    command: ["brightnessctl", "-m", "i"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = this.text.trim().split("\n").filter((l) => l.length > 0);
        const chosen = lines.find((l) => l.split(",")[1] === "backlight") || lines[0];
        if (!chosen) {
          controlCenter.brightnessAvailable = false;
          return;
        }
        const parts = chosen.split(",");
        if (parts.length < 4) {
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
    radius: 12
    color: active ? controlCenter.accentColor : controlCenter.chipBg
    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
      anchors.centerIn: parent
      spacing: 10

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: tileRoot.glyph
        font.pixelSize: 20
        color: tileRoot.active ? "#ffffff" : controlCenter.textColor
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
          text: tileRoot.label
          font.pixelSize: 13
          font.bold: true
          color: tileRoot.active ? "#ffffff" : controlCenter.textColor
        }

        Text {
          text: tileRoot.status
          font.pixelSize: 11
          color: tileRoot.active ? Qt.rgba(1, 1, 1, 0.85) : controlCenter.mutedTextColor
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
    property string label: ""
    property real value: 0
    property bool sliderEnabled: true
    signal moved(real val)

    height: 22

    Text {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: 70
      text: sliderRoot.label
      color: controlCenter.mutedTextColor
      font.pixelSize: 12
    }

    Rectangle {
      id: track
      anchors.left: parent.left
      anchors.leftMargin: 76
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

  PanelWindow {
    screen: Quickshell.screens[0]
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

  PanelWindow {
    screen: Quickshell.screens[0]
    visible: controlCenter.shown
    color: "transparent"
    WlrLayershell.namespace: "quickshell:notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: controlCenter.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

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
      width: 360
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
          anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
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

          Text {
            width: parent.width
            text: "Control Center"
            color: controlCenter.textColor
            font.pixelSize: 18
            font.bold: true
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

        Column {
          id: footerBlock
          anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 16 }
          spacing: 8

          SliderRow {
            width: parent.width
            label: "Volume"
            value: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) ? Pipewire.defaultAudioSink.audio.volume : 0
            onMoved: (v) => {
              const sink = Pipewire.defaultAudioSink;
              if (sink && sink.audio) sink.audio.volume = v;
            }
          }

          SliderRow {
            width: parent.width
            visible: controlCenter.brightnessAvailable
            label: "Brightness"
            value: controlCenter.brightnessValue
            onMoved: (v) => controlCenter.setBrightness(v)
          }

          Item {
            width: parent.width
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
        }

        Flickable {
          anchors {
            top: headerBlock.bottom
            bottom: footerBlock.top
            left: parent.left
            right: parent.right
            topMargin: 12
            bottomMargin: 12
            leftMargin: 16
            rightMargin: 16
          }
          contentWidth: width
          contentHeight: listColumn.implicitHeight
          clip: true

          Text {
            visible: controlCenter.history.length === 0
            anchors.centerIn: parent
            text: "No notifications"
            color: controlCenter.mutedTextColor
            font.pixelSize: 13
          }

          Column {
            id: listColumn
            width: parent.width
            spacing: 8
            visible: controlCenter.history.length > 0

            Repeater {
              model: controlCenter.history
              delegate: Rectangle {
                width: listColumn.width
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
  }
}
