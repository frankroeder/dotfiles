import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../../menu" as Menu
import "../../../"
import "../quick_models.js" as QuickModels

// Bluetooth pane: adapter, paired and discovered devices.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, launcherGeom, quickMode, quickPaneKey, binDir, ...).
Item {
  property var root
  id: quickBtRoot
  anchors.fill: parent
  // Live from BlueZ; never assigned (a `bluetoothctl show` poll and the optimistic toggle broke this binding).
  readonly property bool btOn: !!Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
  // A power toggle takes seconds (BlueZ confirms, then rfkill): the switch dims, the status says so.
  readonly property bool btPowerBusy: btPowerProc.running
  property var btDevs: (Bluetooth.devices && Bluetooth.devices.values) ? Bluetooth.devices.values : []
  property string btAlias: "Bluetooth"
  property string btTooltip: ""
  property int btConnectedCount: 0
  property string btUpdated: ""
  property bool btScanRequested: false
  // quickshell drops a stop sent before BlueZ confirmed the start: re-send it once a second, 3 times.
  property int btStopTries: 0
  // Closing the launcher only hides this pane (the next open destroys it), so stop the scan here:
  // a scan left running holds the shared BCM4388 radio in inquiry (A2DP stutter).
  readonly property bool launcherShown: root ? root.shouldShow : false
  onLauncherShownChanged: if (!launcherShown && btScanRequested) stopScan()
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
    // Stay open (the row moves to Paired in place). A transient unit: a tile switch destroys the pane
    // and kills its Process, which would cut the chain after `pair` (never trusted / connected).
    btActionProc.command = ["systemd-run", "--user", "--wait", "--quiet", "--collect", "bash", "-c",
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
    // Disconnect first; a transient unit so `remove` still runs if the pane goes away.
    btActionProc.command = ["systemd-run", "--user", "--wait", "--quiet", "--collect", "bash", "-c",
      "timeout 10s bluetoothctl disconnect " + root.shQuote(mac) + " >/dev/null 2>&1; " +
      "timeout 10s bluetoothctl remove " + root.shQuote(mac)]
    btActionProc.running = true
  }
  function toggleScan() {
    const a = Bluetooth.defaultAdapter
    if (!a) return
    if (quickBtRoot.btScanRequested) { quickBtRoot.stopScan(); return }
    quickBtRoot.btScanRequested = true
    a.discovering = true
  }
  function stopScan() {
    quickBtRoot.btScanRequested = false
    quickBtRoot.btStopTries = 3
    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = false
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
  Timer { id: btDelay; interval: 500; onTriggered: if (!btJsonProc.running) btJsonProc.running = true }
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
    running: root.shouldShow && root.quickMode && root.quickPaneKey === "bluetooth"
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!btJsonProc.running) btJsonProc.running = true
  }
  // BlueZ discovery sessions time out on their own; keep the scan alive
  // while it is requested (omarchy's discoveryRetry).
  Timer {
    interval: 4000
    repeat: true
    running: quickBtRoot.btScanRequested && quickBtRoot.btOn && !quickBtRoot.btDiscovering
    onTriggered: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = true }
  }
  Timer {
    interval: 1000
    repeat: true
    running: quickBtRoot.btStopTries > 0
    onTriggered: {
      quickBtRoot.btStopTries--
      if (!quickBtRoot.btScanRequested && quickBtRoot.btDiscovering && Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = false
    }
  }
  // Stop also while a retry is pending: BlueZ may have dropped the first stop.
  Component.onDestruction: {
    if ((quickBtRoot.btScanRequested || quickBtRoot.btStopTries > 0) && Bluetooth.defaultAdapter)
      Bluetooth.defaultAdapter.discovering = false
  }
  function toggleBt() {
    if (btPowerProc.running) return
    const next = quickBtRoot.btOn ? "off" : "on"
    // Otherwise the keep-alive timer restarts the scan at the next power-on.
    if (next === "off" && quickBtRoot.btScanRequested) quickBtRoot.stopScan()
    btPowerProc.target = next
    // A transient unit: a pane switch must not kill `off` between the BlueZ power-off and the rfkill block.
    btPowerProc.command = ["systemd-run", "--user", "--wait", "--quiet", "--collect", root.binDir + "/asahi-bluetooth-power", next]
    btPowerProc.running = true
  }
  Process {
    id: btPowerProc
    property string target: ""
    onExited: btDelay.restart()
  }

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

  // ---- M3 building blocks (shared menu widgets) ----
  component Pill: Menu.MenuPill { fontScale: quickBtRoot.root.uiFontScale }
  component Chip: Menu.MenuChip { fontScale: quickBtRoot.root.uiFontScale }
  component IconBtn: Menu.MenuIconBtn { fontScale: quickBtRoot.root.uiFontScale }
  component LinkBtn: Menu.MenuLinkBtn { fontScale: quickBtRoot.root.uiFontScale }

  component Secondary: Text {
    color: Style.m3onSurfaceVariant
    font.family: quickBtRoot.root.uiSans
    font.pixelSize: quickBtRoot.root.fontPx(10)
    elide: Text.ElideRight
    textFormat: Text.PlainText  // device names
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
              if (quickBtRoot.btPowerBusy) return btPowerProc.target === "on" ? "Turning on…" : "Turning off…"
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
          selected: quickBtRoot.btScanRequested
          onClicked: quickBtRoot.toggleScan()
        }
        Row {
          spacing: 8
          Secondary { text: "Enabled"; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
          Menu.MenuSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: quickBtRoot.btOn; locked: quickBtRoot.btPowerBusy
            onToggled: quickBtRoot.toggleBt()
          }
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
        id: btFlick
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
          Column {
            id: btRowsCol
            width: parent.width
            spacing: 2
            Repeater {
              // Diffed by address: a JS-array model rebuilt every row on each refresh tick.
              model: ScriptModel { objectProp: "address"; values: quickBtRoot.btRows }
              delegate: Column {
                id: btDelegate
                required property var modelData
                readonly property bool busy: (modelData.pending || "") !== ""
                width: parent.width
                spacing: 2
                // Section caption: the tracked caps used by SysPanel / recorder.
                Secondary {
                  visible: !!btDelegate.modelData.section
                  text: btDelegate.modelData.section || ""
                  font.pixelSize: root.fontPx(8)
                  font.weight: Font.DemiBold
                  font.letterSpacing: 1.2
                  font.capitalization: Font.AllUppercase
                  leftPadding: 10; topPadding: 8; bottomPadding: 4
                }
                Rectangle {
                  id: btRow
                  width: btDelegate.width
                  height: Math.max(48, btText.implicitHeight + 16)
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
                    // Glyph tile, same as the recorder / battery fact rows.
                    Rectangle {
                      implicitWidth: Math.round(root.fontPx(16) * 1.9); implicitHeight: implicitWidth
                      radius: Style.menuRadiusMd
                      color: btDelegate.modelData.connected ? Style.m3primaryContainer : Style.m3containerHigh
                      Text {
                        anchors.centerIn: parent
                        text: quickBtRoot.devGlyph(btDelegate.modelData.icon, btDelegate.modelData.connected)
                        color: btDelegate.modelData.connected ? Style.m3primary : Style.m3onSurfaceVariant
                        font.family: root.uiFont; font.pixelSize: root.fontPx(14)
                      }
                    }
                    ColumnLayout {
                      id: btText
                      Layout.fillWidth: true
                      spacing: 0
                      Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
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
          }
          // Empty / off state, centred in whatever the rows leave of the card.
          Item {
            visible: !quickBtRoot.btOn || !quickBtRoot.btRows || quickBtRoot.btRows.length === 0
            width: parent.width
            height: Math.max(btEmpty.implicitHeight + 32, btFlick.height - btRowsCol.height - btCol.spacing)
            Menu.MenuEmptyState {
              id: btEmpty
              anchors.centerIn: parent
              fontScale: root.uiFontScale
              iconFamily: root.uiFont
              fontFamily: root.uiSans
              glyph: !quickBtRoot.btOn ? "󰂲" : (quickBtRoot.btScanRequested ? "󰐷" : "󰂯")
              tint: quickBtRoot.btOn ? Style.m3primary : Style.m3onSurfaceVariant
              title: !quickBtRoot.btOn ? "Bluetooth is off"
                : (quickBtRoot.btScanRequested ? "Scanning for devices…" : "No devices yet")
              detail: !quickBtRoot.btOn ? "Paired devices reconnect once it is back on."
                : (quickBtRoot.btScanRequested ? "Put the device in pairing mode." : "Scan to discover devices nearby.")
              actionIcon: !quickBtRoot.btOn ? "󰂯" : "󰐷"
              actionLabel: !quickBtRoot.btOn ? "Turn on" : (quickBtRoot.btScanRequested ? "" : "Scan")
              onAction: quickBtRoot.btOn ? quickBtRoot.toggleScan() : quickBtRoot.toggleBt()
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
