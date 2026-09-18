import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Bluetooth
import "../../menu" as Menu
import "../../../"
import "../quick_models.js" as QuickModels
import "../launcher_layout.js" as LauncherGeom

// Bluetooth pane: adapter, paired and discovered devices.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, launcherGeom, quickMode, quickPaneKey, binDir, ...).
Item {
  property var root
  id: quickBtRoot
  anchors.fill: parent
  property bool btOn: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
  property var btDevs: (Bluetooth.devices && Bluetooth.devices.values) ? Bluetooth.devices.values : []
  property string btAlias: "Bluetooth"
  property string btTooltip: ""
  property int btConnectedCount: 0
  property string btUpdated: ""
  property bool btScanRequested: false
  readonly property bool btDiscovering: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false

  // Address -> "connecting" | "disconnecting" | "forgetting" (omarchy's
  // pendingActions). Keeps the panel open and responsive while BlueZ
  // catches up instead of closing the launcher on every action.
  property var btPending: ({})
  function setBtPending(mac, action) {
    if (!mac) return
    quickBtRoot.btPending = QuickModels.withPendingAction(quickBtRoot.btPending, mac, action)
    if (action) btPendingTimeout.restart()
  }
  function settleBtPending() {
    const next = QuickModels.settledPendingActions(quickBtRoot.btPending, quickBtRoot.btDevs)
    if (next) quickBtRoot.btPending = next
  }

  // Primitives-only rows grouped omarchy-style (Connected / Paired /
  // Discovered). Holding live Device QObjects in model data segfaults
  // quickshell when BlueZ churn (discovery timeouts, unpair) destroys an
  // object while a delegate is still incubating; actions go through
  // bluetoothctl by address instead.
  readonly property var btRows: {
    const tick = quickBtRoot.btUpdated  // periodic refresh picks up device property changes
    const pending = quickBtRoot.btPending || {}
    const devs = quickBtRoot.btDevs || []
    const connected = []; const known = []; const discovered = []
    for (let i = 0; i < devs.length; i++) {
      const d = devs[i]
      if (!d) continue
      const label = String(d.name || d.deviceName || "").trim()
      if (!label) continue
      if (/^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(label)) continue
      if (/^[0-9a-f-]{32,36}$/i.test(label)) continue
      const row = {
        address: d.address || "",
        label: label,
        connected: !!d.connected,
        paired: !!(d.paired || d.bonded || d.trusted),
        batteryAvailable: !!d.batteryAvailable,
        battery: Math.round((d.battery || 0) * 100),
        icon: String(d.icon || ""),
        pending: QuickModels.pendingAction(pending, d.address || ""),
        section: ""
      }
      if (row.connected) connected.push(row)
      else if (row.paired) known.push(row)
      else discovered.push(row)
    }
    const byLabel = function(a, b) { return a.label.localeCompare(b.label) }
    connected.sort(byLabel); known.sort(byLabel); discovered.sort(byLabel)
    const rows = []
    const pushGroup = function(list, title) {
      for (let i = 0; i < list.length; i++) {
        list[i].section = i === 0 ? title : ""
        rows.push(list[i])
      }
    }
    pushGroup(connected, "Connected")
    pushGroup(known, "Paired")
    if (quickBtRoot.btScanRequested || quickBtRoot.btDiscovering) pushGroup(discovered, "Discovered")
    return rows
  }

  function btNotify(title, body) {
    Quickshell.execDetached(["notify-send", "-a", "Bluetooth", title, body])
  }
  function openBtManager() {
    root.execAndClose([root.binDir + "/asahi-launch-bluetooth"])
  }
  // All actions stay open (omarchy behavior): the row shows a pending
  // state and settles in place once BlueZ reports the transition.
  function btConnect(mac, name) {
    if (!mac || btActionProc.running) return
    quickBtRoot.setBtPending(mac, "connecting")
    btActionProc.action = "connect"
    btActionProc.targetMac = mac
    btActionProc.targetName = name || "device"
    btActionProc.command = ["timeout", "20s", "bluetoothctl", "connect", mac]
    btActionProc.running = true
  }
  function btDisconnect(mac, name) {
    if (!mac || btActionProc.running) return
    quickBtRoot.setBtPending(mac, "disconnecting")
    btActionProc.action = "disconnect"
    btActionProc.targetMac = mac
    btActionProc.targetName = name || "device"
    btActionProc.command = ["timeout", "10s", "bluetoothctl", "disconnect", mac]
    btActionProc.running = true
  }
  function btPair(mac, name) {
    if (!mac || btActionProc.running) return
    quickBtRoot.setBtPending(mac, "connecting")
    btActionProc.action = "pair"
    btActionProc.targetMac = mac
    btActionProc.targetName = name || "device"
    // Stay open: the row should move from Discovered to Paired in place.
    btActionProc.command = ["bash", "-c",
      root.shQuote(root.binDir + "/asahi-bluetooth-power") + " on >/dev/null 2>&1 || true; " +
      "timeout 20s bluetoothctl pair " + root.shQuote(mac) +
      " && bluetoothctl trust " + root.shQuote(mac) +
      " && timeout 20s bluetoothctl connect " + root.shQuote(mac)]
    btActionProc.running = true
  }
  function btForget(mac, name) {
    if (!mac || btActionProc.running) return
    quickBtRoot.setBtPending(mac, "forgetting")
    btActionProc.action = "forget"
    btActionProc.targetMac = mac
    btActionProc.targetName = name || "device"
    // Disconnect first so a connected device can be removed cleanly.
    btActionProc.command = ["bash", "-c",
      "timeout 10s bluetoothctl disconnect " + root.shQuote(mac) + " >/dev/null 2>&1; " +
      "timeout 10s bluetoothctl remove " + root.shQuote(mac)]
    btActionProc.running = true
  }
  function toggleScan() {
    const a = Bluetooth.defaultAdapter
    if (!a) return
    quickBtRoot.btScanRequested = !quickBtRoot.btScanRequested
    a.discovering = quickBtRoot.btScanRequested
  }

  Process {
    id: btStat
    command: ["sh", "-c", "bluetoothctl show 2>/dev/null || true"]
    stdout: StdioCollector { onStreamFinished: quickBtRoot.btOn = (text || "").indexOf("Powered: yes") !== -1 }
  }
  Process {
    id: btJsonProc
    command: [root.binDir + "/asahi-bluetooth"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse((text || "").trim() || "{}")
          quickBtRoot.btTooltip = d.tooltip || ""
          const lines = (d.tooltip || "").split("\n")
          quickBtRoot.btAlias = lines[0] || "Bluetooth"
          const m = (lines[1] || "").match(/(\d+)\s+connected/)
          quickBtRoot.btConnectedCount = m ? parseInt(m[1], 10) : 0
          quickBtRoot.btUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
        } catch (_) {}
      }
    }
  }
  Process {
    id: btActionProc
    property string action: ""
    property string targetMac: ""
    property string targetName: ""
    onExited: function(code) {
      // On failure clear the pending row state right away (success settles
      // via the live device list) and notify — the panel stays open so the
      // user can just retry; no jump to an external manager.
      if (code !== 0) quickBtRoot.setBtPending(btActionProc.targetMac, "")
      if (btActionProc.action === "connect") {
        quickBtRoot.btNotify(code === 0 ? "Connected" : "Could not connect", btActionProc.targetName)
      } else if (btActionProc.action === "disconnect" && code === 0) {
        quickBtRoot.btNotify("Disconnected", btActionProc.targetName)
      } else if (btActionProc.action === "pair") {
        quickBtRoot.btNotify(code === 0 ? "Paired" : "Pairing failed", btActionProc.targetName)
      } else if (btActionProc.action === "forget") {
        quickBtRoot.btNotify(code === 0 ? "Forgotten" : "Could not forget", btActionProc.targetName)
      }
      btDelay.restart()
      if (!btJsonProc.running) btJsonProc.running = true
    }
  }
  Timer { id: btDelay; interval: 500; onTriggered: { if (btStat) btStat.running = true; if (btJsonProc) btJsonProc.running = true } }
  // Pending-state failsafe (omarchy's pendingTimeout): if BlueZ never
  // reports the transition, stop showing spinner text after 20s.
  Timer { id: btPendingTimeout; interval: 20000; onTriggered: quickBtRoot.btPending = ({}) }
  // Fast settle poll while any action is in flight so rows flip from
  // "Connecting…" to their real state promptly.
  Timer {
    interval: 800
    repeat: true
    running: Object.keys(quickBtRoot.btPending || {}).length > 0
    onTriggered: {
      quickBtRoot.settleBtPending()
      quickBtRoot.btUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
    }
  }
  Timer {
    interval: 4000
    running: root.quickMode && root.quickPaneKey === "bluetooth"
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!btJsonProc.running) btJsonProc.running = true
      if (!btStat.running) btStat.running = true
    }
  }
  // BlueZ discovery sessions time out on their own; keep the scan alive
  // while it is requested (omarchy's discoveryRetry).
  Timer {
    interval: 4000
    repeat: true
    running: quickBtRoot.btScanRequested && quickBtRoot.btOn && !quickBtRoot.btDiscovering
    onTriggered: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = true }
  }
  Component.onDestruction: {
    if (quickBtRoot.btScanRequested && Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering)
      Bluetooth.defaultAdapter.discovering = false
  }
  function refreshBt() {
    if (btStat && !btStat.running) btStat.running = true
    if (btJsonProc && !btJsonProc.running) btJsonProc.running = true
  }
  function toggleBt() {
    const next = quickBtRoot.btOn ? "off" : "on"
    Quickshell.execDetached([root.binDir + "/asahi-bluetooth-power", next])
    quickBtRoot.btOn = !quickBtRoot.btOn
    btDelay.restart()
  }

  Component.onCompleted: quickBtRoot.refreshBt()

  // Nerd glyph by BlueZ device icon name (caelestia getBluetoothIcon).
  function devGlyph(icon, connected) {
    const i = String(icon || "")
    if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0) return "󰋋"
    if (i.indexOf("keyboard") >= 0) return "󰌌"
    if (i.indexOf("mouse") >= 0) return "󰍽"
    if (i.indexOf("phone") >= 0) return "󰄜"
    if (i.indexOf("audio") >= 0 || i.indexOf("speaker") >= 0) return "󰓃"
    if (i.indexOf("computer") >= 0) return "󰍹"
    if (i.indexOf("gaming") >= 0) return "󰊗"
    if (i.indexOf("watch") >= 0) return "󰖉"
    return connected ? "󰂱" : "󰂯"
  }

  // ---- M3 building blocks (caelestia look) ----
  component Pill: Rectangle {
    property string icon
    property string label
    property color bg: Style.m3containerHigh
    property color fg: Style.m3onSurface
    signal clicked()
    implicitWidth: pillRow.implicitWidth + 24
    implicitHeight: 32
    radius: Style.menuRadiusFull
    color: pillMa.containsMouse ? Qt.lighter(bg, 1.15) : bg
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: 6
      Text {
        visible: !!parent.parent.icon; text: parent.parent.icon; color: parent.parent.fg
        font.family: quickBtRoot.root.uiFont; font.pixelSize: quickBtRoot.root.fontPx(12); anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: parent.parent.label; color: parent.parent.fg; font.weight: Font.Medium
        font.family: quickBtRoot.root.uiSans; font.pixelSize: quickBtRoot.root.fontPx(10); anchors.verticalCenter: parent.verticalCenter
      }
    }
    MouseArea { id: pillMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }

  component Chip: Rectangle {
    property string icon
    property string label
    property color bg: Style.m3secondaryContainer
    property color fg: Style.m3onSurface
    implicitWidth: chipRow.implicitWidth + 18
    implicitHeight: 24
    radius: Style.menuRadiusFull
    color: bg
    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: 5
      Text {
        text: parent.parent.icon; color: parent.parent.fg
        font.family: quickBtRoot.root.uiFont; font.pixelSize: quickBtRoot.root.fontPx(10); anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: parent.parent.label; color: parent.parent.fg; font.weight: Font.Medium
        font.family: quickBtRoot.root.uiSans; font.pixelSize: quickBtRoot.root.fontPx(9); anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // Round link / link_off button: filled m3primary while connected (caelestia).
  component LinkBtn: Rectangle {
    property bool active: false
    property bool busy: false
    signal clicked()
    width: 32; height: 32; radius: 16
    color: active ? Style.m3primary : (linkMa.containsMouse && !busy ? Style.m3stateHover : "transparent")
    opacity: busy ? 0.6 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Text {
      anchors.centerIn: parent
      text: parent.busy ? "󰔟" : (parent.active ? "󰌷" : "󰌸")
      color: parent.active ? Style.m3onPrimary : Style.m3onSurface
      font.family: quickBtRoot.root.uiFont; font.pixelSize: quickBtRoot.root.fontPx(14)
    }
    MouseArea {
      id: linkMa; anchors.fill: parent; hoverEnabled: true
      cursorShape: parent.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
      onClicked: if (!parent.busy) parent.clicked()
    }
  }

  component IconBtn: Rectangle {
    property string icon
    property color tone: Style.m3onSurfaceVariant
    property color hot: Style.m3onSurface
    signal clicked()
    width: 30; height: 30; radius: 15
    color: iconMa.containsMouse ? Style.m3stateHover : "transparent"
    Text {
      anchors.centerIn: parent; text: parent.icon; color: iconMa.containsMouse ? parent.hot : parent.tone
      font.family: quickBtRoot.root.uiFont; font.pixelSize: quickBtRoot.root.fontPx(13)
    }
    MouseArea { id: iconMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }

  // M3 switch: 34x18 track, 14 knob, m3primary when on.
  component M3Switch: Rectangle {
    property bool checked: false
    signal toggled()
    width: 34; height: 18; radius: 9
    color: checked ? Style.m3primary : Style.m3containerHigh
    border.width: checked ? 0 : 1
    border.color: Style.m3outline
    Behavior on color { ColorAnimation { duration: 160 } }
    Rectangle {
      width: 14; height: 14; radius: 7
      x: parent.checked ? parent.width - width - 2 : 2
      anchors.verticalCenter: parent.verticalCenter
      color: parent.checked ? Style.m3onPrimary : Style.m3outline
      Behavior on x { Menu.MenuAnim {} }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.toggled() }
  }

  component Secondary: Text {
    color: Style.m3onSurfaceVariant
    font.family: quickBtRoot.root.uiSans
    font.pixelSize: quickBtRoot.root.fontPx(10)
    elide: Text.ElideRight
  }

  ColumnLayout {
    id: btLayout
    anchors.fill: parent
    spacing: 12

    // Adapter card: glyph tile, alias + state, Enabled switch, Scan pill, manager.
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: btHead.implicitHeight + 28
      radius: Style.menuPanelRadius
      color: Style.m3container
      RowLayout {
        id: btHead
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14
        Rectangle {
          width: 46; height: 46; radius: Style.menuRadiusLg
          color: quickBtRoot.btOn ? Style.m3primaryContainer : Style.m3containerHigh
          Behavior on color { ColorAnimation { duration: 160 } }
          Text {
            anchors.centerIn: parent; text: quickBtRoot.btOn ? "󰂯" : "󰂲"
            color: quickBtRoot.btOn ? Style.m3primary : Style.m3onSurfaceVariant; font.family: root.uiFont; font.pixelSize: 26
          }
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text {
            Layout.fillWidth: true; text: quickBtRoot.btAlias; color: Style.m3onSurface
            font.family: root.uiSans; font.pixelSize: root.fontPx(17); font.weight: Font.DemiBold; elide: Text.ElideRight
          }
          Secondary {
            Layout.fillWidth: true
            text: {
              if (!quickBtRoot.btOn) return "Bluetooth is off"
              const extra = (quickBtRoot.btTooltip || "").split("\n").slice(2).join(" · ").trim()
              const n = quickBtRoot.btConnectedCount
              const head = n === 0 ? "No devices connected" : (n + (n === 1 ? " device" : " devices") + " connected")
              return extra ? head + " · " + extra : head
            }
            font.pixelSize: root.fontPx(11)
          }
        }
        Pill {
          visible: quickBtRoot.btOn
          icon: quickBtRoot.btScanRequested ? "󰔟" : "󰐷"
          label: quickBtRoot.btScanRequested ? "Scanning…" : "Scan"
          bg: quickBtRoot.btScanRequested ? Style.m3primaryContainer : Style.m3containerHigh
          fg: quickBtRoot.btScanRequested ? Style.m3primary : Style.m3onSurface
          onClicked: quickBtRoot.toggleScan()
        }
        Row {
          spacing: 8
          Secondary { text: "Enabled"; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
          M3Switch { checked: quickBtRoot.btOn; onToggled: quickBtRoot.toggleBt(); anchors.verticalCenter: parent.verticalCenter }
        }
      }
    }

    // Device list card: Connected / Paired / Discovered rows.
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Style.menuRadiusLg
      color: Style.m3container
      clip: true

      Flickable {
        anchors.fill: parent
        anchors.margins: 8
        clip: true
        flickableDirection: Flickable.VerticalFlick
        contentHeight: btCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: Menu.MenuScrollBar {}
        Column {
          id: btCol
          width: parent.width
          spacing: 2
          Repeater {
            model: quickBtRoot.btRows || []
            delegate: Column {
              id: btDelegate
              required property var modelData
              readonly property bool busy: (modelData.pending || "") !== ""
              width: parent.width
              spacing: 2
              Secondary {
                visible: !!btDelegate.modelData.section
                text: btDelegate.modelData.section || ""
                font.pixelSize: root.fontPx(9)
                font.weight: Font.Medium
                leftPadding: 10; topPadding: 8; bottomPadding: 2
              }
              Rectangle {
                id: btRow
                width: btDelegate.width
                height: 48
                radius: Style.menuRadiusMd
                color: btd.containsMouse ? Style.m3stateHover : "transparent"
                opacity: btDelegate.busy ? 0.65 : 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 120 } }
                MouseArea { id: btd; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10; anchors.rightMargin: 8
                  spacing: 10
                  Text {
                    Layout.preferredWidth: 26
                    text: quickBtRoot.devGlyph(btDelegate.modelData.icon, btDelegate.modelData.connected)
                    color: btDelegate.modelData.connected ? Style.m3primary : Style.m3onSurfaceVariant
                    font.family: root.uiFont; font.pixelSize: root.fontPx(16)
                    horizontalAlignment: Text.AlignHCenter
                  }
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                      Layout.fillWidth: true
                      text: btDelegate.modelData.label
                      color: Style.m3onSurface
                      font.family: root.uiSans; font.pixelSize: root.fontPx(11)
                      font.weight: btDelegate.modelData.connected ? Font.DemiBold : Font.Medium
                      elide: Text.ElideRight
                    }
                    Secondary {
                      Layout.fillWidth: true
                      text: {
                        const p = btDelegate.modelData.pending || ""
                        if (p === "connecting") return "Connecting…"
                        if (p === "disconnecting") return "Disconnecting…"
                        if (p === "forgetting") return "Forgetting…"
                        if (btDelegate.modelData.connected) return "Connected"
                        return btDelegate.modelData.paired ? "Paired" : btDelegate.modelData.address
                      }
                      color: btDelegate.busy ? Style.m3primary : (btDelegate.modelData.connected ? Style.green : Style.m3onSurfaceVariant)
                      font.pixelSize: root.fontPx(9)
                    }
                  }
                  Chip {
                    visible: btDelegate.modelData.connected && btDelegate.modelData.batteryAvailable
                    icon: btDelegate.modelData.battery < 20 ? "󰁺" : "󰁹"
                    label: btDelegate.modelData.battery + "%"
                    bg: btDelegate.modelData.battery < 20 ? Qt.alpha(Style.red, 0.22) : Style.m3secondaryContainer
                  }
                  // Forget (omarchy's 'x'): only for remembered devices, hidden while an action is in flight.
                  IconBtn {
                    visible: btDelegate.modelData.paired && !btDelegate.busy
                    icon: "󰩹"
                    hot: Style.red
                    onClicked: quickBtRoot.btForget(btDelegate.modelData.address, btDelegate.modelData.label)
                  }
                  LinkBtn {
                    active: btDelegate.modelData.connected
                    busy: btDelegate.busy
                    onClicked: {
                      const dev = btDelegate.modelData
                      if (dev.connected) quickBtRoot.btDisconnect(dev.address, dev.label)
                      else if (dev.paired) quickBtRoot.btConnect(dev.address, dev.label)
                      else quickBtRoot.btPair(dev.address, dev.label)
                    }
                  }
                }
              }
            }
          }
          // Empty states.
          Column {
            visible: !quickBtRoot.btOn || !quickBtRoot.btRows || quickBtRoot.btRows.length === 0
            width: parent.width
            topPadding: 40
            spacing: 6
            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: !quickBtRoot.btOn ? "󰂲" : (quickBtRoot.btScanRequested ? "󰐷" : "󰂯")
              color: Style.m3outline; font.family: root.uiFont; font.pixelSize: root.fontPx(30)
            }
            Secondary {
              anchors.horizontalCenter: parent.horizontalCenter
              text: !quickBtRoot.btOn ? "Bluetooth is off"
                : (quickBtRoot.btScanRequested ? "Scanning for devices…" : "No devices. Tap Scan to discover.")
              font.pixelSize: root.fontPx(11)
            }
          }
        }
      }
    }

    // Footer: manager pill + updated stamp.
    RowLayout {
      Layout.fillWidth: true
      spacing: 12
      Pill {
        icon: "󰒓"; label: "Bluetooth manager"; bg: Style.m3primaryContainer; fg: Style.m3primary
        onClicked: quickBtRoot.openBtManager()
      }
      Item { Layout.fillWidth: true }
      Secondary { text: quickBtRoot.btUpdated ? ("updated " + quickBtRoot.btUpdated) : ""; font.pixelSize: root.fontPx(9) }
    }
  }
}
