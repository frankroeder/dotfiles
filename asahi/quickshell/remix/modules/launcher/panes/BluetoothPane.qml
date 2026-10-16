import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "../../menu" as Menu
import "../../../"
import "../../../services" as Services
import "../quick_models.js" as QuickModels
import "../../../services/bt_monitor.js" as BtModel
import "../../../services/bt_i18n.js" as I18n

// Bluetooth pane: adapter, connection map, devices (BlueZ + asahi-bluetooth-monitor: batteries over any
// connection, Logitech HID++ settings), settings (language, alerts, other devices, tooltip, access).
// Strings are bt_i18n keys (upstream's eight languages; the pane setting, else LC_ALL / LC_MESSAGES / LANG).
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
  property string btUpdated: ""
  property bool btScanRequested: false
  // Closing the launcher only hides this pane (the next open destroys it), so stop the scan here:
  // a scan left running holds the shared BCM4388 radio in inquiry (A2DP stutter).
  readonly property bool launcherShown: root ? root.shouldShow : false
  onLauncherShownChanged: if (!launcherShown) btScanRequested = false
  readonly property bool btDiscovering: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false

  // Monitor snapshot: the helper rescans every 10 s while this pane is up (60 s otherwise).
  readonly property var mon: Services.BtMonitor.snap
  Binding { target: Services.BtMonitor; property: "paneOpen"; value: quickBtRoot.launcherShown }
  // A Loader-destroyed pane does not restore the Binding: the helper would stay on its 10 s rescans.
  Component.onDestruction: Services.BtMonitor.paneOpen = false
  readonly property var mapLinks: BtModel.mapLinks(mon)
  readonly property bool logitechSeen: (mon.receivers || []).length > 0 || (mon.devices || []).some(d => !!d.wpid || !!d.denied)
  property bool settingsOpen: false
  property string expandedUid: ""
  // Forget needs a second click within 3 s (upstream "really forget").
  property string forgetArmed: ""

  readonly property string sysLang: Services.BtMonitor.sysLang
  readonly property string lang: Services.BtMonitor.lang
  function t(key, args) { return I18n.tr(quickBtRoot.lang, key, args) }
  function cap(s) { return s ? s.charAt(0).toUpperCase() + s.slice(1) : s }

  // Launcher Esc / Backspace hooks (true = handled): settings, then an open device, before the pane closes.
  function handleEscape() {
    if (settingsOpen) { settingsOpen = false; return true }
    if (expandedUid) {  // only a layer while it is on screen (its device may have gone offline)
      const shown = btRows.some(r => r.uid === expandedUid && BtModel.hasSettings(r.mon))
      expandedUid = ""
      if (shown) return true
    }
    return false
  }
  function handleBackspace() { return handleEscape() }

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

  // Primitives-only rows grouped omarchy-style (Connected / USB & receivers / Paired / Available).
  // Holding live Device QObjects in model data segfaults quickshell when BlueZ churn (discovery
  // timeouts, unpair) destroys an object while a delegate is still incubating; actions go through
  // bluetoothctl by address instead. Monitor devices merge in by address (bt_monitor.js paneRows).
  readonly property var btRows: {
    const tick = quickBtRoot.btUpdated  // periodic refresh picks up device property changes
    const pending = quickBtRoot.btPending || {}
    const devs = quickBtRoot.btDevs || []
    const bluez = []
    for (let i = 0; i < devs.length; i++) {
      const d = devs[i]
      if (!d) continue
      const label = String(d.name || d.deviceName || "").trim()
      if (!label) continue
      if (/^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(label)) continue
      if (/^[0-9a-f-]{32,36}$/i.test(label)) continue
      bluez.push({
        address: d.address || "",
        label: label,
        connected: !!d.connected,
        paired: !!(d.paired || d.bonded || d.trusted),
        batteryAvailable: !!d.batteryAvailable,
        battery: Math.round((d.battery || 0) * 100),
        icon: String(d.icon || ""),
        pending: QuickModels.pendingAction(pending, d.address || "")
      })
    }
    return BtModel.paneRows(bluez, quickBtRoot.mon, quickBtRoot.btScanRequested || quickBtRoot.btDiscovering)
  }

  function btNotify(titleKey, body) {
    Quickshell.execDetached(["notify-send", "-a", "Bluetooth", quickBtRoot.t(titleKey), body])
  }
  function openBtManager() {
    root.execAndClose([root.binDir + "/asahi-launch-bluetooth"])
  }
  // All actions stay open (omarchy behavior): the row shows a pending
  // state and settles in place once BlueZ reports the transition.
  function btConnect(mac, name, kind) {
    if (!mac || btActionProc.running) return
    quickBtRoot.setBtPending(mac, "connecting")
    btActionProc.action = "connect"
    btActionProc.targetMac = mac
    btActionProc.targetName = name || "device"
    btActionProc.targetAudio = kind === "headset" || kind === "speaker"
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
  function btPair(mac, name, kind) {
    if (!mac || btActionProc.running) return
    quickBtRoot.setBtPending(mac, "connecting")
    btActionProc.action = "pair"
    btActionProc.targetMac = mac
    btActionProc.targetName = name || "device"
    btActionProc.targetAudio = kind === "headset" || kind === "speaker"
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
  function armForget(mac, name) {
    if (quickBtRoot.forgetArmed !== mac) { quickBtRoot.forgetArmed = mac; forgetDisarm.restart(); return }
    quickBtRoot.forgetArmed = ""
    quickBtRoot.btForget(mac, name)
  }
  function toggleScan() { quickBtRoot.btScanRequested = !quickBtRoot.btScanRequested }

  // The discovery session lives as long as this bluetoothctl (BlueZ ends it with its client): no stop
  // call that quickshell could drop, and a closed launcher / destroyed pane / dead qs ends it too.
  readonly property bool scanWanted: btScanRequested && btOn  // a hidden launcher clears the request
  onScanWantedChanged: scanProc.running = scanWanted
  Process {
    id: scanProc
    command: ["setpriv", "--pdeathsig", "TERM", "bluetoothctl", "--timeout", "300", "scan", "on"]
    onExited: if (quickBtRoot.scanWanted) scanRetry.restart()
  }
  Timer { id: scanRetry; interval: 1000; onTriggered: scanProc.running = quickBtRoot.scanWanted }
  // With --timeout, bluetoothctl stays up when StartDiscovery fails (busy right after power-on): restart it.
  Timer {
    interval: 5000; repeat: true
    running: scanProc.running && !quickBtRoot.btDiscovering
    onTriggered: scanProc.running = false
  }

  // A headset that just connected becomes the output (upstream): its sink appears a moment after `connect`;
  // look for it by MAC (bluez_output.AA_BB_…) or name, 8 × 500 ms. WirePlumber persists the choice.
  function followAudio(mac, label) { audioTimer.mac = mac; audioTimer.label = label; audioTimer.tries = 8; audioTimer.restart() }
  Timer {
    id: audioTimer
    property string mac: ""
    property string label: ""
    property int tries: 0
    interval: 500
    repeat: true
    onTriggered: {
      const key = mac.replace(/:/g, "_").toUpperCase()
      const nodes = Pipewire.nodes ? Pipewire.nodes.values : []
      const sink = nodes.find(n => n && n.isSink && !n.isStream
        && (String(n.name || "").toUpperCase().indexOf(key) >= 0 || String(n.description || "") === label))
      if (sink) {
        if (Pipewire.defaultAudioSink !== sink) Pipewire.preferredDefaultAudioSink = sink
        stop()
      } else if (--tries <= 0) stop()
    }
  }

  Process {
    id: btActionProc
    property string action: ""
    property string targetMac: ""
    property string targetName: ""
    property bool targetAudio: false
    onExited: function(code) {
      // On failure clear the pending row state right away (success settles
      // via the live device list) and notify — the panel stays open so the
      // user can just retry; no jump to an external manager.
      if (code !== 0) quickBtRoot.setBtPending(btActionProc.targetMac, "")
      if (btActionProc.action === "connect") {
        quickBtRoot.btNotify(code === 0 ? "nfConnected" : "nfConnectFailed", btActionProc.targetName)
      } else if (btActionProc.action === "disconnect" && code === 0) {
        quickBtRoot.btNotify("nfDisconnected", btActionProc.targetName)
      } else if (btActionProc.action === "pair") {
        quickBtRoot.btNotify(code === 0 ? "nfPaired" : "nfPairFailed", btActionProc.targetName)
      } else if (btActionProc.action === "forget") {
        quickBtRoot.btNotify(code === 0 ? "nfForgotten" : "nfForgetFailed", btActionProc.targetName)
      }
      if (code === 0 && btActionProc.targetAudio && (btActionProc.action === "connect" || btActionProc.action === "pair"))
        quickBtRoot.followAudio(btActionProc.targetMac, btActionProc.targetName)
      btActionProc.targetAudio = false
      Services.BtMonitor.refresh()
    }
  }
  Timer { id: forgetDisarm; interval: 3000; onTriggered: quickBtRoot.forgetArmed = "" }
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
  // Row refresh tick (no fork: BlueZ properties are live, the monitor pushes its own snapshots).
  Timer {
    interval: 4000
    running: root.shouldShow && root.quickMode && root.quickPaneKey === "bluetooth"
    repeat: true
    triggeredOnStart: true
    onTriggered: quickBtRoot.btUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
  }
  function toggleBt() {
    if (btPowerProc.running) return
    const next = quickBtRoot.btOn ? "off" : "on"
    // Otherwise the scan restarts at the next power-on.
    if (next === "off") quickBtRoot.btScanRequested = false
    btPowerProc.target = next
    // A transient unit: a pane switch must not kill `off` between the BlueZ power-off and the rfkill block.
    btPowerProc.command = ["systemd-run", "--user", "--wait", "--quiet", "--collect", root.binDir + "/asahi-bluetooth-power", next]
    btPowerProc.running = true
  }
  Process {
    id: btPowerProc
    property string target: ""
  }

  function stateColor(state) {
    return state === "critical" ? Style.red : (state === "low" ? Style.orange : Style.m3onSurface)
  }
  function batteryBg(battery, state) {
    if (battery && battery.charging) return Qt.alpha(Style.green, 0.18)
    return state === "critical" ? Qt.alpha(Style.red, 0.22) : (state === "low" ? Qt.alpha(Style.orange, 0.22) : Style.m3secondaryContainer)
  }
  // "Bolt dongle · slot 2 · charging", "Bluetooth · no battery reading", "not connected", …
  function rowStatus(row) {
    const p = row.pending || ""
    if (quickBtRoot.forgetArmed && quickBtRoot.forgetArmed === row.address) return t("btReallyForget")
    if (p === "connecting") return t("btConnecting")
    if (p === "disconnecting") return t("btDisconnecting")
    if (p === "forgetting") return t("btForgetting")
    const m = row.mon
    const b = row.battery
    const parts = []
    if (row.wired) {
      parts.push(BtModel.connectionLabel(m, quickBtRoot.t))
      if (m && m.denied) parts.push(t("accessNeeded"))
      else if (!row.connected) parts.push(t("deviceOff"))
    } else if (row.connected) {
      parts.push(t("conn_bluetooth"))
      if (!b) parts.push(t("noBattery"))
    } else {
      parts.push(row.paired ? t("notConnected") : row.address)
    }
    if (row.connected && b && b.charging) parts.push(t("charging"))
    else if (row.connected && b && b.status === "full" && b.external_power) parts.push(t("charged"))
    return parts.join(" · ")
  }
  readonly property string headStatus: {
    if (btPowerBusy) return t(btPowerProc.target === "on" ? "turningOn" : "turningOff")
    if (!btOn) return t("btOffHint")
    if (!mon.updated) return t("looking")
    const known = btRows.filter(r => r.connected || r.paired || r.wired)
    const parts = [t("connectedOf", [known.filter(r => r.connected).length, known.length])]
    const nr = (mon.receivers || []).length
    if (nr) parts.push(I18n.trn(lang, "receiversN", nr, [nr]))
    const a = (mon.adapters || [])[0]
    if (a) parts.push(t(a.builtin ? "btBuiltin" : "btDongle") + (a.vendor ? " · " + a.vendor : ""))
    return parts.join(" · ")
  }
  // Second header line (upstream's hero detail): lowest battery, missing access.
  readonly property string headDetail: {
    const parts = []
    const low = mon.lowest
    if (low && low.percent < 100) parts.push(t("lowestBattery", [low.percent]) + " · " + low.name)
    if (mon.phase === "permission" || (mon.denied || []).length) parts.push(t("accessNeeded"))
    return parts.join(" · ")
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
  component Label: Text {
    color: Style.m3onSurface
    font.family: quickBtRoot.root.uiSans
    font.pixelSize: quickBtRoot.root.fontPx(10)
    font.weight: Font.Medium
    elide: Text.ElideRight
    textFormat: Text.PlainText
  }
  component Hint: Secondary {
    Layout.fillWidth: true
    font.pixelSize: quickBtRoot.root.fontPx(9)
    wrapMode: Text.WordWrap
    elide: Text.ElideNone
  }
  // Title + hint, a switch at the right (settings rows, HID++ toggles).
  component SwitchRow: RowLayout {
    id: sr
    property string title
    property string hint
    property bool checked
    signal toggled()
    Layout.fillWidth: true
    spacing: 10
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      Label { text: sr.title; Layout.fillWidth: true }
      Hint { text: sr.hint }
    }
    Menu.MenuSwitch { checked: sr.checked; onToggled: sr.toggled() }
  }
  // Section caption: the tracked caps used by SysPanel / recorder.
  component Caption: Secondary {
    font.pixelSize: quickBtRoot.root.fontPx(8)
    font.weight: Font.DemiBold
    font.letterSpacing: 1.2
    font.capitalization: Font.AllUppercase
    leftPadding: 10; topPadding: 8; bottomPadding: 4
  }

  // Logitech HID++ controls of one monitor device (helper `set`), upstream's card: title row, control, hint.
  // Sliders preview locally and send 300 ms after the last move.
  component HidSettings: ColumnLayout {
    id: hs
    required property var dev
    property int dpiPreview: -1
    property int thrPreview: -1
    readonly property int dpiShown: hs.dpiPreview >= 0 ? hs.dpiPreview : (hs.dev.dpi ? hs.dev.dpi.value : 0)
    readonly property int thrShown: hs.thrPreview >= 0 ? hs.thrPreview : ((hs.dev.smartshift && hs.dev.smartshift.threshold) || 10)
    readonly property string ssMode: hs.dev.smartshift ? hs.dev.smartshift.mode : ""
    onDevChanged: {
      if (!dpiCommit.running) hs.dpiPreview = -1
      if (!thrCommit.running) hs.thrPreview = -1
    }
    spacing: 4
    Timer { id: dpiCommit; interval: 300; onTriggered: Services.BtMonitor.setValue(hs.dev.id, "dpi", hs.dpiPreview) }
    Timer { id: thrCommit; interval: 300; onTriggered: Services.BtMonitor.setValue(hs.dev.id, "threshold", hs.thrPreview) }
    // Closing the settings within the debounce still sends the last move.
    Component.onDestruction: {
      if (dpiCommit.running) Services.BtMonitor.setValue(hs.dev.id, "dpi", hs.dpiPreview)
      if (thrCommit.running) Services.BtMonitor.setValue(hs.dev.id, "threshold", hs.thrPreview)
    }

    RowLayout {
      visible: !!hs.dev.dpi && hs.dev.dpi.max > hs.dev.dpi.min
      Layout.fillWidth: true
      spacing: 8
      Label { text: quickBtRoot.t("dpi"); Layout.fillWidth: true }
      Secondary { text: hs.dpiShown + (hs.dev.dpi && hs.dpiShown === hs.dev.dpi.default ? " · " + quickBtRoot.t("dpiDefault") : "") }
      Pill {
        visible: !!hs.dev.dpi && hs.dpiShown !== hs.dev.dpi.default
        label: quickBtRoot.cap(quickBtRoot.t("dpiDefault"))
        onClicked: { hs.dpiPreview = hs.dev.dpi.default; dpiCommit.restart() }
      }
    }
    Menu.MenuSlider {
      visible: !!hs.dev.dpi && hs.dev.dpi.max > hs.dev.dpi.min
      Layout.fillWidth: true
      Layout.bottomMargin: 6
      value: hs.dev.dpi ? BtModel.dpiFrac(hs.dev.dpi, hs.dpiShown) : 0
      onMoved: v => { hs.dpiPreview = BtModel.dpiAt(hs.dev.dpi, v); dpiCommit.restart() }
    }
    Label { visible: !!hs.dev.smartshift; text: quickBtRoot.t("wheelMode") }
    Row {
      visible: !!hs.dev.smartshift
      spacing: 6
      Repeater {
        model: ["smartshift", "ratchet", "freespin"]
        Pill {
          required property string modelData
          label: quickBtRoot.t(modelData)
          selected: hs.ssMode === modelData
          onClicked: Services.BtMonitor.setValue(hs.dev.id, "smartshift", modelData)
        }
      }
    }
    Hint { visible: hs.ssMode !== ""; text: hs.ssMode ? quickBtRoot.t(hs.ssMode + "Tip") : ""; Layout.bottomMargin: 6 }
    RowLayout {
      visible: hs.ssMode === "smartshift"
      Layout.fillWidth: true
      Label { text: quickBtRoot.t("sensitivity"); Layout.fillWidth: true }
      Secondary { text: String(hs.thrShown) }
    }
    Menu.MenuSlider {
      visible: hs.ssMode === "smartshift"
      Layout.fillWidth: true
      value: (hs.thrShown - 1) / 49
      onMoved: v => { hs.thrPreview = Math.round(1 + v * 49); thrCommit.restart() }
    }
    Hint { visible: hs.ssMode === "smartshift"; text: quickBtRoot.t("sensitivityHint"); Layout.bottomMargin: 6 }
    SwitchRow {
      visible: !!hs.dev.wheel
      title: quickBtRoot.t("natural"); hint: quickBtRoot.t("naturalHint")
      checked: !!hs.dev.wheel && hs.dev.wheel.invert
      onToggled: Services.BtMonitor.setValue(hs.dev.id, "invert", !checked)
    }
    SwitchRow {
      visible: !!hs.dev.wheel
      title: quickBtRoot.t("hires"); hint: quickBtRoot.t("hiresHint")
      checked: !!hs.dev.wheel && hs.dev.wheel.hires
      onToggled: Services.BtMonitor.setValue(hs.dev.id, "hires", !checked)
    }
    SwitchRow {
      visible: !!hs.dev.fnswap
      title: quickBtRoot.t("fnswap"); hint: quickBtRoot.t(checked ? "fnswapOn" : "fnswapOff")
      checked: !!hs.dev.fnswap && hs.dev.fnswap.on
      onToggled: Services.BtMonitor.setValue(hs.dev.id, "fnswap", !checked)
    }
  }

  ColumnLayout {
    id: btLayout
    anchors.fill: parent
    spacing: 12

    // Adapter card: glyph tile, alias + state, Scan pill, settings button, power switch.
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
            Layout.fillWidth: true; color: Style.m3onSurface
            text: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.name ? Bluetooth.defaultAdapter.name
              : (Bluetooth.defaultAdapter ? quickBtRoot.t("bluetooth") : quickBtRoot.t("btNoAdapter"))
            textFormat: Text.PlainText
            font.family: root.uiSans; font.pixelSize: root.fontPx(17); font.weight: Font.DemiBold; elide: Text.ElideRight
          }
          Secondary { Layout.fillWidth: true; text: quickBtRoot.headStatus; font.pixelSize: root.fontPx(11) }
          Secondary {
            Layout.fillWidth: true; visible: text !== ""; text: quickBtRoot.headDetail; font.pixelSize: root.fontPx(10)
            color: quickBtRoot.stateColor(Services.BtMonitor.alert.state)
          }
        }
        Pill {
          visible: quickBtRoot.btOn && !quickBtRoot.settingsOpen
          icon: quickBtRoot.btScanRequested ? "󰔟" : "󰐷"
          label: quickBtRoot.btScanRequested ? quickBtRoot.t("btScanningShort") : quickBtRoot.t("btScan")
          selected: quickBtRoot.btScanRequested
          onClicked: quickBtRoot.toggleScan()
        }
        IconBtn {
          icon: BtModel.GLYPH_COG
          bg: quickBtRoot.settingsOpen ? Style.m3primaryContainer : "transparent"
          tone: quickBtRoot.settingsOpen ? Style.m3primary : Style.m3onSurfaceVariant
          onClicked: quickBtRoot.settingsOpen = !quickBtRoot.settingsOpen
        }
        Row {
          spacing: 8
          Secondary {
            text: quickBtRoot.t(quickBtRoot.btOn ? "btOn" : "btOffState")
            font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter
          }
          Menu.MenuSwitch {
            anchors.verticalCenter: parent.verticalCenter
            checked: quickBtRoot.btOn; locked: quickBtRoot.btPowerBusy
            onToggled: quickBtRoot.toggleBt()
          }
        }
      }
    }

    // Main card: connection map + devices, or the settings.
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

          // ---- connection map: this PC → adapters / dongles / USB → devices ----
          // Solid lines are cables or built-in parts, dotted ones radio (upstream's map).
          Column {
            id: mapCol
            visible: !quickBtRoot.settingsOpen && quickBtRoot.mapLinks.length > 0
            width: parent.width
            readonly property int node: Math.round(root.fontPx(16) * 1.9)
            readonly property int indent: Math.round(node * 1.3)
            readonly property int labelW: Math.round(root.fontPx(10) * 12)
            readonly property color line: Qt.alpha(Style.m3onSurface, 0.25)
            topPadding: 6
            bottomPadding: 6
            leftPadding: 6

            Caption { text: quickBtRoot.t("connections"); leftPadding: 4; topPadding: 0 }
            // This PC
            Item {
              width: mapCol.width - mapCol.leftPadding
              height: mapCol.node + 8
              Rectangle {  // trunk start
                x: mapCol.node / 2 - 1; y: mapCol.node / 2; width: 2; height: parent.height - y
                color: mapCol.line
              }
              Rectangle {
                width: mapCol.node; height: mapCol.node; radius: width / 2
                color: Style.m3primaryContainer
                Text {
                  anchors.centerIn: parent; text: BtModel.GLYPH_LAPTOP
                  color: Style.m3primary; font.family: root.uiFont; font.pixelSize: root.fontPx(14)
                }
              }
              Column {
                x: mapCol.node + 10
                anchors.verticalCenter: parent.top
                anchors.verticalCenterOffset: mapCol.node / 2
                Text {
                  text: quickBtRoot.t("thisPc"); color: Style.m3onSurface
                  font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.DemiBold
                }
                Secondary { text: quickBtRoot.mon.host || ""; font.pixelSize: root.fontPx(9) }
              }
            }
            Repeater {
              model: quickBtRoot.mapLinks
              delegate: Item {
                id: linkItem
                required property var modelData
                required property int index
                readonly property bool last: index === quickBtRoot.mapLinks.length - 1
                readonly property bool wired: modelData.type === "usb"
                readonly property int mid: mapCol.node / 2 + 4
                readonly property int chipsX: mapCol.indent + mapCol.node + 10 + mapCol.labelW + 30
                width: mapCol.width - mapCol.leftPadding
                height: Math.max(mapCol.node, chipFlow.implicitHeight) + 8
                Rectangle {  // trunk
                  x: mapCol.node / 2 - 1; width: 2; height: linkItem.last ? linkItem.mid : linkItem.height
                  color: mapCol.line
                }
                Rectangle {  // branch: solid, accent while a device on it is online
                  x: mapCol.node / 2; y: linkItem.mid - 1; width: mapCol.indent - mapCol.node / 2; height: 2
                  color: linkItem.modelData.online ? Style.m3primary : mapCol.line
                }
                Rectangle {
                  x: mapCol.indent; y: 4
                  width: mapCol.node; height: mapCol.node; radius: Style.menuRadiusMd
                  color: linkItem.modelData.online ? Style.m3primaryContainer : Style.m3containerHigh
                  Text {
                    anchors.centerIn: parent
                    text: ({ bluetooth: BtModel.GLYPH_BT, receiver: BtModel.GLYPH_DONGLE, wireless: BtModel.GLYPH_WIFI })[linkItem.modelData.type]
                      || BtModel.GLYPH_USB
                    color: linkItem.modelData.online ? Style.m3primary : Style.m3onSurfaceVariant
                    font.family: root.uiFont; font.pixelSize: root.fontPx(14)
                  }
                  // Corner mark: built into this PC, or a USB stick.
                  Rectangle {
                    visible: linkItem.modelData.type === "bluetooth"
                    width: Math.round(mapCol.node * 0.5); height: width; radius: width / 2
                    x: parent.width - width * 0.7; y: parent.height - height * 0.7
                    color: Style.m3containerHigh
                    border.width: 1; border.color: Style.m3container
                    Text {
                      anchors.centerIn: parent
                      text: linkItem.modelData.builtin ? BtModel.GLYPH_LAPTOP : BtModel.GLYPH_DONGLE
                      color: Style.m3onSurfaceVariant; font.family: root.uiFont; font.pixelSize: root.fontPx(7)
                    }
                  }
                }
                Column {
                  x: mapCol.indent + mapCol.node + 10
                  width: mapCol.labelW
                  anchors.verticalCenter: parent.top
                  anchors.verticalCenterOffset: linkItem.mid
                  Text {
                    width: parent.width; color: Style.m3onSurface; elide: Text.ElideRight
                    text: quickBtRoot.t(linkItem.modelData.title) + (linkItem.modelData.n ? " " + linkItem.modelData.n : "")
                    font.family: root.uiSans; font.pixelSize: root.fontPx(10); font.weight: Font.DemiBold
                  }
                  Secondary {
                    width: parent.width; visible: text !== ""; font.pixelSize: root.fontPx(9)
                    text: linkItem.modelData.vendor || (linkItem.modelData.sub ? quickBtRoot.t(linkItem.modelData.sub, linkItem.modelData.subArgs) : "")
                    color: linkItem.modelData.denied ? Style.orange : Style.m3onSurfaceVariant
                  }
                }
                // Device link: a solid line for cables, four dots for radio.
                Rectangle {
                  visible: linkItem.wired && linkItem.modelData.devices.length > 0
                  x: linkItem.chipsX - 26; y: linkItem.mid - 1; width: 22; height: 2
                  color: linkItem.modelData.online ? Style.m3primary : mapCol.line
                }
                Row {
                  visible: !linkItem.wired && linkItem.modelData.devices.length > 0
                  x: linkItem.chipsX - 26; y: linkItem.mid - 1.5
                  spacing: 3
                  Repeater {
                    model: 4
                    Rectangle { width: 3; height: 3; radius: 1; color: linkItem.modelData.online ? Style.m3primary : mapCol.line }
                  }
                }
                Flow {
                  id: chipFlow
                  x: linkItem.chipsX; y: 4 + (mapCol.node - 28) / 2
                  width: Math.max(0, linkItem.width - linkItem.chipsX)
                  spacing: 6
                  Repeater {
                    model: linkItem.modelData.devices
                    Rectangle {
                      id: devChip
                      required property var modelData
                      implicitWidth: chipRow.implicitWidth + 20
                      implicitHeight: 28
                      radius: Style.menuRadiusFull
                      color: devChip.modelData.state !== "ok" && devChip.modelData.online
                        ? quickBtRoot.batteryBg(devChip.modelData.battery, devChip.modelData.state)
                        : (devChip.modelData.online ? Style.m3secondaryContainer : Style.m3containerHigh)
                      opacity: devChip.modelData.online ? 1 : 0.65
                      Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                          anchors.verticalCenter: parent.verticalCenter
                          text: BtModel.kindGlyph(devChip.modelData.kind, devChip.modelData.online)
                          color: Style.m3onSurface; font.family: root.uiFont; font.pixelSize: root.fontPx(11)
                        }
                        Text {
                          anchors.verticalCenter: parent.verticalCenter
                          width: Math.min(implicitWidth, root.fontPx(10) * 14)
                          text: devChip.modelData.name || quickBtRoot.t("unnamed"); textFormat: Text.PlainText; elide: Text.ElideRight
                          color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(10); font.weight: Font.Medium
                        }
                        Text {
                          anchors.verticalCenter: parent.verticalCenter
                          visible: text !== ""
                          text: !devChip.modelData.online ? quickBtRoot.t("deviceOff")
                            : (devChip.modelData.battery ? BtModel.batteryGlyph(devChip.modelData.battery) + " " + BtModel.batteryText(devChip.modelData.battery, quickBtRoot.t) : "")
                          color: devChip.modelData.battery && devChip.modelData.battery.charging ? Style.green : quickBtRoot.stateColor(devChip.modelData.state)
                          font.family: root.uiFont; font.pixelSize: root.fontPx(10)
                        }
                      }
                    }
                  }
                }
              }
            }
            Secondary { text: quickBtRoot.t("radioHint"); font.pixelSize: root.fontPx(8); leftPadding: 4; topPadding: 6 }
          }

          // ---- devices: Connected / USB & receivers / Paired / Available ----
          Column {
            id: btRowsCol
            visible: !quickBtRoot.settingsOpen
            width: parent.width
            spacing: 2
            Repeater {
              // Diffed by uid (address / monitor id): a JS-array model rebuilt every row on each refresh tick.
              model: ScriptModel { objectProp: "uid"; values: quickBtRoot.btRows }
              delegate: Column {
                id: btDelegate
                required property var modelData
                readonly property bool busy: (modelData.pending || "") !== ""
                readonly property bool hasSettings: BtModel.hasSettings(modelData.mon)
                readonly property bool settingsShown: quickBtRoot.expandedUid === modelData.uid && hasSettings
                width: parent.width
                spacing: 2
                Caption {
                  visible: !!btDelegate.modelData.section
                  text: btDelegate.modelData.section ? quickBtRoot.t(btDelegate.modelData.section) : ""
                }
                Rectangle {
                  id: btRow
                  width: btDelegate.width
                  height: Math.max(48, btText.implicitHeight + 16)
                  radius: Style.menuRadiusMd
                  color: btd.containsMouse || btDelegate.settingsShown ? Style.m3stateHover : "transparent"
                  opacity: btDelegate.busy ? 0.65 : 1
                  Behavior on color { ColorAnimation { duration: 120 } }
                  Behavior on opacity { NumberAnimation { duration: 120 } }
                  // Hover; a row with HID++ settings opens them on click (its buttons take their own clicks).
                  MouseArea {
                    id: btd; anchors.fill: parent; hoverEnabled: true
                    cursorShape: btDelegate.hasSettings ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (btDelegate.hasSettings)
                      quickBtRoot.expandedUid = btDelegate.settingsShown ? "" : btDelegate.modelData.uid
                  }

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
                        text: BtModel.kindGlyph(btDelegate.modelData.kind, btDelegate.modelData.connected)
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
                        text: btDelegate.modelData.label || quickBtRoot.t("unnamed")
                        color: Style.m3onSurface
                        font.family: root.uiSans; font.pixelSize: root.fontPx(11)
                        font.weight: btDelegate.modelData.connected ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                      }
                      Secondary {
                        Layout.fillWidth: true
                        text: quickBtRoot.rowStatus(btDelegate.modelData)
                        color: quickBtRoot.forgetArmed && quickBtRoot.forgetArmed === btDelegate.modelData.address ? Style.red
                          : (btDelegate.busy ? Style.m3primary : (btDelegate.modelData.connected ? Style.green : Style.m3onSurfaceVariant))
                        font.pixelSize: root.fontPx(9)
                      }
                    }
                    Chip {
                      visible: !!btDelegate.modelData.battery && btDelegate.modelData.connected
                      icon: BtModel.batteryGlyph(btDelegate.modelData.battery)
                      label: BtModel.batteryText(btDelegate.modelData.battery, quickBtRoot.t)
                      bg: quickBtRoot.batteryBg(btDelegate.modelData.battery, btDelegate.modelData.state)
                    }
                    // Logitech hidraw is root-only until the uaccess rule is in (pkexec).
                    Pill {
                      visible: !!btDelegate.modelData.mon && !!btDelegate.modelData.mon.denied
                      icon: "󰌋"
                      label: Services.BtMonitor.allowing ? quickBtRoot.t("waitingPassword") : quickBtRoot.t("allowAccess")
                      onClicked: Services.BtMonitor.allowAccess()
                    }
                    IconBtn {
                      visible: btDelegate.hasSettings
                      icon: btDelegate.settingsShown ? BtModel.GLYPH_CHEVRON_DOWN : BtModel.GLYPH_CHEVRON_RIGHT
                      onClicked: quickBtRoot.expandedUid = btDelegate.settingsShown ? "" : btDelegate.modelData.uid
                    }
                    // Forget (omarchy's 'x'): remembered devices only, a second click within 3 s.
                    IconBtn {
                      visible: btDelegate.modelData.paired && !btDelegate.busy
                      readonly property bool armed: quickBtRoot.forgetArmed === btDelegate.modelData.address
                      icon: "󰩹"
                      hot: Style.red
                      tone: armed ? Style.red : Style.m3onSurfaceVariant
                      bg: armed ? Qt.alpha(Style.red, 0.22) : "transparent"
                      onClicked: quickBtRoot.armForget(btDelegate.modelData.address, btDelegate.modelData.label)
                    }
                    LinkBtn {
                      visible: !btDelegate.modelData.wired && quickBtRoot.btOn  // connect needs the radio on
                      active: btDelegate.modelData.connected
                      busy: btDelegate.busy
                      onClicked: {
                        const dev = btDelegate.modelData
                        if (dev.connected) quickBtRoot.btDisconnect(dev.address, dev.label)
                        else if (dev.paired) quickBtRoot.btConnect(dev.address, dev.label, dev.kind)
                        else quickBtRoot.btPair(dev.address, dev.label, dev.kind)
                      }
                    }
                  }
                }
                // HID++ settings, one device open at a time.
                Loader {
                  active: btDelegate.settingsShown
                  visible: active
                  width: btDelegate.width
                  sourceComponent: Item {
                    implicitHeight: hidSettings.implicitHeight + 16
                    HidSettings {
                      id: hidSettings
                      dev: btDelegate.modelData.mon
                      anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                      anchors.leftMargin: Math.round(root.fontPx(16) * 1.9) + 20; anchors.rightMargin: 12; anchors.topMargin: 4
                    }
                  }
                }
              }
            }
          }
          // Empty / off state, centred in whatever the map and rows leave of the card.
          Item {
            visible: !quickBtRoot.settingsOpen && (!quickBtRoot.btOn || quickBtRoot.btRows.length === 0)
            width: parent.width
            height: Math.max(btEmpty.implicitHeight + 32, btFlick.height - btRowsCol.height - (mapCol.visible ? mapCol.height : 0) - 2 * btCol.spacing)
            Menu.MenuEmptyState {
              id: btEmpty
              anchors.centerIn: parent
              fontScale: root.uiFontScale
              iconFamily: root.uiFont
              fontFamily: root.uiSans
              glyph: !quickBtRoot.btOn ? "󰂲" : (quickBtRoot.btScanRequested ? "󰐷" : "󰂯")
              tint: quickBtRoot.btOn ? Style.m3primary : Style.m3onSurfaceVariant
              title: !quickBtRoot.btOn ? quickBtRoot.t("btOffHint")
                : quickBtRoot.t(quickBtRoot.btScanRequested ? "btScanning" : "nothingFound")
              detail: quickBtRoot.t(!quickBtRoot.btOn ? "offDetail" : (quickBtRoot.btScanRequested ? "pairHint" : "scanHint"))
              actionIcon: !quickBtRoot.btOn ? "󰂯" : "󰐷"
              actionLabel: !quickBtRoot.btOn ? quickBtRoot.t("btTurnOn") : (quickBtRoot.btScanRequested ? "" : quickBtRoot.t("btScan"))
              onAction: quickBtRoot.btOn ? quickBtRoot.toggleScan() : quickBtRoot.toggleBt()
            }
          }

          // ---- settings: language, alerts, other devices, tooltip, receiver access ----
          ColumnLayout {
            visible: quickBtRoot.settingsOpen
            width: parent.width
            spacing: 6
            RowLayout {
              Layout.fillWidth: true
              Layout.margins: 6
              Pill {
                icon: BtModel.GLYPH_BACK
                label: quickBtRoot.t("back")
                onClicked: quickBtRoot.settingsOpen = false
              }
              Secondary { text: quickBtRoot.t("backTip"); font.pixelSize: root.fontPx(9) }
              Item { Layout.fillWidth: true }
              Text {
                text: quickBtRoot.t("settings"); color: Style.m3onSurface
                font.family: root.uiSans; font.pixelSize: root.fontPx(12); font.weight: Font.DemiBold
              }
            }

            Caption { text: quickBtRoot.t("language") }
            Flow {
              Layout.fillWidth: true
              Layout.leftMargin: 10; Layout.rightMargin: 10
              spacing: 6
              Repeater {
                model: [{ code: "auto", name: quickBtRoot.t("systemLanguage", [I18n.languageName(quickBtRoot.sysLang)]) }].concat(I18n.LANGUAGES)
                Pill {
                  required property var modelData
                  label: modelData.name
                  selected: (quickBtRoot.mon.language || "auto") === modelData.code
                  onClicked: Services.BtMonitor.setOptions({ language: modelData.code })
                }
              }
            }

            Caption { text: quickBtRoot.t("alerts") }
            Hint { Layout.leftMargin: 10; Layout.rightMargin: 10; text: quickBtRoot.t("alertsHint") }
            Repeater {
              model: [["lowAt", [15, 20, 25, 30, 40, 50]], ["criticalAt", [5, 10, 15, 20]]]
              ColumnLayout {
                id: alertRow
                required property var modelData
                readonly property bool isLow: modelData[0] === "lowAt"
                readonly property int value: isLow ? (quickBtRoot.mon.low_at || 25) : (quickBtRoot.mon.critical_at || 10)
                Layout.fillWidth: true
                Layout.leftMargin: 10; Layout.rightMargin: 10
                spacing: 4
                Label { text: quickBtRoot.t(alertRow.modelData[0]) + " · " + quickBtRoot.t("atOrBelow", [alertRow.value]) }
                Row {
                  spacing: 6
                  Repeater {
                    model: alertRow.modelData[1]
                    Pill {
                      required property int modelData
                      visible: alertRow.isLow || modelData <= (quickBtRoot.mon.low_at || 25)
                      label: modelData + "%"
                      selected: alertRow.value === modelData
                      onClicked: alertRow.isLow
                        ? Services.BtMonitor.setThresholds(modelData, Math.min(quickBtRoot.mon.critical_at || 10, modelData))
                        : Services.BtMonitor.setThresholds(quickBtRoot.mon.low_at || 25, modelData)
                    }
                  }
                }
              }
            }

            Caption { text: quickBtRoot.t("devices") }
            SwitchRow {
              Layout.leftMargin: 10; Layout.rightMargin: 10
              title: quickBtRoot.t("otherDevices"); hint: quickBtRoot.t("otherDevicesHint")
              checked: quickBtRoot.mon.other_devices !== false
              onToggled: Services.BtMonitor.setOptions({ other_devices: !checked })
            }
            SwitchRow {
              Layout.leftMargin: 10; Layout.rightMargin: 10
              title: quickBtRoot.t("barTooltip"); hint: quickBtRoot.t("barTooltipHint")
              checked: !!quickBtRoot.mon.bar_tooltip
              onToggled: Services.BtMonitor.setOptions({ bar_tooltip: !checked })
            }

            Caption { visible: quickBtRoot.logitechSeen; text: quickBtRoot.t("access") }
            RowLayout {
              visible: quickBtRoot.logitechSeen
              Layout.fillWidth: true
              Layout.leftMargin: 10; Layout.rightMargin: 10
              spacing: 10
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                  text: (quickBtRoot.mon.denied || []).length ? quickBtRoot.t("accessMissing") : quickBtRoot.t("accessGranted")
                  color: (quickBtRoot.mon.denied || []).length ? Style.orange : Style.green
                }
                Hint { visible: (quickBtRoot.mon.denied || []).length > 0; text: quickBtRoot.t("setupText") }
              }
              Pill {
                visible: (quickBtRoot.mon.denied || []).length > 0
                icon: "󰌋"
                label: Services.BtMonitor.allowing ? quickBtRoot.t("waitingPassword") : quickBtRoot.t("allowAccess")
                bg: Style.m3primaryContainer; fg: Style.m3primary
                onClicked: Services.BtMonitor.allowAccess()
              }
            }

          }
        }
      }
    }

    // Footer: manager + refresh pills, helper message, updated stamp.
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Pill {
        icon: "󰒓"; label: quickBtRoot.t("btManager"); bg: Style.m3primaryContainer; fg: Style.m3primary
        onClicked: quickBtRoot.openBtManager()
      }
      Pill {
        icon: BtModel.GLYPH_REFRESH; label: quickBtRoot.t("refresh")
        onClicked: Services.BtMonitor.refresh()
      }
      Secondary {
        Layout.fillWidth: true
        leftPadding: 4
        text: quickBtRoot.mon.message_code ? quickBtRoot.t(quickBtRoot.mon.message_code, quickBtRoot.mon.message_args)
          : (quickBtRoot.mon.error ? quickBtRoot.t("error", [quickBtRoot.mon.error]) : "")
        color: Style.red
      }
      Secondary {
        text: quickBtRoot.mon.updated ? quickBtRoot.t("updatedAt", [Qt.formatTime(new Date(quickBtRoot.mon.updated * 1000), "HH:mm:ss")]) : ""
        font.pixelSize: root.fontPx(9)
      }
    }
  }
}
