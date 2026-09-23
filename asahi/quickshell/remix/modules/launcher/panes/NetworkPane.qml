import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../../menu" as Menu
import "../../../"
import "../quick_models.js" as QuickModels
import "../launcher_layout.js" as LauncherGeom

// Network pane: Wi-Fi / LAN / VPN state and controls, network list, tools.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, launcherGeom, quickMode, quickPaneKey, binDir, ...).
Item {
  property var root
  id: quickNetworkRoot
  anchors.fill: parent
  // full port of network from old (wifi enable/scan/list/conn + tooltip/ssid, eth toggle, refresh, state/procs; compressed)
  property var wifiNetworks: []
  property bool wifiEnabled: true
  property string currentWifiSsid: ""
  // False until the first asahi-network answer: show "Checking…" instead of
  // flashing "No network" / "Not connected" for a frame.
  property bool wifiChecked: false
  property bool wifiScanning: false
  property string wifiDevice: ""
  property string wifiLabel: "WiFi"
  property string wifiTooltip: ""
  property string ethDevice: ""
  property string ethState: ""
  property string ethConnection: ""
  property bool ethConnected: false
  property var ethDevices: []
  property var activeConnections: []
  property bool showPasswordPrompt: false
  property string pendingSsid: ""
  property string pendingSec: ""
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
  function openNetworkEditor() {
    root.execAndClose([root.binDir + "/asahi-launch", "nm-connection-editor"])
  }
  function rescanWifi() {
    Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"])
    Qt.callLater(quickNetworkRoot.scanWifi)
  }
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
    Qt.callLater(function() { if (ethCheck && !ethCheck.running) ethCheck.running = true })
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
    let targets = QuickModels.nmTargets(runnable, "")
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
    if (quickNetworkRoot.isTuhhTarget(target)) {
      quickNetworkRoot.launchTuhhVpn()
      return
    } else if (QuickModels.needsUsername(target) && target.hasUsername === false) {
      quickNetworkRoot.vpnError = "\"" + target.label + "\" has no username"
      quickNetworkRoot.vpnBusy = false
      quickNetworkRoot.vpnStage = ""
      return
    } else {
      vpnConnectProc.command = ["nmcli"].concat(target.args || [])
      quickNetworkRoot.vpnStatus = "Connecting to " + target.label + "…"
    }
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
    const key = quickNetworkRoot.vpnSummary + "|" + ext
    if (key === quickNetworkRoot.vpnIpKey && quickNetworkRoot.vpnPublicIp) return
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
    quickNetworkRoot.pendingSec = sec || ""
    if (!sec) { quickNetworkRoot.doConnect(ssid, null); return }
    savedCheckProc.targetSsid = ssid
    savedCheckProc.command = [
      "bash", "-c",
      "nmcli -g NAME connection show | grep -Fx " + root.shQuote(ssid) + " >/dev/null && echo saved || echo new"
    ]
    savedCheckProc.running = true
  }
  // Stays open (omarchy behavior): the row shows "Connecting…", failures
  // reopen the passphrase prompt with the reason instead of bailing to an
  // external editor.
  function doConnect(ssid, pass) {
    quickNetworkRoot.showPasswordPrompt = false
    quickNetworkRoot.passwordError = ""
    quickNetworkRoot.connectingSsid = ssid
    connectProc.targetSsid = ssid
    connectProc.usedPassword = !!(pass && pass.length)
    let cmd = "nmcli dev wifi connect " + root.shQuote(ssid)
    if (pass && pass.length) cmd += " password " + root.shQuote(pass)
    connectProc.command = ["bash", "-c", cmd]
    connectProc.running = true
  }

  function scanWifi() {
    // Radio off (or still settling after a toggle): no point scanning —
    // repeated failed scans while off were a major source of list churn.
    if (quickNetworkRoot.wifiEnabled && !radioSettle.running) {
      quickNetworkRoot.wifiScanning = true
      wifiListProc.command = quickNetworkRoot.wifiDevice
        ? ["nmcli", "-w", "8", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,FREQ", "dev", "wifi", "list", "ifname", quickNetworkRoot.wifiDevice, "--rescan", "yes"]
        : ["nmcli", "-w", "8", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,FREQ", "dev", "wifi", "list", "--rescan", "yes"]
      if (!wifiListProc.running) wifiListProc.running = true
    }
    if (typeof wifiProc !== 'undefined' && wifiProc) wifiProc.running = true
    if (typeof wifiPowerCheck !== 'undefined' && wifiPowerCheck) wifiPowerCheck.running = true
    if (typeof ethCheck !== 'undefined' && ethCheck) ethCheck.running = true
    if (typeof activeConnProc !== 'undefined' && activeConnProc) activeConnProc.running = true
    if (typeof savedWifiProc !== 'undefined' && savedWifiProc && !savedWifiProc.running) savedWifiProc.running = true
    quickNetworkRoot.refreshVpn()
  }

  Process {
    id: wifiProc
    command: [root.binDir + "/asahi-network"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse((text || "").trim() || "{}")
          quickNetworkRoot.wifiLabel = (d.text || "WiFi").replace(/<[^>]*>/g, "")
          quickNetworkRoot.wifiTooltip = d.tooltip || ""
          quickNetworkRoot.wifiChecked = true
          const m = (d.tooltip || "").match(/^Connected to (.+)$/m)
          if (m) quickNetworkRoot.currentWifiSsid = m[1].trim()
        } catch (_) {}
      }
    }
  }
  Process {
    id: wifiListProc
    command: ["true"]  // set dynamically in scanWifi before .running (avoids init-time wifiDevice + ensures reactive)
    stdout: StdioCollector { onStreamFinished: {
        quickNetworkRoot.wifiScanning = false
        const lines = (text || "").trim().split("\n").filter(l => l)
        const out = []; const seen = {}
        for (const line of lines) {
          const p = QuickModels.nmcliFields(line)
          if (p.length < 3) continue
          const ssid = p[1] || ""
          if (!ssid || seen[ssid]) continue
          seen[ssid] = true
          const inUse = p[0] === "*"
          const isCurrent = inUse || (ssid === quickNetworkRoot.currentWifiSsid)
          out.push({
            ssid: ssid, signal: parseInt(p[2])||0, sec: p[3]||"", active: isCurrent,
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
    stderr: StdioCollector {}
    onExited: (code) => { if (code !== 0) quickNetworkRoot.wifiScanning = false }
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
    id: activeConnProc
    command: ["nmcli", "-t", "-f", "TYPE,NAME,DEVICE", "connection", "show", "--active"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = (text || "").trim().split("\n").filter(function(l) { return l.length > 0 })
        const out = []
        for (let i = 0; i < lines.length; i++) {
          const p = QuickModels.nmcliFields(lines[i])
          // lo is always "active" in NM — noise, not a connection.
          if (p.length >= 3 && p[0] !== "loopback")
            out.push({ type: p[0] === "802-11-wireless" ? "wifi" : (p[0] === "802-3-ethernet" ? "ethernet" : p[0]), name: p[1] || "", device: p[2] || "" })
        }
        quickNetworkRoot.activeConnections = out
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
      } else if (quickNetworkRoot.pendingSec) {
        // A failed secured attempt leaves a half-baked profile behind that
        // would silently reuse the bad passphrase on retry — drop it and
        // re-open the prompt with the reason (omarchy's reprompt path).
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", connectProc.targetSsid])
        quickNetworkRoot.pendingSsid = connectProc.targetSsid
        quickNetworkRoot.passwordError = connectProc.usedPassword ? "Wrong password — try again" : "Passphrase required"
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

  Timer { interval: 6000; running: root.quickMode && root.quickPaneKey === "network"; repeat: true; triggeredOnStart: true; onTriggered: quickNetworkRoot.scanWifi() }
  Timer { interval: 1500; running: root.quickMode && root.quickPaneKey === "network"; repeat: true; triggeredOnStart: true; onTriggered: quickNetworkRoot.sampleThroughput() }
  Timer { interval: 4000; running: root.quickMode && root.quickPaneKey === "network"; repeat: true; triggeredOnStart: true; onTriggered: { if (!pingProc.running) pingProc.running = true } }

  Component.onCompleted: Qt.callLater(quickNetworkRoot.scanWifi)

  // ---- M3 building blocks (caelestia look) ----
  readonly property var activeNet: (quickNetworkRoot.wifiNetworks || []).find(function(n) { return n.active }) || null
  readonly property var signalGlyphs: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
  function signalGlyph(pct) { return quickNetworkRoot.signalGlyphs[Math.max(0, Math.min(4, Math.ceil(pct / 20) - 1))] }
  // asahi-network tooltip lines minus the SSID + signal (both shown in the title row).
  // Blank rows before the first answer hold the grid's usual height.
  readonly property var wifiFacts: !quickNetworkRoot.wifiChecked ? [" ", " ", " ", " ", " "]
    : (quickNetworkRoot.wifiTooltip || "").split("\n")
      .filter(function(l) { return l.trim() && !/^(Connected to|Signal:)/.test(l) })

  component Card: Rectangle {
    radius: Style.menuRadiusLg
    color: Style.m3container
  }

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
        font.family: quickNetworkRoot.root.uiFont; font.pixelSize: quickNetworkRoot.root.fontPx(12); anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: parent.parent.label; color: parent.parent.fg; font.weight: Font.Medium
        font.family: quickNetworkRoot.root.uiSans; font.pixelSize: quickNetworkRoot.root.fontPx(10); anchors.verticalCenter: parent.verticalCenter
      }
    }
    MouseArea { id: pillMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }

  // Stats chip: icon + Medium label in a tonal pill; optional click (public IP copies).
  component Chip: Rectangle {
    property string icon
    property string label
    property color bg: Style.m3secondaryContainer
    property color fg: Style.m3onSurface
    property bool clickable: false
    property int fixedWidth: 0
    signal clicked()
    implicitWidth: fixedWidth > 0 ? fixedWidth : chipRow.implicitWidth + 18
    implicitHeight: 28
    width: implicitWidth
    radius: Style.menuRadiusFull
    color: clickable && chipMa.containsMouse ? Qt.lighter(bg, 1.15) : bg
    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: 6
      Text {
        text: parent.parent.icon; color: parent.parent.fg
        font.family: quickNetworkRoot.root.uiFont; font.pixelSize: quickNetworkRoot.root.fontPx(11); anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: parent.parent.label; color: parent.parent.fg; font.weight: Font.Medium
        font.family: quickNetworkRoot.root.uiSans; font.pixelSize: quickNetworkRoot.root.fontPx(10); anchors.verticalCenter: parent.verticalCenter
      }
    }
    MouseArea {
      id: chipMa; anchors.fill: parent; hoverEnabled: parent.clickable; enabled: parent.clickable
      cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked()
    }
  }

  // Round link / link_off button: filled m3primary while connected (caelestia).
  component LinkBtn: Rectangle {
    property bool active: false
    property bool busy: false
    signal clicked()
    width: 32; height: 32; radius: 16
    color: active ? Style.m3primary : (linkMa.containsMouse ? Style.m3stateHover : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }
    Text {
      anchors.centerIn: parent
      text: parent.busy ? "󰔟" : (parent.active ? "󰌷" : "󰌸")
      color: parent.active ? Style.m3onPrimary : Style.m3onSurface
      font.family: quickNetworkRoot.root.uiFont; font.pixelSize: quickNetworkRoot.root.fontPx(14)
    }
    MouseArea { id: linkMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
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
      font.family: quickNetworkRoot.root.uiFont; font.pixelSize: quickNetworkRoot.root.fontPx(13)
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
            M3Switch { checked: quickNetworkRoot.wifiEnabled; onToggled: quickNetworkRoot.toggleWifi() }
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
                  bg: quickNetworkRoot.wifiQrPath ? Style.m3primaryContainer : Style.m3secondaryContainer
                  onClicked: quickNetworkRoot.toggleWifiQr()
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
          // Active NM connections (type · name · device).
          Repeater {
            model: quickNetworkRoot.activeConnections || []
            delegate: RowLayout {
              Layout.fillHeight: false
              required property var modelData
              Layout.fillWidth: true
              spacing: 6
              Text { text: "󰒢"; color: Style.green; font.family: root.uiFont; font.pixelSize: root.fontPx(10) }
              Secondary {
                Layout.fillWidth: true
                text: (modelData.name || "") + "  ·  " + (modelData.device || "") + "  ·  " + (modelData.type || "")
              }
            }
          }
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
            text: "󰦝"; color: QuickModels.activeNmProfile(quickNetworkRoot.vpnProfiles) ? Style.m3primary : Style.m3onSurfaceVariant
            font.family: root.uiFont; font.pixelSize: root.fontPx(15)
          }
          CardTitle { text: "VPN" }
          Secondary {
            text: quickNetworkRoot.vpnSummary
            color: QuickModels.activeNmProfile(quickNetworkRoot.vpnProfiles) ? Style.green : Style.m3onSurfaceVariant
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
              text: modelData.connection || modelData.device; color: Style.m3onSurface
              font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.Medium; elide: Text.ElideRight
            }
            Secondary { Layout.fillWidth: true; text: "External tunnel  ·  " + (modelData.device || "") }
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
          Text { text: "󰖩"; color: Style.m3onSurfaceVariant; font.family: root.uiFont; font.pixelSize: root.fontPx(15) }
          CardTitle { text: "Networks" }
          Secondary {
            text: {
              const n = (quickNetworkRoot.wifiNetworks || []).length
              if (!quickNetworkRoot.wifiEnabled) return ""
              return quickNetworkRoot.wifiScanning && n === 0 ? "Scanning…" : n + " network" + (n === 1 ? "" : "s") + " available"
            }
          }
          Item { Layout.fillWidth: true }
          IconBtn { icon: "󰑐"; onClicked: { quickNetworkRoot.scanWifi(); if (ethCheck && !ethCheck.running) ethCheck.running = true } }
          Pill {
            icon: quickNetworkRoot.wifiScanning ? "󰔟" : "󰤨"; label: "Rescan networks"
            bg: Style.m3primaryContainer
            onClicked: quickNetworkRoot.rescanWifi()
          }
        }
        ListView {
          id: netList
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          spacing: 2
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: Menu.MenuScrollBar { id: netScroll }
          model: quickNetworkRoot.wifiNetworks || []
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
          Secondary {
            visible: (quickNetworkRoot.wifiNetworks || []).length === 0
            anchors.centerIn: parent
            text: !quickNetworkRoot.wifiEnabled ? "Turn Wi-Fi on to see networks"
              : (quickNetworkRoot.wifiScanning ? "Scanning…" : "No networks found. Rescan.")
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
    color: Qt.rgba(0, 0, 0, 0.55)
    visible: quickNetworkRoot.showPasswordPrompt
    onVisibleChanged: if (visible) { netPassInput.text = ""; netPassInput.forceActiveFocus() }
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
            onAccepted: quickNetworkRoot.doConnect(quickNetworkRoot.pendingSsid, text)
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
