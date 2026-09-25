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
  // Persisted across shell restarts; unread = arrived after the sheet was last opened/closed.
  property real lastSeen: 0
  property bool historyLoaded: false
  readonly property int unreadCount: history.filter(e => (e.ts || 0) > lastSeen).length
  readonly property string historyPath: Quickshell.env("HOME") + "/.local/state/asahi/notifications.json"
  readonly property int maxHistory: 100
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

  // Any app on the bus can set image-path, and IconImage will fetch an http
  // URL — so only local sources are rendered; the rest fall back to the app
  // icon. (appIcon is safe already: it goes through the icon-theme lookup,
  // which returns "" for a URL.)
  function localImage(value) {
    const s = String(value || "")
    return s.startsWith("image:") || s.startsWith("file:") || s.startsWith("/")
  }

  function iconFor(entry) {
    if (!entry) return ""
    if (localImage(entry.image)) return entry.image
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
      ts: Date.now(),
      time: Qt.formatTime(new Date(), "HH:mm")
    }
  }

  // Day, not hour: what you remember about a notification you hunt for is the day.
  function dayLabel(ts) {
    const d = new Date(ts || 0)
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const days = Math.round((today - new Date(d).setHours(0, 0, 0, 0)) / 86400000)
    if (days <= 0) return "Today"
    if (days === 1) return "Yesterday"
    if (days < 7) return Qt.formatDate(d, "dddd")
    return Qt.formatDate(d, "d MMM yyyy")
  }

  // Focus the sender's window by class. Never runs anything the notification carried.
  function focusApp(entry) {
    Quickshell.execDetached(["sh", "-c",
      "a=$(hyprctl clients -j | jq -r --arg d \"$1\" --arg n \"$2\" " +
      "'[.[] | select((.class | ascii_downcase) as $c | $c == ($d | ascii_downcase) or $c == ($n | ascii_downcase))][0].address // empty'); " +
      "[ -n \"$a\" ] && hyprctl dispatch \"hl.dsp.focus({ window = \\\"address:$a\\\" })\"",
      "sh", entry.desktopEntry || "", entry.appName || ""])
  }

  function save() {
    if (root.historyLoaded) histFile.setText(JSON.stringify({ lastSeen: root.lastSeen, history: root.history }))
  }
  onHistoryChanged: save()
  onLastSeenChanged: save()

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
    lastSeen = Date.now()
  }

  function clearHistory() {
    root.history = []
    root.toasts = []
  }

  function toggleDnd() {
    dndEnabled = !dndEnabled
  }

  function dismissOne() {
    if (root.toasts.length > 0) {
      root.removeToast(root.toasts[0].key)
      return
    }
    if (root.history.length > 0)
      root.history = root.history.slice(1)
  }

  function dismissAll() {
    root.toasts = []
    root.history = []
  }

  NotificationServer {
    id: notifServer
    bodySupported: true
    bodyMarkupSupported: false
    actionsSupported: false
    imageSupported: true
    onNotification: (n) => root.handleNotification(n)
  }

  // Private file (0600, non-atomic writes keep the mode); load only after it exists.
  Process {
    running: true
    command: ["sh", "-c", "umask 077; mkdir -p \"$(dirname \"$1\")\" && touch \"$1\" && chmod 600 \"$1\"", "sh", root.historyPath]
    onExited: histFile.path = root.historyPath
  }

  FileView {
    id: histFile
    atomicWrites: false
    onLoaded: {
      const raw = histFile.text().trim()
      const saved = raw ? JSON.parse(raw) : {}
      root.lastSeen = saved.lastSeen || 0
      root.historyLoaded = true
      root.history = root.history.concat(saved.history || []).slice(0, root.maxHistory)
    }
  }

  IpcHandler {
    target: "notifications"
    function toggleHistory(): void { root.toggleHistory() }
    function clear(): void { root.clearHistory() }
    function toggleDnd(): void { root.toggleDnd() }
    function dismissOne(): void { root.dismissOne() }
    function dismissAll(): void { root.dismissAll() }
  }

  PanelWindow {
    // Top-right under the bar; the open sheet takes that spot, so toasts wait.
    visible: root.toasts.length > 0 && !root.historyVisible
    color: "transparent"
    screen: root.toastScreen
    // Normal + zone 0: sit below the bar's exclusive zone (44 or notch height).
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    anchors { top: true; right: true }
    // Right edge shared with the history sheet and the bar (barEdgeMargin).
    margins { top: 8; right: Style.barEdgeMargin }
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
          onActivated: { root.focusApp(modelData); root.removeToast(modelData.key) }
        }
      }
    }
  }

  PanelWindow {
    visible: root.historyVisible
    color: "transparent"
    screen: root.historyScreen
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notification-center"
    anchors { top: true; right: true }
    margins { top: 8; right: Style.barEdgeMargin }
    implicitWidth: 420
    // Grow with the list up to a cap instead of a fixed tall sheet.
    implicitHeight: Math.max(180, Math.min(560, historyColumn.implicitHeight + historyHeader.implicitHeight + 14 * 2 + 21))

    Rectangle {
      anchors.fill: parent
      radius: Style.menuRadiusLg
      color: Style.menuBg
      border.color: Style.menuSep
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
          id: historyHeader
          Layout.fillWidth: true
          spacing: 8
          Text {
            text: "Notifications"
            font.family: Style.menuSans
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Style.menuInk
          }
          Rectangle {
            visible: root.historyCount > 0
            implicitWidth: countText.implicitWidth + 12
            implicitHeight: 18
            radius: 9
            color: Style.m3primaryContainer
            Text {
              id: countText
              anchors.centerIn: parent
              text: root.historyCount
              font.family: Style.menuSans
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: Style.menuInk
            }
          }
          Item { Layout.fillWidth: true }
          HeaderButton {
            glyph: root.dndEnabled ? "󰂛" : "󰂚"
            tone: root.dndEnabled ? Style.yellow : Style.menuInkDeep
            onClicked: root.toggleDnd()
          }
          HeaderButton {
            glyph: "󰆴"
            tone: Style.menuInkDeep
            onClicked: root.clearHistory()
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Style.menuSep }

        Flickable {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          contentHeight: historyColumn.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          ColumnLayout {
            id: historyColumn
            width: parent.width
            spacing: 8

            Column {
              visible: root.history.length === 0
              Layout.alignment: Qt.AlignHCenter
              Layout.topMargin: 28
              spacing: 6
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dndEnabled ? "󰂛" : "󰂚"
                font.family: Style.fontFamily
                font.pixelSize: 26
                color: Style.menuInkMuted
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dndEnabled ? "Do not disturb is on" : "No notifications"
                font.family: Style.menuSans
                font.pixelSize: 12
                color: Style.menuInkDeep
              }
            }

            Repeater {
              model: root.history
              delegate: ColumnLayout {
                required property var modelData
                required property int index
                readonly property string day: root.dayLabel(modelData.ts)
                Layout.fillWidth: true
                spacing: 6

                Text {
                  visible: index === 0 || root.dayLabel(root.history[index - 1].ts) !== parent.day
                  Layout.topMargin: index === 0 ? 0 : 6
                  text: parent.day
                  font.family: Style.menuSans
                  font.pixelSize: 11
                  font.weight: Font.DemiBold
                  color: Style.menuInkMuted
                }

                NotificationCard {
                  Layout.fillWidth: true
                  entry: modelData
                  compact: true
                  timeout: false
                  onDismiss: root.history = root.history.filter(item => item.key !== modelData.key)
                  onActivated: { root.focusApp(modelData); root.historyVisible = false }
                }
              }
            }
          }
        }
      }
    }
  }

  component HeaderButton: MouseArea {
    id: hb
    property string glyph: ""
    property color tone: Style.menuInkDeep
    implicitWidth: 28
    implicitHeight: 28
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: hb.containsMouse ? Style.m3stateHover : "transparent"
    }
    Text {
      anchors.centerIn: parent
      text: hb.glyph
      font.family: Style.fontFamily
      font.pixelSize: 15
      color: hb.tone
    }
  }

  // Quiet card: hairline border, urgency as a slim left strip (critical also
  // tints the border), app name demoted to the meta line next to the time.
  component NotificationCard: Rectangle {
    id: card

    property var entry: null
    property bool compact: false
    property bool timeout: false
    readonly property color accent: root.urgencyColor(entry ? entry.urgency : 1)
    readonly property bool critical: !!entry && entry.urgency === 2
    signal dismiss()
    signal activated()

    color: card.compact ? Style.m3container : Style.menuBg
    radius: Style.menuRadiusMd
    border.color: card.critical ? Qt.alpha(Style.red, 0.55) : Style.menuSep
    border.width: 1
    implicitHeight: cardBody.implicitHeight + 22
    clip: true

    Timer {
      interval: card.critical ? 9000 : 6000
      running: card.timeout
      repeat: false
      onTriggered: card.dismiss()
    }

    // Under the row, so the close button (declared later) still wins its clicks.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: (mouse) => mouse.button === Qt.RightButton ? card.dismiss() : card.activated()
    }

    Rectangle {
      anchors {
        left: parent.left
        top: parent.top
        bottom: parent.bottom
        topMargin: 10
        bottomMargin: 10
        leftMargin: 5
      }
      width: 3
      radius: 2
      color: card.accent
      opacity: card.entry && card.entry.urgency === 0 ? 0.5 : 1
    }

    RowLayout {
      id: cardBody
      anchors.fill: parent
      anchors.margins: 11
      anchors.leftMargin: 16
      spacing: 12

      Rectangle {
        Layout.preferredWidth: 36
        Layout.preferredHeight: 36
        Layout.alignment: Qt.AlignTop
        radius: Style.menuRadiusMd - 2
        color: Style.menuControlBg

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
        spacing: 2

        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          Text {
            text: card.entry ? (card.entry.appName || "Notification") : ""
            textFormat: Text.PlainText
            font.family: Style.menuSans
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Style.menuInkDeep
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Text {
            text: card.entry ? card.entry.time : ""
            font.family: Style.menuSans
            font.pixelSize: 11
            color: Style.menuInkMuted
          }
        }

        Text {
          text: card.entry ? card.entry.summary : ""
          visible: text.length > 0
          textFormat: Text.PlainText
          font.family: Style.menuSans
          font.pixelSize: 13
          font.weight: Font.DemiBold
          color: Style.menuInk
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Text {
          text: card.entry ? card.entry.body : ""
          visible: text.length > 0
          textFormat: Text.PlainText
          font.family: Style.menuSans
          font.pixelSize: 12
          color: Style.menuInkDeep
          wrapMode: Text.Wrap
          elide: Text.ElideRight
          maximumLineCount: card.compact ? 3 : 2
          Layout.fillWidth: true
        }
      }

      MouseArea {
        id: closeMa
        Layout.preferredWidth: 22
        Layout.preferredHeight: 22
        Layout.alignment: Qt.AlignTop
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.dismiss()

        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: closeMa.containsMouse ? Style.m3stateHover : "transparent"
        }
        Text {
          anchors.centerIn: parent
          text: "󰅖"
          font.family: Style.fontFamily
          font.pixelSize: 13
          color: closeMa.containsMouse ? Style.red : Style.menuInkMuted
        }
      }
    }
  }
}
