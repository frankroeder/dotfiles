import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "../../"

Scope {
  id: root

  property var toastScreen: null
  property var historyScreen: null
  property var toasts: []
  property var history: []
  property bool historyVisible: false
  property bool dndEnabled: false
  readonly property int historyCount: history.length
  readonly property int maxHistory: 40
  readonly property int maxToasts: 4
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  function focusedScreen() {
    const mon = Hyprland.focusedMonitor
    return mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
  }

  function urgencyColor(urgency) {
    if (urgency === 2) return Style.red
    if (urgency === 0) return Style.textMuted
    return Style.blueAlt
  }

  function stripMarkup(value) {
    return String(value || "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
  }

  function iconFor(entry) {
    if (!entry) return ""
    if (entry.image) return entry.image
    const raw = entry.appIcon || entry.desktopEntry || entry.appName || ""
    return raw ? Quickshell.iconPath(raw, true) : ""
  }

  function snapshot(n) {
    return {
      key: String(Date.now()) + "-" + Math.floor(Math.random() * 10000),
      appName: stripMarkup(n.appName || ""),
      appIcon: String(n.appIcon || ""),
      desktopEntry: String(n.desktopEntry || ""),
      image: String(n.image || ""),
      summary: stripMarkup(n.summary || ""),
      body: stripMarkup(n.body || ""),
      urgency: Number(n.urgency) || 1,
      time: Qt.formatTime(new Date(), "HH:mm")
    }
  }

  function addHistory(entry) {
    let next = root.history.slice()
    if (entry.appName === "Asahi Battery") next = next.filter(item => item.appName !== "Asahi Battery")
    next.unshift(entry)
    root.history = next.slice(0, root.maxHistory)
  }

  function addToast(entry) {
    let next = root.toasts.slice()
    next.unshift(entry)
    root.toasts = next.slice(0, root.maxToasts)
  }

  function removeToast(key) {
    root.toasts = root.toasts.filter(item => item.key !== key)
  }

  function handleNotification(n) {
    const entry = snapshot(n)
    addHistory(entry)
    toastScreen = focusedScreen()
    if (!dndEnabled || entry.urgency === 2) {
      addToast(entry)
      Quickshell.execDetached([root.binDir + "/asahi-notification-sound"])
    }
  }

  function toggleHistory() {
    historyScreen = focusedScreen()
    historyVisible = !historyVisible
  }

  function clearHistory() {
    root.history = []
    root.toasts = []
  }

  function toggleDnd() {
    dndEnabled = !dndEnabled
  }

  NotificationServer {
    id: notifServer
    bodySupported: true
    bodyMarkupSupported: false
    actionsSupported: false
    imageSupported: true
    onNotification: (n) => root.handleNotification(n)
  }

  IpcHandler {
    target: "notifications"
    function toggleHistory(): void { root.toggleHistory() }
    function clear(): void { root.clearHistory() }
    function toggleDnd(): void { root.toggleDnd() }
  }

  PanelWindow {
    visible: root.toasts.length > 0
    color: "transparent"
    screen: root.toastScreen
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    anchors { bottom: true; right: true }
    margins { bottom: 56; right: 36 }
    implicitWidth: 380
    implicitHeight: toastColumn.implicitHeight

    ColumnLayout {
      id: toastColumn
      width: parent.width
      spacing: 8

      Repeater {
        model: root.toasts
        delegate: NotificationCard {
          width: toastColumn.width
          entry: modelData
          compact: false
          timeout: true
          onDismiss: root.removeToast(modelData.key)
        }
      }
    }
  }

  PanelWindow {
    visible: root.historyVisible
    color: "transparent"
    screen: root.historyScreen
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notification-center"
    anchors { top: true; right: true }
    margins { top: 52; right: 12 }
    implicitWidth: 420
    implicitHeight: 520

    Rectangle {
      anchors.fill: parent
      radius: 8
      color: Style.surface
      border.color: Style.border
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Notifications"
            font.family: Style.fontFamily
            font.pixelSize: 14
            font.bold: true
            color: Style.text
            Layout.fillWidth: true
          }
          MouseArea {
            width: 24
            height: 24
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleDnd()
            Text {
              anchors.centerIn: parent
              text: root.dndEnabled ? "󰂛" : "󰂚"
              font.family: Style.fontFamily
              font.pixelSize: 13
              color: root.dndEnabled ? Style.yellow : Style.textMuted
            }
          }
          MouseArea {
            width: 24
            height: 24
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clearHistory()
            Text {
              anchors.centerIn: parent
              text: "󰆴"
              font.family: Style.fontFamily
              font.pixelSize: 13
              color: Style.textMuted
            }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Style.border; opacity: 0.65 }

        Flickable {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          contentHeight: historyColumn.implicitHeight

          ColumnLayout {
            id: historyColumn
            width: parent.width
            spacing: 8

            Text {
              visible: root.history.length === 0
              text: "No notifications"
              font.family: Style.fontFamily
              font.pixelSize: 12
              color: Style.textMuted
              Layout.alignment: Qt.AlignHCenter
              Layout.topMargin: 130
            }

            Repeater {
              model: root.history
              delegate: NotificationCard {
                Layout.fillWidth: true
                entry: modelData
                compact: true
                timeout: false
                onDismiss: root.history = root.history.filter(item => item.key !== modelData.key)
              }
            }
          }
        }
      }
    }
  }

  component NotificationCard: Rectangle {
    id: card

    property var entry: null
    property bool compact: false
    property bool timeout: false
    readonly property color accent: root.urgencyColor(entry ? entry.urgency : 1)
    signal dismiss()

    color: Style.surface2
    radius: 8
    border.color: card.accent
    border.width: 2
    implicitHeight: cardBody.implicitHeight + 18

    Timer {
      interval: card.entry && card.entry.urgency === 2 ? 9000 : 6000
      running: card.timeout
      repeat: false
      onTriggered: card.dismiss()
    }

    Rectangle {
      anchors {
        left: parent.left
        top: parent.top
        bottom: parent.bottom
        margins: 2
      }
      width: 5
      radius: 2
      color: card.accent
    }

    RowLayout {
      id: cardBody
      anchors.fill: parent
      anchors.margins: 9
      anchors.leftMargin: 14
      spacing: 10

      Rectangle {
        Layout.preferredWidth: 36
        Layout.preferredHeight: 36
        Layout.alignment: Qt.AlignTop
        radius: 6
        color: Qt.rgba(0, 0, 0, 0.18)

        IconImage {
          anchors.centerIn: parent
          width: 24
          height: 24
          source: root.iconFor(card.entry)
          visible: source !== ""
        }

        Text {
          anchors.centerIn: parent
          visible: root.iconFor(card.entry) === ""
          text: "󰂚"
          font.family: Style.fontFamily
          font.pixelSize: 16
          color: card.accent
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: card.entry ? ((card.entry.appName ? card.entry.appName + "  " : "") + card.entry.summary) : ""
            textFormat: Text.PlainText
            font.family: Style.fontFamily
            font.pixelSize: 12
            font.bold: true
            color: Style.text
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Text {
            text: card.entry ? card.entry.time : ""
            font.family: Style.fontFamily
            font.pixelSize: 10
            color: Style.textMuted
          }
        }

        Text {
          text: card.entry ? card.entry.body : ""
          visible: text.length > 0
          textFormat: Text.PlainText
          font.family: Style.fontFamily
          font.pixelSize: 11
          color: Style.textAlt
          wrapMode: Text.Wrap
          maximumLineCount: card.compact ? 3 : 2
          Layout.fillWidth: true
        }
      }

      MouseArea {
        Layout.preferredWidth: 20
        Layout.preferredHeight: 20
        Layout.alignment: Qt.AlignTop
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.dismiss()

        Text {
          anchors.centerIn: parent
          text: "󰅖"
          font.family: Style.fontFamily
          font.pixelSize: 12
          color: parent.containsMouse ? Style.red : Style.textMuted
        }
      }
    }
  }
}
