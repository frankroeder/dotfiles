import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import "../../"
import "../wallpaper" as WallpaperModule
import "../menu" as Menu
import "." as FeatureMenu

pragma ComponentBehavior: Bound

Scope {
  id: root

  property bool shouldShow: false
  property var featureScreen: null
  property string mode: "hub"  // hub | wallpaper | screenshots | media | network | monitors | temp | bluetooth | power
  property string pendingConfirm: ""
  property bool bluetoothPowered: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
  // Manual Media page Cava panel height.
  property int mediaCavaHeight: 260
  readonly property int uiFontBump: 2
  readonly property real uiFontScale: 1.2
  readonly property string uiFont: "Hack Nerd Font"
  readonly property color menuTileBg: Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.03)
  readonly property color menuDangerBg: Qt.rgba(Style.red.r, Style.red.g, Style.red.b, 0.16)
  readonly property color menuSuccessBg: Qt.rgba(Style.green.r, Style.green.g, Style.green.b, 0.16)
  function fontPx(size) { return Math.round(size * root.uiFontScale) }

  readonly property int menuWidth: {
    const s = root.featureScreen || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    return s ? Math.min(1180, Math.round(s.width * 0.94)) : 1120
  }
  readonly property int menuHeight: {
    const s = root.featureScreen || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    return s ? Math.min(820, Math.round(s.height * 0.88)) : 780
  }
  readonly property int hubMenuHeight: {
    const s = root.featureScreen || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    return s ? Math.min(720, Math.round(s.height * 0.80)) : 660
  }

  readonly property string modeHeaderSubtitle: {
    if (root.mode === "hub") return "DASHBOARD"
    if (root.mode === "wallpaper") return "WALLPAPERS"
    if (root.mode === "screenshots") return "SCREENSHOTS"
    if (root.mode === "media") return "MEDIA"
    if (root.mode === "network") return "NETWORK"
    if (root.mode === "monitors") return "MONITORS"
    if (root.mode === "temp") return "TEMPERATURES"
    if (root.mode === "bluetooth") return "BLUETOOTH"
    if (root.mode === "power") return "POWER"
    return "FEATURES"
  }

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property string shotDir: Quickshell.env("HOME") + "/screenshots"

  // Live wifi status for overview tile (enriched for native menu like NetworkPopupWindow)
  property string wifiLabel: "WiFi"
  property string wifiTooltip: ""
  property string netDevice: ""
  Process {
    id: wifiProc
    command: [binDir + "/asahi-network"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(text.trim())
          root.wifiLabel = (d.text || "WiFi").replace(/<[^>]*>/g, "")
          root.wifiTooltip = d.tooltip || ""
          root.netDevice = d.device || ""
          const m = (d.tooltip || "").match(/^Connected to (.+)$/m)
          if (m) root.currentWifiSsid = m[1].trim()
        } catch (_) {}
      }
    }
  }
  Timer { interval: 7000; running: shouldShow; repeat: true; onTriggered: wifiProc.running = true }

  // Sidebar live telemetry data
  property int sidebarCpu: 0
  property int sidebarMem: 0
  property int sidebarBat: 100
  property string sidebarBatStatus: "Discharging"
  property real sidebarCpuPrevIdle: -1
  property real sidebarCpuPrevTotal: -1

  Process {
    id: sidebarProc
    command: [
      "sh", "-c",
      "awk '/^cpu / { idle=$5+$6; total=0; for (i=2; i<=NF; i++) total+=$i; print idle; print total }' /proc/stat; " +
      "awk '/MemTotal:/ { total=$2 } /MemAvailable:/ { available=$2 } END { if (total > 0) print (total - available) * 100 / total; else print 0 }' /proc/meminfo; " +
      "for p in /sys/class/power_supply/macsmc-battery /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1 /sys/class/power_supply/*; do " +
      "[ -r \"$p/type\" ] || continue; [ \"$(cat \"$p/type\")\" = Battery ] || continue; " +
      "case \"$p\" in *hid-*) continue;; esac; [ -r \"$p/capacity\" ] || continue; " +
      "cat \"$p/capacity\"; cat \"$p/status\" 2>/dev/null || echo Unknown; exit; done; echo 100; echo Unknown"
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const lines = text.trim().split("\n")
          if (lines.length >= 5) {
            const idle = parseFloat(lines[0])
            const total = parseFloat(lines[1])
            if (root.sidebarCpuPrevTotal >= 0 && total > root.sidebarCpuPrevTotal) {
              const totalDelta = total - root.sidebarCpuPrevTotal
              const idleDelta = idle - root.sidebarCpuPrevIdle
              root.sidebarCpu = Math.max(0, Math.min(100, Math.round(100 * (totalDelta - idleDelta) / totalDelta)))
            }
            root.sidebarCpuPrevIdle = idle
            root.sidebarCpuPrevTotal = total
            root.sidebarMem = Math.round(parseFloat(lines[2]) || 0)
            const bat = parseFloat(lines[3])
            root.sidebarBat = Number.isFinite(bat) ? Math.max(0, Math.min(100, Math.round(bat))) : 100
            root.sidebarBatStatus = lines[4].trim()
          }
        } catch (_) {}
      }
    }
  }
  Timer {
    interval: 2000; running: shouldShow; repeat: true; triggeredOnStart: true
    onTriggered: if (!sidebarProc.running) sidebarProc.running = true
  }

  // Embedded wifi (native, no popup) - enriched like NetworkPopupWindow
  property var wifiNetworks: []
  property bool wifiEnabled: true
  property string currentWifiSsid: ""
  property bool wifiScanning: false
  property string wifiDevice: ""
  property real netRxSpeed: 0
  property real netTxSpeed: 0
  property real netPreviousRxBytes: -1
  property real netPreviousTxBytes: -1
  property real netPreviousSampleMs: 0
  property string netSpeedDevice: ""
  property var netRxHistory: []
  property var netTxHistory: []
  readonly property int netHistoryLimit: 60

  function formatNetSpeed(bytes) {
    let unit = "K"
    let value = bytes / 1024
    if (value >= 1024) {
      unit = "M"
      value /= 1024
    }
    if (value >= 1024) {
      unit = "G"
      value /= 1024
    }
    return Math.min(999, Math.round(value)).toString().padStart(3, "0") + " " + unit + "/s"
  }
  function resetNetSpeed(device) {
    root.netSpeedDevice = device || ""
    root.netRxSpeed = 0
    root.netTxSpeed = 0
    root.netPreviousRxBytes = -1
    root.netPreviousTxBytes = -1
    root.netPreviousSampleMs = 0
    root.netRxHistory = []
    root.netTxHistory = []
  }
  function activeNetDevice() {
    return root.netDevice || root.wifiDevice || root.ethDevice || ""
  }
  function refreshNetSpeed() {
    const dev = root.activeNetDevice()
    if (!dev || netSpeedProc.running) return
    if (dev !== root.netSpeedDevice) root.resetNetSpeed(dev)
    netSpeedProc.command = [
      "cat",
      "/sys/class/net/" + dev + "/statistics/rx_bytes",
      "/sys/class/net/" + dev + "/statistics/tx_bytes"
    ]
    netSpeedProc.running = true
  }
  function updateNetSpeed(out) {
    const values = (out || "").trim().split(/\s+/)
    if (values.length < 2) return
    const now = Date.now()
    const rxBytes = Number(values[0])
    const txBytes = Number(values[1])
    const seconds = (now - root.netPreviousSampleMs) / 1000

    if (root.netPreviousSampleMs > 0 && seconds > 0) {
      root.netRxSpeed = Math.max(0, (rxBytes - root.netPreviousRxBytes) / seconds)
      root.netTxSpeed = Math.max(0, (txBytes - root.netPreviousTxBytes) / seconds)
      const rx = root.netRxHistory.slice(-root.netHistoryLimit + 1)
      const tx = root.netTxHistory.slice(-root.netHistoryLimit + 1)
      rx.push(root.netRxSpeed)
      tx.push(root.netTxSpeed)
      root.netRxHistory = rx
      root.netTxHistory = tx
    }

    root.netPreviousRxBytes = rxBytes
    root.netPreviousTxBytes = txBytes
    root.netPreviousSampleMs = now
  }
  function scanWifi() {
    wifiScanning = true
    wifiProc.running = true
    if (!wifiListProc.running) wifiListProc.running = true
    wifiPowerCheck.running = true
    ethCheck.running = true
  }
  Process {
    id: wifiListProc
    command: root.wifiDevice
      ? ["nmcli", "-w", "8", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "ifname", root.wifiDevice, "--rescan", "yes"]
      : ["nmcli", "-w", "8", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.wifiScanning = false
        const lines = text.trim().split("\n").filter(l => l)
        const out = []
        const seen = {}
        for (const line of lines) {
          const p = line.split(":")
          if (p.length < 3) continue
          const ssid = p[1] || ""
          if (!ssid || seen[ssid]) continue
          seen[ssid] = true
          const inUse = p[0] === "*"
          const isCurrent = inUse || (ssid === root.currentWifiSsid)
          out.push({ ssid, signal: parseInt(p[2])||0, sec: p[3]||"", active: isCurrent })
        }
        const ai = out.findIndex(n => n.active)
        if (ai > 0) { const a = out.splice(ai, 1)[0]; out.unshift(a) }
        const next = out.slice(0, 12)
        if (next.length === 1 && next[0].active && root.wifiNetworks.length > 1) {
          root.wifiNetworks = [next[0]].concat(root.wifiNetworks.filter(n => n.ssid !== next[0].ssid)).slice(0, 12)
        } else {
          root.wifiNetworks = next
        }
      }
    }
  }

  Process {
    id: wifiPowerCheck
    command: ["nmcli", "radio", "wifi"]
    stdout: StdioCollector {
      onStreamFinished: { root.wifiEnabled = text.trim().indexOf("enabled") !== -1 }
    }
  }
  Timer {
    interval: 6000; running: shouldShow && root.mode === "network"; repeat: true
    onTriggered: root.scanWifi()
  }

  Process {
    id: netSpeedProc
    command: ["true"]
    stdout: StdioCollector { onStreamFinished: root.updateNetSpeed(text) }
  }
  Timer {
    interval: 1000; running: shouldShow && root.mode === "network"; repeat: true; triggeredOnStart: true
    onTriggered: root.refreshNetSpeed()
  }

  // fastfetch for Dashboard (more system info like requested; --logo none keeps it compact)
  property string fastfetchOut: ""
  Process {
    id: ffProc
    command: [
      "fastfetch",
      "--logo", "none",
      "--structure", "OS:Host:Kernel:Uptime:Packages:Shell:Display:WM:Terminal:TerminalFont:Disk:LocalIP:Battery:Locale",
      "--config", "none"
    ]
    stdout: StdioCollector { onStreamFinished: root.fastfetchOut = text.trim() }
  }
  Timer { interval: 12000; running: shouldShow && root.mode === "hub"; repeat: true; triggeredOnStart: true; onTriggered: ffProc.running = true }

  // LAN/ethernet status + control (for Network tab, LAN-only cases)
  property string ethDevice: ""
  property string ethState: ""
  property string ethConnection: ""
  property bool ethConnected: false
  property var ethDevices: []
  Process {
    id: ethCheck
    command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        const devices = []
        const lines = text.trim().split("\n").filter(l => l)
        for (const line of lines) {
          const p = line.split(":")
          if (p[1] === "wifi" && !root.wifiDevice) root.wifiDevice = p[0] || ""
          if (p[1] !== "ethernet") continue
          devices.push({ device: p[0] || "", state: p[2] || "", connection: p.slice(3).join(":") || "" })
        }
        root.ethDevices = devices
        const active = devices.find(d => d.state === "connected") || devices[0] || null
        root.ethDevice = active ? active.device : ""
        root.ethState = active ? active.state : ""
        root.ethConnection = active ? active.connection : ""
        root.ethConnected = active ? active.state === "connected" : false
      }
    }
  }

  // Monitors state (hyprctl JSON for viz + controls)
  property var monitorList: []
  property int monitorVersion: 0
  property string monitorStatus: ""
  Process {
    id: monitorsProc
    command: ["hyprctl", "monitors", "all", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.monitorList = JSON.parse(text.trim() || "[]")
        } catch(_) {
          root.monitorList = []
        }
        root.monitorVersion = (root.monitorVersion + 1) % 1000
      }
    }
  }
  Timer { id: monitorRefreshDelay; interval: 900; onTriggered: monitorsProc.running = true }
  Timer {
    interval: 2500; running: shouldShow && root.mode === "monitors"; repeat: true
    onTriggered: if (!monitorsProc.running) monitorsProc.running = true
  }
  Process {
    id: monitorActionProc
    stdout: StdioCollector { id: monitorStdout }
    stderr: StdioCollector { id: monitorStderr }
    onExited: (code) => {
      const out = (monitorStdout.text + monitorStderr.text).trim()
      if (code === 0) {
        root.monitorStatus = out || "Monitor command applied"
        monitorRefreshDelay.restart()
        return
      }
      root.monitorStatus = out || ("Monitor command failed: " + code)
      monitorRefreshDelay.restart()
    }
  }
  function luaString(value) {
    return "\"" + String(value || "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
  }
  function monitorMode(m) {
    if (!m) return "preferred"
    const rr = m.refreshRate ? "@" + Number(m.refreshRate).toFixed(3) : ""
    return (m.width || 0) + "x" + (m.height || 0) + rr
  }
  function monitorPrimary() {
    const mons = root.monitorList || []
    return mons.find(m => m.name === "eDP-1") || mons.find(m => m.focused) || mons[0] || null
  }
  function monitorLogicalWidth(m) { return (m.width || 1920) / Math.max(0.25, m.scale || 1) }
  function monitorLogicalHeight(m) { return (m.height || 1080) / Math.max(0.25, m.scale || 1) }
  function mirrorMonitors() {
    const primary = monitorPrimary()
    if (!primary) {
      root.monitorStatus = "No primary monitor"
      return
    }
    const calls = []
    for (const m of root.monitorList || []) {
      if (!m || m.name === primary.name || m.disabled) continue
      calls.push(
        "hl.monitor({ output = " + luaString(m.name)
        + ", mode = \"preferred\", position = \"0x0\", scale = " + (m.scale || 1)
        + ", mirror = " + luaString(primary.name) + " })"
      )
    }
    if (!calls.length) {
      root.monitorStatus = "No external monitor to mirror"
      return
    }
    root.monitorStatus = "Mirroring to " + primary.name + "..."
    monitorActionProc.command = ["hyprctl", "eval", calls.join("\n")]
    monitorActionProc.running = true
  }
  function extendMonitors() {
    root.monitorStatus = "Reloading monitors.lua..."
    monitorActionProc.command = ["hyprctl", "reload"]
    monitorActionProc.running = true
  }
  function externalOnlyMonitors() {
    const external = (root.monitorList || []).find(m => m && m.name !== "eDP-1")
    if (!external) {
      root.monitorStatus = "No external monitor found"
      return
    }
    root.monitorStatus = "Switching to external only..."
    monitorActionProc.command = ["hyprctl", "eval",
      "hl.monitor({ output = " + luaString(external.name) + ", mode = \"preferred\", position = \"0x0\", scale = " + (external.scale || 1) + " })\n" +
      "hl.monitor({ output = \"eDP-1\", disabled = true })"
    ]
    monitorActionProc.running = true
  }
  function rescanMonitors() {
    root.monitorStatus = "Refreshing monitor list..."
    if (!monitorsProc.running) monitorsProc.running = true
  }

  // Temperatures (full like asahi-temperature script)
  property string tempOutput: ""
  property var tempSensors: []
  property var tempGroups: []
  property var hottestSensor: null
  property string tempUpdated: ""
  Process {
    id: tempProc
    command: [binDir + "/asahi-temperature"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.tempOutput = text.trim()
        root.parseTemperatures(root.tempOutput)
        root.tempUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
      }
    }
  }
  Timer {
    interval: 2500; running: shouldShow && root.mode === "temp"; repeat: true; triggeredOnStart: true
    onTriggered: if (!tempProc.running) tempProc.running = true
  }
  function parseTemperatures(out) {
    const sensors = []
    let groupName = ""
    let groupPath = ""
    let last = null
    const lines = (out || "").split("\n")
    for (const line of lines) {
      if (line.indexOf("Hottest:") === 0) break
      const gm = line.match(/^>>> (.+?) \((.+)\)$/)
      if (gm) {
        groupName = gm[1]
        groupPath = gm[2]
        continue
      }
      const sm = line.match(/^\s*(\S+)\s+(.+?)\s+(-?\d+(?:\.\d+)?)°C\s+(.+)$/)
      if (sm) {
        const keyName = groupName || sm[1]
        const keyPath = groupPath || sm[4].trim().replace(/\/temp[^/]+$/, "")
        last = {
          group: keyName,
          groupPath: keyPath,
          groupKey: keyName + "|" + keyPath,
          name: sm[1],
          label: sm[2].trim(),
          displayLabel: sm[2].trim(),
          value: Number(sm[3]),
          path: sm[4].trim(),
          desc: ""
        }
        sensors.push(last)
        continue
      }
      const dm = line.match(/^\s{4}(.+)$/)
      if (dm && last) last.desc = dm[1].trim()
    }

    const groups = []
    for (const sensor of sensors) {
      let g = groups.find(item => item.key === sensor.groupKey)
      if (!g) {
        g = { key: sensor.groupKey, name: sensor.group, path: sensor.groupPath, sensors: [], max: sensor.value, sum: 0 }
        groups.push(g)
      }
      g.sensors.push(sensor)
      g.max = Math.max(g.max, sensor.value)
      g.sum = (g.sum || 0) + sensor.value
    }
    for (const g of groups) {
      g.avg = g.sum / Math.max(1, g.sensors.length)
    }
    const groupNameMap = {
      "macsmc_hwmon": "SMC Sensors",
      "tas2764": "Speaker Amps",
      "macsmc_battery": "Battery",
      "nvme": "NVMe SSD"
    }
    const sourceCounts = {}
    for (const g of groups) sourceCounts[g.name] = (sourceCounts[g.name] || 0) + 1
    const sourceSeen = {}
    for (const g of groups) {
      const baseName = groupNameMap[g.name] || g.name
      sourceSeen[g.name] = (sourceSeen[g.name] || 0) + 1
      g.displayName = sourceCounts[g.name] > 1 ? (baseName + " " + sourceSeen[g.name]) : baseName

      const labelCounts = {}
      for (const s of g.sensors) labelCounts[s.label] = (labelCounts[s.label] || 0) + 1
      const labelSeen = {}
      for (const s of g.sensors) {
        labelSeen[s.label] = (labelSeen[s.label] || 0) + 1
        s.displayLabel = labelCounts[s.label] > 1 ? (s.label + " " + labelSeen[s.label]) : s.label
        s.groupDisplayName = g.displayName
      }

      const descs = g.sensors.map(s => s.desc || "").filter(d => d)
      let shared = null
      if (descs.length > 0) {
        shared = descs[0]
        for (let i = 1; i < descs.length; i++) if (descs[i] !== shared) { shared = null; break }
      }
      g.sharedDesc = shared
      for (const s of g.sensors) s.sharedDesc = g.sharedDesc
    }
    groups.sort((a, b) => b.max - a.max)
    root.tempSensors = sensors
    root.tempGroups = groups
    root.hottestSensor = sensors.reduce((best, sensor) => !best || sensor.value > best.value ? sensor : best, null)
  }
  function tempColor(value) {
    if (value >= 70) return Style.red
    if (value >= 55) return Style.orange
    if (value >= 45) return Style.yellow
    return Style.green
  }
  function tempPercent(value) {
    return Math.max(0, Math.min(1, (value - 25) / 55))
  }

  Process {
    id: bluetoothStatusProc
    command: ["sh", "-c", "bluetoothctl show 2>/dev/null || true"]
    stdout: StdioCollector {
      onStreamFinished: root.bluetoothPowered = text.indexOf("Powered: yes") !== -1
    }
  }
  Timer {
    id: bluetoothRefreshDelay
    interval: 500
    onTriggered: root.refreshBluetoothPower()
  }
  function refreshBluetoothPower() {
    if (!bluetoothStatusProc.running) bluetoothStatusProc.running = true
  }
  function toggleBluetoothPower() {
    const next = root.bluetoothPowered ? "off" : "on"
    Quickshell.execDetached([
      "sh", "-c",
      "if [ \"$1\" = on ]; then rfkill unblock bluetooth 2>/dev/null || true; fi; bluetoothctl power \"$1\"",
      "sh", next
    ])
    root.bluetoothPowered = !root.bluetoothPowered
    bluetoothRefreshDelay.restart()
  }

  // Media mode state (players via Mpris, audio via wpctl, cava viz)
  property var cavaValues: []
  property bool cavaRunning: false
  property string cavaStatus: "idle"
  property real cavaLastFrameMs: 0
  readonly property string cavaDir: "/tmp/quickshell-remix-" + (Quickshell.env("USER") || "user")
  readonly property string cavaConfigPath: cavaDir + "/cava.conf"
  readonly property string cavaFramePath: cavaDir + "/cava-frame"

  // Active MPRIS player (playing preferred)
  readonly property var activePlayer: {
    const list = Mpris.players && Mpris.players.values ? Mpris.players.values : []
    for (let i = 0; i < list.length; i++) if (list[i] && list[i].isPlaying) return list[i]
    return list.length > 0 ? list[0] : null
  }
  function enterMedia() {
    startCavaIfNeeded()
    pollAudioDefaults()
    refreshAudioMixer()
  }
  function startCavaIfNeeded() {
    if (cavaRunning) return
    cavaRunning = true
    cavaStatus = "starting"
    cavaLastFrameMs = 0
    root.cavaValues = []
    Quickshell.execDetached([
      "sh", "-c",
      "dir=$1; conf=$2; frame=$3; " +
      "if ! command -v cava >/dev/null 2>&1; then echo 'cava missing' >/tmp/quickshell-cava.err; exit 0; fi; " +
      "pkill -f \"cava -p $conf\" 2>/dev/null || true; " +
      "mkdir -p \"$dir\"; " +
      "printf '%s\n' " +
      "'[general]' 'bars=24' 'framerate=30' 'autosens=1' 'sensitivity=180' '' " +
      "'[input]' 'method=pulse' 'source=auto' '' " +
      "'[output]' 'method=raw' 'raw_target=/dev/stdout' 'data_format=ascii' 'ascii_max_range=100' " +
      "'bar_delimiter=59' 'frame_delimiter=10' > \"$conf\"; " +
      ": > \"$frame\"; " +
      "(stdbuf -oL cava -p \"$conf\" 2>/tmp/quickshell-cava.err | while IFS= read -r line; do printf '%s\n' \"$line\" > \"$frame\"; done) &",
      "sh", cavaDir, cavaConfigPath, cavaFramePath
    ])
  }
  function stopCava() {
    if (!cavaRunning) return
    cavaRunning = false
    cavaStatus = "idle"
    cavaLastFrameMs = 0
    Quickshell.execDetached(["pkill", "-f", "cava -p " + cavaConfigPath])
  }
  function updateCavaFrame(line) {
    line = (line || "").trim()
    if (!line) return
    const parts = line.split(/[;,\t ]+/)
    const vals = []
    for (let i=0; i<parts.length && i<24; i++) {
      const v = parseInt(parts[i]) || 0
      vals.push(Math.max(0, Math.min(100, v)))
    }
    while (vals.length < 24) vals.push(0)
    root.cavaValues = vals
    root.cavaLastFrameMs = Date.now()
    root.cavaStatus = vals.some(v => v > 0) ? "active" : "waiting for audio"
  }

  Process {
    id: cavaReadProc
    command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true", "sh", root.cavaFramePath]
    stdout: StdioCollector {
      onStreamFinished: root.updateCavaFrame(text)
    }
  }
  Timer {
    interval: 80
    running: root.shouldShow && root.mode === "media"
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (root.cavaRunning && root.cavaLastFrameMs > 0 && Date.now() - root.cavaLastFrameMs > 3000) root.cavaRunning = false
      if (!root.cavaRunning) root.startCavaIfNeeded()
      if (!cavaReadProc.running) cavaReadProc.running = true
    }
  }

  // Simple default sink/source volume (wpctl based, like asahi-audio)
  property string defaultSinkVol: "—"
  property string defaultSourceVol: "—"
  property bool defaultSinkMuted: false
  property bool defaultSourceMuted: false
  property var audioSinks: []
  property var audioSources: []
  property var audioStreams: []

  function parseWpVolume(line) {
    const value = (line || "").match(/[0-9.]+/)
    return value ? Math.round(parseFloat(value[0]) * 100) + "%" : "—"
  }
  function pollAudioDefaults() {
    audioPollProc.command = [
      "sh", "-c",
      "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null ; " +
      "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null"
    ]
    audioPollProc.running = true
  }
  Process {
    id: audioPollProc
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n")
        root.defaultSinkVol = root.parseWpVolume(lines[0])
        root.defaultSourceVol = root.parseWpVolume(lines[1])
        root.defaultSinkMuted = (lines[0] || "").indexOf("MUTED") !== -1
        root.defaultSourceMuted = (lines[1] || "").indexOf("MUTED") !== -1
      }
    }
  }
  function volAdjust(target, delta) {
    const targets = Array.isArray(target) ? target : [target]
    for (let i = 0; i < targets.length; i++) {
      Quickshell.execDetached(["wpctl", "set-volume", "-l", "1", String(targets[i]), delta > 0 ? "5%+" : "5%-"])
    }
    audioRefreshDelay.restart()
  }
  function toggleMute(target) {
    const targets = Array.isArray(target) ? target : [target]
    for (let i = 0; i < targets.length; i++) {
      Quickshell.execDetached(["wpctl", "set-mute", String(targets[i]), "toggle"])
    }
    audioRefreshDelay.restart()
  }
  function refreshAudioMixer() {
    if (!audioMixerProc.running) audioMixerProc.running = true
  }
  function setAudioDefault(id) {
    Quickshell.execDetached(["wpctl", "set-default", String(id)])
    audioRefreshDelay.restart()
  }
  function parseAudioNode(line) {
    const m = line.match(/^\s*[│├└]?\s*(\*)?\s*(\d+)\.\s+(.+?)(?:\s+\[([^\]]+)\])?\s*$/)
    if (!m) return null
    const meta = m[4] || ""
    const vol = meta.match(/vol:\s*([0-9.]+)/)
    return {
      active: m[1] === "*",
      id: m[2],
      name: m[3].trim(),
      meta: meta,
      targets: [],
      volume: vol ? Math.round(parseFloat(vol[1]) * 100) + "%" : "",
      muted: meta.indexOf("MUTED") !== -1
    }
  }
  function refreshAudioStreamVolumes() {
    if (audioStreamVolumeProc.running || root.audioStreams.length === 0) return
    const cmds = []
    for (let i = 0; i < root.audioStreams.length; i++) {
      const id = String(root.audioStreams[i].id)
      cmds.push("printf '" + id + " '; wpctl get-volume " + id + " 2>/dev/null || printf 'Volume: ?\\n'")
    }
    audioStreamVolumeProc.command = ["sh", "-c", cmds.join("; ")]
    audioStreamVolumeProc.running = true
  }
  function applyAudioStreamVolumes(out) {
    const volumes = {}
    for (const line of (out || "").split("\n")) {
      const m = line.match(/^(\d+)\s+Volume:\s+([0-9.]+)(.*)$/)
      if (!m) continue
      volumes[m[1]] = {
        volume: Math.round(parseFloat(m[2]) * 100) + "%",
        muted: m[3].indexOf("MUTED") !== -1
      }
    }

    const streams = []
    for (let i = 0; i < root.audioStreams.length; i++) {
      const item = root.audioStreams[i]
      const state = volumes[item.id]
      streams.push({
        active: item.active,
        id: item.id,
        name: item.name,
        meta: item.meta,
        targets: item.targets,
        volume: state ? state.volume : item.volume,
        muted: state ? state.muted : item.muted
      })
    }
    root.audioStreams = streams
  }
  function parseAudioStatus(out) {
    const sinks = []
    const sources = []
    const streams = []
    let lastStream = null
    let inAudio = false
    let section = ""

    for (const line of (out || "").split("\n")) {
      const trimmed = line.trim()
      if (trimmed === "Audio") {
        inAudio = true
        section = ""
        continue
      }
      if (trimmed === "Video" || trimmed === "Settings") {
        inAudio = false
        section = ""
        continue
      }
      if (!inAudio) continue
      if (trimmed.indexOf("Sinks:") !== -1) { section = "sink"; lastStream = null; continue }
      if (trimmed.indexOf("Sources:") !== -1) { section = "source"; lastStream = null; continue }
      if (trimmed.indexOf("Streams:") !== -1) { section = "stream"; lastStream = null; continue }
      if (trimmed.indexOf("Filters:") !== -1) { section = "filter"; lastStream = null; continue }
      if (trimmed.indexOf("Devices:") !== -1) { section = ""; lastStream = null; continue }

      const item = parseAudioNode(line)
      if (!item) continue
      if (section === "sink" || (section === "filter" && item.meta.indexOf("Audio/Sink") !== -1)) sinks.push(item)
      else if (section === "source" || (section === "filter" && item.meta.indexOf("Audio/Source") !== -1)) sources.push(item)
      else if (section === "stream" || (section === "filter" && item.meta.indexOf("Stream/") !== -1)) {
        if (item.name.indexOf(">") === -1) {
          lastStream = item
          streams.push(item)
        } else if (lastStream) {
          lastStream.targets.push(item.id)
        }
      }
    }

    root.audioSinks = sinks
    root.audioSources = sources
    root.audioStreams = streams
    root.refreshAudioStreamVolumes()
  }
  Process {
    id: audioMixerProc
    command: ["wpctl", "status"]
    stdout: StdioCollector { onStreamFinished: root.parseAudioStatus(text) }
  }
  Process {
    id: audioStreamVolumeProc
    stdout: StdioCollector { onStreamFinished: root.applyAudioStreamVolumes(text) }
  }
  Timer {
    id: audioRefreshDelay
    interval: 350
    onTriggered: {
      root.pollAudioDefaults()
      root.refreshAudioMixer()
    }
  }

  // Screenshots
  property var shots: []
  property string copiedShot: ""
  property string shotPreviewPath: ""
  Timer { id: copyClear; interval: 1200; onTriggered: copiedShot = "" }

  function scanShots() {
    shotScan.command = [
      "sh", "-c",
      "find \"" + shotDir + "\" -maxdepth 1 -type f -name 'screenshot-*.png' 2>/dev/null | " +
      "sort -r | head -200"
    ]
    shotScan.running = true
  }
  Process {
    id: shotScan
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n").filter(l => l.length > 0)
        root.shots = lines.map(p => ({ path: p, label: p.split("/").pop().replace("screenshot-", "").replace(".png", "") }))
      }
    }
  }

  function copyShot(p) {
    if (!p) return
    copiedShot = p
    copyClear.restart()
    Quickshell.execDetached([
      "sh", "-c",
      "notify-send -a screenshot -t 900 'Copied' \"$(basename \"$1\")\"; exec wl-copy --foreground -t image/png < \"$1\"",
      "sh", p
    ])
  }
  function openShot(p) { if (p) Quickshell.execDetached(["xdg-open", p]) }
  function previewShot(p) { if (p) root.shotPreviewPath = p }
  function deleteShot(p) {
    if (!p) return
    if (root.shotPreviewPath === p) root.shotPreviewPath = ""
    if (root.copiedShot === p) root.copiedShot = ""
    root.shots = root.shots.filter(s => s.path !== p)
    Quickshell.execDetached([
      "sh", "-c",
      "rm -f -- \"$1\" && notify-send -a screenshot -t 900 'Deleted' \"$(basename \"$1\")\"",
      "sh", p
    ])
    Qt.callLater(root.scanShots)
  }
  function capture(kind) {
    Quickshell.execDetached([binDir + "/asahi-cmd-screenshot", kind || "smart"])
    Qt.callLater(function() { Qt.callLater(scanShots) })
  }

  // Wallpaper Picker search & preview properties
  property string wallpaperSearchText: ""
  property string wallpaperPreviewPath: ""
  property var filteredWallpapers: {
    const q = wallpaperSearchText.toLowerCase()
    if (q === "") return WallpaperModule.WallpaperService.wallpapers
    return WallpaperModule.WallpaperService.wallpapers.filter(p => {
      const name = p.split("/").pop().toLowerCase()
      return name.includes(q)
    })
  }

  function activateMode(nextMode) {
    const wasMedia = root.mode === "media"
    root.mode = nextMode || "hub"
    root.pendingConfirm = ""
    if (wasMedia && root.mode !== "media") root.stopCava()
    if (root.mode === "screenshots" || root.mode === "hub") root.scanShots()
    else if (root.mode === "network") { root.scanWifi(); ethCheck.running = true }
    else if (root.mode === "media") root.enterMedia()
    else if (root.mode === "monitors") monitorsProc.running = true
    else if (root.mode === "temp") tempProc.running = true
    else if (root.mode === "bluetooth") root.refreshBluetoothPower()
  }

  function openFeatureMode(nextMode) {
    const mon = Hyprland.focusedMonitor
    featureScreen = mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
    shouldShow = true
    monitorStatus = ""
    wifiProc.running = true
    wifiPowerCheck.running = true
    ffProc.running = true
    ethCheck.running = true
    sidebarProc.running = true
    monitorsProc.running = true
    tempProc.running = true
    root.activateMode(nextMode || "hub")
  }
  function openFeature() {
    root.openFeatureMode("hub")
  }
  function closeFeature() {
    if (mode === "media") root.stopCava()
    shouldShow = false
    mode = "hub"
    pendingConfirm = ""
    shotPreviewPath = ""
    stopCava()
  }

  // Power actions
  function doLock() { Quickshell.execDetached(["loginctl", "lock-session"]); closeFeature() }
  function doSuspend() { Quickshell.execDetached(["sh", "-c", "loginctl lock-session && systemctl suspend"]); closeFeature() }  // s2idle (Asahi: hibernation not supported)
  function doReboot() {
    if (pendingConfirm === "reboot") { Quickshell.execDetached(["systemctl", "reboot"]); closeFeature() }
    else pendingConfirm = "reboot"
  }
  function doShutdown() {
    if (pendingConfirm === "shutdown") { Quickshell.execDetached(["systemctl", "poweroff"]); closeFeature() }
    else pendingConfirm = "shutdown"
  }
  function cancelConfirm() { pendingConfirm = "" }

  // Reload helpers
  function toggleScratch() { Quickshell.execDetached(["hyprctl", "dispatch", "togglespecialworkspace", "scratch"]); closeFeature() }
  function reloadBar() { Quickshell.execDetached([binDir + "/asahi-restart-app", "qs", "-c", "remix"]); closeFeature() }
  function reloadHyprland() { Quickshell.execDetached([binDir + "/asahi-reload-hyprland"]); closeFeature() }
  function restartHyprpaper() { Quickshell.execDetached([binDir + "/asahi-restart-app", "hyprpaper"]); closeFeature() }
  function restartHypridle() { Quickshell.execDetached([binDir + "/asahi-restart-app", "hypridle"]); closeFeature() }

  PanelWindow {
    id: panel
    visible: root.shouldShow
    focusable: true
    color: "transparent"
    screen: root.featureScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-feature"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    Menu.MenuBackdrop {
      reveal: root.shouldShow ? 1 : 0
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.closeFeature()
    }

    Menu.MenuCard {
      id: box
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height * 0.10
      width: root.menuWidth
      height: root.mode === "hub" ? root.hubMenuHeight : root.menuHeight
      cardMargin: 17

      Keys.onEscapePressed: {
        if (root.shotPreviewPath !== "") {
          root.shotPreviewPath = ""
        } else if (root.wallpaperPreviewPath !== "") {
          root.wallpaperPreviewPath = ""
        } else if (root.mode !== "hub") {
          root.mode = "hub"
          root.pendingConfirm = ""
        } else {
          root.closeFeature()
        }
      }
      focus: true

      RowLayout {
        anchors.fill: parent
        spacing: 0

        // LEFT NAVIGATION SIDEBAR (hidden for grid overview; the submenus are incorporated in the grid tiles)
        Rectangle {
          id: sidebar
          Layout.preferredWidth: 0
          Layout.fillHeight: true
          visible: false
          color: Style.menuBg
          topLeftRadius: 16
          bottomLeftRadius: 16

          // Right border divider
          Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Style.menuSep
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // User Profile slot
            RowLayout {
              spacing: 10
              Layout.fillWidth: true

              Rectangle {
                width: 38
                height: 38
                radius: 19
                color: root.menuTileBg
                border.width: 1
                border.color: Style.menuSep
                Text {
                  anchors.centerIn: parent
                  visible: distroIcon.source === ""
                  text: ""
                  font.pixelSize: root.fontPx(20 + root.uiFontBump)
                  color: Style.menuIndigo
                }
                IconImage {
                  id: distroIcon
                  anchors.centerIn: parent
                  width: 24
                  height: 24
                  source: Quickshell.iconPath("fedora-logo-icon", true)
                }
              }
              Column {
                Text {
                  text: "froeder"
                  color: Style.menuInk
                  font.pixelSize: root.fontPx(13 + root.uiFontBump)
                  font.bold: true
                  font.family: root.uiFont
                }
                Text {
                  text: "@asahi"
                  color: Style.menuInkDeep
                  font.pixelSize: root.fontPx(10 + root.uiFontBump)
                  font.family: root.uiFont
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Style.menuSep
            }

            // Navigation menu list
            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: 4

              Repeater {
                model: [
                  { key: "hub", icon: "󰕮", label: "Dashboard" },
                  { key: "wallpaper", icon: "󰸉", label: "Wallpapers" },
                  { key: "screenshots", icon: "󰹑", label: "Screenshots" },
                  { key: "media", icon: "󰝚", label: "Media" },
                  { key: "network", icon: "󰈀", label: "Network" },
                  { key: "monitors", icon: "󰍹", label: "Monitors" },
                  { key: "temp", icon: "󰔄", label: "Temperatures" },
                  { key: "bluetooth", icon: "󰂯", label: "Bluetooth" },
                  { key: "power", icon: "󰐥", label: "Power" }
                ]
                delegate: Rectangle {
                  id: navRow
                  required property var modelData
                  readonly property bool isActive: root.mode === modelData.key
                  readonly property bool isHovered: navMa.containsMouse

                  Layout.fillWidth: true
                  height: 34
                  radius: 8
                  color: isActive ? Style.menuRowSel : (isHovered ? Style.menuRowHi : "transparent")
                  border.width: 1
                  border.color: isActive ? Style.menuSeal : (isHovered ? Style.menuSep : "transparent")
                  scale: isHovered && !isActive ? 1.015 : 1.0

                  Behavior on color { ColorAnimation { duration: 150 } }
                  Behavior on border.color { ColorAnimation { duration: 150 } }
                  Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                  Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    radius: 1.5
                    color: Style.menuSeal
                    opacity: navRow.isActive ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: 150 } }
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                      text: modelData.icon
                      font.pixelSize: root.fontPx(14 + root.uiFontBump)
                      color: navRow.isActive ? Style.menuSeal : (navRow.isHovered ? Style.menuInk : Style.menuInkDeep)
                      font.family: root.uiFont
                      Layout.preferredWidth: 18
                      horizontalAlignment: Text.AlignHCenter
                      Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                      text: modelData.label
                      font.pixelSize: root.fontPx(11 + root.uiFontBump)
                      font.bold: navRow.isActive
                      color: navRow.isActive ? Style.menuInk : Style.menuInkDeep
                      font.family: root.uiFont
                      Behavior on color { ColorAnimation { duration: 150 } }
                    }
                  }

                  MouseArea {
                    id: navMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.activateMode(modelData.key)
                    }
                  }
                }
              }
              Item { Layout.fillHeight: true }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Style.menuSep
            }

            // Quick stats telemetry in sidebar
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 8

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                  Text { text: "CPU Load"; font.pixelSize: root.fontPx(10 + root.uiFontBump); color: Style.menuInkDeep; font.family: root.uiFont }
                  Item { Layout.fillWidth: true }
                  Text { text: root.sidebarCpu + "%"; font.pixelSize: root.fontPx(10 + root.uiFontBump); color: Style.orange || "#fab387"; font.family: root.uiFont; font.bold: true }
                }
                Rectangle {
                  Layout.fillWidth: true; height: 5; radius: 2.5; color: Style.menuControlBg
                  Rectangle { width: parent.width * root.sidebarCpu / 100; height: parent.height; radius: 2.5; color: Style.orange || "#fab387" }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                  Text { text: "Memory"; font.pixelSize: root.fontPx(10 + root.uiFontBump); color: Style.menuInkDeep; font.family: root.uiFont }
                  Item { Layout.fillWidth: true }
                  Text { text: root.sidebarMem + "%"; font.pixelSize: root.fontPx(10 + root.uiFontBump); color: Style.lavender || "#b4befe"; font.family: root.uiFont; font.bold: true }
                }
                Rectangle {
                  Layout.fillWidth: true; height: 5; radius: 2.5; color: Style.menuControlBg
                  Rectangle { width: parent.width * root.sidebarMem / 100; height: parent.height; radius: 2.5; color: Style.lavender || "#b4befe" }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                  Text { text: "Battery"; font.pixelSize: root.fontPx(10 + root.uiFontBump); color: Style.menuInkDeep; font.family: root.uiFont }
                  Item { Layout.fillWidth: true }
                  Text { text: root.sidebarBat + "%"; font.pixelSize: root.fontPx(10 + root.uiFontBump); color: Style.green || "#a6e3a1"; font.family: root.uiFont; font.bold: true }
                }
                Rectangle {
                  Layout.fillWidth: true; height: 5; radius: 2.5; color: Style.menuControlBg
                  Rectangle { width: parent.width * root.sidebarBat / 100; height: parent.height; radius: 2.5; color: root.sidebarBatStatus === "Charging" ? Style.yellow : (root.sidebarBat < 20 ? Style.red : Style.green) }
                }
              }
            }
          }
        }

        // RIGHT MAIN CONTENT PANE (transparent to use outer MenuCard bg like launcher/wp)
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: "transparent"
          radius: Style.menuRadius

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header Row - uniform with launcher + wallpaper manager using MenuHeader + mode subtitle
            RowLayout {
              Layout.fillWidth: true

              Menu.MenuHeader {
                Layout.fillWidth: true
                fontFamily: root.uiFont
                title: "ASAHI"
                subtitle: {
                  var s = root.modeHeaderSubtitle
                  if (root.mode === "screenshots" && root.shots.length) s += "  ·  " + root.shots.length + " RECENT"
                  return s
                }
              }

              Rectangle {
                id: closeButton
                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                color: closeMa.containsMouse ? Style.menuRowSel : Style.menuControlBg
                border.width: 1
                border.color: closeMa.containsMouse ? Style.menuSeal : Style.menuSep
                Text { anchors.centerIn: parent; text: "󰅖"; color: closeMa.containsMouse ? Style.menuSeal : Style.menuInkDeep; font.pixelSize: root.fontPx(16 + root.uiFontBump); font.family: root.uiFont }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
                MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closeFeature() }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Style.menuSep
            }

            // DYNAMIC VIEWS CONTAINER
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              // ----------------------------------------------------
              // OVERVIEW GRID (hub) - 3x3 feature tiles + lower CPU/RAM/BAT + latest shots.
              // Fully styled with Menu* + menu* palette + uiFont from launcher + wallpaper.
              // ----------------------------------------------------
              Grid {
                id: featureGrid
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                readonly property int tileHeight: Math.max(104, Math.min(128, Math.floor((parent.height - 220) / 3)))

                height: 3 * tileHeight + 2 * 12
                columns: 3
                rowSpacing: 12
                columnSpacing: 12
                visible: root.mode === "hub"

                Repeater {
                  model: [
                    { key: "hub", icon: "󰕮", label: "Dashboard", sub: "System & quick" },
                    { key: "wallpaper", icon: "󰸉", label: "Wallpapers", sub: "Browse & set" },
                    { key: "screenshots", icon: "󰹑", label: "Screenshots", sub: "Recent & capture" },
                    { key: "media", icon: "󰝚", label: "Media", sub: "Players & mixer" },
                    { key: "network", icon: "󰈀", label: "Network", sub: "WiFi & LAN" },
                    { key: "monitors", icon: "󰍹", label: "Monitors", sub: "Layout & control" },
                    { key: "temp", icon: "󰔄", label: "Temperatures", sub: "Sensors" },
                    { key: "bluetooth", icon: "󰂯", label: "Bluetooth", sub: "Devices" },
                    { key: "power", icon: "󰐥", label: "Power", sub: "Session" }
                  ]
                  delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.mode === modelData.key
                    width: (featureGrid.width - 2 * 12) / 3
                    height: featureGrid.tileHeight

                    Rectangle {
                      anchors.fill: parent
                      anchors.margins: 1
                      radius: Style.menuRadius
                      color: selected
                        ? Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.08)
                        : tileMouse.containsMouse
                          ? Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.05)
                          : Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.03)
                      border.color: selected ? Style.menuSeal : Style.menuSep
                      border.width: selected ? 2 : 1
                      Behavior on color { ColorAnimation { duration: 50 } }
                      Behavior on border.color { ColorAnimation { duration: 50 } }
                      Behavior on border.width { NumberAnimation { duration: 50 } }
                    }

                    Column {
                      anchors.centerIn: parent
                      width: parent.width - 18
                      spacing: 3

                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        color: selected ? Style.menuSeal : Style.menuInk
                        font.family: root.uiFont
                        font.pixelSize: root.fontPx(20)
                      }
                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: modelData.label.toUpperCase()
                        color: Style.menuInk
                        font.family: root.uiFont
                        font.pixelSize: root.fontPx(9)
                        font.letterSpacing: 1.4
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                      }
                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        text: modelData.sub
                        color: Style.menuInkDeep
                        font.family: root.uiFont
                        font.pixelSize: root.fontPx(8)
                        font.letterSpacing: 1
                        opacity: 0.85
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                      }
                    }

                    MouseArea {
                      id: tileMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.activateMode(modelData.key)
                    }
                  }
                }
              }

              // LOWER of grid (hub only): CPU/RAM/Battery (as previously) + latest 4 shots click-to-copy.
              // Styled with menu* colors, uiFont, radii, hovers, borders exactly like launcher rows + wallpaper tiles.
              Item {
                anchors.top: featureGrid.bottom
                anchors.topMargin: 14
                anchors.left: featureGrid.left
                anchors.right: featureGrid.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                visible: root.mode === "hub"

                RowLayout {
                  anchors.fill: parent
                  spacing: 12

                  // left: telemetry bars (CPU / RAM / Battery)
                  Rectangle {
                    Layout.preferredWidth: 218
                    Layout.fillHeight: true
                    radius: Style.menuRadius
                    color: Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.03)
                    border.color: Style.menuSep
                    border.width: 1

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 10
                      spacing: 6

                      Repeater {
                        model: [
                          { label: "CPU", key: "cpu" },
                          { label: "RAM", key: "ram" },
                          { label: "BAT", key: "bat" }
                        ]
                        delegate: Item {
                          required property var modelData
                          readonly property int meterValue: modelData.key === "cpu"
                            ? root.sidebarCpu
                            : (modelData.key === "ram" ? root.sidebarMem : root.sidebarBat)
                          readonly property color meterColor: modelData.key === "cpu"
                            ? Style.orange
                            : (modelData.key === "ram"
                              ? Style.lavender
                              : (root.sidebarBatStatus === "Charging" ? Style.yellow : (root.sidebarBat < 20 ? Style.red : Style.green)))
                          Layout.fillWidth: true
                          Layout.fillHeight: true

                          RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            spacing: 8

                            Text {
                              text: modelData.label
                              color: Style.menuInkDeep
                              font.pixelSize: root.fontPx(9)
                              font.family: root.uiFont
                              font.letterSpacing: 1.2
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                              text: meterValue + "%"
                              color: meterColor
                              font.pixelSize: root.fontPx(10)
                              font.family: root.uiFont
                              font.weight: Font.Medium
                            }
                          }

                          Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            height: 6
                            radius: 3
                            color: Style.menuControlBg
                            Rectangle {
                              width: parent.width * Math.max(0, Math.min(1, meterValue / 100))
                              height: parent.height
                              radius: 3
                              color: meterColor
                            }
                          }
                        }
                      }
                    }
                  }

                  // right: latest screenshots strip (4, click copy, right open; styled like wp tiles)
                  Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Style.menuRadius
                    color: Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.03)
                    border.color: Style.menuSep
                    border.width: 1

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 10
                      spacing: 8

                      Text {
                        text: "SCREENSHOTS"
                        color: Style.menuInk
                        font.pixelSize: root.fontPx(9)
                        font.family: root.uiFont
                        font.letterSpacing: 1.4
                        font.weight: Font.Medium
                      }

                      Grid {
                        id: lowerShots
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 4
                        columnSpacing: 8
                        rowSpacing: 8
                        Repeater {
                          model: root.shots.slice(0, 4)
                          delegate: Item {
                            required property var modelData
                            width: (lowerShots.width - 3 * 8) / 4
                            height: lowerShots.height
                            Rectangle {
                              anchors.fill: parent
                              radius: Style.menuRadius
                              clip: true
                              color: shotMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
                              border.color: root.copiedShot === modelData.path ? Style.green : Style.menuSep
                              border.width: root.copiedShot === modelData.path ? 2 : 1
                              Behavior on color { ColorAnimation { duration: 80 } }
                              Behavior on border.color { ColorAnimation { duration: 80 } }

                              Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: "file://" + modelData.path
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 240
                                sourceSize.height: 140
                              }

                              Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 16
                                color: Qt.rgba(0, 0, 0, 0.62)
                                Text {
                                  anchors.centerIn: parent
                                  text: modelData.label
                                  color: Style.menuInk
                                  font.pixelSize: root.fontPx(7)
                                  font.family: root.uiFont
                                  elide: Text.ElideRight
                                  width: parent.width - 6
                                  horizontalAlignment: Text.AlignHCenter
                                }
                              }

                              Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(Style.green.r, Style.green.g, Style.green.b, 0.35)
                                visible: root.copiedShot === modelData.path
                                Text {
                                  anchors.centerIn: parent
                                  text: "COPIED"
                                  color: Style.menuInk
                                  font.pixelSize: root.fontPx(8)
                                  font.family: root.uiFont
                                  font.weight: Font.Medium
                                  font.letterSpacing: 1
                                }
                              }

                              MouseArea {
                                id: shotMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                  if (mouse.button === Qt.RightButton) root.openShot(modelData.path)
                                  else root.copyShot(modelData.path)
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

              // ----------------------------------------------------
              // DASHBOARD VIEW (HUB) - kept for compatibility but hidden in hub (grid above takes over the overview)
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "hub" && false
                spacing: 12

                RowLayout {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  spacing: 12

                  // Left column: System telemetry status
                  Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1.2
                    radius: 12
                    color: root.menuTileBg
                    border.color: Style.menuSep
                    border.width: 1

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 14
                      spacing: 10

                      Text {
                        text: "󰌢  System Information"
                        color: Style.menuIndigo
                        font.pixelSize: root.fontPx(13 + root.uiFontBump)
                        font.bold: true
                        font.family: root.uiFont
                      }

                      // fastfetch pane (compact no-logo system overview)
                      Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 320
                        radius: 6
                        color: Style.menuControlBg
                        border.color: Style.menuSep
                        border.width: 1
                        clip: true
                        Flickable {
                          anchors.fill: parent; anchors.margins: 6
                          contentHeight: ffText.height; boundsBehavior: Flickable.StopAtBounds
                          Text {
                            id: ffText
                            text: root.fastfetchOut || "loading system info..."
                            font.family: root.uiFont; font.pixelSize: root.fontPx(10 + root.uiFontBump); color: Style.menuInk
                            wrapMode: Text.Wrap; width: parent.width
                          }
                        }
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        RowLayout {
                          Layout.fillWidth: true
                          Text {
                            text: "󰹑  Recent Screenshots"
                            color: Style.menuInkDeep
                            font.pixelSize: root.fontPx(11 + root.uiFontBump)
                            font.family: root.uiFont
                            font.bold: true
                          }
                          Item { Layout.fillWidth: true }
                          Text {
                            visible: root.shots.length > 0
                            text: "view all →"
                            color: Style.menuSeal
                            font.pixelSize: root.fontPx(10 + root.uiFontBump)
                            font.family: root.uiFont
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = "screenshots" }
                          }
                        }

                        GridView {
                          id: dashShotGrid
                          Layout.fillWidth: true
                          Layout.fillHeight: true
                          cellWidth: Math.floor(width / 2)
                          cellHeight: Math.min(104, Math.max(76, height / 2))
                          clip: true
                          interactive: false
                          model: root.shots.slice(0, 4)

                          delegate: Item {
                            required property var modelData
                            width: dashShotGrid.cellWidth
                            height: dashShotGrid.cellHeight

                            Rectangle {
                              anchors.fill: parent
                              anchors.margins: 4
                              radius: 8
                              clip: true
                              color: dashShotMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
                              border.color: root.copiedShot === modelData.path ? Style.green : (dashShotMa.containsMouse ? Style.menuSep : Style.menuSep)
                              border.width: root.copiedShot === modelData.path ? 2 : 1
                              scale: dashShotMa.containsMouse ? 1.025 : 1.0

                              Behavior on color { ColorAnimation { duration: 140 } }
                              Behavior on border.color { ColorAnimation { duration: 140 } }
                              Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                              Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: "file://" + modelData.path
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 260
                                sourceSize.height: 150
                              }

                              Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 20
                                color: Qt.rgba(0, 0, 0, 0.55)
                                Text {
                                  anchors.centerIn: parent
                                  width: parent.width - 8
                                  text: modelData.label
                                  color: "#ffffff"
                                  font.pixelSize: root.fontPx(9 + root.uiFontBump)
                                  font.family: root.uiFont
                                  elide: Text.ElideRight
                                  horizontalAlignment: Text.AlignHCenter
                                }
                              }

                              Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0.4, 0.8, 0.5, 0.32)
                                visible: root.copiedShot === modelData.path
                                Text { anchors.centerIn: parent; text: "COPIED"; color: "#ffffff"; font.pixelSize: root.fontPx(11 + root.uiFontBump); font.family: root.uiFont; font.bold: true }
                              }

                              MouseArea {
                                id: dashShotMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => { if (mouse.button === Qt.RightButton) root.openShot(modelData.path); else root.copyShot(modelData.path) }
                              }

                              Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 7
                                width: 24
                                height: 24
                                radius: 12
                                z: 4
                                visible: dashShotMa.containsMouse
                                color: Style.menuControlBg
                                border.width: 1
                                border.color: Style.menuSep
                                Text { anchors.centerIn: parent; text: "󰋲"; color: Style.menuSeal; font.pixelSize: root.fontPx(12 + root.uiFontBump); font.family: root.uiFont }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.previewShot(modelData.path) }
                              }
                            }
                          }
                        }

                        Text {
                          visible: root.shots.length === 0
                          text: "No screenshots yet"
                          color: Style.menuInkDeep
                          font.pixelSize: root.fontPx(10 + root.uiFontBump)
                          font.family: root.uiFont
                          Layout.alignment: Qt.AlignHCenter
                        }
                      }
                    }
                  }

                  // Right column: Now playing and wallpaper preview
                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    // Mini Now playing
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      radius: 12
                      color: root.menuTileBg
                      border.color: Style.menuSep
                      border.width: 1

                      ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        Text {
                          text: "󰎈  Now Playing"
                          color: Style.menuIndigo
                          font.pixelSize: root.fontPx(13 + root.uiFontBump)
                          font.bold: true
                          font.family: root.uiFont
                        }

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: 10

                          Rectangle {
                            width: 36
                            height: 36
                            radius: 8
                            color: Style.menuControlBg
                            Text {
                              anchors.centerIn: parent
                              text: "󰎆"
                              font.pixelSize: root.fontPx(18 + root.uiFontBump)
                              color: Style.green
                            }
                          }

                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                              text: {
                                const p = root.activePlayer
                                if (!p) return "No media playing"
                                return p.trackTitle || "Unknown Track"
                              }
                              color: Style.menuInk
                              font.pixelSize: root.fontPx(12 + root.uiFontBump)
                              font.bold: true
                              font.family: root.uiFont
                              elide: Text.ElideRight
                              Layout.fillWidth: true
                            }
                            Text {
                              text: {
                                const p = root.activePlayer
                                if (!p) return "System Player"
                                return p.trackArtist || "Unknown Artist"
                              }
                              color: Style.menuInkDeep
                              font.pixelSize: root.fontPx(10 + root.uiFontBump)
                              font.family: root.uiFont
                              elide: Text.ElideRight
                              Layout.fillWidth: true
                            }
                          }
                        }

                        // Compact playback controls
                        RowLayout {
                          Layout.alignment: Qt.AlignHCenter
                          spacing: 16

                          MouseArea {
                            width: 24; height: 24; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              const p = root.activePlayer
                              if (p && p.canGoPrevious) p.previous()
                            }
                            Text { anchors.centerIn: parent; text: "󰒮"; font.pixelSize: root.fontPx(18 + root.uiFontBump); color: Style.menuInkDeep; font.family: root.uiFont }
                          }

                          Rectangle {
                            width: 32; height: 32; radius: 16
                            color: Style.green
                            opacity: 0.15

                            Text {
                              anchors.centerIn: parent
                              text: {
                                const p = root.activePlayer
                                return (p && p.isPlaying) ? "󰏤" : "󰐊"
                              }
                              font.pixelSize: root.fontPx(16 + root.uiFontBump)
                              color: Style.green
                              font.family: root.uiFont
                            }
                            MouseArea {
                              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                const p = root.activePlayer
                                if (p && p.canTogglePlaying) p.togglePlaying()
                              }
                            }
                          }

                          MouseArea {
                            width: 24; height: 24; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              const p = root.activePlayer
                              if (p && p.canGoNext) p.next()
                            }
                            Text { anchors.centerIn: parent; text: "󰒭"; font.pixelSize: root.fontPx(18 + root.uiFontBump); color: Style.menuInkDeep; font.family: root.uiFont }
                          }
                        }
                      }
                    }

                    // Mini Wallpaper Preview
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      radius: 12
                      clip: true
                      color: root.menuTileBg
                      border.color: Style.menuSep
                      border.width: 1

                      Image {
                        anchors.fill: parent
                        source: WallpaperModule.WallpaperService.currentWallpaper ? "file://" + WallpaperModule.WallpaperService.currentWallpaper : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: 0.8

                        Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0,0.4) }
                      }

                      ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4

                        Text {
                          text: "󰸉  Active Wallpaper"
                          color: Style.menuInk
                          font.pixelSize: root.fontPx(12 + root.uiFontBump)
                          font.bold: true
                          font.family: root.uiFont
                          style: Text.Outline; styleColor: "#000000"
                        }
                        Item { Layout.fillHeight: true }
                        Text {
                          text: WallpaperModule.WallpaperService.currentWallpaper ? WallpaperModule.WallpaperService.currentWallpaper.split("/").pop() : "No wallpaper active"
                          color: Style.menuInk
                          font.pixelSize: root.fontPx(10 + root.uiFontBump)
                          font.bold: true
                          font.family: root.uiFont
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                          style: Text.Outline; styleColor: "#000000"
                        }
                      }

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.mode = "wallpaper"
                      }
                    }
                  }
                }

                // Bottom row: reload tools
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8
                  Repeater {
                    model: [
                      { icon: "󱂬", label: "Scratch", act: () => root.toggleScratch() },
                      { icon: "󰑓", label: "Hypr", act: () => root.reloadHyprland() },
                      { icon: "󰑐", label: "QS Remix", act: () => root.reloadBar() },
                      { icon: "󰑓", label: "Paper", act: () => root.restartHyprpaper() },
                      { icon: "󰑓", label: "Idle", act: () => root.restartHypridle() },
                      { icon: "󰌾", label: "Lock", act: () => root.doLock() }
                    ]
                    delegate: Rectangle {
                      required property var modelData
                      Layout.fillWidth: true; height: 32; radius: 8
                      color: reloadMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
                      border.color: reloadMa.containsMouse ? Style.menuSep : Style.menuSep
                      border.width: 1
                      scale: reloadMa.containsMouse ? 1.02 : 1.0

                      Behavior on color { ColorAnimation { duration: 140 } }
                      Behavior on border.color { ColorAnimation { duration: 140 } }
                      Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                      Row { anchors.centerIn: parent; spacing: 6; Text { text: modelData.icon; font.pixelSize: root.fontPx(13 + root.uiFontBump); color: Style.menuIndigo; font.family: root.uiFont } Text { text: modelData.label; font.pixelSize: root.fontPx(11 + root.uiFontBump); color: Style.menuInk; font.family: root.uiFont } }
                      MouseArea { id: reloadMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.act() }
                    }
                  }
                }
              }

              // ----------------------------------------------------
              // WALLPAPER SELECTION VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "wallpaper"
                spacing: 10

                Rectangle {
                  Layout.fillWidth: true
                  height: 36
                  radius: 8
                  color: Style.menuControlBg
                  border.color: searchInput.activeFocus ? Style.menuSep : Style.menuSep
                  border.width: 1
                  Behavior on border.color { ColorAnimation { duration: 140 } }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    TextInput {
                      id: searchInput
                      Layout.fillWidth: true
                      Layout.alignment: Qt.AlignVCenter
                      color: Style.menuInk
                      font.pixelSize: root.fontPx(13 + root.uiFontBump)
                      font.family: root.uiFont
                      clip: true
                      selectByMouse: true
                      onTextChanged: root.wallpaperSearchText = text
                    }

                    Text {
                      text: "Search wallpapers..."
                      color: Style.menuInkDeep
                      font.pixelSize: root.fontPx(13 + root.uiFontBump)
                      font.family: root.uiFont
                      visible: searchInput.text === "" && !searchInput.activeFocus
                    }
                  }
                }

                GridView {
                  id: wallpaperGrid
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  cellWidth: Math.floor((width - 10) / 3)
                  cellHeight: cellWidth * 0.6 + 6
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                  cacheBuffer: 200
                  model: root.filteredWallpapers

                  delegate: Item {
                    required property string modelData
                    required property int index
                    width: wallpaperGrid.cellWidth
                    height: wallpaperGrid.cellHeight

                    Rectangle {
                      anchors.fill: parent
                      anchors.margins: 4
                      radius: 8
                      color: wallGridMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
                      border.color: WallpaperModule.WallpaperService.currentWallpaper === modelData ? Style.green : (wallGridMa.containsMouse ? Style.menuSep : Style.menuSep)
                      border.width: WallpaperModule.WallpaperService.currentWallpaper === modelData ? 2 : 1
                      clip: true
                      scale: wallGridMa.containsMouse ? 1.025 : 1.0

                      Behavior on color { ColorAnimation { duration: 140 } }
                      Behavior on border.color { ColorAnimation { duration: 140 } }
                      Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                      Image {
                        anchors.fill: parent
                        anchors.margins: WallpaperModule.WallpaperService.currentWallpaper === modelData ? 2 : 1
                        source: "file://" + modelData
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 200
                        sourceSize.height: 120
                        asynchronous: true

                        Rectangle {
                          anchors.fill: parent
                          color: Style.menuControlBg
                          visible: parent.status !== Image.Ready
                          Text { anchors.centerIn: parent; text: "󰋩"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(22 + root.uiFontBump) }
                        }
                      }

                      Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 20
                        color: Qt.rgba(0, 0, 0, 0.6)
                        Text { anchors.centerIn: parent; text: modelData.split("/").pop(); color: "#ffffff"; font.pixelSize: root.fontPx(9 + root.uiFontBump); font.family: root.uiFont; elide: Text.ElideMiddle; width: parent.width - 6; horizontalAlignment: Text.AlignHCenter }
                      }

                      Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 18; height: 18; radius: 9
                        color: Style.green
                        visible: WallpaperModule.WallpaperService.currentWallpaper === modelData
                        Text { anchors.centerIn: parent; text: "✓"; color: Style.menuPaper; font.pixelSize: root.fontPx(11 + root.uiFontBump); font.bold: true }
                      }

                      MouseArea {
                        id: wallGridMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (e) => {
                          if (e.button === Qt.RightButton) {
                            root.wallpaperPreviewPath = modelData
                          } else {
                            WallpaperModule.WallpaperService.setWallpaper(modelData)
                            root.closeFeature()
                          }
                        }
                      }
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 12
                  Text { text: "Left-click: apply • Right-click: widescreen preview"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(10 + root.uiFontBump); font.family: root.uiFont }
                  Item { Layout.fillWidth: true }
                  Text { text: WallpaperModule.WallpaperService.wallpapers.length + " wallpapers"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(10 + root.uiFontBump); font.family: root.uiFont }
                }
              }

              // ----------------------------------------------------
              // SCREENSHOTS VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "screenshots"
                spacing: 8

                GridView {
                  id: shotGrid
                  Layout.fillWidth: true; Layout.fillHeight: true
                  cellWidth: Math.floor((width - 10) / 3)
                  cellHeight: cellWidth * 0.6 + 6
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                  model: root.shots

                  delegate: Item {
                    required property var modelData
                    required property int index
                    width: shotGrid.cellWidth
                    height: shotGrid.cellHeight

                    Rectangle {
                      anchors.fill: parent
                      anchors.margins: 4
                      radius: 8; clip: true
                      color: hma.containsMouse ? Style.menuRowHi : Style.menuControlBg
                      border.color: root.copiedShot === modelData.path ? Style.green : (hma.containsMouse ? Style.menuSep : Style.menuSep)
                      border.width: root.copiedShot === modelData.path ? 2 : 1
                      scale: hma.containsMouse ? 1.025 : 1.0

                      Behavior on color { ColorAnimation { duration: 140 } }
                      Behavior on border.color { ColorAnimation { duration: 140 } }
                      Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                      Image {
                        anchors.fill: parent; anchors.margins: 1
                        source: "file://" + modelData.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 200
                        sourceSize.height: 120
                      }

                      Rectangle {
                        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 18; color: Qt.rgba(0,0,0,0.55)
                        Text { anchors.centerIn: parent; text: modelData.label; color: "#ffffff"; font.pixelSize: root.fontPx(9 + root.uiFontBump); font.family: root.uiFont; elide: Text.ElideRight; width: parent.width-6; horizontalAlignment: Text.AlignHCenter }
                      }

                      Rectangle {
                        anchors.fill: parent; anchors.margins: 1; radius: 6; color: Qt.rgba(0.4,0.8,0.5,0.32); visible: root.copiedShot === modelData.path
                        Text { anchors.centerIn: parent; text: "COPIED"; color: "#ffffff"; font.pixelSize: root.fontPx(12 + root.uiFontBump); font.family: root.uiFont; font.bold: true }
                      }

                      MouseArea {
                        id: hma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => { if (mouse.button === Qt.RightButton) root.openShot(modelData.path); else root.copyShot(modelData.path) }
                      }

                      Rectangle {
                        id: shotQuickPreview
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 7
                        width: 24
                        height: 24
                        radius: 12
                        z: 4
                        visible: hma.containsMouse
                        color: Style.menuControlBg
                        border.width: 1
                        border.color: Style.menuSep
                        Text { anchors.centerIn: parent; text: "󰋲"; color: Style.menuSeal; font.pixelSize: root.fontPx(12 + root.uiFontBump); font.family: root.uiFont }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.previewShot(modelData.path) }
                      }

                      Rectangle {
                        anchors.top: parent.top
                        anchors.right: shotQuickPreview.left
                        anchors.topMargin: 7
                        anchors.rightMargin: 6
                        width: 24
                        height: 24
                        radius: 12
                        z: 4
                        visible: hma.containsMouse
                        color: Style.menuControlBg
                        border.width: 1
                        border.color: Style.menuSep
                        Text { anchors.centerIn: parent; text: "󰆴"; color: Style.red; font.pixelSize: root.fontPx(12 + root.uiFontBump); font.family: root.uiFont }
                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: mouse => {
                            mouse.accepted = true
                            root.deleteShot(modelData.path)
                          }
                        }
                      }
                    }
                  }
                }
                Text { visible: root.shots.length === 0; text: "No screenshots in ~/screenshots"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(11 + root.uiFontBump); font.family: root.uiFont; Layout.alignment: Qt.AlignHCenter }
              }

              // ----------------------------------------------------
              // MEDIA VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "media"
                spacing: 12

                // Players Control Panel
                Rectangle {
                  Layout.fillWidth: true
                  radius: 12
                  color: root.menuTileBg
                  border.color: Style.menuSep
                  border.width: 1
                  Layout.preferredHeight: 82
                  Layout.maximumHeight: 82

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: "󰎈  Now Playing Status"; color: Style.menuIndigo; font.pixelSize: root.fontPx(12 + root.uiFontBump); font.family: root.uiFont; font.bold: true }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10

                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                          text: {
                            const p = root.activePlayer
                            if (!p) return "No active media player"
                            return (p.trackArtist || "Unknown Artist") + " — " + (p.trackTitle || "Unknown Track")
                          }
                          color: Style.menuInk
                          font.pixelSize: root.fontPx(12 + root.uiFontBump)
                          font.bold: true
                          font.family: root.uiFont
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }
                      }

                      // Controls
                      RowLayout {
                        spacing: 14
                        MouseArea {
                          width: 22; height: 22; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            const p = root.activePlayer
                            if (p && p.canGoPrevious) p.previous()
                          }
                          Text { text: "󰒮"; font.pixelSize: root.fontPx(16 + root.uiFontBump); color: Style.menuInk; font.family: root.uiFont }
                        }

                        Rectangle {
                          width: 28; height: 28; radius: 14
                          color: Style.green
                          opacity: 0.2
                          Text {
                            anchors.centerIn: parent
                            text: {
                              const p = root.activePlayer
                              return (p && p.isPlaying) ? "󰏤" : "󰐊"
                            }
                            font.pixelSize: root.fontPx(15 + root.uiFontBump); color: Style.green; font.family: root.uiFont
                          }
                          MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              const p = root.activePlayer
                              if (p && p.canTogglePlaying) p.togglePlaying()
                            }
                          }
                        }

                        MouseArea {
                          width: 22; height: 22; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            const p = root.activePlayer
                            if (p && p.canGoNext) p.next()
                          }
                          Text { text: "󰒭"; font.pixelSize: root.fontPx(16 + root.uiFontBump); color: Style.menuInk; font.family: root.uiFont }
                        }
                      }
                    }
                  }
                }

                // Volume Controls
                RowLayout {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 36
                  Layout.maximumHeight: 36
                  spacing: 12

                  // Output Vol
                  Rectangle {
                    Layout.fillWidth: true; height: 36; radius: 8; color: root.menuTileBg
                    border.color: Style.menuSep; border.width: 1

                    RowLayout {
                      anchors.fill: parent; anchors.margins: 10
                      Text {
                        text: root.defaultSinkMuted ? "󰖁  Speakers" : "󰕾  Speakers"
                        font.pixelSize: root.fontPx(11 + root.uiFontBump)
                        color: root.defaultSinkMuted ? Style.red : Style.menuInk
                        font.family: root.uiFont
                        font.bold: true
                      }
                      Item { Layout.fillWidth: true }
                      Text {
                        text: root.defaultSinkVol
                        font.pixelSize: root.fontPx(11 + root.uiFontBump)
                        color: root.defaultSinkMuted ? Style.red : Style.menuIndigo
                        font.family: root.uiFont
                        font.bold: true
                      }

                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.menuControlBg
                        Text {
                          anchors.centerIn: parent
                          text: root.defaultSinkMuted ? "󰖁" : "󰕾"
                          font.pixelSize: root.fontPx(12 + root.uiFontBump)
                          color: Style.menuInk
                        }
                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleMute("@DEFAULT_AUDIO_SINK@")
                        }
                      }

                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.menuControlBg
                        Text { anchors.centerIn: parent; text: "−"; font.pixelSize: root.fontPx(12 + root.uiFontBump); color: Style.menuInk }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volAdjust("@DEFAULT_AUDIO_SINK@", -5) }
                      }
                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.menuControlBg
                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: root.fontPx(12 + root.uiFontBump); color: Style.menuInk }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volAdjust("@DEFAULT_AUDIO_SINK@", 5) }
                      }
                    }
                  }

                  // Mic Vol
                  Rectangle {
                    Layout.fillWidth: true; height: 36; radius: 8; color: root.menuTileBg
                    border.color: Style.menuSep; border.width: 1

                    RowLayout {
                      anchors.fill: parent; anchors.margins: 10
                      Text {
                        text: root.defaultSourceMuted ? "󰍭  Microphone" : "󰍬  Microphone"
                        font.pixelSize: root.fontPx(11 + root.uiFontBump)
                        color: root.defaultSourceMuted ? Style.red : Style.menuInk
                        font.family: root.uiFont
                        font.bold: true
                      }
                      Item { Layout.fillWidth: true }
                      Text {
                        text: root.defaultSourceVol
                        font.pixelSize: root.fontPx(11 + root.uiFontBump)
                        color: root.defaultSourceMuted ? Style.red : Style.menuIndigo
                        font.family: root.uiFont
                        font.bold: true
                      }

                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.menuControlBg
                        Text {
                          anchors.centerIn: parent
                          text: root.defaultSourceMuted ? "󰍭" : "󰍬"
                          font.pixelSize: root.fontPx(12 + root.uiFontBump)
                          color: Style.menuInk
                        }
                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.toggleMute("@DEFAULT_AUDIO_SOURCE@")
                        }
                      }

                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.menuControlBg
                        Text { anchors.centerIn: parent; text: "−"; font.pixelSize: root.fontPx(12 + root.uiFontBump); color: Style.menuInk }
                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.volAdjust("@DEFAULT_AUDIO_SOURCE@", -5)
                        }
                      }
                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.menuControlBg
                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: root.fontPx(12 + root.uiFontBump); color: Style.menuInk }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volAdjust("@DEFAULT_AUDIO_SOURCE@", 5) }
                      }
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 96
                  Layout.maximumHeight: 96
                  spacing: 12

                  Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: root.menuTileBg
                    border.color: Style.menuSep
                    border.width: 1

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 8
                      spacing: 3

                      Text {
                        text: "󰕾  Output devices"
                        font.pixelSize: root.fontPx(10 + root.uiFontBump)
                        color: Style.menuInkDeep
                        font.family: root.uiFont
                        font.bold: true
                      }
                      Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: outputDeviceColumn.height
                        Column {
                          id: outputDeviceColumn
                          width: parent.width
                          spacing: 2
                          Text {
                            visible: root.audioSinks.length === 0
                            text: "No outputs"
                            color: Style.menuInkDeep
                            font.pixelSize: root.fontPx(9 + root.uiFontBump)
                            font.family: root.uiFont
                          }
                          Repeater {
                            model: root.audioSinks
                            delegate: Rectangle {
                              required property var modelData
                              width: parent.width
                              height: 22
                              radius: 5
                              color: modelData.active
                                ? Qt.rgba(Style.menuIndigo.r, Style.menuIndigo.g, Style.menuIndigo.b, 0.18)
                                : (outMa.containsMouse ? Style.menuRowHi : "transparent")
                              border.color: modelData.active ? Style.menuIndigo : (outMa.containsMouse ? Style.menuSep : "transparent")
                              border.width: 1
                              Behavior on color { ColorAnimation { duration: 140 } }
                              Behavior on border.color { ColorAnimation { duration: 140 } }
                              RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 7
                                anchors.rightMargin: 7
                                spacing: 6
                                Text {
                                  text: modelData.active ? "●" : "○"
                                  color: modelData.active ? Style.green : Style.menuInkDeep
                                  font.pixelSize: root.fontPx(7 + root.uiFontBump)
                                }
                                Text {
                                  text: modelData.name
                                  color: Style.menuInk
                                  font.pixelSize: root.fontPx(8 + root.uiFontBump)
                                  font.family: root.uiFont
                                  elide: Text.ElideRight
                                  Layout.fillWidth: true
                                }
                                Text {
                                  text: "#" + modelData.id
                                  color: Style.menuInkDeep
                                  font.pixelSize: root.fontPx(8 + root.uiFontBump)
                                  font.family: root.uiFont
                                }
                              }
                              MouseArea {
                                id: outMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setAudioDefault(modelData.id)
                              }
                            }
                          }
                        }
                      }
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: root.menuTileBg
                    border.color: Style.menuSep
                    border.width: 1

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 8
                      spacing: 3

                      Text {
                        text: "󰍬  Input sources"
                        font.pixelSize: root.fontPx(10 + root.uiFontBump)
                        color: Style.menuInkDeep
                        font.family: root.uiFont
                        font.bold: true
                      }
                      Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: inputDeviceColumn.height
                        Column {
                          id: inputDeviceColumn
                          width: parent.width
                          spacing: 2
                          Text {
                            visible: root.audioSources.length === 0
                            text: "No inputs"
                            color: Style.menuInkDeep
                            font.pixelSize: root.fontPx(9 + root.uiFontBump)
                            font.family: root.uiFont
                          }
                          Repeater {
                            model: root.audioSources
                            delegate: Rectangle {
                              required property var modelData
                              width: parent.width
                              height: 22
                              radius: 5
                              color: modelData.active
                                ? Qt.rgba(Style.menuIndigo.r, Style.menuIndigo.g, Style.menuIndigo.b, 0.18)
                                : (inMa.containsMouse ? Style.menuRowHi : "transparent")
                              border.color: modelData.active ? Style.menuIndigo : (inMa.containsMouse ? Style.menuSep : "transparent")
                              border.width: 1
                              Behavior on color { ColorAnimation { duration: 140 } }
                              Behavior on border.color { ColorAnimation { duration: 140 } }
                              RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 7
                                anchors.rightMargin: 7
                                spacing: 6
                                Text {
                                  text: modelData.active ? "●" : "○"
                                  color: modelData.active ? Style.green : Style.menuInkDeep
                                  font.pixelSize: root.fontPx(7 + root.uiFontBump)
                                }
                                Text {
                                  text: modelData.name
                                  color: Style.menuInk
                                  font.pixelSize: root.fontPx(8 + root.uiFontBump)
                                  font.family: root.uiFont
                                  elide: Text.ElideRight
                                  Layout.fillWidth: true
                                }
                                Text {
                                  text: "#" + modelData.id
                                  color: Style.menuInkDeep
                                  font.pixelSize: root.fontPx(8 + root.uiFontBump)
                                  font.family: root.uiFont
                                }
                              }
                              MouseArea {
                                id: inMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setAudioDefault(modelData.id)
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 116
                  Layout.maximumHeight: 116
                  radius: 10
                  color: root.menuTileBg
                  border.color: Style.menuSep
                  border.width: 1

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 3

                    Text {
                      text: "󰝚  Stream mixer"
                      font.pixelSize: root.fontPx(10 + root.uiFontBump)
                      color: Style.menuInkDeep
                      font.family: root.uiFont
                      font.bold: true
                    }
                    Flickable {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      clip: true
                      contentHeight: streamMixerColumn.height
                      Column {
                        id: streamMixerColumn
                        width: parent.width
                        spacing: 4
                        Text {
                          visible: root.audioStreams.length === 0
                          text: "No active streams"
                          color: Style.menuInkDeep
                          font.pixelSize: root.fontPx(9 + root.uiFontBump)
                          font.family: root.uiFont
                        }
                        Repeater {
                          model: root.audioStreams
                          delegate: Rectangle {
                            id: streamRow
                            required property var modelData
                            width: parent.width
                            height: 26
                            radius: 6
                            color: modelData.muted ? root.menuDangerBg : Style.menuControlBg
                            border.width: 1
                            border.color: modelData.muted ? Style.red : Style.menuSep
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }

                            RowLayout {
                              anchors.fill: parent
                              anchors.leftMargin: 7
                              anchors.rightMargin: 7
                              spacing: 6

                              Text {
                                text: "󰝚"
                                color: Style.green
                                font.pixelSize: root.fontPx(10 + root.uiFontBump)
                                font.family: root.uiFont
                              }
                              Text {
                                text: modelData.name
                                color: modelData.muted ? Style.menuInkDeep : Style.menuInk
                                font.pixelSize: root.fontPx(9 + root.uiFontBump)
                                font.family: root.uiFont
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                              }
                              Text {
                                text: modelData.volume || "#" + modelData.id
                                color: modelData.muted ? Style.red : Style.menuIndigo
                                font.pixelSize: root.fontPx(9 + root.uiFontBump)
                                font.family: root.uiFont
                                font.bold: true
                              }
                              Rectangle {
                                width: 18; height: 18; radius: 4; color: Style.menuControlBg
                                Text {
                                  anchors.centerIn: parent
                                  text: modelData.muted ? "󰖁" : "󰕾"
                                  font.pixelSize: root.fontPx(10 + root.uiFontBump)
                                  color: modelData.muted ? Style.red : Style.menuInk
                                }
                                MouseArea {
                                  anchors.fill: parent
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                    root.toggleMute(streamRow.modelData.id)
                                  }
                                }
                              }
                              Rectangle {
                                width: 18; height: 18; radius: 4; color: Style.menuControlBg
                                Text {
                                  anchors.centerIn: parent
                                  text: "−"
                                  font.pixelSize: root.fontPx(10 + root.uiFontBump)
                                  color: Style.menuInk
                                }
                                MouseArea {
                                  anchors.fill: parent
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                    root.volAdjust(streamRow.modelData.id, -5)
                                  }
                                }
                              }
                              Rectangle {
                                width: 18; height: 18; radius: 4; color: Style.menuControlBg
                                Text {
                                  anchors.centerIn: parent
                                  text: "+"
                                  font.pixelSize: root.fontPx(10 + root.uiFontBump)
                                  color: Style.menuInk
                                }
                                MouseArea {
                                  anchors.fill: parent
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                    root.volAdjust(streamRow.modelData.id, 5)
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

                // Cava Spectrum visualization
                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: root.mediaCavaHeight
                  Layout.maximumHeight: root.mediaCavaHeight
                  radius: 12
                  color: root.menuTileBg
                  border.color: Style.menuSep
                  border.width: 1

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                      Layout.fillWidth: true
                      Text {
                        text: "󰎈  Live Cava Audio Spectrum"
                        color: Style.menuInkDeep
                        font.pixelSize: root.fontPx(10 + root.uiFontBump)
                        font.family: root.uiFont
                        font.bold: true
                      }
                      Item { Layout.fillWidth: true }
                      Text {
                        text: root.cavaStatus
                        color: root.cavaStatus === "active" ? Style.green : Style.menuInkDeep
                        font.pixelSize: root.fontPx(9 + root.uiFontBump)
                        font.family: root.uiFont
                      }
                    }

                    Item {
                      Layout.fillWidth: true
                      Layout.fillHeight: true

                      Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Repeater {
                          model: 24
                          delegate: Rectangle {
                            required property int index
                            width: (parent.width - 23 * 4) / 24
                            height: root.cavaValues && root.cavaValues.length > index ? Math.max(3, (root.cavaValues[index] || 0) / 100 * parent.height) : 3
                            color: Style.green || "#a6e3a1"
                            radius: 2
                            anchors.bottom: parent.bottom
                            Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                          }
                        }
                      }
                    }
                  }
                }
              }

              // ----------------------------------------------------
              // NETWORK VIEW (renamed from wifi; wifi radio + LAN controls for LAN-only use)
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "network"
                spacing: 10

                RowLayout {
                  Layout.fillWidth: true
                  Text { text: "󰈀 Network"; font.pixelSize: root.fontPx(12 + root.uiFontBump); color: Style.green; font.family: root.uiFont; font.bold: true }
                  Text {
                    text: root.wifiNetworks.length + " Wi-Fi networks"
                    color: Style.menuInkDeep; font.pixelSize: root.fontPx(10 + root.uiFontBump); font.family: root.uiFont
                  }
                  Item { Layout.fillWidth: true }
                  Rectangle {
                    width: 70; height: 24; radius: 6; color: refreshNetMa.containsMouse ? Style.menuRowHi : root.menuTileBg
                    border.color: refreshNetMa.containsMouse ? Style.menuSep : Style.menuSep; border.width: 1
                    Text { anchors.centerIn: parent; text: "Refresh"; font.pixelSize: root.fontPx(10 + root.uiFontBump); color: Style.menuInk; font.family: root.uiFont }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    MouseArea {
                      id: refreshNetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: { root.scanWifi(); root.ethCheck.running = true }
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 10

                  Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 170
                    radius: 8; color: root.menuTileBg; border.color: root.wifiEnabled ? Style.menuSep : Style.menuSep; border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    ColumnLayout {
                      anchors.fill: parent; anchors.margins: 12; spacing: 6
                      RowLayout {
                        Layout.fillWidth: true
                        Text { text: "󰤨 Wi-Fi"; color: Style.menuIndigo; font.pixelSize: root.fontPx(12 + root.uiFontBump); font.family: root.uiFont; font.bold: true }
                        Text {
                          text: root.wifiEnabled ? "enabled" : "disabled"
                          color: root.wifiEnabled ? Style.green : Style.red
                          font.pixelSize: root.fontPx(10 + root.uiFontBump); font.family: root.uiFont; font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                          width: 74; height: 22; radius: 5
                          color: root.wifiEnabled
                            ? Qt.rgba(Style.red.r, Style.red.g, Style.red.b, 0.18)
                            : Qt.rgba(Style.green.r, Style.green.g, Style.green.b, 0.18)
                          border.color: root.wifiEnabled ? Style.red : Style.green; border.width: 1
                          Text {
                            anchors.centerIn: parent
                            text: root.wifiEnabled ? "Disable" : "Enable"
                            color: root.wifiEnabled ? Style.red : Style.green
                            font.pixelSize: root.fontPx(9 + root.uiFontBump); font.family: root.uiFont; font.bold: true
                          }
                          MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              const tgt = root.wifiEnabled ? "off" : "on"
                              Quickshell.execDetached(["nmcli", "radio", "wifi", tgt])
                              root.wifiEnabled = !root.wifiEnabled
                              Qt.callLater(root.scanWifi)
                            }
                          }
                        }
                      }
                      Text {
                        Layout.fillWidth: true
                        text: root.currentWifiSsid ? root.currentWifiSsid : root.wifiLabel
                        color: Style.menuInk; font.pixelSize: root.fontPx(11 + root.uiFontBump); font.family: root.uiFont; font.bold: true
                        elide: Text.ElideRight
                      }
                      Text {
                        Layout.fillWidth: true
                        text: {
                          let t = root.wifiTooltip || "No Wi-Fi connection details"
                          t = t.replace(/^Connected to [^\n]*\n?/, "")
                          return t.trim() || "No Wi-Fi connection details"
                        }
                        color: Style.menuInkDeep; font.pixelSize: root.fontPx(9 + root.uiFontBump); font.family: root.uiFont
                        wrapMode: Text.Wrap
                        maximumLineCount: 5
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignTop
                      }
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 170
                    radius: 8; color: root.menuTileBg; border.color: root.ethConnected ? Style.menuSep : Style.menuSep; border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    ColumnLayout {
                      anchors.fill: parent; anchors.margins: 12; spacing: 6
                      RowLayout {
                        Layout.fillWidth: true
                        Text { text: "󰈀 LAN"; color: Style.menuIndigo; font.pixelSize: root.fontPx(12 + root.uiFontBump); font.family: root.uiFont; font.bold: true }
                        Text {
                          text: root.ethDevice ? root.ethState : "missing"
                          color: root.ethConnected ? Style.green : Style.menuInkDeep
                          font.pixelSize: root.fontPx(10 + root.uiFontBump); font.family: root.uiFont; font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                          visible: !!root.ethDevice
                          width: 84; height: 22; radius: 5
                          color: root.ethConnected
                            ? Qt.rgba(Style.red.r, Style.red.g, Style.red.b, 0.18)
                            : Qt.rgba(Style.green.r, Style.green.g, Style.green.b, 0.18)
                          border.color: root.ethConnected ? Style.red : Style.green; border.width: 1
                          Text {
                            anchors.centerIn: parent
                            text: root.ethConnected ? "Disable" : "Enable"
                            color: root.ethConnected ? Style.red : Style.green
                            font.pixelSize: root.fontPx(9 + root.uiFontBump); font.family: root.uiFont; font.bold: true
                          }
                          MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              if (root.ethConnected) Quickshell.execDetached(["nmcli", "device", "disconnect", root.ethDevice])
                              else Quickshell.execDetached(["nmcli", "device", "connect", root.ethDevice])
                              Qt.callLater(function(){ root.ethCheck.running = true })
                            }
                          }
                        }
                      }
                      Text {
                        Layout.fillWidth: true
                        text: root.ethDevice ? root.ethDevice : "No ethernet device"
                        color: Style.menuInk; font.pixelSize: root.fontPx(11 + root.uiFontBump); font.family: root.uiFont; font.bold: true
                        elide: Text.ElideRight
                      }
                      Text {
                        Layout.fillWidth: true
                        text: root.ethConnection || (
                          root.ethDevices.length > 1 ? (root.ethDevices.length + " ethernet devices") : "No active LAN connection"
                        )
                        color: Style.menuInkDeep; font.pixelSize: root.fontPx(9 + root.uiFontBump); font.family: root.uiFont
                        elide: Text.ElideRight
                      }
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 110
                  Layout.maximumHeight: 110
                  radius: 8
                  color: root.menuTileBg
                  border.color: Style.menuSep
                  border.width: 1

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                      Layout.fillWidth: true
                      Text {
                        text: "Traffic"
                        color: Style.menuInk
                        font.pixelSize: root.fontPx(10 + root.uiFontBump)
                        font.family: root.uiFont
                        font.bold: true
                      }
                      Text {
                        text: root.netSpeedDevice || "no interface"
                        color: Style.menuInkDeep
                        font.pixelSize: root.fontPx(9 + root.uiFontBump)
                        font.family: root.uiFont
                      }
                      Item { Layout.fillWidth: true }
                      Text {
                        text: "↑ " + root.formatNetSpeed(root.netTxSpeed)
                        color: root.netTxSpeed >= 1024 ? Style.green : Style.menuInkDeep
                        font.pixelSize: root.fontPx(9 + root.uiFontBump)
                        font.family: root.uiFont
                      }
                      Text {
                        text: "↓ " + root.formatNetSpeed(root.netRxSpeed)
                        color: root.netRxSpeed >= 1024 ? Style.menuIndigo : Style.menuInkDeep
                        font.pixelSize: root.fontPx(9 + root.uiFontBump)
                        font.family: root.uiFont
                      }
                    }

                    Canvas {
                      id: netTimelineCanvas
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Connections {
                        target: root
                        function onNetRxHistoryChanged() { netTimelineCanvas.requestPaint() }
                        function onNetTxHistoryChanged() { netTimelineCanvas.requestPaint() }
                      }
                      onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const w = width
                        const h = height
                        const rx = root.netRxHistory || []
                        const tx = root.netTxHistory || []
                        const n = Math.max(rx.length, tx.length)
                        let maxValue = 1024
                        for (let i = 0; i < rx.length; i++) maxValue = Math.max(maxValue, rx[i])
                        for (let i = 0; i < tx.length; i++) maxValue = Math.max(maxValue, tx[i])

                        ctx.strokeStyle = Qt.rgba(Style.menuInkDeep.r, Style.menuInkDeep.g, Style.menuInkDeep.b, 0.22)
                        ctx.lineWidth = 1
                        for (let i = 1; i < 4; i++) {
                          const y = Math.round(h * i / 4) + 0.5
                          ctx.beginPath()
                          ctx.moveTo(0, y)
                          ctx.lineTo(w, y)
                          ctx.stroke()
                        }

                        function drawLine(values, color) {
                          if (values.length < 2) return
                          ctx.strokeStyle = color
                          ctx.lineWidth = 2
                          ctx.beginPath()
                          for (let i = 0; i < values.length; i++) {
                            const x = values.length === 1 ? w : i * w / (values.length - 1)
                            const y = h - Math.max(0, Math.min(1, values[i] / maxValue)) * h
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                          }
                          ctx.stroke()
                        }

                        if (n === 0) {
                          ctx.fillStyle = Style.menuInkDeep
                          ctx.font = root.fontPx(9 + root.uiFontBump) + "px sans-serif"
                          ctx.fillText("waiting for traffic samples", 8, Math.round(h / 2))
                        } else {
                          drawLine(tx, Style.green)
                          drawLine(rx, Style.menuIndigo)
                        }
                      }
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  Text { text: "Available networks"; font.pixelSize: root.fontPx(10 + root.uiFontBump); color: Style.menuInkDeep; font.family: root.uiFont }
                  Text {
                    visible: root.wifiScanning; text: " (scanning...)"
                    font.pixelSize: root.fontPx(9 + root.uiFontBump); color: Style.menuInkDeep; font.family: root.uiFont
                  }
                  Item { Layout.fillWidth: true }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Style.menuSep }

                Flickable {
                  Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                  contentHeight: wifiCol.height
                  boundsBehavior: Flickable.StopAtBounds
                  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                  Column {
                    id: wifiCol; width: parent.width; spacing: 4
                    Repeater {
                      model: root.wifiNetworks
                      delegate: Rectangle {
                        required property var modelData
                        width: parent.width - 8; x: 4; height: 58; radius: 6
                        color: modelData.active
                          ? Qt.rgba(Style.menuIndigo.r, Style.menuIndigo.g, Style.menuIndigo.b, 0.16)
                          : (netMa.containsMouse ? Style.menuRowHi : "transparent")
                        border.color: modelData.active ? Style.menuIndigo : (netMa.containsMouse ? Style.menuSep : "transparent")
                        border.width: 1
                        scale: netMa.containsMouse && !modelData.active ? 1.01 : 1.0
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        RowLayout {
                          anchors.fill: parent
                          anchors.leftMargin: 14
                          anchors.rightMargin: 14
                          anchors.topMargin: 9
                          anchors.bottomMargin: 9
                          spacing: 8
                          Text {
                            text: modelData.signal > 75 ? "󰤨" : (modelData.signal > 50 ? "󰤥" : (modelData.signal > 25 ? "󰤢" : "󰤟"))
                            font.family: root.uiFont; font.pixelSize: root.fontPx(14 + root.uiFontBump)
                            color: modelData.active ? Style.menuIndigo : Style.menuInkDeep
                          }
                          ColumnLayout {
                            spacing: 2; Layout.fillWidth: true; Layout.fillHeight: true
                            Text {
                              text: modelData.ssid;
                              font.family: root.uiFont;
                              font.pixelSize: root.fontPx(11 + root.uiFontBump);
                              font.bold: modelData.active
                              color: modelData.active ? Style.menuIndigo : Style.menuInk;
                              elide: Text.ElideRight;
                              Layout.fillWidth: true
                            }
                            Text {
                              text: modelData.active ? "Connected" : (modelData.sec ? "Secure" : "Open")
                              font.family: root.uiFont;
                              font.pixelSize: root.fontPx(9 + root.uiFontBump);
                              color: modelData.active ? Style.menuIndigo : Style.menuInkDeep
                            }
                          }
                          Text { text: modelData.sec ? "󰌾" : ""; font.family: root.uiFont; font.pixelSize: root.fontPx(12 + root.uiFontBump); color: Style.menuInkDeep }
                          Text { text: modelData.signal + "%"; font.family: root.uiFont; font.pixelSize: root.fontPx(9 + root.uiFontBump); color: Style.menuInkDeep }

                          // Disconnect affordance for active (exact marking from popup)
                          MouseArea {
                            visible: modelData.active; width: 18; height: 18
                            onClicked: { Quickshell.execDetached(["nmcli", "con", "down", "id", modelData.ssid]); root.scanWifi() }
                            Text { anchors.centerIn: parent; text: "󰅙"; font.family: root.uiFont; font.pixelSize: root.fontPx(14 + root.uiFontBump); color: Style.red }
                          }
                        }

                        MouseArea {
                          id: netMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: -1
                          onClicked: {
                            if (modelData.active) {
                              Quickshell.execDetached(["nmcli", "con", "down", "id", modelData.ssid])
                              root.scanWifi()
                              return
                            }
                            Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", modelData.ssid])
                          }
                        }
                      }
                    }
                  }
                }
                Text {
                  visible: root.wifiNetworks.length === 0
                  text: root.wifiScanning ? "Scanning..." : "No networks found. Tap Scan."
                  color: Style.menuInkDeep; font.pixelSize: root.fontPx(10 + root.uiFontBump); font.family: root.uiFont
                  Layout.alignment: Qt.AlignHCenter
                }
              }

              // ----------------------------------------------------
              // MONITORS VIEW (live layout viz + mirror/extend controls)
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "monitors"
                spacing: 8
                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    text: "󰍹 Monitors (" + (root.monitorList ? root.monitorList.length : 0) + ")"
                    font.pixelSize: root.fontPx(12 + root.uiFontBump); color: Style.green; font.family: root.uiFont; font.bold: true
                  }
                  Text {
                    text: root.monitorStatus || "Live layout"
                    color: root.monitorStatus.indexOf("failed") >= 0 || root.monitorStatus.indexOf("can't") >= 0 ? Style.red : Style.menuInkDeep
                    font.pixelSize: root.fontPx(9 + root.uiFontBump); font.family: root.uiFont
                    Layout.fillWidth: true; elide: Text.ElideRight
                  }
                  Rectangle {
                    width: 76; height: 26; radius: 5; color: mirrorMouse.containsMouse ? Style.menuRowHi : root.menuTileBg
                    border.color: mirrorMouse.containsMouse ? Style.menuSep : Style.menuSep; border.width: 1
                    Text { anchors.centerIn: parent; text: "Mirror"; font.pixelSize: root.fontPx(9 + root.uiFontBump); color: Style.menuInk; font.family: root.uiFont }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    MouseArea {
                      id: mirrorMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.mirrorMonitors()
                    }
                  }
                  Rectangle {
                    width: 76; height: 26; radius: 5; color: extendMouse.containsMouse ? Style.menuRowHi : root.menuTileBg
                    border.color: extendMouse.containsMouse ? Style.menuSep : Style.menuSep; border.width: 1
                    Text { anchors.centerIn: parent; text: "Extend"; font.pixelSize: root.fontPx(9 + root.uiFontBump); color: Style.menuInk; font.family: root.uiFont }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    MouseArea {
                      id: extendMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.extendMonitors()
                    }
                  }
                  Rectangle {
                    width: 76; height: 26; radius: 5; color: externalMouse.containsMouse ? Style.menuRowHi : root.menuTileBg
                    border.color: externalMouse.containsMouse ? Style.menuSep : Style.menuSep; border.width: 1
                    Text { anchors.centerIn: parent; text: "External"; font.pixelSize: root.fontPx(9 + root.uiFontBump); color: Style.menuInk; font.family: root.uiFont }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    MouseArea {
                      id: externalMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.externalOnlyMonitors()
                    }
                  }
                  Rectangle {
                    width: 76; height: 26; radius: 5; color: rescanMouse.containsMouse ? Style.menuRowHi : root.menuTileBg
                    border.color: rescanMouse.containsMouse ? Style.menuSep : Style.menuSep; border.width: 1
                    Text { anchors.centerIn: parent; text: "Rescan"; font.pixelSize: root.fontPx(9 + root.uiFontBump); color: Style.menuInk; font.family: root.uiFont }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    MouseArea {
                      id: rescanMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.rescanMonitors()
                    }
                  }
                }
                // Layout visualization (normalized rects from hyprctl coords)
                Rectangle {
                  Layout.fillWidth: true; Layout.preferredHeight: 420
                  radius: 6; color: Style.menuControlBg; border.color: Style.menuSep; border.width: 1
                  Canvas {
                    anchors.fill: parent; anchors.margins: 10
                    property int v: root.monitorVersion
                    onVChanged: requestPaint()
                    onPaint: {
                      const ctx = getContext("2d"); ctx.reset()
                      const mons = root.monitorList || []
                      if (!mons.length) {
                        ctx.fillStyle = Style.menuInkDeep
                        ctx.font = root.fontPx(12) + "px monospace"
                        ctx.fillText("Loading... (Rescan after open)", 10, 20)
                        return
                      }
                      let minX=0, minY=0, maxX=0, maxY=0
                      for (const m of mons) {
                        minX = Math.min(minX, m.x || 0)
                        minY = Math.min(minY, m.y || 0)
                        maxX = Math.max(maxX, (m.x || 0) + root.monitorLogicalWidth(m))
                        maxY = Math.max(maxY, (m.y || 0) + root.monitorLogicalHeight(m))
                      }
                      const W=width, H=height, pad=10
                      const sx=(W-2*pad)/Math.max(1,maxX-minX), sy=(H-2*pad)/Math.max(1,maxY-minY)
                      for (const m of mons) {
                        const x=pad+((m.x||0)-minX)*sx, y=pad+((m.y||0)-minY)*sy
                        const w=root.monitorLogicalWidth(m)*sx, h=root.monitorLogicalHeight(m)*sy
                        ctx.strokeStyle = Style.menuIndigo
                        ctx.lineWidth = 1
                        ctx.strokeRect(x, y, w, h)
                        ctx.fillStyle = m.focused
                          ? Qt.rgba(Style.menuIndigo.r, Style.menuIndigo.g, Style.menuIndigo.b, 0.24)
                          : root.menuTileBg
                        ctx.fillRect(x+1,y+1,w-2,h-2)
                        ctx.fillStyle = Style.menuInk
                        ctx.font = root.fontPx(13) + "px monospace"
                        ctx.fillText((m.name||"mon").slice(0,14), x+8, y+18)
                        ctx.font = root.fontPx(11) + "px monospace"
                        ctx.fillText(
                          Math.round(root.monitorLogicalWidth(m))+"x"+Math.round(root.monitorLogicalHeight(m))+" logical",
                          x+8,
                          y+34
                        )
                        ctx.fillText("scale " + (m.scale || 1) + "  " + (m.x || 0) + "," + (m.y || 0), x+8, y+48)
                      }
                    }
                  }
                }
                Text {
                  text: "Mirror uses eDP-1 as source when present. Extend reloads monitors.lua. Layout drawn in logical coordinates."
                  color: Style.menuInkDeep; font.pixelSize: root.fontPx(9 + root.uiFontBump); font.family: root.uiFont; Layout.alignment: Qt.AlignHCenter
                }
                Flickable { Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentHeight: monListCol.height
                  Column { id: monListCol; width: parent.width; spacing: 6
                    Repeater {
                      model: root.monitorList || []
                      delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 46; radius: 6
                        color: modelData.focused ? Qt.rgba(Style.menuIndigo.r, Style.menuIndigo.g, Style.menuIndigo.b, 0.16) : root.menuTileBg
                        border.color: modelData.focused ? Style.menuIndigo : Style.menuSep; border.width: 1
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                        RowLayout {
                          anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                          Text {
                            text: modelData.focused ? "󰍹" : "󰌢"
                            color: modelData.focused ? Style.menuIndigo : Style.menuInkDeep
                            font.pixelSize: root.fontPx(14 + root.uiFontBump); font.family: root.uiFont
                          }
                          ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text {
                              text: (modelData.name || "?")
                                + (modelData.mirrorOf && modelData.mirrorOf !== "none" ? (" mirrors " + modelData.mirrorOf) : "")
                              color: Style.menuInk; font.pixelSize: root.fontPx(10 + root.uiFontBump); font.family: root.uiFont; font.bold: modelData.focused
                              elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Text {
                              text: root.monitorMode(modelData) + "  scale " + (modelData.scale || 1)
                                + "  pos " + (modelData.x || 0) + "," + (modelData.y || 0)
                              color: Style.menuInkDeep; font.pixelSize: root.fontPx(8 + root.uiFontBump); font.family: root.uiFont
                              elide: Text.ElideRight; Layout.fillWidth: true
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }

              // ----------------------------------------------------
              // TEMPERATURES VIEW (full asahi-temperature output)
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "temp"
                spacing: 8
                Rectangle {
                  Layout.fillWidth: true; Layout.fillHeight: true
                  radius: 6; color: Style.menuControlBg; border.color: Style.menuSep; border.width: 1
                  Flickable {
                    anchors.fill: parent; anchors.margins: 8; clip: true
                    contentHeight: tempCol.height; boundsBehavior: Flickable.StopAtBounds
                    Column {
                      id: tempCol
                      width: parent.width; spacing: 8
                      Text {
                        visible: root.tempSensors.length === 0
                        text: root.tempOutput ? "No sensors parsed. Raw script output unavailable here." : "Loading sensors..."
                        font.family: root.uiFont; font.pixelSize: root.fontPx(10 + root.uiFontBump); color: Style.menuInkDeep
                        wrapMode: Text.Wrap; width: parent.width
                      }
                      Text {
                        visible: !!root.hottestSensor && root.tempGroups.length > 0
                        text: "Hottest: " + (root.hottestSensor ? ((root.hottestSensor.groupDisplayName || root.hottestSensor.group) + " / " + root.hottestSensor.displayLabel) : "") + " " + (root.hottestSensor ? root.hottestSensor.value.toFixed(1) : "") + "°C"
                        color: root.hottestSensor ? root.tempColor(root.hottestSensor.value) : Style.menuInkDeep
                        font.family: root.uiFont; font.pixelSize: root.fontPx(10 + root.uiFontBump); font.bold: true
                        width: parent.width; elide: Text.ElideRight
                      }
                      Repeater {
                        model: root.tempGroups
                        delegate: Rectangle {
                          required property var modelData
                          width: parent.width; height: groupCol.height + 14; radius: 6
                          color: root.menuTileBg; border.color: Style.menuSep; border.width: 1
                          Column {
                            id: groupCol
                            width: parent.width - 16; x: 8; y: 7; spacing: 5
                            RowLayout {
                              width: parent.width
                              Text {
                                text: modelData.displayName || modelData.name
                                color: Style.menuInk; font.pixelSize: root.fontPx(11 + root.uiFontBump); font.family: root.uiFont; font.bold: true
                                Layout.fillWidth: true; elide: Text.ElideRight
                              }
                              Text {
                                text: "avg " + modelData.avg.toFixed(1) + "°C"
                                color: root.tempColor(modelData.avg); font.pixelSize: root.fontPx(10 + root.uiFontBump); font.family: root.uiFont; font.bold: true
                              }
                            }
                            Repeater {
                              model: modelData.sensors
                              delegate: Column {
                                required property var modelData
                                required property int index
                                width: groupCol.width; spacing: 2
                                RowLayout {
                                  width: parent.width
                                  Text {
                                    text: modelData.displayLabel || modelData.label
                                    color: Style.menuInkDeep; font.pixelSize: root.fontPx(9 + root.uiFontBump); font.family: root.uiFont
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                  }
                                  Text {
                                    text: modelData.value.toFixed(1) + "°C"
                                    color: root.tempColor(modelData.value); font.pixelSize: root.fontPx(9 + root.uiFontBump); font.family: root.uiFont; font.bold: true
                                  }
                                }
                                Rectangle {
                                  width: parent.width; height: 5; radius: 3; color: Qt.rgba(0,0,0,0.22)
                                  Rectangle {
                                    width: parent.width * root.tempPercent(modelData.value); height: parent.height; radius: parent.radius
                                    color: root.tempColor(modelData.value)
                                  }
                                }
                                Text {
                                  visible: !!modelData.desc && (index === 0 || !modelData.sharedDesc)
                                  text: modelData.sharedDesc || modelData.desc
                                  color: Style.menuInkDeep; font.pixelSize: root.fontPx(8 + root.uiFontBump); font.family: root.uiFont
                                  width: parent.width; elide: Text.ElideRight
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

              // ----------------------------------------------------
              // BLUETOOTH VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "bluetooth"
                spacing: 10

                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    text: "Bluetooth Radio: " + (root.bluetoothPowered ? "Active" : "Off")
                    color: root.bluetoothPowered ? Style.green : Style.menuInkDeep
                    font.pixelSize: root.fontPx(11 + root.uiFontBump); font.family: root.uiFont; font.bold: true
                  }
                  Item { Layout.fillWidth: true }
                  Rectangle {
                    width: 70; height: 24; radius: 6; color: btPowerMa.containsMouse ? Style.menuRowHi : root.menuTileBg
                    border.color: btPowerMa.containsMouse ? Style.menuSep : Style.menuSep; border.width: 1
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }
                    Text {
                      anchors.centerIn: parent
                      text: root.bluetoothPowered ? "Turn Off" : "Turn On"
                      font.pixelSize: root.fontPx(10 + root.uiFontBump)
                      color: Style.menuInk
                      font.family: root.uiFont
                    }
                    MouseArea {
                      id: btPowerMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.toggleBluetoothPower()
                    }
                  }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Style.menuSep }

                Flickable {
                  Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                  contentHeight: btCol.height
                  boundsBehavior: Flickable.StopAtBounds
                  Column {
                    id: btCol; width: parent.width; spacing: 4
                    Repeater {
                      model: Bluetooth.devices ? Bluetooth.devices.values : []
                      delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 38; radius: 6
                        color: modelData.connected ? Style.menuRowSel : (bth.containsMouse ? Style.menuRowHi : "transparent")
                        border.width: 1
                        border.color: modelData.connected ? Style.menuSeal : (bth.containsMouse ? Style.menuSep : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        RowLayout {
                          anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                          Text { text: modelData.connected ? "󰂱" : "󰂯"; font.pixelSize: root.fontPx(14 + root.uiFontBump); color: modelData.connected ? Style.green : Style.menuInkDeep }

                          ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text { text: modelData.name || modelData.alias || modelData.address; font.pixelSize: root.fontPx(11 + root.uiFontBump); color: Style.menuInk; font.family: root.uiFont; elide: Text.ElideRight; font.bold: modelData.connected }
                            Text { text: modelData.batteryAvailable ? ("Battery: " + modelData.battery + "%") : (modelData.paired ? "Paired" : "Nearby Device"); font.pixelSize: root.fontPx(9 + root.uiFontBump); color: Style.menuInkDeep; font.family: root.uiFont }
                          }
                          Item { Layout.fillWidth: true }
                          Rectangle {
                            width: 64; height: 20; radius: 4
                            color: Style.menuControlBg
                            border.color: Style.menuSep; border.width: 1
                            Text { anchors.centerIn: parent; text: modelData.connected ? "󰂲" : (modelData.paired ? "󰂱" : "󰂯"); font.pixelSize: root.fontPx(14 + root.uiFontBump); color: Style.menuIndigo; font.family: root.uiFont }
                            MouseArea {
                              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                              onClicked: { if (modelData.connected) modelData.disconnect(); else if (modelData.paired) modelData.connect(); else modelData.pair() }
                            }
                          }
                        }
                        MouseArea { id: bth; anchors.fill: parent; hoverEnabled: true }
                      }
                    }
                  }
                }
                Text { visible: (!Bluetooth.devices || Bluetooth.devices.values.length === 0); text: "No devices found"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(11 + root.uiFontBump); font.family: root.uiFont; Layout.alignment: Qt.AlignHCenter }
              }

              // ----------------------------------------------------
              // POWER VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "power"
                spacing: 18

                Text { text: root.pendingConfirm ? "Confirm action: " + root.pendingConfirm + "?" : "Select Power Action"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(12 + root.uiFontBump); font.family: root.uiFont; Layout.alignment: Qt.AlignHCenter }

                GridLayout {
                  id: powerGrid
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  columns: 2
                  rowSpacing: 14
                  columnSpacing: 14
                  Repeater {
                    model: [
                      { icon: "󰌾", label: "Lock Session", act: () => root.doLock(), danger: false },
                      { icon: "󰒲", label: "Suspend", act: () => root.doSuspend(), danger: false },
                      { icon: "󰑓", label: "Reboot System", act: () => root.doReboot(), danger: true },
                      { icon: "󰐥", label: "Shutdown Power", act: () => root.doShutdown(), danger: true }
                    ]
                    delegate: Rectangle {
                      required property var modelData
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      Layout.preferredHeight: Math.max(118, (powerGrid.height - powerGrid.rowSpacing) / 2)
                      radius: 12
                      color: modelData.danger ? root.menuDangerBg : (pma.containsMouse ? Style.menuRowHi : root.menuTileBg)
                      border.color: pma.containsMouse ? (modelData.danger ? Style.red : Style.menuSep) : Style.menuSep
                      border.width: 1
                      scale: pma.containsMouse ? 1.02 : 1.0

                      Behavior on color { ColorAnimation { duration: 140 } }
                      Behavior on border.color { ColorAnimation { duration: 140 } }
                      Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                      Row { anchors.centerIn: parent; spacing: 12; Text { text: modelData.icon; font.pixelSize: root.fontPx(24 + root.uiFontBump); color: modelData.danger ? Style.red : Style.menuIndigo; font.family: root.uiFont } Text { text: modelData.label; font.pixelSize: root.fontPx(14 + root.uiFontBump); color: Style.menuInk; font.family: root.uiFont; font.bold: true } }
                      MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.act() }
                    }
                  }
                }

                RowLayout {
                  visible: !!root.pendingConfirm
                  Layout.alignment: Qt.AlignHCenter
                  spacing: 12

                  Rectangle { width: 118; height: 40; radius: 8; color: root.menuSuccessBg; border.width: 1; border.color: Style.green
                    Text { anchors.centerIn: parent; text: "Confirm"; color: Style.green; font.pixelSize: root.fontPx(12 + root.uiFontBump); font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.pendingConfirm === "reboot") root.doReboot(); else if (root.pendingConfirm === "shutdown") root.doShutdown() } }
                  }
                  Rectangle { width: 118; height: 40; radius: 8; color: Style.menuControlBg; border.width: 1; border.color: Style.menuSep
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(12 + root.uiFontBump) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cancelConfirm() }
                  }
                }
              }
            }
          }
        }
      }
    }

    // SCREENSHOT PREVIEW OVERLAY
    Rectangle {
      anchors.fill: parent
      color: Style.menuDim
      visible: root.shotPreviewPath !== ""
      radius: 16
      z: 30

      MouseArea { anchors.fill: parent; onClicked: root.shotPreviewPath = "" }

      Image {
        anchors.centerIn: parent
        width: parent.width * 0.86
        height: parent.height * 0.82
        source: root.shotPreviewPath !== "" ? "file://" + root.shotPreviewPath : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
      }

      RowLayout {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 28
        spacing: 10

        Rectangle {
          width: 96; height: 34; radius: 17
          color: copyShotPreviewMa.containsMouse ? root.menuSuccessBg : Style.menuControlBg
          border.width: 1
          border.color: copyShotPreviewMa.containsMouse ? Style.green : Style.menuSep
          Text { anchors.centerIn: parent; text: "Copy"; color: copyShotPreviewMa.containsMouse ? Style.green : Style.menuInk; font.pixelSize: root.fontPx(11 + root.uiFontBump); font.bold: true; font.family: root.uiFont }
          MouseArea {
            id: copyShotPreviewMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => { mouse.accepted = true; root.copyShot(root.shotPreviewPath) }
          }
        }

        Rectangle {
          width: 96; height: 34; radius: 17
          color: openShotPreviewMa.containsMouse ? Style.menuRowSel : Style.menuControlBg
          border.width: 1
          border.color: openShotPreviewMa.containsMouse ? Style.menuSeal : Style.menuSep
          Text { anchors.centerIn: parent; text: "Open"; color: openShotPreviewMa.containsMouse ? Style.menuSeal : Style.menuInk; font.pixelSize: root.fontPx(11 + root.uiFontBump); font.bold: true; font.family: root.uiFont }
          MouseArea { id: openShotPreviewMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openShot(root.shotPreviewPath) }
        }

        Rectangle {
          width: 96; height: 34; radius: 17
          color: deleteShotPreviewMa.containsMouse ? root.menuDangerBg : Style.menuControlBg
          border.width: 1
          border.color: deleteShotPreviewMa.containsMouse ? Style.red : Style.menuSep
          Text { anchors.centerIn: parent; text: "Delete"; color: deleteShotPreviewMa.containsMouse ? Style.red : Style.menuInk; font.pixelSize: root.fontPx(11 + root.uiFontBump); font.bold: true; font.family: root.uiFont }
          MouseArea {
            id: deleteShotPreviewMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
              mouse.accepted = true
              root.deleteShot(root.shotPreviewPath)
            }
          }
        }
      }
    }

    // WIDESCREEN WALLPAPER PICKER PREVIEW OVERLAY
    Rectangle {
      anchors.fill: parent
      color: Style.menuDim
      visible: root.wallpaperPreviewPath !== ""
      radius: 16

      MouseArea { anchors.fill: parent; onClicked: root.wallpaperPreviewPath = "" }

      Image {
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: parent.height * 0.8
        source: root.wallpaperPreviewPath !== "" ? "file://" + root.wallpaperPreviewPath : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
      }

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 30
        width: applyRow.width + 36
        height: 40
        radius: 20
        color: Style.menuSeal
        border.width: 1
        border.color: Style.menuSeal

        RowLayout {
          id: applyRow
          anchors.centerIn: parent
          spacing: 10
          Text { text: "✓"; color: Style.crust || "#11111b"; font.pixelSize: root.fontPx(14 + root.uiFontBump); font.bold: true }
          Text { text: "Apply Wallpaper"; color: Style.crust || "#11111b"; font.pixelSize: root.fontPx(12 + root.uiFontBump); font.bold: true; font.family: root.uiFont }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            WallpaperModule.WallpaperService.setWallpaper(root.wallpaperPreviewPath)
            root.wallpaperPreviewPath = ""
          }
        }
      }

      Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        text: "Press ESC or click anywhere to exit preview"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(11 + root.uiFontBump); font.family: root.uiFont
      }
    }
  }
}
