import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Item {
  id: notifCenter

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

  component IconButton: Rectangle {
    id: iconBtnRoot
    property string glyph: ""
    property int glyphSize: 13
    signal clicked()

    width: 28
    height: 28
    radius: 8
    color: mouseArea.containsMouse ? notifCenter.chipHoverBg : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
      anchors.centerIn: parent
      text: iconBtnRoot.glyph
      font.pixelSize: iconBtnRoot.glyphSize
      color: notifCenter.textColor
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      onClicked: iconBtnRoot.clicked()
    }
  }

  PanelWindow {
    screen: Quickshell.screens[0]
    color: "transparent"
    visible: notifCenter.toasts.length > 0
    WlrLayershell.namespace: "quickshell:notification-popups"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins.top: notifCenter.barHeight + 10
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

            Item {
              width: parent.width
              height: Math.max(summaryText.implicitHeight, 16)

              Text {
                id: summaryText
                anchors { left: parent.left; right: closeIcon.left; rightMargin: 8 }
                text: modelData.summary
                color: notifCenter.textColor
                font.bold: true
                font.pixelSize: 14
                elide: Text.ElideRight
              }

              Text {
                id: closeIcon
                anchors.right: parent.right
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

  PanelWindow {
    screen: Quickshell.screens[0]
    visible: notifCenter.shown
    color: "transparent"
    WlrLayershell.namespace: "quickshell:notification-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: notifCenter.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }

    MouseArea {
      anchors.fill: parent
      onClicked: notifCenter.close()
    }

    FocusScope {
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: notifCenter.barHeight + 10
      anchors.rightMargin: 14
      width: 360
      height: Math.min(parent.height - notifCenter.barHeight - 40, panelColumn.implicitHeight + 32)
      focus: notifCenter.shown

      Keys.onEscapePressed: notifCenter.close()

      Rectangle {
        anchors.fill: parent
        radius: 18
        color: notifCenter.islandBg
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        MouseArea { anchors.fill: parent }

        Column {
          id: panelColumn
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
          spacing: 12

          Item {
            width: parent.width
            height: 28

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Notifications"
              color: notifCenter.textColor
              font.pixelSize: 18
              font.bold: true
            }

            IconButton {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              glyph: "⏻"
              onClicked: {
                notifCenter.requestSessionScreen();
                notifCenter.close();
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
            height: Math.min(320, listColumn.implicitHeight)
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

                    Item {
                      width: parent.width
                      height: Math.max(entrySummary.implicitHeight, 16)

                      Text {
                        id: entrySummary
                        anchors { left: parent.left; right: entryClose.left; rightMargin: 8 }
                        text: modelData.summary
                        color: notifCenter.textColor
                        font.bold: true
                        font.pixelSize: 13
                        elide: Text.ElideRight
                      }

                      Text {
                        id: entryClose
                        anchors.right: parent.right
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

          Item {
            width: parent.width
            height: 28

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: notifCenter.count + " Notifications"
              color: notifCenter.mutedTextColor
              font.pixelSize: 12
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 4

              IconButton {
                glyph: "✕"
                onClicked: notifCenter.clearAll()
              }

              IconButton {
                glyph: notifCenter.dnd ? "" : ""
                onClicked: notifCenter.toggleDnd()
              }
            }
          }
        }
      }
    }
  }
}
