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
      // App-requested lifetime (Quickshell: seconds; <= 0 = server default).
      expire: Number(n.expireTimeout) || 0,
      ts: Date.now(),
      time: Qt.formatTime(new Date(), "HH:mm")
    }
  }

  // Upstream relative times; clockTick re-evaluates them every 10 s while a card is on screen.
  property int clockTick: 0
  Timer { interval: 10000; repeat: true; running: root.historyVisible || root.toasts.length > 0; onTriggered: root.clockTick++ }
  function relTime(ts, _tick) {
    const d = new Date(ts || 0), sec = (Date.now() - d) / 1000
    if (sec < 60) return "now"
    if (sec < 3600) return Math.floor(sec / 60) + " min ago"
    return Qt.formatTime(d, "HH:mm")  // day headers in the history say which day
  }

  // History grouped per day by app (upstream NotificationManager): groups keep the order of their
  // newest entry; a group with several shows the newest card until expanded.
  property var expandedGroups: ({})
  readonly property var historyGroups: {
    const out = [], idx = {}
    for (const e of root.history) {
      const day = root.dayLabel(e.ts), app = e.appName || e.desktopEntry || "Notification"
      const k = day + "|" + app
      if (idx[k] === undefined) { idx[k] = out.length; out.push({ key: k, day: day, app: app, items: [] }) }
      out[idx[k]].items.push(e)
    }
    return out
  }
  function toggleGroup(k) {
    const g = Object.assign({}, root.expandedGroups)
    if (g[k]) delete g[k]
    else g[k] = true
    root.expandedGroups = g
  }
  function dismissGroup(group) {
    const keys = group.items.map(e => e.key)
    root.history = root.history.filter(e => keys.indexOf(e.key) < 0)
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
  Timer { id: toastLinger; interval: 260 }
  onToastsChanged: if (root.toasts.length === 0) toastLinger.restart()

  property var lastEntry: null
  function handleNotification(n) {
    const entry = snapshot(n)
    // Burst guard (upstream): the same notification again within 100 ms is a duplicate; different
    // ones arriving together are all kept.
    const prev = root.lastEntry
    root.lastEntry = entry
    if (prev && entry.ts - prev.ts < 100 && entry.appName === prev.appName
      && entry.summary === prev.summary && entry.body === prev.body) return
    addHistory(entry)
    toastScreen = focusedScreen()
    if (!dndEnabled || entry.urgency === 2) {
      addToast(entry)
      Quickshell.execDetached([root.binDir + "/asahi-notification-sound"])
    }
  }

  // The bell click that ends the focus grab would reopen the sheet right away: ignore it.
  property real grabClosedAt: 0
  function toggleHistory() {
    if (!historyVisible && Date.now() - grabClosedAt < 300) return
    historyScreen = focusedScreen()
    historyVisible = !historyVisible
  }
  // Every open/close (bell, Esc, click outside, card click) marks the history seen.
  onHistoryVisibleChanged: {
    lastSeen = Date.now()
    if (!historyVisible) armGrab.armed = false
  }

  function clearHistory() {
    root.history = []
    root.toasts = []
  }

  function toggleDnd() {
    dndEnabled = !dndEnabled
  }

  // Keys (Super+comma / Super+Shift+comma) dismiss popups only: they used to delete the saved
  // history too (the newest entry, or all of it), which lost it silently. Clearing it is the
  // sheet's trash button (clearHistory / IPC `clear`).
  function dismissOne() {
    if (root.toasts.length > 0) root.removeToast(root.toasts[0].key)
  }

  function dismissAll() {
    root.toasts = []
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
      root.history = root.history.concat(saved.history || []).slice(0, root.maxHistory)
      // Only after the merge: loading must not write the file back (a second instance or a
      // config reload re-saving on load could race a write and persist a short history).
      root.historyLoaded = true
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
    // Top-centre under the bar, dropping out of the notch (the sheet is top-right, so they never
    // overlap). Stays mapped 260 ms after the last one goes so its leave animation plays.
    visible: root.toasts.length > 0 || toastLinger.running
    color: "transparent"
    screen: root.toastScreen
    // Normal + zone 0: sit below the bar's exclusive zone (notch floor).
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    // Only `top` anchored: layer-shell centres it horizontally (under the notch on the laptop).
    anchors { top: true }
    margins { top: 6 }
    implicitWidth: 380
    implicitHeight: Math.max(1, toastList.contentHeight)

    // ScriptModel diffs root.toasts by object: existing cards (and their timers) survive a new
    // toast arriving; enter / leave / shift animate (upstream NotificationPopups transitions).
    ListView {
      id: toastList
      anchors.fill: parent
      interactive: false
      spacing: 8
      model: ScriptModel { values: root.toasts }
      delegate: NotificationCard {
        required property var modelData
        width: toastList.width
        entry: modelData
        compact: false
        timeout: true
        onDismiss: root.removeToast(modelData.key)
        onActivated: { root.focusApp(modelData); root.removeToast(modelData.key) }
      }
      add: Transition {
        NumberAnimation { property: "fade"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { property: "y"; from: -24; duration: 250; easing.type: Easing.OutCubic }
      }
      remove: Transition {
        NumberAnimation { property: "fade"; to: 0; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { property: "y"; to: -16; duration: 200; easing.type: Easing.OutCubic }
      }
      displaced: Transition { NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic } }
    }
  }

  PanelWindow {
    id: historySheet
    visible: root.historyVisible
    color: "transparent"
    screen: root.historyScreen
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // Esc / click outside closes (serpantinum popups); the bar's bell toggles as before.
    // Armed 200 ms after opening: a bar popup / calendar unmapping at the same moment (they close
    // when the sheet opens) would otherwise clear this grab too and shut the sheet at once.
    Timer { id: armGrab; property bool armed: false; interval: 200; running: root.historyVisible && !armed; onTriggered: armed = true }
    HyprlandFocusGrab {
      windows: [historySheet]
      active: root.historyVisible && armGrab.armed
      onCleared: { root.grabClosedAt = Date.now(); root.historyVisible = false }
    }
    Shortcut {
      enabled: root.historyVisible
      sequences: ["Escape"]
      onActivated: root.historyVisible = false
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notification-center"
    // Under the bell, the bar's last chip (right edge = barEdgeMargin).
    anchors { top: true; right: true }
    margins { top: 8; right: Style.barEdgeMargin }
    implicitWidth: 420
    // Grow with the list up to a cap instead of a fixed tall sheet.
    implicitHeight: Math.max(180, Math.min(560, historyColumn.implicitHeight + historyHeader.implicitHeight + 14 * 2 + 21))

    Rectangle {
      anchors.fill: parent
      radius: Style.menuRadiusLg
      color: Style.menuBg
      border.color: Style.popupBorder
      border.width: Style.popupBorderWidth

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
          // Clearing everything takes two clicks (the first arms it red for 3 s): one stray click on
          // the trash used to wipe the whole saved history.
          Text {
            visible: clearArm.running
            text: "Clear all?"
            font.family: Style.menuSans
            font.pixelSize: 11
            color: Style.red
          }
          HeaderButton {
            glyph: "󰆴"
            tone: clearArm.running ? Style.red : Style.menuInkDeep
            onClicked: {
              if (!clearArm.running) { clearArm.restart(); return }
              clearArm.stop()
              root.clearHistory()
            }
            Timer { id: clearArm; interval: 3000 }
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
              model: root.historyGroups
              delegate: ColumnLayout {
                id: group
                required property var modelData
                required property int index
                readonly property bool many: modelData.items.length > 1
                readonly property bool open: !many || !!root.expandedGroups[modelData.key]
                Layout.fillWidth: true
                spacing: 6

                Text {
                  visible: group.index === 0 || root.historyGroups[group.index - 1].day !== group.modelData.day
                  Layout.topMargin: group.index === 0 ? 0 : 6
                  text: group.modelData.day
                  font.family: Style.menuSans
                  font.pixelSize: 11
                  font.weight: Font.DemiBold
                  color: Style.menuInkMuted
                }

                // Group header (2+ from one app): name, count, expand / collapse, clear the group.
                RowLayout {
                  visible: group.many
                  Layout.fillWidth: true
                  Layout.leftMargin: 4
                  spacing: 6
                  Text {
                    text: group.modelData.app
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    Layout.maximumWidth: 220
                    font.family: Style.menuSans
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Style.menuInkDeep
                  }
                  Rectangle {
                    implicitWidth: groupCount.implicitWidth + 10
                    implicitHeight: 16
                    radius: 8
                    color: Style.m3primaryContainer
                    Text {
                      id: groupCount
                      anchors.centerIn: parent
                      text: group.modelData.items.length
                      font.family: Style.menuSans
                      font.pixelSize: 10
                      font.weight: Font.DemiBold
                      color: Style.menuInk
                    }
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    text: group.open ? "Show less" : "Show all"
                    font.family: Style.menuSans
                    font.pixelSize: 11
                    color: toggleMa.containsMouse ? Style.menuSeal : Style.menuInkMuted
                    MouseArea { id: toggleMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleGroup(group.modelData.key) }
                  }
                  Text {
                    text: "󰅖"
                    font.family: Style.fontFamily
                    font.pixelSize: 12
                    color: clearMa.containsMouse ? Style.red : Style.menuInkMuted
                    MouseArea { id: clearMa; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.dismissGroup(group.modelData) }
                  }
                }

                Repeater {
                  model: group.open ? group.modelData.items : group.modelData.items.slice(0, 1)
                  NotificationCard {
                    required property var modelData
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
    // Toasts float over windows: the popup outline; history cards sit inside the sheet: hairline.
    border.color: card.critical ? Qt.alpha(Style.red, 0.55) : card.compact ? Style.menuSep : Style.popupBorder
    border.width: card.compact ? 1 : Style.popupBorderWidth
    implicitHeight: cardBody.implicitHeight + 22
    clip: true

    // Upstream timeout rules: critical stays until dismissed; the app's expire time wins over 6 s;
    // the timer pauses while the pointer is on the card or it is being dragged.
    readonly property int lifeMs: {
      if (!card.entry || card.critical) return 0
      const e = Number(card.entry.expire) || 0
      return e > 0 ? Math.round(e > 600 ? e : e * 1000) : 6000
    }
    Timer {
      interval: Math.max(1000, card.lifeMs)
      running: card.timeout && card.lifeMs > 0 && !cardMa.containsMouse && !cardMa.dragging
      onTriggered: card.dismiss()
    }

    // Swipe sideways to dismiss (upstream: lock after 6 px, dismiss past 18 % of the width).
    property real dragX: 0
    property real fade: 1  // list enter / leave transitions animate this, not opacity (keeps the binding)
    transform: Translate { x: card.dragX }
    opacity: card.fade * Math.max(0, 1 - Math.abs(card.dragX) / (card.width * 0.75))
    scale: cardMa.pressed && !cardMa.dragging ? 0.98 : 1
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }
    NumberAnimation { id: dragBack; target: card; property: "dragX"; to: 0; duration: 200; easing.type: Easing.OutCubic }
    SequentialAnimation {
      id: dragOut
      property real to: 0
      NumberAnimation { target: card; property: "dragX"; to: dragOut.to; duration: 200; easing.type: Easing.OutQuad }
      ScriptAction { script: card.dismiss() }
    }

    // Critical: slow red pulse instead of a static border only.
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      visible: card.critical
      color: Qt.alpha(Style.red, 0.08)
      SequentialAnimation on opacity {
        // Toasts animate while shown; history cards only while the sheet is open (a card inside the
        // hidden sheet window stays `visible` and would pulse forever).
        running: card.critical && (card.timeout || root.historyVisible)
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 0.4; duration: 1800; easing.type: Easing.InOutSine }
        NumberAnimation { from: 0.4; to: 1; duration: 1800; easing.type: Easing.InOutSine }
      }
    }

    // Under the row, so the close button (declared later) still wins its clicks.
    MouseArea {
      id: cardMa
      property real startX: 0
      property bool dragging: false
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
      onPressed: (mouse) => { startX = mouse.x; dragging = false; preventStealing = false }
      onPositionChanged: (mouse) => {
        if (!pressed || mouse.buttons !== Qt.LeftButton) return
        if (!dragging && Math.abs(mouse.x - startX) > 6) { dragging = true; preventStealing = true }
        if (dragging) card.dragX = mouse.x - startX
      }
      onReleased: {
        if (!dragging) return
        if (Math.abs(card.dragX) > card.width * 0.18) { dragOut.to = (card.dragX > 0 ? 1.2 : -1.2) * card.width; dragOut.start() }
        else dragBack.start()
      }
      onClicked: (mouse) => {
        if (dragging) { dragging = false; return }
        mouse.button === Qt.RightButton ? card.dismiss() : card.activated()
      }
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
            text: card.entry ? root.relTime(card.entry.ts, root.clockTick) : ""
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
