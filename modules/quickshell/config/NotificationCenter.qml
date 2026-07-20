import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Notification center, sshell-style: quickshell owns notifications directly
// (Quickshell.Services.Notifications.NotificationServer) instead of going
// through swaync - toast popups top-right, a toggleable history panel with
// DND/clear-all/power in its header (the standalone power button moved in
// here, same as sshell's ControlCenter). All glyphs below are written as
// \u{...} escapes rather than pasted literal characters - this repo hit
// real UTF-8 byte-corruption bugs earlier from copy/pasting multi-byte
// glyphs through shell tooling, and a JS unicode escape is immune to that
// entire class of problem.
Item {
  id: notifCenter

  readonly property color islandBg: "#181825"
  readonly property color chipBg: "#22222c"
  readonly property color chipHoverBg: "#33333f"
  readonly property color textColor: "#d8d8e2"
  readonly property color mutedTextColor: "#9a9aab"
  readonly property color accentColor: "#6c7ce0"

  // Toasts: currently-visible popups (cleared on timeout or dismiss).
  // History: everything not yet cleared, most recent first - what the
  // panel's list shows. A notification lives in both until its toast
  // times out; closing/clearing removes it from both at once.
  property var toasts: []
  property var history: []
  property bool dnd: false
  property bool shown: false
  readonly property int count: history.length

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
      if (!notifCenter.dnd) {
        toasts = [entry, ...toasts];
        const timeout = n.expireTimeout > 0 ? n.expireTimeout : 5000;
        const timer = dismissTimerComponent.createObject(notifCenter, { notifId: entry.id, interval: timeout });
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
        notifCenter.toasts = notifCenter.toasts.filter((t) => t.id !== notifId);
        destroy();
      }
    }
  }

  // ---------------- toasts: non-modal, top-right, one per screen[0] ----------------
  PanelWindow {
    screen: Quickshell.screens[0]
    color: "transparent"
    visible: notifCenter.toasts.length > 0
    WlrLayershell.namespace: "quickshell:notification-popups"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    implicitWidth: 340
    implicitHeight: toastColumn.implicitHeight + 20

    Column {
      id: toastColumn
      x: 10
      y: 10
      width: parent.width - 20
      spacing: 8

      Repeater {
        model: notifCenter.toasts
        delegate: Rectangle {
          width: toastColumn.width
          height: toastContent.implicitHeight + 20
          radius: 14
          color: notifCenter.islandBg

          Column {
            id: toastContent
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 4

            Row {
              width: parent.width

              Text {
                width: parent.width - 20
                text: modelData.summary
                color: notifCenter.textColor
                font.bold: true
                font.pixelSize: 14
                elide: Text.ElideRight
              }

              Text {
                text: "✕"
                color: notifCenter.mutedTextColor
                font.pixelSize: 12

                MouseArea {
                  anchors.fill: parent
                  onClicked: notifCenter.dismissToast(modelData.id)
                }
              }
            }

            Text {
              width: parent.width
              visible: modelData.body.length > 0
              text: modelData.body
              color: notifCenter.mutedTextColor
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

  // ---------------- history panel: modal, opened from the bar's bell ----------------
  PanelWindow {
    screen: Quickshell.screens[0]
    visible: notifCenter.shown
    color: "transparent"
    WlrLayershell.namespace: "quickshell:notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: notifCenter.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    // Full-window click-outside catcher, sits behind the panel below.
    MouseArea {
      anchors.fill: parent
      onClicked: notifCenter.close()
    }

    FocusScope {
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 60
      anchors.rightMargin: 14
      width: 360
      height: Math.min(parent.height - 100, panelColumn.implicitHeight + 32)
      focus: notifCenter.shown

      Keys.onEscapePressed: notifCenter.close()

      Rectangle {
        anchors.fill: parent
        radius: 18
        color: notifCenter.islandBg
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        // Swallows clicks so they don't fall through to the outer
        // click-outside catcher and close the panel on its own content.
        MouseArea { anchors.fill: parent }

        Column {
          id: panelColumn
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
          spacing: 12

          Row {
            width: parent.width
            spacing: 8

            Text {
              text: "Notifications"
              color: notifCenter.textColor
              font.pixelSize: 18
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 220; height: 1 }

            Rectangle {
              width: 28
              height: 28
              radius: 8
              color: dndMouse.containsMouse ? notifCenter.chipHoverBg : notifCenter.chipBg

              Text {
                anchors.centerIn: parent
                text: notifCenter.dnd ? "\u{1F515}" : "\u{1F514}"
                font.pixelSize: 13
                color: notifCenter.textColor
              }

              MouseArea {
                id: dndMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: notifCenter.toggleDnd()
              }
            }

            Rectangle {
              width: 28
              height: 28
              radius: 8
              color: clearMouse.containsMouse ? notifCenter.chipHoverBg : notifCenter.chipBg

              Text {
                anchors.centerIn: parent
                text: "\u{1F5D1}"
                font.pixelSize: 13
                color: notifCenter.textColor
              }

              MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: notifCenter.clearAll()
              }
            }

            Rectangle {
              width: 28
              height: 28
              radius: 8
              color: powerMouse.containsMouse ? notifCenter.chipHoverBg : notifCenter.chipBg

              Text {
                anchors.centerIn: parent
                text: "⏻"
                font.pixelSize: 13
                color: notifCenter.textColor
              }

              MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  notifCenter.requestSessionScreen();
                  notifCenter.close();
                }
              }
            }
          }

          Text {
            visible: notifCenter.history.length === 0
            width: parent.width
            text: "No notifications"
            color: notifCenter.mutedTextColor
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
          }

          Flickable {
            width: parent.width
            height: Math.min(400, listColumn.implicitHeight)
            contentWidth: width
            contentHeight: listColumn.implicitHeight
            clip: true
            visible: notifCenter.history.length > 0

            Column {
              id: listColumn
              width: parent.width
              spacing: 8

              Repeater {
                model: notifCenter.history
                delegate: Rectangle {
                  width: listColumn.width
                  height: entryContent.implicitHeight + 20
                  radius: 12
                  color: notifCenter.chipBg

                  Column {
                    id: entryContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    spacing: 4

                    Row {
                      width: parent.width

                      Text {
                        width: parent.width - 20
                        text: modelData.summary
                        color: notifCenter.textColor
                        font.bold: true
                        font.pixelSize: 13
                        elide: Text.ElideRight
                      }

                      Text {
                        text: "✕"
                        color: notifCenter.mutedTextColor
                        font.pixelSize: 12

                        MouseArea {
                          anchors.fill: parent
                          onClicked: notifCenter.closeNotification(modelData)
                        }
                      }
                    }

                    Text {
                      width: parent.width
                      visible: modelData.body.length > 0
                      text: modelData.body
                      color: notifCenter.mutedTextColor
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
}
