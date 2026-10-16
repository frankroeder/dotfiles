import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../menu" as Menu
import "../../../"
import "../quick_models.js" as QuickModels
// Qualified on purpose: shell.qml loads the launcher by Loader source, so qs never scans this directory and a bare
// sibling type (LanDevices) is "not a type" in the live shell (an offscreen file: harness hides that).
import "." as Panes

// Network pane: Wi-Fi / LAN / VPN state and controls, network list, tools.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, launcherGeom, quickMode, quickPaneKey, binDir, ...).
Item {
  property var root
  id: quickNetworkRoot
  anchors.fill: parent
  // full port of network from old (wifi enable/scan/list/conn + tooltip/ssid, eth toggle, refresh, state/procs; compressed)
  property var wifiNetworks: []
  // Diffed by ssid: a reassigned JS-array model resets the ListView and
  // jumped the scrolled list back to the top whenever a network appeared.
  ScriptModel { id: wifiNetworksModel; objectProp: "ssid"; values: quickNetworkRoot.wifiNetworks || [] }
  property bool wifiEnabled: true
  property string currentWifiSsid: ""
  property bool wifiScanned: false
  // False until the first asahi-network answer: show "Checking…" instead of
  // flashing "No network" / "Not connected" for a frame.
  property bool wifiChecked: false
  property bool wifiScanning: false
  property string wifiDevice: ""
  property string wifiTooltip: ""
  property string ethDevice: ""
  property string ethState: ""
  property string ethConnection: ""
  property bool ethConnected: false
  property var ethDevices: []
  property bool showPasswordPrompt: false
  property string pendingSsid: ""
  property string passwordError: ""
  property string connectingSsid: ""

  // NetworkManager VPN / WireGuard profiles. TUHH is NM-openconnect
  // (`tuhhvpn` → `nmcli --ask connection up TUHH-VPN`).
  readonly property string vpnTuhhScript: Quickshell.env("HOME") + "/.dotfiles/bin/Linux/tuhhvpn"
  property var vpnProfiles: []
  property var vpnTargets: []
  property var vpnExternal: []
  property var vpnTools: ({ openconnect: false, wireguard: false, openvpn: false, vpnc: false })
  property string vpnSummary: "No profiles"
  property string vpnPublicIp: ""
  property string vpnStatus: ""
  property string vpnError: ""
  property bool vpnBusy: false
  property var vpnPending: null
  property string vpnStage: ""
  property string vpnIpKey: ""
  property var vpnLastConns: []
  property var vpnLastDetails: ({})

  // Saved wifi profile names (known-network grouping, omarchy-style).
  property var savedWifi: ({})

  // Live throughput of the active device + connection quality (rolling
  // router/internet ping, packet loss) while the panel is open.
  property real netRxRate: 0
  property real netTxRate: 0
  property real prevRxBytes: -1
  property real prevTxBytes: -1
  property real prevSampleMs: 0
  property string statsDevice: ""
  property var routerPings: []
  property var netPings: []

  // Devices on this LAN (asahi-lan watch, idea: uBruckhaus/omarchy-wlan-monitor): one collector while the Devices tab is
  // shown (it pings a trusted network once on start, never in the background), a JSON line per change; edits (trust,
  // rename, pin, grouping) go back as JSON lines on its stdin.
  property string netTab: "networks"  // networks | devices
  // The last tab survives closing the pane (the grouping already lives in lan.json).
  FileView {
    id: tabFile
    path: Quickshell.env("HOME") + "/.local/state/asahi/network-tab"
    blockLoading: true
    printErrors: false
    onLoaded: {
      const t = tabFile.text().trim()
      if (t === "devices") quickNetworkRoot.netTab = t
    }
  }
  onNetTabChanged: if (tabFile.text().trim() !== netTab) tabFile.setText(netTab)
  property var lan: ({})
  function lanCmd(cmd) {
    if (lanProc.running) lanProc.write((typeof cmd === "string" ? cmd : JSON.stringify(cmd)) + "\n")
  }
  // Launcher Esc: the Devices layers (rename, open row, search) first.
  function handleEscape() { return quickNetworkRoot.netTab === "devices" && lanDevices.handleEscape() }
  Process {
    id: lanProc
    // pdeathsig: the collector (it shares port 5353 with avahi) dies with qs.
    command: ["setpriv", "--pdeathsig", "TERM", root.binDir + "/asahi-lan", "watch"]
    running: quickNetworkRoot.live && quickNetworkRoot.netTab === "devices"
    stdinEnabled: true
    stdout: SplitParser { onRead: line => quickNetworkRoot.lan = JSON.parse(line) }
  }

  function pingAvg(samples) {
    let total = 0, count = 0
    for (let i = 0; i < samples.length; i++) {
      if (samples[i] !== null) { total += samples[i]; count++ }
    }
    return count > 0 ? total / count : -1
  }
  function fmtPing(ms) {
    if (ms < 0) return "--"
    return ms.toFixed(ms > 0 && ms < 10 ? 1 : 0) + " ms"
  }
  function pingLoss(samples) {
    if (samples.length === 0) return "--"
    let lost = 0
    for (let i = 0; i < samples.length; i++) if (samples[i] === null) lost++
    return Math.round(lost * 100 / samples.length) + "%"
  }
  function sampleThroughput() {
    const dev = quickNetworkRoot.ethConnected ? quickNetworkRoot.ethDevice : quickNetworkRoot.wifiDevice
    if (!dev || throughputProc.running) return
    if (dev !== quickNetworkRoot.statsDevice) {
      quickNetworkRoot.statsDevice = dev
      quickNetworkRoot.prevSampleMs = 0
    }
    throughputProc.command = ["cat",
      "/sys/class/net/" + dev + "/statistics/rx_bytes",
      "/sys/class/net/" + dev + "/statistics/tx_bytes"]
    throughputProc.running = true
  }

  function notifyNet(title, body) {
    Quickshell.execDetached(["notify-send", "-a", "Network", title, body])
  }
  function rescanWifi() { quickNetworkRoot.scanWifi(true) }
  function disconnectWifi() {
    if (!quickNetworkRoot.wifiDevice) return
    Quickshell.execDetached(["nmcli", "device", "disconnect", quickNetworkRoot.wifiDevice])
    quickNetworkRoot.currentWifiSsid = ""
    quickNetworkRoot.wifiQrPath = ""
    Qt.callLater(quickNetworkRoot.scanWifi)
  }
  // asahi-speedtest: ~15 s of curl against speed.cloudflare.com.
  property string speedResult: ""
  function runSpeedtest() {
    if (speedProc.running) return
    quickNetworkRoot.speedResult = "Measuring download, upload and latency…"
    speedProc.running = true
  }
  Process {
    id: speedProc
    command: [root.binDir + "/asahi-speedtest"]
    stdout: StdioCollector { onStreamFinished: if (text.trim()) quickNetworkRoot.speedResult = text.trim() }
    onExited: function(code) { if (code !== 0) quickNetworkRoot.speedResult = "Speed test failed (offline?)" }
  }
  // Join-QR for the active network (asahi-wifi-qr → PNG in XDG_RUNTIME_DIR).
  property string wifiQrPath: ""
  property string wifiQrError: ""
  function toggleWifiQr() {
    if (quickNetworkRoot.wifiQrPath) { quickNetworkRoot.wifiQrPath = ""; return }
    if (wifiQrProc.running) return
    quickNetworkRoot.wifiQrError = ""
    wifiQrProc.running = true
  }
  Process {
    id: wifiQrProc
    command: [root.binDir + "/asahi-wifi-qr"]
    stdout: StdioCollector { onStreamFinished: if (text.trim()) quickNetworkRoot.wifiQrPath = "file://" + text.trim() + "?" + Date.now() }
    stderr: StdioCollector { onStreamFinished: if (text.trim()) quickNetworkRoot.wifiQrError = text.trim().replace(/^asahi-wifi-qr: /, "") }
  }
  // asahi-wifi-band pins the profile to 2.4/5 GHz (band-steering flaps). Cycles auto → 5 → 2.4.
  property string wifiBand: ""
  onCurrentWifiSsidChanged: refreshBand()
  function refreshBand() {
    if (!quickNetworkRoot.currentWifiSsid) { quickNetworkRoot.wifiBand = ""; return }
    if (!bandProc.running) bandProc.running = true
  }
  function cycleBand() {
    if (bandSetProc.running) return
    const next = ({ "auto": "5", "5": "2.4" })[quickNetworkRoot.wifiBand] || "auto"
    // A transient unit: destroying the pane mid-switch must not kill the script before its revert.
    bandSetProc.command = ["systemd-run", "--user", "--wait", "--quiet", "--collect",
      root.binDir + "/asahi-wifi-band", next]
    bandSetProc.running = true
  }
  Process {
    id: bandProc
    command: [root.binDir + "/asahi-wifi-band", "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        quickNetworkRoot.wifiBand = text.trim() ? JSON.parse(text).band : ""
      }
    }
  }
  Process {
    id: bandSetProc
    onExited: function(code) {
      if (code !== 0) quickNetworkRoot.notifyNet("Wi-Fi band", "Switch failed; kept the previous band")
      quickNetworkRoot.refreshBand()
      Qt.callLater(quickNetworkRoot.scanWifi)
    }
  }
  // Optimistic toggle with a settle window: while radioSettle runs, the
  // periodic power poll must not overwrite the button state (nmcli reports
  // the OLD radio state for a moment, which made the button flip-flop),
  // and no wifi rescans fire until the radio has actually switched.
  function toggleWifi() {
    const turningOn = !quickNetworkRoot.wifiEnabled
    quickNetworkRoot.wifiEnabled = turningOn
    if (!turningOn) {
      quickNetworkRoot.wifiNetworks = []
      quickNetworkRoot.currentWifiSsid = ""
      quickNetworkRoot.wifiScanning = false
    }
    radioSettle.stop()
    radioProc.command = ["nmcli", "radio", "wifi", turningOn ? "on" : "off"]
    radioProc.running = true
  }
  Process {
    id: radioProc
    onExited: radioSettle.restart()
  }
  Timer {
    id: radioSettle
    interval: 1500
    onTriggered: {
      if (quickNetworkRoot.wifiEnabled) quickNetworkRoot.scanWifi()
      else if (!wifiPowerCheck.running) wifiPowerCheck.running = true
    }
  }
  function toggleEth() {
    if (quickNetworkRoot.ethConnected) Quickshell.execDetached(["nmcli", "device", "disconnect", quickNetworkRoot.ethDevice])
    else Quickshell.execDetached(["nmcli", "device", "connect", quickNetworkRoot.ethDevice])
    Qt.callLater(function() { ethCheck.running = true })
  }
  function disconnectSsid(ssid) {
    Quickshell.execDetached(["nmcli", "con", "down", "id", ssid])
    quickNetworkRoot.currentWifiSsid = ""
    Qt.callLater(quickNetworkRoot.scanWifi)
  }
  // Forget a saved profile in place (omarchy's 'x'); the row drops from
  // "Known networks" on the next scan.
  function forgetSsid(ssid) {
    if (!ssid) return
    forgetProc.targetSsid = ssid
    forgetProc.command = ["nmcli", "connection", "delete", "id", ssid]
    forgetProc.running = true
  }
  function applyVpnProfiles(connections, details) {
    quickNetworkRoot.vpnLastConns = connections || []
    quickNetworkRoot.vpnLastDetails = details || {}
    const merged = QuickModels.mergeVpnDetails(connections, details || {})
    const runnable = QuickModels.filterRunnableProfiles(merged, quickNetworkRoot.vpnTools)
    quickNetworkRoot.vpnProfiles = runnable
    let targets = QuickModels.nmTargets(runnable)
    let hasTuhh = false
    for (let i = 0; i < targets.length; i++) {
      if ((targets[i].gateway || "").indexOf("tuhh.de") !== -1 || targets[i].label === "TUHH-VPN")
        hasTuhh = true
    }
    if (quickNetworkRoot.vpnTools.openconnect && !hasTuhh) {
      targets = [{
        key: "cli:tuhh",
        label: "TUHH-VPN",
        detail: "nmcli --ask",
        glyph: QuickModels.GLYPH_SHIELD_LOCK,
        gateway: "any1.rz.tuhh.de",
        kind: "openconnect-cli",
        active: false
      }].concat(targets)
    }
    quickNetworkRoot.vpnTargets = targets
    quickNetworkRoot.vpnSummary = QuickModels.nmSummary(runnable)
    quickNetworkRoot.maybeFetchPublicIp()
  }
  function isTuhhTarget(target) {
    if (!target) return false
    if (target.kind === "openconnect-cli") return true
    if (target.label === "TUHH-VPN") return true
    return (target.gateway || "").indexOf("tuhh.de") !== -1
  }
  function launchTuhhVpn() {
    root.execAndClose([root.binDir + "/asahi-launch-or-focus-tui", quickNetworkRoot.vpnTuhhScript])
  }
  function refreshVpn() {
    if (vpnListProc.running || vpnDetailsProc.running) return
    vpnListProc.running = true
  }
  function startVpnUp(target) {
    vpnConnectProc.command = ["nmcli"].concat(target.args || [])
    quickNetworkRoot.vpnStatus = "Connecting to " + target.label + "…"
    quickNetworkRoot.vpnError = ""
    quickNetworkRoot.vpnBusy = true
    vpnConnectProc.running = true
  }
  function tapVpn(target) {
    if (!target || quickNetworkRoot.vpnBusy) return
    if (quickNetworkRoot.isTuhhTarget(target) && !target.active) {
      quickNetworkRoot.launchTuhhVpn()
      return
    }
    if (target.active) {
      quickNetworkRoot.vpnPending = null
      quickNetworkRoot.vpnStage = "final"
      quickNetworkRoot.vpnStatus = "Disconnecting…"
      quickNetworkRoot.vpnError = ""
      quickNetworkRoot.vpnBusy = true
      vpnConnectProc.command = ["nmcli", "connection", "down", "uuid", target.uuid]
      vpnConnectProc.running = true
      return
    }
    // Refuse before the handover: a profile without its username used to drop the working VPN first.
    if (QuickModels.needsUsername(target) && target.hasUsername === false) {
      quickNetworkRoot.vpnError = "\"" + target.label + "\" has no username"
      return
    }
    const active = QuickModels.activeNmProfile(quickNetworkRoot.vpnProfiles)
    quickNetworkRoot.vpnPending = target
    if (active && active.uuid !== target.uuid) {
      quickNetworkRoot.vpnStage = "handover"
      quickNetworkRoot.vpnStatus = "Switching…"
      quickNetworkRoot.vpnError = ""
      quickNetworkRoot.vpnBusy = true
      vpnConnectProc.command = ["nmcli", "connection", "down", "uuid", active.uuid]
      vpnConnectProc.running = true
      return
    }
    quickNetworkRoot.vpnStage = "final"
    quickNetworkRoot.startVpnUp(target)
  }
  function copyPublicIp() {
    if (!quickNetworkRoot.vpnPublicIp) return
    Quickshell.execDetached(["wl-copy", quickNetworkRoot.vpnPublicIp])
    quickNetworkRoot.vpnStatus = "Copied " + quickNetworkRoot.vpnPublicIp
  }
  function maybeFetchPublicIp() {
    const ext = (quickNetworkRoot.vpnExternal[0] && quickNetworkRoot.vpnExternal[0].device) || ""
    // Another Wi-Fi / LAN / tunnel is another public IP: refetch, and drop the old one meanwhile.
    const key = [quickNetworkRoot.vpnSummary, ext, quickNetworkRoot.currentWifiSsid,
      quickNetworkRoot.ethConnected ? quickNetworkRoot.ethConnection : ""].join("|")
    if (key === quickNetworkRoot.vpnIpKey && quickNetworkRoot.vpnPublicIp) return
    if (key !== quickNetworkRoot.vpnIpKey) quickNetworkRoot.vpnPublicIp = ""
    quickNetworkRoot.vpnIpKey = key
    const xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      if (xhr.status !== 200) return
      const ip = QuickModels.parsePublicIp(xhr.responseText)
      if (ip) quickNetworkRoot.vpnPublicIp = ip
    }
    xhr.open("GET", "https://checkip.amazonaws.com")
    xhr.send()
  }
  function tapNetwork(net) {
    if (net.active) { quickNetworkRoot.disconnectSsid(net.ssid); return }
    quickNetworkRoot.requestConnect(net.ssid, net.sec)
  }
  function requestConnect(ssid, sec) {
    // One attempt at a time: a second tap would overwrite targetSsid.
    if (connectProc.running || savedCheckProc.running) return
    if (!QuickModels.wifiNeedsPassword(sec)) { quickNetworkRoot.doConnect(ssid, null); return }
    savedCheckProc.targetSsid = ssid
    savedCheckProc.command = [
      "bash", "-c",
      // -e no: names with ':' or '\\' print unescaped, so grep -Fx matches (a miss would
      // treat a saved profile as new and delete it after a failed connect).
      "nmcli -e no -g NAME connection show | grep -Fx " + root.shQuote(ssid) + " >/dev/null && echo saved || echo new"
    ]
    savedCheckProc.running = true
  }
  // Stays open (omarchy behavior): the row shows "Connecting…", failures
  // reopen the passphrase prompt with the reason instead of bailing to an
  // external editor. A typed passphrase runs as a transient unit that deletes the
  // profile `connect` just created when it fails: a pane switch mid-connect used to
  // leave that wrong-passphrase profile, which later taps connected without a prompt.
  // SSID / PSK reach it through the environment (-E NAME copies ours), not systemd-run's argv
  // (nmcli's own argv still carries the PSK while it runs).
  function doConnect(ssid, pass) {
    quickNetworkRoot.showPasswordPrompt = false
    quickNetworkRoot.passwordError = ""
    quickNetworkRoot.connectingSsid = ssid
    connectProc.targetSsid = ssid
    connectProc.usedPassword = !!pass
    connectProc.environment = pass ? { SSID: ssid, PSK: pass } : {}
    connectProc.command = pass
      ? ["systemd-run", "--user", "--wait", "--quiet", "--collect", "-E", "SSID", "-E", "PSK", "bash", "-c",
        "nmcli dev wifi connect \"$SSID\" password \"$PSK\" || { nmcli connection delete id \"$SSID\"; exit 1; }"]
      : ["nmcli", "dev", "wifi", "connect", ssid]
    connectProc.running = true
  }

  // `rescan` forces a fresh scan (Rescan pill); the poll takes NetworkManager's list (auto: a forced
  // off-channel scan every 6 s skewed the latency chips and starved Bluetooth on the shared radio).
  function scanWifi(rescan) {
    // Radio off (or still settling after a toggle): no point scanning —
    // repeated failed scans while off were a major source of list churn.
    if (quickNetworkRoot.wifiEnabled && !radioSettle.running) {
      quickNetworkRoot.wifiScanning = true
      wifiListProc.command = ["nmcli", "-w", "8", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,FREQ", "dev", "wifi", "list"]
        .concat(quickNetworkRoot.wifiDevice ? ["ifname", quickNetworkRoot.wifiDevice] : [], ["--rescan", rescan ? "yes" : "auto"])
      if (!wifiListProc.running) wifiListProc.running = true
    }
    wifiProc.running = true
    wifiPowerCheck.running = true
    ethCheck.running = true
    savedWifiProc.running = true
    quickNetworkRoot.refreshVpn()
  }

  Process {
    id: wifiProc
    command: [root.binDir + "/asahi-network"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse((text || "").trim() || "{}")
          quickNetworkRoot.wifiTooltip = d.tooltip || ""
          quickNetworkRoot.wifiChecked = true
          // Fast first answer while the first scan runs; after that the scan's in-use row owns the SSID.
          const m = (d.tooltip || "").match(/^Connected to (.+)$/m)
          if (m && !quickNetworkRoot.wifiScanned) quickNetworkRoot.currentWifiSsid = m[1].trim()
        } catch (_) {}
      }
    }
  }
  Process {
    id: wifiListProc
    command: ["true"]  // set dynamically in scanWifi before .running (avoids init-time wifiDevice + ensures reactive)
    stdout: StdioCollector { id: wifiListOut; waitForEnd: true }
    stderr: StdioCollector {}
    onExited: function(code) {
      quickNetworkRoot.wifiScanning = false
      // A failed / timed-out scan keeps the last list and SSID.
      if (code !== 0) return
      const rows = (wifiListOut.text || "").trim().split("\n").filter(l => l).map(l => QuickModels.nmcliFields(l))
      // The SSID is the in-use row's, so a dropped link clears it (the status tooltip never did).
      const inUse = rows.find(p => p[0] === "*")
      quickNetworkRoot.currentWifiSsid = inUse ? inUse[1] || "" : ""
      quickNetworkRoot.wifiScanned = true
      const out = []; const seen = {}
      for (const p of rows) {
        if (p.length < 3) continue
        const ssid = p[1] || ""
        if (!ssid || seen[ssid]) continue
        seen[ssid] = true
        out.push({
          ssid: ssid, signal: parseInt(p[2])||0, sec: p[3]||"", active: ssid === quickNetworkRoot.currentWifiSsid,
          known: quickNetworkRoot.savedWifi[ssid] === true,
          band: QuickModels.formatHeaderFreq(p[4] || "")
        })
      }
      // A scan can momentarily report only the active AP; keep the last list.
      let next = out
      if (out.length === 1 && out[0].active && (quickNetworkRoot.wifiNetworks || []).length > 1) {
        next = [out[0]].concat((quickNetworkRoot.wifiNetworks || []).filter(n => n.ssid !== out[0].ssid))
      }
      // omarchy ordering: connected, then known, then by signal.
      next.sort(function(a, b) {
        if (a.active !== b.active) return a.active ? -1 : 1
        if (a.known !== b.known) return a.known ? -1 : 1
        return b.signal - a.signal
      })
      next = next.slice(0, 20)
      for (let i = 0; i < next.length; i++) {
        const curKnown = next[i].active || next[i].known
        const prevKnown = i > 0 ? (next[i - 1].active || next[i - 1].known) : null
        next[i].section = ""
        if (i === 0 && curKnown) next[i].section = "Known networks"
        else if (!curKnown && (i === 0 || prevKnown)) next[i].section = "Other networks"
      }
      // Only reassign when contents actually changed — a fresh array per
      // 6s poll rebuilt every Repeater row and made the list twitch.
      if (JSON.stringify(next) !== JSON.stringify(quickNetworkRoot.wifiNetworks))
        quickNetworkRoot.wifiNetworks = next
    }
  }
  Process {
    id: wifiPowerCheck
    command: ["nmcli", "radio", "wifi"]
    stdout: StdioCollector {
      onStreamFinished: {
        // Don't fight an in-flight toggle: nmcli briefly reports the old
        // radio state, which flip-flopped the Enable/Disable button.
        if (radioProc.running || radioSettle.running) return
        quickNetworkRoot.wifiEnabled = (text || "").trim().indexOf("enabled") !== -1
        // Radio off, also from outside the pane: no stale list or "Connected".
        if (!quickNetworkRoot.wifiEnabled) {
          quickNetworkRoot.wifiNetworks = []
          quickNetworkRoot.currentWifiSsid = ""
        }
      }
    }
  }
  Process {
    id: ethCheck
    command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        const devices = []
        const lines = (text || "").trim().split("\n").filter(l => l)
        for (const line of lines) {
          const p = QuickModels.nmcliFields(line)
          if (p[1] === "wifi" && !quickNetworkRoot.wifiDevice) quickNetworkRoot.wifiDevice = p[0] || ""
          if (p[1] !== "ethernet") continue
          devices.push({ device: p[0] || "", state: p[2] || "", connection: p.slice(3).join(":") || "" })
        }
        quickNetworkRoot.ethDevices = devices
        const active = devices.find(d => d.state === "connected") || devices[0] || null
        quickNetworkRoot.ethDevice = active ? active.device : ""
        quickNetworkRoot.ethState = active ? active.state : ""
        quickNetworkRoot.ethConnection = active ? active.connection : ""
        quickNetworkRoot.ethConnected = active ? active.state === "connected" : false
        const names = {}
        const profiles = quickNetworkRoot.vpnProfiles || []
        for (let i = 0; i < profiles.length; i++) names[profiles[i].name] = true
        quickNetworkRoot.vpnExternal = QuickModels.parseExternalTunnels(text || "", names)
      }
    }
  }
  Process {
    id: savedCheckProc
    property string targetSsid: ""
    stdout: StdioCollector {
      onStreamFinished: {
        const saved = (text || "").trim() === "saved"
        if (saved) quickNetworkRoot.doConnect(savedCheckProc.targetSsid, null)
        else {
          quickNetworkRoot.pendingSsid = savedCheckProc.targetSsid
          quickNetworkRoot.passwordError = ""
          quickNetworkRoot.showPasswordPrompt = true
        }
      }
    }
  }
  Process {
    id: connectProc
    property string targetSsid: ""
    property bool usedPassword: false
    onExited: function(code) {
      quickNetworkRoot.connectingSsid = ""
      if (code === 0) {
        quickNetworkRoot.notifyNet("Connected", connectProc.targetSsid)
        quickNetworkRoot.currentWifiSsid = connectProc.targetSsid
      } else if (connectProc.usedPassword) {
        // A failed connect with a typed passphrase (the unit dropped its new profile): re-prompt.
        // Saved profiles never get here (out of range / DHCP timeout must not delete their settings).
        quickNetworkRoot.pendingSsid = connectProc.targetSsid
        quickNetworkRoot.passwordError = "Wrong password — try again"
        quickNetworkRoot.showPasswordPrompt = true
      } else {
        quickNetworkRoot.notifyNet("Could not connect", connectProc.targetSsid)
      }
      Qt.callLater(quickNetworkRoot.scanWifi)
    }
  }
  Process {
    id: forgetProc
    property string targetSsid: ""
    onExited: function(code) {
      quickNetworkRoot.notifyNet(code === 0 ? "Forgotten" : "Could not forget", forgetProc.targetSsid)
      Qt.callLater(quickNetworkRoot.scanWifi)
    }
  }

  Process {
    id: savedWifiProc
    command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
    stdout: StdioCollector {
      onStreamFinished: {
        const map = {}
        const lines = (text || "").trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
          const idx = lines[i].lastIndexOf(":")
          if (idx < 0) continue
          if (lines[i].slice(idx + 1) !== "802-11-wireless") continue
          // nmcli -t escapes ':' in values as '\:'
          map[lines[i].slice(0, idx).replace(/\\:/g, ":")] = true
        }
        quickNetworkRoot.savedWifi = map
      }
    }
  }
  Process {
    id: throughputProc
    command: ["true"]
    stdout: StdioCollector {
      onStreamFinished: {
        const values = (text || "").trim().split(/\s+/)
        if (values.length < 2) return
        const now = Date.now()
        const rx = Number(values[0]); const tx = Number(values[1])
        const seconds = (now - quickNetworkRoot.prevSampleMs) / 1000
        if (quickNetworkRoot.prevSampleMs > 0 && seconds > 0) {
          quickNetworkRoot.netRxRate = Math.max(0, (rx - quickNetworkRoot.prevRxBytes) / seconds)
          quickNetworkRoot.netTxRate = Math.max(0, (tx - quickNetworkRoot.prevTxBytes) / seconds)
        }
        quickNetworkRoot.prevRxBytes = rx
        quickNetworkRoot.prevTxBytes = tx
        quickNetworkRoot.prevSampleMs = now
      }
    }
  }
  Process {
    id: pingProc
    command: [root.binDir + "/asahi-net-quality"]
    stdout: StdioCollector {
      onStreamFinished: {
        const p = (text || "").trim().split(/\s+/)
        if (p.length < 2) return
        const router = p[0] === "x" ? null : parseFloat(p[0])
        const inet = p[1] === "x" ? null : parseFloat(p[1])
        quickNetworkRoot.routerPings = quickNetworkRoot.routerPings.concat([router]).slice(-5)
        quickNetworkRoot.netPings = quickNetworkRoot.netPings.concat([inet]).slice(-5)
      }
    }
  }

  Process {
    id: vpnToolProbe
    command: ["sh", "-c", "command -v wg >/dev/null && echo wg; command -v openvpn >/dev/null && echo ovpn; { test -x /usr/libexec/nm-vpnc-service || test -x /usr/lib/nm-vpnc-service; } && echo vpnc; true"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const blob = (text || "")
        const next = Object.assign({}, quickNetworkRoot.vpnTools)
        next.wireguard = blob.indexOf("wg") !== -1
        next.openvpn = blob.indexOf("ovpn") !== -1
        next.vpnc = blob.indexOf("vpnc") !== -1
        quickNetworkRoot.vpnTools = next
        quickNetworkRoot.applyVpnProfiles(quickNetworkRoot.vpnLastConns, quickNetworkRoot.vpnLastDetails)
      }
    }
  }
  Process {
    id: vpnOcProbe
    command: ["sh", "-c", "command -v openconnect >/dev/null"]
    running: true
    onExited: function(code) {
      const next = Object.assign({}, quickNetworkRoot.vpnTools)
      next.openconnect = code === 0
      quickNetworkRoot.vpnTools = next
      quickNetworkRoot.applyVpnProfiles(quickNetworkRoot.vpnLastConns, quickNetworkRoot.vpnLastDetails)
    }
  }
  Process {
    id: vpnListProc
    command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE,FILENAME", "connection", "show"]
    property var pending: []
    stdout: StdioCollector {
      id: vpnListOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (code !== 0) return
      const conns = QuickModels.parseNmcliConnections(vpnListOut.text || "")
      vpnListProc.pending = conns
      const uuids = []
      for (let i = 0; i < conns.length; i++) {
        if (conns[i].kind === "vpn") uuids.push(conns[i].uuid)
      }
      if (uuids.length === 0) {
        quickNetworkRoot.applyVpnProfiles(conns, {})
        return
      }
      vpnDetailsProc.command = ["nmcli", "-t", "-f", "connection.uuid,vpn.service-type,vpn.data", "connection", "show"].concat(uuids)
      vpnDetailsProc.running = true
    }
  }
  Process {
    id: vpnDetailsProc
    command: ["true"]
    stdout: StdioCollector {
      id: vpnDetailsOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (code !== 0) {
        quickNetworkRoot.applyVpnProfiles(vpnListProc.pending || [], {})
        return
      }
      quickNetworkRoot.applyVpnProfiles(
        vpnListProc.pending || [],
        QuickModels.parseNmcliVpnDetails(vpnDetailsOut.text || "")
      )
    }
  }
  Process {
    id: vpnConnectProc
    command: ["true"]
    stdout: StdioCollector { id: vpnConnOut; waitForEnd: true }
    stderr: StdioCollector { id: vpnConnErr; waitForEnd: true }
    onExited: function(code) {
      if (quickNetworkRoot.vpnStage === "handover") {
        quickNetworkRoot.vpnStage = ""
        vpnHandover.restart()
        return
      }
      quickNetworkRoot.vpnStage = ""
      quickNetworkRoot.vpnBusy = false
      quickNetworkRoot.vpnPending = null
      if (code !== 0) {
        const output = String(vpnConnErr.text || "") + "\n" + String(vpnConnOut.text || "")
        quickNetworkRoot.vpnError = output.replace(/\s+/g, " ").trim().slice(0, 140) || "VPN command failed"
        quickNetworkRoot.vpnStatus = ""
      } else {
        quickNetworkRoot.vpnError = ""
        quickNetworkRoot.vpnStatus = ""
      }
      Qt.callLater(quickNetworkRoot.refreshVpn)
    }
  }
  Timer {
    id: vpnHandover
    interval: 0
    onTriggered: {
      const target = quickNetworkRoot.vpnPending
      if (!target) { quickNetworkRoot.vpnBusy = false; return }
      quickNetworkRoot.vpnStage = "final"
      quickNetworkRoot.startVpnUp(target)
    }
  }

  readonly property bool live: root.shouldShow && root.quickMode && root.quickPaneKey === "network"
  Timer { interval: 6000; running: quickNetworkRoot.live; repeat: true; triggeredOnStart: true; onTriggered: quickNetworkRoot.scanWifi() }
  Timer { interval: 1500; running: quickNetworkRoot.live; repeat: true; triggeredOnStart: true; onTriggered: quickNetworkRoot.sampleThroughput() }
  Timer { interval: 4000; running: quickNetworkRoot.live; repeat: true; triggeredOnStart: true; onTriggered: { if (!pingProc.running) pingProc.running = true } }

  // ---- M3 building blocks (caelestia look) ----
  readonly property var activeNet: (quickNetworkRoot.wifiNetworks || []).find(function(n) { return n.active }) || null
  readonly property var signalGlyphs: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
  function signalGlyph(pct) { return quickNetworkRoot.signalGlyphs[Math.max(0, Math.min(4, Math.ceil(pct / 20) - 1))] }
  // asahi-network tooltip lines minus the SSID + signal (title row) and the VPN (VPN card).
  // Blank rows before the first answer hold the grid's usual height.
  readonly property var wifiFacts: !quickNetworkRoot.wifiChecked ? [" ", " ", " ", " ", " "]
    : (quickNetworkRoot.wifiTooltip || "").split("\n")
      .filter(function(l) { return l.trim() && !/^(Connected to|Signal:|VPN:)/.test(l) })
  // The live tunnel, NM profile or not (the Proton app's WireGuard connection is an "external" one): "ProtonVPN DE#609 · up 3m".
  readonly property bool vpnUp: !!QuickModels.activeNmProfile(quickNetworkRoot.vpnProfiles) || (quickNetworkRoot.vpnExternal || []).length > 0
  readonly property string vpnLine: ((quickNetworkRoot.wifiTooltip || "").match(/^VPN: (.+)$/m) || ["", ""])[1].replace(" (external tunnel)", "")

  component Card: Rectangle {
    radius: Style.menuRadiusLg
    color: Style.m3container
  }

  component Pill: Menu.MenuPill { fontScale: quickNetworkRoot.root.uiFontScale }
  // Stats chip: `fixedWidth` for the live rates, `clickable` for the public IP (copies).
  component Chip: Menu.MenuChip { fontScale: quickNetworkRoot.root.uiFontScale }
  component LinkBtn: Menu.MenuLinkBtn { fontScale: quickNetworkRoot.root.uiFontScale }
  component IconBtn: Menu.MenuIconBtn { fontScale: quickNetworkRoot.root.uiFontScale }

  component CardTitle: Text {
    color: Style.m3onSurface
    font.family: quickNetworkRoot.root.uiSans
    font.pixelSize: quickNetworkRoot.root.fontPx(12)
    font.weight: Font.DemiBold
  }
  component Secondary: Text {
    color: Style.m3onSurfaceVariant
    font.family: quickNetworkRoot.root.uiSans
    font.pixelSize: quickNetworkRoot.root.fontPx(10)
    elide: Text.ElideRight
    textFormat: Text.PlainText  // SSIDs, connection names
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 10

    // Wi-Fi + LAN cards.
    RowLayout {
      Layout.fillHeight: false
      Layout.fillWidth: true
      spacing: 10
      Card {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 3
        implicitHeight: wifiCol.implicitHeight + 24
        ColumnLayout {
          id: wifiCol
          anchors.fill: parent
          anchors.margins: 12
          spacing: 6
          RowLayout {
            Layout.fillHeight: false
            Layout.fillWidth: true
            spacing: 8
            Text { text: "󰤨"; color: Style.m3primary; font.family: root.uiFont; font.pixelSize: root.fontPx(15) }
            CardTitle { text: "Wi-Fi" }
            Secondary {
              text: quickNetworkRoot.wifiChecked
                ? QuickModels.wifiRadioStatus(quickNetworkRoot.wifiEnabled, quickNetworkRoot.currentWifiSsid) : "Checking…"
            }
            Item { Layout.fillWidth: true }
            Menu.MenuSwitch { checked: quickNetworkRoot.wifiEnabled; onToggled: quickNetworkRoot.toggleWifi() }
          }
          RowLayout {
            Layout.fillHeight: false
            Layout.fillWidth: true
            spacing: 12
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 4
              RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  text: quickNetworkRoot.currentWifiSsid
                    || (!quickNetworkRoot.wifiChecked ? "Checking…" : (quickNetworkRoot.wifiEnabled ? "No network" : "—"))
                  color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(15)
                  font.weight: Font.DemiBold; elide: Text.ElideRight
                }
                Text {
                  visible: !!quickNetworkRoot.activeNet
                  readonly property int sig: quickNetworkRoot.activeNet ? quickNetworkRoot.activeNet.signal : 0
                  text: quickNetworkRoot.signalGlyph(sig) + "  " + sig + "%"
                  color: Style.m3primary; font.family: root.uiFont; font.pixelSize: root.fontPx(11)
                }
              }
              // Facts grid (IP, gateway, freq, bitrate…); signal is shown next to the SSID.
              GridLayout {
                Layout.fillWidth: true
                columns: 2; columnSpacing: 18; rowSpacing: 1
                Repeater {
                  model: quickNetworkRoot.wifiFacts
                  delegate: Secondary { required property var modelData; text: modelData }
                }
                Secondary { visible: quickNetworkRoot.wifiChecked && quickNetworkRoot.wifiFacts.length === 0; text: "No connection details" }
              }
              Secondary {
                visible: !!quickNetworkRoot.wifiQrError && !quickNetworkRoot.wifiQrPath
                Layout.fillWidth: true; text: quickNetworkRoot.wifiQrError; color: Style.red
              }
              // Fixed height so the pills arriving with the first status do not push the page down.
              RowLayout {
                Layout.topMargin: 2
                Layout.preferredHeight: 32
                spacing: 8
                Pill {
                  visible: !!quickNetworkRoot.currentWifiSsid && !!quickNetworkRoot.wifiDevice && quickNetworkRoot.wifiEnabled
                  icon: "󰌸"; label: "Disconnect"; fg: Style.red
                  onClicked: quickNetworkRoot.disconnectWifi()
                }
                Pill {
                  visible: !!quickNetworkRoot.currentWifiSsid && quickNetworkRoot.wifiEnabled
                  icon: "󰐲"; label: quickNetworkRoot.wifiQrPath ? "Hide QR" : "Share QR"
                  bg: Style.m3secondaryContainer; selected: !!quickNetworkRoot.wifiQrPath
                  onClicked: quickNetworkRoot.toggleWifiQr()
                }
                Pill {
                  visible: (!!quickNetworkRoot.wifiBand || bandSetProc.running) && quickNetworkRoot.wifiEnabled
                  icon: "󰖩"
                  label: bandSetProc.running ? "Switching…"
                    : (quickNetworkRoot.wifiBand === "auto" ? "Band auto" : quickNetworkRoot.wifiBand + " GHz")
                  bg: Style.m3secondaryContainer; selected: !!quickNetworkRoot.wifiBand && quickNetworkRoot.wifiBand !== "auto"
                  onClicked: quickNetworkRoot.cycleBand()
                }
              }
            }
            Rectangle {
              visible: !!quickNetworkRoot.wifiQrPath
              Layout.alignment: Qt.AlignTop
              width: 112; height: 112; radius: Style.menuRadiusMd; color: "white"
              Image {
                anchors.fill: parent; anchors.margins: 6; source: quickNetworkRoot.wifiQrPath
                cache: false; smooth: false; fillMode: Image.PreserveAspectFit
              }
            }
          }
          Item { Layout.fillHeight: true }
        }
      }

      Card {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 2
        implicitHeight: ethCol.implicitHeight + 24
        ColumnLayout {
          id: ethCol
          anchors.fill: parent
          anchors.margins: 12
          spacing: 6
          RowLayout {
            Layout.fillHeight: false
            Layout.fillWidth: true
            spacing: 8
            Text {
              text: "󰈀"; color: quickNetworkRoot.ethConnected ? Style.m3primary : Style.m3onSurfaceVariant
              font.family: root.uiFont; font.pixelSize: root.fontPx(15)
            }
            CardTitle { text: "LAN" }
            Secondary {
              text: quickNetworkRoot.ethDevice ? quickNetworkRoot.ethState : "No device"
              color: quickNetworkRoot.ethConnected ? Style.green : Style.m3onSurfaceVariant
            }
            Item { Layout.fillWidth: true }
            LinkBtn { visible: !!quickNetworkRoot.ethDevice; active: quickNetworkRoot.ethConnected; onClicked: quickNetworkRoot.toggleEth() }
          }
          Text {
            Layout.fillWidth: true
            text: quickNetworkRoot.ethDevice ? quickNetworkRoot.ethDevice : "No ethernet device"
            color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(15); font.weight: Font.DemiBold; elide: Text.ElideRight
          }
          Secondary {
            Layout.fillWidth: true
            text: quickNetworkRoot.ethConnection
              || ((quickNetworkRoot.ethDevices || []).length > 1 ? quickNetworkRoot.ethDevices.length + " ethernet devices" : "No active LAN")
          }
          Item { Layout.fillHeight: true }
        }
      }
    }

    // Stats strip: throughput, latency, loss, public IP. Flow wraps instead of
    // widening the whole column past the pane (a RowLayout's minimum is the chip sum).
    Flow {
      Layout.fillWidth: true
      spacing: 6
      Chip {
        icon: "󰕒"
        label: QuickModels.formatRate(quickNetworkRoot.netTxRate)
        fixedWidth: QuickModels.rateChipWidth(root.fontPx(10))
      }
      Chip {
        icon: "󰇚"
        label: QuickModels.formatRate(quickNetworkRoot.netRxRate)
        fixedWidth: QuickModels.rateChipWidth(root.fontPx(10))
      }
      Chip { icon: "󰑩"; label: "Router " + quickNetworkRoot.fmtPing(quickNetworkRoot.pingAvg(quickNetworkRoot.routerPings)) }
      Chip { icon: "󰖟"; label: "Internet " + quickNetworkRoot.fmtPing(quickNetworkRoot.pingAvg(quickNetworkRoot.netPings)) }
      Chip {
        readonly property string loss: quickNetworkRoot.pingLoss(quickNetworkRoot.netPings)
        icon: "󰀦"; label: "Loss " + loss
        bg: loss !== "--" && loss !== "0%" ? Qt.alpha(Style.red, 0.22) : Style.m3secondaryContainer
      }
      Chip {
        visible: !!quickNetworkRoot.vpnPublicIp
        icon: "󰩟"; label: quickNetworkRoot.vpnPublicIp
        bg: Style.m3tertiaryContainer; clickable: true
        onClicked: quickNetworkRoot.copyPublicIp()
      }
    }

    // VPN card.
    Card {
      Layout.fillWidth: true
      implicitHeight: vpnCol.implicitHeight + 24
      ColumnLayout {
        id: vpnCol
        anchors.fill: parent
        anchors.margins: 12
        spacing: 4
        RowLayout {
          Layout.fillHeight: false
          Layout.fillWidth: true
          Layout.leftMargin: 2
          spacing: 8
          Text {
            text: "󰦝"; color: quickNetworkRoot.vpnUp ? Style.m3primary : Style.m3onSurfaceVariant
            font.family: root.uiFont; font.pixelSize: root.fontPx(15)
          }
          CardTitle { text: "VPN" }
          Secondary {
            text: quickNetworkRoot.vpnUp ? (quickNetworkRoot.vpnLine || "Connected") : quickNetworkRoot.vpnSummary
            color: quickNetworkRoot.vpnUp ? Style.green : Style.m3onSurfaceVariant
          }
          Item { Layout.fillWidth: true }
          Secondary {
            visible: !!quickNetworkRoot.vpnStatus || !!quickNetworkRoot.vpnError
            Layout.maximumWidth: vpnCol.width * 0.6
            text: quickNetworkRoot.vpnError || quickNetworkRoot.vpnStatus
            color: quickNetworkRoot.vpnError ? Style.red : Style.m3onSurfaceVariant
          }
        }
        Repeater {
          model: quickNetworkRoot.vpnExternal || []
          delegate: RowLayout {
              Layout.fillHeight: false
            required property var modelData
            Layout.fillWidth: true
            Layout.leftMargin: 8; Layout.rightMargin: 8
            spacing: 10
            Text { text: "󰯄"; color: Style.green; font.family: root.uiFont; font.pixelSize: root.fontPx(14) }
            Text {
              text: modelData.connection || modelData.device; color: Style.m3onSurface; textFormat: Text.PlainText
              font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.Medium; elide: Text.ElideRight
            }
            Secondary {
              Layout.fillWidth: true
              text: ({ wireguard: "WireGuard", tun: "Tunnel", vpn: "VPN" }[modelData.type] || modelData.type) + "  ·  " + (modelData.device || "")
            }
          }
        }
        Repeater {
          model: quickNetworkRoot.vpnTargets || []
          delegate: Rectangle {
            id: vpnRow
            required property var modelData
            readonly property bool busyRow: quickNetworkRoot.vpnBusy && !!quickNetworkRoot.vpnPending
              && quickNetworkRoot.vpnPending.key === modelData.key
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Style.menuRadiusMd
            color: vpnMa.containsMouse ? Style.m3stateHover : "transparent"
            MouseArea {
              id: vpnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: quickNetworkRoot.tapVpn(vpnRow.modelData)
            }
            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8; anchors.rightMargin: 4
              spacing: 10
              Text {
                text: vpnRow.modelData.glyph || "󰯄"; color: vpnRow.modelData.active ? Style.m3primary : Style.m3onSurfaceVariant
                font.family: root.uiFont; font.pixelSize: root.fontPx(14)
              }
              Text {
                text: vpnRow.modelData.label
                color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11)
                font.weight: vpnRow.modelData.active ? Font.Medium : Font.Normal; elide: Text.ElideRight
              }
              Secondary {
                Layout.fillWidth: true
                text: vpnRow.modelData.detail + (vpnRow.modelData.gateway ? "  ·  " + vpnRow.modelData.gateway : "")
              }
              LinkBtn { active: !!vpnRow.modelData.active; busy: vpnRow.busyRow; onClicked: quickNetworkRoot.tapVpn(vpnRow.modelData) }
            }
          }
        }
        Secondary {
          visible: (quickNetworkRoot.vpnTargets || []).length === 0 && (quickNetworkRoot.vpnExternal || []).length === 0
          Layout.fillWidth: true; Layout.leftMargin: 8
          text: "No VPN profiles. TUHH: tap TUHH-VPN or run tuhhvpn."
        }
      }
    }

    // Networks card: count + rescan, scrolling list of known / other networks.
    Card {
      Layout.fillWidth: true
      Layout.fillHeight: true
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6
        RowLayout {
          Layout.fillHeight: false
          Layout.fillWidth: true
          Layout.leftMargin: 2
          spacing: 8
          // Tabs: Wi-Fi networks nearby, the devices on this LAN. A static model: one that read `lan` rebuilt both pills
          // on every snapshot.
          Repeater {
            model: [{ key: "networks", icon: "󰖩", label: "Networks" }, { key: "devices", icon: "󰉹", label: "Devices" }]
            delegate: Pill {
              required property var modelData
              readonly property int count: modelData.key === "devices" ? (quickNetworkRoot.lan.total || 0)
                : (quickNetworkRoot.wifiEnabled ? (quickNetworkRoot.wifiNetworks || []).length : 0)
              icon: modelData.icon
              label: modelData.label + (count ? " " + count : "")
              selected: quickNetworkRoot.netTab === modelData.key
              bg: "transparent"; fg: Style.m3onSurfaceVariant
              onClicked: quickNetworkRoot.netTab = modelData.key
            }
          }
          Item { Layout.fillWidth: true }
          Pill {
            visible: quickNetworkRoot.netTab === "networks"
            icon: quickNetworkRoot.wifiScanning ? "󰔟" : "󰤨"; label: "Rescan networks"
            bg: Style.m3primaryContainer
            onClicked: quickNetworkRoot.rescanWifi()
          }
          // Trust = this network may be pinged (once per opening) and gets NEW badges; untrusted ones never are.
          Pill {
            visible: quickNetworkRoot.netTab === "devices" && !!quickNetworkRoot.lan.can_trust
            icon: "󰒘"; label: quickNetworkRoot.lan.trusted ? "Trusted" : "Trust"
            selected: !!quickNetworkRoot.lan.trusted; bg: Style.m3secondaryContainer
            onClicked: quickNetworkRoot.lanCmd(quickNetworkRoot.lan.trusted ? "untrust" : "trust")
          }
          Pill {
            visible: quickNetworkRoot.netTab === "devices" && !!quickNetworkRoot.lan.active
            icon: "󰕰"; label: (quickNetworkRoot.lan.view || {}).mode === "type" ? "By type" : "No groups"
            bg: Style.m3secondaryContainer
            onClicked: lanDevices.toggleMode()
          }
          Pill {
            visible: quickNetworkRoot.netTab === "devices" && !!quickNetworkRoot.lan.active
            icon: quickNetworkRoot.lan.scanning ? "󰔟" : "󰑐"
            // Untrusted networks are never pinged: Refresh only asks for the names again.
            label: quickNetworkRoot.lan.scanning ? "Scanning…" : (quickNetworkRoot.lan.trusted ? "Rescan" : "Refresh")
            bg: Style.m3primaryContainer
            onClicked: quickNetworkRoot.lanCmd("rescan")
          }
        }
        Panes.LanDevices {
          id: lanDevices
          visible: quickNetworkRoot.netTab === "devices"
          Layout.fillWidth: true
          Layout.fillHeight: true
          root: quickNetworkRoot.root
          lan: quickNetworkRoot.lan
          onCommand: cmd => quickNetworkRoot.lanCmd(cmd)
        }
        ListView {
          id: netList
          visible: quickNetworkRoot.netTab === "networks"
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 2
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: Menu.MenuScrollBar { id: netScroll }
          model: wifiNetworksModel
          delegate: Column {
            id: netDelegate
            required property var modelData
            // Gutter so the scrollbar never sits on the connect buttons.
            width: netList.width - (netScroll.overflow ? netScroll.implicitWidth + 4 : 0)
            spacing: 2
            Secondary {
              visible: !!netDelegate.modelData.section
              text: netDelegate.modelData.section || ""
              font.weight: Font.Medium
              leftPadding: 10; topPadding: 6; bottomPadding: 2
            }
            Rectangle {
              width: parent.width
              height: 40
              radius: Style.menuRadiusMd
              color: netMa.containsMouse ? Style.m3stateHover : "transparent"
              MouseArea {
                id: netMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: quickNetworkRoot.tapNetwork(netDelegate.modelData)
              }
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 6
                spacing: 10
                Text {
                  text: quickNetworkRoot.signalGlyph(netDelegate.modelData.signal)
                  color: netDelegate.modelData.active ? Style.m3primary : Style.m3onSurfaceVariant
                  font.family: root.uiFont; font.pixelSize: root.fontPx(15)
                }
                Text {
                  visible: !!netDelegate.modelData.sec; text: "󰌾"; color: Style.m3onSurfaceVariant
                  font.family: root.uiFont; font.pixelSize: root.fontPx(11)
                }
                Text {
                  textFormat: Text.PlainText
                  text: netDelegate.modelData.ssid
                  color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11)
                  font.weight: netDelegate.modelData.active ? Font.Medium : Font.Normal; elide: Text.ElideRight
                  Layout.maximumWidth: netList.width * 0.45
                }
                Secondary {
                  Layout.fillWidth: true
                  text: {
                    if (quickNetworkRoot.connectingSsid === netDelegate.modelData.ssid) return "Connecting…"
                    const band = netDelegate.modelData.band ? "  ·  " + netDelegate.modelData.band : ""
                    if (netDelegate.modelData.active) return "Connected" + band
                    const sec = netDelegate.modelData.sec ? "Secure" : "Open"
                    return (netDelegate.modelData.known ? "Saved  ·  " + sec : sec) + band
                  }
                  color: netDelegate.modelData.active ? Style.m3primary : Style.m3onSurfaceVariant
                }
                Secondary { text: netDelegate.modelData.signal + "%" }
                IconBtn {
                  visible: netDelegate.modelData.known && !netDelegate.modelData.active
                  icon: "󰩺"; hot: Style.red
                  onClicked: quickNetworkRoot.forgetSsid(netDelegate.modelData.ssid)
                }
                LinkBtn {
                  active: !!netDelegate.modelData.active
                  busy: quickNetworkRoot.connectingSsid === netDelegate.modelData.ssid
                  onClicked: quickNetworkRoot.tapNetwork(netDelegate.modelData)
                }
              }
            }
          }
          Menu.MenuEmptyState {
            visible: (quickNetworkRoot.wifiNetworks || []).length === 0
            anchors.centerIn: parent
            fontScale: root.uiFontScale
            iconFamily: root.uiFont
            fontFamily: root.uiSans
            glyph: !quickNetworkRoot.wifiEnabled ? "󰤮" : (quickNetworkRoot.wifiScanning ? "󰐷" : "󰤯")
            tint: quickNetworkRoot.wifiEnabled ? Style.m3primary : Style.m3onSurfaceVariant
            title: !quickNetworkRoot.wifiEnabled ? "Networks hidden"
              : (quickNetworkRoot.wifiScanning ? "Scanning…" : "No networks found")
            detail: !quickNetworkRoot.wifiEnabled ? "Turn on Wi-Fi to see networks nearby." : ""
            actionIcon: !quickNetworkRoot.wifiEnabled ? "󰤨" : "󰑐"
            actionLabel: !quickNetworkRoot.wifiEnabled ? "Turn on Wi-Fi" : (quickNetworkRoot.wifiScanning ? "" : "Rescan")
            onAction: quickNetworkRoot.wifiEnabled ? quickNetworkRoot.rescanWifi() : quickNetworkRoot.toggleWifi()
          }
        }
      }
    }

    // Tools.
    RowLayout {
      Layout.fillHeight: false
      Layout.fillWidth: true
      spacing: 8
      Pill {
        Layout.fillWidth: true; icon: "󰈀"; label: "Editor"
        onClicked: root.execAndClose([root.binDir + "/asahi-launch", "nm-connection-editor"])
      }
      Pill { Layout.fillWidth: true; icon: "󱘖"; label: "nmtui"; onClicked: root.execAndClose([root.binDir + "/asahi-launch-or-focus-tui", "nmtui"]) }
      Pill {
        Layout.fillWidth: true
        icon: "󰓅"; label: speedProc.running ? "Testing…" : "Speed test"
        bg: Style.m3secondaryContainer
        onClicked: quickNetworkRoot.runSpeedtest()
      }
    }
    Secondary {
      visible: !!quickNetworkRoot.speedResult
      Layout.fillWidth: true
      text: quickNetworkRoot.speedResult
      horizontalAlignment: Text.AlignHCenter
    }
  }

  // Passphrase dialog (scrim + M3 card).
  Rectangle {
    anchors.fill: parent
    radius: Style.menuRadiusLg
    color: Style.menuDim
    visible: quickNetworkRoot.showPasswordPrompt
    // Clear the field and hand focus back on hide; otherwise keystrokes go into the invisible input.
    onVisibleChanged: {
      netPassInput.text = ""
      if (visible) netPassInput.forceActiveFocus()
      else root.focusLauncherInput()
    }
    z: 20
    MouseArea { anchors.fill: parent; onClicked: quickNetworkRoot.showPasswordPrompt = false }
    Rectangle {
      anchors.centerIn: parent
      width: Math.min(380, parent.width - 40)
      implicitHeight: passCol.implicitHeight + 40
      radius: Style.menuPanelRadius
      color: Style.m3container
      MouseArea { anchors.fill: parent }
      ColumnLayout {
        id: passCol
        anchors.fill: parent
        anchors.margins: 20
        spacing: 10
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Text { text: "󰌾"; color: Style.m3primary; font.family: root.uiFont; font.pixelSize: root.fontPx(16) }
          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: quickNetworkRoot.pendingSsid
            color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(14); font.weight: Font.DemiBold; elide: Text.ElideRight
          }
        }
        Secondary {
          Layout.fillWidth: true
          text: quickNetworkRoot.passwordError || "Enter the network passphrase"
          color: quickNetworkRoot.passwordError ? Style.red : Style.m3onSurfaceVariant
        }
        Rectangle {
          Layout.fillWidth: true
          height: 40
          radius: Style.menuRadiusFull
          color: Style.m3containerHigh
          border.width: netPassInput.activeFocus ? 2 : 0
          border.color: Style.m3primary
          TextInput {
            id: netPassInput
            anchors.fill: parent
            anchors.leftMargin: 16; anchors.rightMargin: 16
            color: Style.m3onSurface
            font.family: root.uiSans
            font.pixelSize: root.fontPx(12)
            echoMode: TextInput.Password
            verticalAlignment: TextInput.AlignVCenter
            // Keep keys in the dialog: unhandled arrows, Esc and Return would reach the launcher (tile
            // navigation destroys the pane and the typed passphrase).
            Keys.onPressed: event => {
              if (event.key === Qt.Key_Escape) { quickNetworkRoot.showPasswordPrompt = false; event.accepted = true }
              // Not onAccepted: Return would still bubble on.
              else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                quickNetworkRoot.doConnect(quickNetworkRoot.pendingSsid, text); event.accepted = true
              }
              // Tab would move focus to the launcher: the rest of the passphrase landed, readable, in its search field.
              else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                event.accepted = true
              else if ((event.key === Qt.Key_Left && cursorPosition === 0)
                       || (event.key === Qt.Key_Right && cursorPosition === text.length)) event.accepted = true
            }
          }
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Item { Layout.fillWidth: true }
          Pill { label: "Cancel"; bg: "transparent"; fg: Style.m3onSurfaceVariant; onClicked: quickNetworkRoot.showPasswordPrompt = false }
          Pill {
            icon: "󰌷"; label: "Connect"; bg: Style.m3primary; fg: Style.m3onPrimary
            onClicked: quickNetworkRoot.doConnect(quickNetworkRoot.pendingSsid, netPassInput.text)
          }
        }
      }
    }
  }
}
