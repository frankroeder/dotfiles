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

pragma ComponentBehavior: Bound

Scope {
  id: root

  property bool shouldShow: false
  property var featureScreen: null
  property string mode: "hub"  // hub | wallpaper | screenshots | media | network | monitors | temp | bluetooth | power
  property string pendingConfirm: ""
  property bool bluetoothPowered: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
  // Manual Media page Cava panel height.
  property int mediaCavaHeight: 220
  readonly property int uiFontBump: 2

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property string shotDir: Quickshell.env("HOME") + "/screenshots"

  // Live wifi status for overview tile (enriched for native menu like NetworkPopupWindow)
  property string wifiLabel: "WiFi"
  property string wifiTooltip: ""
  Process {
    id: wifiProc
    command: [binDir + "/asahi-network"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(text.trim())
          root.wifiLabel = (d.text || "WiFi").replace(/<[^>]*>/g, "")
          root.wifiTooltip = d.tooltip || ""
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

  Process {
    id: sidebarProc
    command: [
      "sh", "-c",
      "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' ; " +
      "free | grep Mem | awk '{print $3/$2 * 100}' ; " +
      "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || " +
      "cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 100 ; " +
      "cat /sys/class/power_supply/BAT0/status 2>/dev/null || " +
      "cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo 'Full'"
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const lines = text.trim().split("\n")
          if (lines.length >= 4) {
            root.sidebarCpu = Math.round(parseFloat(lines[0]) || 0)
            root.sidebarMem = Math.round(parseFloat(lines[1]) || 0)
            root.sidebarBat = Math.round(parseFloat(lines[2]) || 100)
            root.sidebarBatStatus = lines[3].trim()
          }
        } catch (_) {}
      }
    }
  }
  Timer {
    interval: 3000; running: shouldShow; repeat: true; triggeredOnStart: true
    onTriggered: sidebarProc.running = true
  }

  // Embedded wifi (native, no popup) - enriched like NetworkPopupWindow
  property var wifiNetworks: []
  property bool wifiEnabled: true
  property string currentWifiSsid: ""
  property bool wifiScanning: false
  function scanWifi() {
    wifiScanning = true
    wifiListProc.running = true
    wifiPowerCheck.running = true
  }
  Process {
    id: wifiListProc
    command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "auto"]
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
        root.wifiNetworks = out.slice(0, 12)
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
    onTriggered: {
      wifiProc.running = true
      wifiPowerCheck.running = true
      ethCheck.running = true
    }
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
    let group = ""
    let last = null
    const lines = (out || "").split("\n")
    for (const line of lines) {
      if (line.indexOf("Hottest:") === 0) break
      const gm = line.match(/^>>> (.+?) \((.+)\)$/)
      if (gm) {
        group = gm[1]
        continue
      }
      const sm = line.match(/^\s*(\S+)\s+(.+?)\s+(-?\d+(?:\.\d+)?)°C\s+(.+)$/)
      if (sm) {
        last = { group: group || sm[1], name: sm[1], label: sm[2].trim(), value: Number(sm[3]), path: sm[4].trim(), desc: "" }
        sensors.push(last)
        continue
      }
      const dm = line.match(/^\s{4}(.+)$/)
      if (dm && last) last.desc = dm[1].trim()
    }

    const groups = []
    for (const sensor of sensors) {
      let g = groups.find(item => item.name === sensor.group)
      if (!g) {
        g = { name: sensor.group, sensors: [], max: sensor.value }
        groups.push(g)
      }
      g.sensors.push(sensor)
      g.max = Math.max(g.max, sensor.value)
    }
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
    Quickshell.execDetached([
      "sh", "-c",
      "pkill -x cava 2>/dev/null || true; " +
      "mkdir -p ~/.config/cava; " +
      "echo '[general]' > ~/.config/cava/config; " +
      "echo 'bars=24' >> ~/.config/cava/config; " +
      "echo 'framerate=30' >> ~/.config/cava/config; " +
      "echo 'sensitivity=180' >> ~/.config/cava/config; " +
      "echo '[input]' >> ~/.config/cava/config; " +
      "echo 'method=pulse' >> ~/.config/cava/config; " +
      "echo '[output]' >> ~/.config/cava/config; " +
      "echo 'method=raw' >> ~/.config/cava/config; " +
      "echo 'raw_target=/dev/stdout' >> ~/.config/cava/config; " +
      "echo 'data_format=ascii' >> ~/.config/cava/config; " +
      "echo 'ascii_max_range=100' >> ~/.config/cava/config; " +
      "rm -f /tmp/quickshell_cava; " +
      "nohup bash -c 'cava -p ~/.config/cava/config 2>/dev/null | while IFS= read -r line; do printf \"%s\" \"$line\" > /tmp/quickshell_cava; done' >/dev/null 2>&1 & disown"
    ])
    cavaWatcher.path = ""
    Qt.callLater(function(){ cavaWatcher.path = "/tmp/quickshell_cava" })
  }
  function stopCava() {
    if (!cavaRunning) return
    cavaRunning = false
    Quickshell.execDetached(["pkill", "-x", "cava"])
  }
  FileView {
    id: cavaWatcher
    watchChanges: true
    onTextChanged: {
      const line = (text() || "").trim()
      if (!line) return
      const parts = line.split(/[;,\t ]+/)
      const vals = []
      for (let i=0; i<parts.length && i<24; i++) {
        const v = parseInt(parts[i]) || 0
        vals.push(Math.max(0, Math.min(100, v)))
      }
      while (vals.length < 24) vals.push(0)
      root.cavaValues = vals
    }
  }

  // Simple default sink/source volume (wpctl based, like asahi-audio)
  property string defaultSinkVol: "—"
  property string defaultSourceVol: "—"
  property var audioSinks: []
  property var audioSources: []
  property var audioStreams: []

  function pollAudioDefaults() {
    audioPollProc.command = [
      "sh", "-c",
      "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2*100}' ; " +
      "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk '{print $2*100}'"
    ]
    audioPollProc.running = true
  }
  Process {
    id: audioPollProc
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n")
        root.defaultSinkVol = lines[0] ? (Math.round(parseFloat(lines[0])) + "%") : "—"
        root.defaultSourceVol = lines[1] ? (Math.round(parseFloat(lines[1])) + "%") : "—"
      }
    }
  }
  function volAdjust(target, delta) {
    Quickshell.execDetached(["wpctl", "set-volume", target, (delta > 0 ? "+" : "") + "5%"])
    Qt.callLater(pollAudioDefaults)
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
    return { active: m[1] === "*", id: m[2], name: m[3].trim(), meta: m[4] || "" }
  }
  function parseAudioStatus(out) {
    const sinks = []
    const sources = []
    const streams = []
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
      if (trimmed.indexOf("Sinks:") !== -1) { section = "sink"; continue }
      if (trimmed.indexOf("Sources:") !== -1) { section = "source"; continue }
      if (trimmed.indexOf("Streams:") !== -1) { section = "stream"; continue }
      if (trimmed.indexOf("Filters:") !== -1) { section = "filter"; continue }
      if (trimmed.indexOf("Devices:") !== -1) { section = ""; continue }

      const item = parseAudioNode(line)
      if (!item) continue
      if (section === "sink" || (section === "filter" && item.meta.indexOf("Audio/Sink") !== -1)) sinks.push(item)
      else if (section === "source" || (section === "filter" && item.meta.indexOf("Audio/Source") !== -1)) sources.push(item)
      else if (section === "stream" || (section === "filter" && item.meta.indexOf("Stream/") !== -1)) streams.push(item)
    }

    root.audioSinks = sinks
    root.audioSources = sources
    root.audioStreams = streams
  }
  Process {
    id: audioMixerProc
    command: ["wpctl", "status"]
    stdout: StdioCollector { onStreamFinished: root.parseAudioStatus(text) }
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
      "wl-copy < \"$1\" && notify-send -a screenshot -t 900 'Copied' \"$(basename \"$1\")\"",
      "sh", p
    ])
  }
  function openShot(p) { if (p) Quickshell.execDetached(["xdg-open", p]) }
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

  function openFeature() {
    const mon = Hyprland.focusedMonitor
    featureScreen = mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
    shouldShow = true
    mode = "hub"
    pendingConfirm = ""
    monitorStatus = ""
    wifiProc.running = true
    wifiPowerCheck.running = true
    ffProc.running = true
    ethCheck.running = true
    monitorsProc.running = true
    tempProc.running = true
    scanShots()
  }
  function closeFeature() {
    shouldShow = false
    mode = "hub"
    pendingConfirm = ""
    stopCava()
  }

  // Power actions
  function doLock() { Quickshell.execDetached(["loginctl", "lock-session"]); closeFeature() }
  function doSuspend() { Quickshell.execDetached(["sh", "-c", "loginctl lock-session && systemctl suspend"]); closeFeature() }
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

    // Backdrop overlay
    MouseArea {
      anchors.fill: parent
      onClicked: root.closeFeature()
      Rectangle { anchors.fill: parent; color: Style.bgOverlay || "#88000000" }
    }

      // Centered console box
    Rectangle {
      id: box
      anchors.centerIn: parent
      width: Math.min(1080, parent.width * 0.86)
      height: Math.min(720, parent.height * 0.86)
      radius: 12
      color: Style.bgBase || Style.surface || "#1e1e2e"
      border.color: Style.bgBorder || Style.border || "#45475a"
      border.width: 1

      MouseArea { anchors.fill: parent; onClicked: event => event.accepted = true }

      Keys.onEscapePressed: {
        if (root.wallpaperPreviewPath !== "") {
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

        // LEFT NAVIGATION SIDEBAR
        Rectangle {
          id: sidebar
          Layout.preferredWidth: 220
          Layout.fillHeight: true
          color: Style.crust || "#11111b"
          topLeftRadius: 12
          bottomLeftRadius: 12

          // Right border divider
          Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Style.border || "#45475a"
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
                color: Style.moduleBg || "#313244"
                Text {
                  anchors.centerIn: parent
                  visible: distroIcon.source === ""
                  text: ""
                  font.pixelSize: 20 + root.uiFontBump
                  color: Style.blue || "#89b4fa"
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
                  color: Style.text || "#cdd6f4"
                  font.pixelSize: 13 + root.uiFontBump
                  font.bold: true
                  font.family: "JetBrainsMono Nerd Font"
                }
                Text {
                  text: "@asahi"
                  color: Style.textMuted || "#a6adc8"
                  font.pixelSize: 10 + root.uiFontBump
                  font.family: "JetBrainsMono Nerd Font"
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Style.border || "#45475a"
              opacity: 0.4
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
                  required property var modelData
                  Layout.fillWidth: true
                  height: 34
                  radius: 8
                  color: root.mode === modelData.key ? (Style.moduleBg || "#313244") : (navMa.containsMouse ? (Style.hoverBg || "#45475a") : "transparent")

                  Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    radius: 1.5
                    color: Style.blue || "#89b4fa"
                    visible: root.mode === modelData.key
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                      text: modelData.icon
                      font.pixelSize: 14 + root.uiFontBump
                      color: root.mode === modelData.key ? (Style.blue || "#89b4fa") : (Style.textMuted || "#a6adc8")
                      font.family: "JetBrainsMono Nerd Font"
                      Layout.preferredWidth: 18
                      horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                      text: modelData.label
                      font.pixelSize: 11 + root.uiFontBump
                      font.bold: root.mode === modelData.key
                      color: root.mode === modelData.key ? (Style.text || "#cdd6f4") : (Style.textAlt || "#bac2de")
                      font.family: "JetBrainsMono Nerd Font"
                    }
                  }

                  MouseArea {
                    id: navMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.mode = modelData.key
                      root.pendingConfirm = ""
                      if (modelData.key === "screenshots") root.scanShots()
                      else if (modelData.key === "network") { root.scanWifi(); ethCheck.running = true }
                      else if (modelData.key === "media") root.enterMedia()
                      else if (modelData.key === "monitors") monitorsProc.running = true
                      else if (modelData.key === "temp") tempProc.running = true
                      else if (modelData.key === "bluetooth") root.refreshBluetoothPower()
                    }
                  }
                }
              }
              Item { Layout.fillHeight: true }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Style.border || "#45475a"
              opacity: 0.4
            }

            // Quick stats telemetry in sidebar
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 8

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                  Text { text: "CPU Load"; font.pixelSize: 10 + root.uiFontBump; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
                  Item { Layout.fillWidth: true }
                  Text { text: root.sidebarCpu + "%"; font.pixelSize: 10 + root.uiFontBump; color: Style.orange || "#fab387"; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                }
                Rectangle {
                  Layout.fillWidth: true; height: 5; radius: 2.5; color: Style.moduleBg || "#313244"
                  Rectangle { width: parent.width * root.sidebarCpu / 100; height: parent.height; radius: 2.5; color: Style.orange || "#fab387" }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                  Text { text: "Memory"; font.pixelSize: 10 + root.uiFontBump; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
                  Item { Layout.fillWidth: true }
                  Text { text: root.sidebarMem + "%"; font.pixelSize: 10 + root.uiFontBump; color: Style.lavender || "#b4befe"; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                }
                Rectangle {
                  Layout.fillWidth: true; height: 5; radius: 2.5; color: Style.moduleBg || "#313244"
                  Rectangle { width: parent.width * root.sidebarMem / 100; height: parent.height; radius: 2.5; color: Style.lavender || "#b4befe" }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                  Text { text: "Battery"; font.pixelSize: 10 + root.uiFontBump; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
                  Item { Layout.fillWidth: true }
                  Text { text: root.sidebarBat + "%"; font.pixelSize: 10 + root.uiFontBump; color: Style.green || "#a6e3a1"; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                }
                Rectangle {
                  Layout.fillWidth: true; height: 5; radius: 2.5; color: Style.moduleBg || "#313244"
                  Rectangle { width: parent.width * root.sidebarBat / 100; height: parent.height; radius: 2.5; color: root.sidebarBatStatus === "Charging" ? Style.yellow : (root.sidebarBat < 20 ? Style.red : Style.green) }
                }
              }
            }
          }
        }

        // RIGHT MAIN CONTENT PANE
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Style.base || "#1e1e2e"
          topRightRadius: 12
          bottomRightRadius: 12

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header Row
            RowLayout {
              Layout.fillWidth: true

              Text {
                text: {
                  if (root.mode === "hub") return "󰕮  Dashboard"
                  if (root.mode === "wallpaper") return "󰸉  Wallpapers"
                  if (root.mode === "screenshots") return "󰹑  Screenshots Gallery"
                  if (root.mode === "media") return "󰝚  Media"
                  if (root.mode === "network") return "󰈀  Network"
                  if (root.mode === "monitors") return "󰍹  Monitors"
                  if (root.mode === "temp") return "󰔄  Temperatures"
                  if (root.mode === "bluetooth") return "󰂯  Bluetooth Devices"
                  if (root.mode === "power") return "󰐥  Power Actions"
                  return "Features"
                }
                color: Style.blue || "#89b4fa"
                font.pixelSize: 16 + root.uiFontBump
                font.family: "JetBrainsMono Nerd Font"
                font.bold: true
              }

              Item { Layout.fillWidth: true }

              Text {
                visible: root.mode === "screenshots" && root.shots.length
                text: root.shots.length + " recent"
                color: Style.textMuted
                font.pixelSize: 11 + root.uiFontBump
                font.family: "JetBrainsMono Nerd Font"
              }

              Rectangle {
                visible: root.mode !== "hub"
                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                color: "transparent"
                Text { anchors.centerIn: parent; text: "←"; color: Style.textMuted; font.pixelSize: 16 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font" }
                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.mode = "hub"; root.pendingConfirm = "" } }
              }

              Rectangle {
                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                color: "transparent"
                Text { anchors.centerIn: parent; text: "󰅖"; color: Style.textMuted; font.pixelSize: 16 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font" }
                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closeFeature() }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Style.border || "#45475a"
              opacity: 0.3
            }

            // DYNAMIC VIEWS CONTAINER
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              // ----------------------------------------------------
              // DASHBOARD VIEW (HUB)
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "hub"
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
                    color: Style.moduleBg || "#313244"
                    border.color: Style.border || "#45475a"
                    border.width: 1

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 14
                      spacing: 10

                      Text {
                        text: "󰌢  System Information"
                        color: Style.blue
                        font.pixelSize: 13 + root.uiFontBump
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                      }

                      // fastfetch pane (compact no-logo system overview)
                      Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 320
                        radius: 6
                        color: Style.surface || "#313244"
                        border.color: Style.border || "#45475a"
                        border.width: 1
                        clip: true
                        Flickable {
                          anchors.fill: parent; anchors.margins: 6
                          contentHeight: ffText.height; boundsBehavior: Flickable.StopAtBounds
                          Text {
                            id: ffText
                            text: root.fastfetchOut || "loading system info..."
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 + root.uiFontBump; color: Style.text
                            wrapMode: Text.Wrap; width: parent.width
                          }
                        }
                      }

                      Item { Layout.fillHeight: true }
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
                      color: Style.moduleBg || "#313244"
                      border.color: Style.border || "#45475a"
                      border.width: 1

                      ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        Text {
                          text: "󰎈  Now Playing"
                          color: Style.blue
                          font.pixelSize: 13 + root.uiFontBump
                          font.bold: true
                          font.family: "JetBrainsMono Nerd Font"
                        }

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: 10

                          Rectangle {
                            width: 36
                            height: 36
                            radius: 8
                            color: Style.surface || "#1e1e2e"
                            Text {
                              anchors.centerIn: parent
                              text: "󰎆"
                              font.pixelSize: 18 + root.uiFontBump
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
                              color: Style.text
                              font.pixelSize: 12 + root.uiFontBump
                              font.bold: true
                              font.family: "JetBrainsMono Nerd Font"
                              elide: Text.ElideRight
                              Layout.fillWidth: true
                            }
                            Text {
                              text: {
                                const p = root.activePlayer
                                if (!p) return "System Player"
                                return p.trackArtist || "Unknown Artist"
                              }
                              color: Style.textMuted
                              font.pixelSize: 10 + root.uiFontBump
                              font.family: "JetBrainsMono Nerd Font"
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
                            Text { anchors.centerIn: parent; text: "󰒮"; font.pixelSize: 18 + root.uiFontBump; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
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
                              font.pixelSize: 16 + root.uiFontBump
                              color: Style.green
                              font.family: "JetBrainsMono Nerd Font"
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
                            Text { anchors.centerIn: parent; text: "󰒭"; font.pixelSize: 18 + root.uiFontBump; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
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
                      color: Style.moduleBg || "#313244"
                      border.color: Style.border || "#45475a"
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
                          color: Style.text
                          font.pixelSize: 12 + root.uiFontBump
                          font.bold: true
                          font.family: "JetBrainsMono Nerd Font"
                          style: Text.Outline; styleColor: "#000000"
                        }
                        Item { Layout.fillHeight: true }
                        Text {
                          text: WallpaperModule.WallpaperService.currentWallpaper ? WallpaperModule.WallpaperService.currentWallpaper.split("/").pop() : "No wallpaper active"
                          color: Style.text
                          font.pixelSize: 10 + root.uiFontBump
                          font.bold: true
                          font.family: "JetBrainsMono Nerd Font"
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

                // Recent Screenshots strip
                Item {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 74
                  visible: root.shots.length > 0

                  ColumnLayout {
                    anchors.fill: parent
                    spacing: 4
                    RowLayout {
                      Layout.fillWidth: true
                      Text { text: "󰹑  Recent Screenshots"; color: Style.textMuted; font.pixelSize: 11 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                      Item { Layout.fillWidth: true }
                      Text {
                        text: "view all →"
                        color: Style.blue
                        font.pixelSize: 10 + root.uiFontBump
                        font.family: "JetBrainsMono Nerd Font"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = "screenshots" }
                      }
                    }
                    Row {
                      spacing: 8
                      Repeater {
                        model: root.shots.slice(0, 4)
                        delegate: Rectangle {
                          required property var modelData
                          width: 106; height: 50; radius: 8; clip: true
                          color: Style.surface || "#313244"
                          border.color: root.copiedShot === modelData.path ? Style.green : (dashShotMa.containsMouse ? Style.blue : "transparent")
                          border.width: 1

                          Image { anchors.fill: parent; anchors.margins: 1; source: "file://" + modelData.path; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(150, 90) }

                          Rectangle { anchors.fill: parent; color: Qt.rgba(0.4, 0.8, 0.5, 0.35); visible: root.copiedShot === modelData.path; Text { anchors.centerIn: parent; text: "COPIED"; color: "#cdd6f4"; font.pixelSize: 9 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true } }

                          MouseArea {
                            id: dashShotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (e) => { if (e.button === Qt.RightButton) root.openShot(modelData.path); else root.copyShot(modelData.path) }
                          }
                        }
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
                      color: Style.surface || "#313244"
                      border.color: reloadMa.containsMouse ? Style.blue : Style.border || "transparent"
                      border.width: 1

                      Row { anchors.centerIn: parent; spacing: 6; Text { text: modelData.icon; font.pixelSize: 13 + root.uiFontBump; color: Style.blue; font.family: "JetBrainsMono Nerd Font" } Text { text: modelData.label; font.pixelSize: 11 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font" } }
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
                  color: Style.surface || "#313244"
                  border.color: searchInput.activeFocus ? Style.blue : Style.border || "#45475a"
                  border.width: 1

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    TextInput {
                      id: searchInput
                      Layout.fillWidth: true
                      Layout.alignment: Qt.AlignVCenter
                      color: Style.text || "#cdd6f4"
                      font.pixelSize: 13 + root.uiFontBump
                      font.family: "JetBrainsMono Nerd Font"
                      clip: true
                      selectByMouse: true
                      onTextChanged: root.wallpaperSearchText = text
                    }

                    Text {
                      text: "Search wallpapers..."
                      color: Style.textMuted || "#a6adc8"
                      font.pixelSize: 13 + root.uiFontBump
                      font.family: "JetBrainsMono Nerd Font"
                      visible: searchInput.text === "" && !searchInput.activeFocus
                    }
                  }
                }

                GridView {
                  id: wallpaperGrid
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  cellWidth: Math.floor(width / 3)
                  cellHeight: cellWidth * 0.6 + 6
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
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
                      color: Style.surface || "#313244"
                      border.color: WallpaperModule.WallpaperService.currentWallpaper === modelData ? Style.green : (wallGridMa.containsMouse ? Style.blue : Style.border || "transparent")
                      border.width: WallpaperModule.WallpaperService.currentWallpaper === modelData ? 2 : 1
                      clip: true

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
                          color: Style.surface
                          visible: parent.status !== Image.Ready
                          Text { anchors.centerIn: parent; text: "󰋩"; color: Style.textMuted; font.pixelSize: 22 + root.uiFontBump }
                        }
                      }

                      Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 20
                        color: Qt.rgba(0, 0, 0, 0.6)
                        Text { anchors.centerIn: parent; text: modelData.split("/").pop(); color: "#ffffff"; font.pixelSize: 9 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideMiddle; width: parent.width - 6; horizontalAlignment: Text.AlignHCenter }
                      }

                      Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 18; height: 18; radius: 9
                        color: Style.green
                        visible: WallpaperModule.WallpaperService.currentWallpaper === modelData
                        Text { anchors.centerIn: parent; text: "✓"; color: Style.bg || "#1e1e2e"; font.pixelSize: 11 + root.uiFontBump; font.bold: true }
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
                  Text { text: "Left-click: apply • Right-click: widescreen preview"; color: Style.textMuted; font.pixelSize: 10 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font" }
                  Item { Layout.fillWidth: true }
                  Text { text: WallpaperModule.WallpaperService.wallpapers.length + " wallpapers"; color: Style.textMuted; font.pixelSize: 10 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font" }
                }
              }

              // ----------------------------------------------------
              // SCREENSHOTS VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "screenshots"
                spacing: 8

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8

                  Repeater {
                    model: [
                      { label: "󰄄  Region", k: "region" },
                      { label: "󰹑  Fullscreen", k: "fullscreen" }
                    ]
                    delegate: Rectangle {
                      required property var modelData
                      width: 110; height: 28; radius: 8
                      color: Style.moduleBg || "#313244"
                      border.color: ca.containsMouse ? Style.green : "transparent"
                      border.width: 1
                      Text { anchors.centerIn: parent; text: modelData.label; font.pixelSize: 11 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                      MouseArea { id: ca; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.capture(modelData.k) }
                    }
                  }
                  Item { Layout.fillWidth: true }
                  Text { text: "Click to copy • Right-click to open"; color: Style.textMuted; font.pixelSize: 10 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font" }
                }

                GridView {
                  id: shotGrid
                  Layout.fillWidth: true; Layout.fillHeight: true
                  cellWidth: Math.floor(width / 3)
                  cellHeight: cellWidth * 0.6 + 6
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
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
                      color: Style.surface || "#313244"
                      border.color: root.copiedShot === modelData.path ? Style.green : (hma.containsMouse ? Style.blue : Style.border || "transparent")
                      border.width: root.copiedShot === modelData.path ? 2 : 1

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
                        Text { anchors.centerIn: parent; text: modelData.label; color: "#ffffff"; font.pixelSize: 9 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight; width: parent.width-6; horizontalAlignment: Text.AlignHCenter }
                      }

                      Rectangle {
                        anchors.fill: parent; anchors.margins: 1; radius: 6; color: Qt.rgba(0.4,0.8,0.5,0.32); visible: root.copiedShot === modelData.path
                        Text { anchors.centerIn: parent; text: "COPIED"; color: "#ffffff"; font.pixelSize: 12 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                      }

                      MouseArea {
                        id: hma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (e) => { if (e.button === Qt.RightButton) root.openShot(modelData.path); else root.copyShot(modelData.path) }
                      }
                    }
                  }
                }
                Text { visible: root.shots.length === 0; text: "No screenshots in ~/screenshots"; color: Style.textMuted; font.pixelSize: 11 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; Layout.alignment: Qt.AlignHCenter }
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
                  color: Style.moduleBg || "#313244"
                  border.color: Style.border || "#45475a"
                  border.width: 1
                  Layout.preferredHeight: 76
                  Layout.maximumHeight: 76

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: "󰎈  Now Playing Status"; color: Style.blue; font.pixelSize: 12 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true }

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
                          color: Style.text
                          font.pixelSize: 12 + root.uiFontBump
                          font.bold: true
                          font.family: "JetBrainsMono Nerd Font"
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
                          Text { text: "󰒮"; font.pixelSize: 16 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
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
                            font.pixelSize: 15 + root.uiFontBump; color: Style.green; font.family: "JetBrainsMono Nerd Font"
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
                          Text { text: "󰒭"; font.pixelSize: 16 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
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
                    Layout.fillWidth: true; height: 36; radius: 8; color: Style.moduleBg || "#313244"
                    border.color: Style.border || "#45475a"; border.width: 1

                    RowLayout {
                      anchors.fill: parent; anchors.margins: 10
                      Text { text: "󰕾  Speakers"; font.pixelSize: 11 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                      Item { Layout.fillWidth: true }
                      Text { text: root.defaultSinkVol; font.pixelSize: 11 + root.uiFontBump; color: Style.blue; font.family: "JetBrainsMono Nerd Font"; font.bold: true }

                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.surface
                        Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 12 + root.uiFontBump; color: Style.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volAdjust("@DEFAULT_AUDIO_SINK@", -5) }
                      }
                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.surface
                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 12 + root.uiFontBump; color: Style.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volAdjust("@DEFAULT_AUDIO_SINK@", 5) }
                      }
                    }
                  }

                  // Mic Vol
                  Rectangle {
                    Layout.fillWidth: true; height: 36; radius: 8; color: Style.moduleBg || "#313244"
                    border.color: Style.border || "#45475a"; border.width: 1

                    RowLayout {
                      anchors.fill: parent; anchors.margins: 10
                      Text { text: "󰍬  Microphone"; font.pixelSize: 11 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                      Item { Layout.fillWidth: true }
                      Text { text: root.defaultSourceVol; font.pixelSize: 11 + root.uiFontBump; color: Style.blue; font.family: "JetBrainsMono Nerd Font"; font.bold: true }

                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.surface
                        Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 12 + root.uiFontBump; color: Style.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volAdjust("@DEFAULT_AUDIO_SOURCE@", -5) }
                      }
                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.surface
                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 12 + root.uiFontBump; color: Style.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volAdjust("@DEFAULT_AUDIO_SOURCE@", 5) }
                      }
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 52
                  Layout.maximumHeight: 52
                  spacing: 12

                  Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: Style.moduleBg || "#313244"
                    border.color: Style.border || "#45475a"
                    border.width: 1

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 8
                      spacing: 3

                      Text {
                        text: "󰕾  Output"
                        font.pixelSize: 10 + root.uiFontBump
                        color: Style.textMuted
                        font.family: "JetBrainsMono Nerd Font"
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
                            color: Style.textMuted
                            font.pixelSize: 9 + root.uiFontBump
                            font.family: "JetBrainsMono Nerd Font"
                          }
                          Repeater {
                            model: root.audioSinks
                            delegate: Rectangle {
                              required property var modelData
                              width: parent.width
                              height: 18
                              radius: 5
                              color: modelData.active
                                ? Qt.rgba(Style.blue.r, Style.blue.g, Style.blue.b, 0.18)
                                : (outMa.containsMouse ? Style.surface : "transparent")
                              border.color: modelData.active ? Style.blue : "transparent"
                              border.width: 1
                              RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 7
                                anchors.rightMargin: 7
                                spacing: 6
                                Text {
                                  text: modelData.active ? "●" : "○"
                                  color: modelData.active ? Style.green : Style.textMuted
                                  font.pixelSize: 7 + root.uiFontBump
                                }
                                Text {
                                  text: modelData.name
                                  color: Style.text
                                  font.pixelSize: 8 + root.uiFontBump
                                  font.family: "JetBrainsMono Nerd Font"
                                  elide: Text.ElideRight
                                  Layout.fillWidth: true
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
                    color: Style.moduleBg || "#313244"
                    border.color: Style.border || "#45475a"
                    border.width: 1

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 8
                      spacing: 3

                      Text {
                        text: "󰍬  Input"
                        font.pixelSize: 10 + root.uiFontBump
                        color: Style.textMuted
                        font.family: "JetBrainsMono Nerd Font"
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
                            color: Style.textMuted
                            font.pixelSize: 9 + root.uiFontBump
                            font.family: "JetBrainsMono Nerd Font"
                          }
                          Repeater {
                            model: root.audioSources
                            delegate: Rectangle {
                              required property var modelData
                              width: parent.width
                              height: 18
                              radius: 5
                              color: modelData.active
                                ? Qt.rgba(Style.blue.r, Style.blue.g, Style.blue.b, 0.18)
                                : (inMa.containsMouse ? Style.surface : "transparent")
                              border.color: modelData.active ? Style.blue : "transparent"
                              border.width: 1
                              RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 7
                                anchors.rightMargin: 7
                                spacing: 6
                                Text {
                                  text: modelData.active ? "●" : "○"
                                  color: modelData.active ? Style.green : Style.textMuted
                                  font.pixelSize: 7 + root.uiFontBump
                                }
                                Text {
                                  text: modelData.name
                                  color: Style.text
                                  font.pixelSize: 8 + root.uiFontBump
                                  font.family: "JetBrainsMono Nerd Font"
                                  elide: Text.ElideRight
                                  Layout.fillWidth: true
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
                  Layout.preferredHeight: 88
                  Layout.maximumHeight: 88
                  radius: 10
                  color: Style.moduleBg || "#313244"
                  border.color: Style.border || "#45475a"
                  border.width: 1

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 3

                    Text {
                      text: "󰝚  Stream mixer"
                      font.pixelSize: 10 + root.uiFontBump
                      color: Style.textMuted
                      font.family: "JetBrainsMono Nerd Font"
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
                          color: Style.textMuted
                          font.pixelSize: 9 + root.uiFontBump
                          font.family: "JetBrainsMono Nerd Font"
                        }
                        Repeater {
                          model: root.audioStreams
                          delegate: RowLayout {
                            required property var modelData
                            width: parent.width
                            height: 22
                            Text {
                              text: modelData.name
                              color: Style.text
                              font.pixelSize: 9 + root.uiFontBump
                              font.family: "JetBrainsMono Nerd Font"
                              elide: Text.ElideRight
                              Layout.fillWidth: true
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
                  color: Style.moduleBg || "#313244"
                  border.color: Style.border || "#45475a"
                  border.width: 1

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    Text { text: "󰎈  Live Cava Audio Spectrum"; color: Style.textMuted; font.pixelSize: 10 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true }

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
                  Text { text: "󰈀 Network"; font.pixelSize: 12 + root.uiFontBump; color: Style.green; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                  Text {
                    text: root.wifiNetworks.length + " Wi-Fi networks"
                    color: Style.textMuted; font.pixelSize: 10 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"
                  }
                  Item { Layout.fillWidth: true }
                  Rectangle {
                    width: 70; height: 24; radius: 6; color: Style.moduleBg || "#313244"
                    border.color: Style.border; border.width: 1
                    Text { anchors.centerIn: parent; text: "Refresh"; font.pixelSize: 10 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: { root.scanWifi(); root.ethCheck.running = true }
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 10

                  Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 146
                    radius: 6; color: Qt.rgba(0,0,0,0.15); border.color: Style.border; border.width: 1
                    ColumnLayout {
                      anchors.fill: parent; anchors.margins: 12; spacing: 6
                      RowLayout {
                        Layout.fillWidth: true
                        Text { text: "󰤨 Wi-Fi"; color: Style.blueAlt; font.pixelSize: 12 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                        Text {
                          text: root.wifiEnabled ? "enabled" : "disabled"
                          color: root.wifiEnabled ? Style.green : Style.red
                          font.pixelSize: 10 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true
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
                            font.pixelSize: 9 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true
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
                        color: Style.text; font.pixelSize: 11 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true
                        elide: Text.ElideRight
                      }
                      Text {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: root.wifiTooltip || "No Wi-Fi connection details"
                        color: Style.textMuted; font.pixelSize: 9 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignTop
                      }
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 146
                    radius: 6; color: Qt.rgba(0,0,0,0.15); border.color: Style.border; border.width: 1
                    ColumnLayout {
                      anchors.fill: parent; anchors.margins: 12; spacing: 6
                      RowLayout {
                        Layout.fillWidth: true
                        Text { text: "󰈀 LAN"; color: Style.cyan; font.pixelSize: 12 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                        Text {
                          text: root.ethDevice ? root.ethState : "missing"
                          color: root.ethConnected ? Style.green : Style.textMuted
                          font.pixelSize: 10 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true
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
                            font.pixelSize: 9 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true
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
                        color: Style.text; font.pixelSize: 11 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true
                        elide: Text.ElideRight
                      }
                      Text {
                        Layout.fillWidth: true
                        text: root.ethConnection || (
                          root.ethDevices.length > 1 ? (root.ethDevices.length + " ethernet devices") : "No active LAN connection"
                        )
                        color: Style.textMuted; font.pixelSize: 9 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"
                        elide: Text.ElideRight
                      }
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  Text { text: "Available networks"; font.pixelSize: 10 + root.uiFontBump; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
                  Text {
                    visible: root.wifiScanning; text: " (scanning...)"
                    font.pixelSize: 9 + root.uiFontBump; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font"
                  }
                  Item { Layout.fillWidth: true }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Style.border; opacity: 0.4 }

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
                        width: parent.width - 8; x: 4; height: 34; radius: 6
                        color: modelData.active
                          ? Qt.rgba(Style.blue.r, Style.blue.g, Style.blue.b, 0.16)
                          : (netMa.containsMouse ? Qt.rgba(Style.surface.r, Style.surface.g, Style.surface.b, 0.25) : "transparent")
                        border.color: modelData.active ? Style.blueAlt : "transparent"
                        border.width: modelData.active ? 1 : 0

                        RowLayout {
                          anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                          Text {
                            text: modelData.signal > 75 ? "󰤨" : (modelData.signal > 50 ? "󰤥" : (modelData.signal > 25 ? "󰤢" : "󰤟"))
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 + root.uiFontBump
                            color: modelData.active ? Style.blueAlt : Style.textMuted
                          }
                          ColumnLayout {
                            spacing: 0; Layout.fillWidth: true
                            Text {
                              text: modelData.ssid;
                              font.family: "JetBrainsMono Nerd Font";
                              font.pixelSize: 11 + root.uiFontBump;
                              font.bold: modelData.active
                              color: modelData.active ? Style.blueAlt : Style.text;
                              elide: Text.ElideRight;
                              Layout.fillWidth: true
                            }
                            Text {
                              text: modelData.active ? "Connected" : (modelData.sec ? "Secure" : "Open")
                              font.family: "JetBrainsMono Nerd Font";
                              font.pixelSize: 9 + root.uiFontBump;
                              color: modelData.active ? Style.blueAlt : Style.textMuted
                            }
                          }
                          Text { text: modelData.sec ? "󰌾" : ""; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 + root.uiFontBump; color: Style.textMuted }
                          Text { text: modelData.signal + "%"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9 + root.uiFontBump; color: Style.textMuted }

                          // Disconnect affordance for active (exact marking from popup)
                          MouseArea {
                            visible: modelData.active; width: 18; height: 18
                            onClicked: { Quickshell.execDetached(["nmcli", "con", "down", "id", modelData.ssid]); root.scanWifi() }
                            Text { anchors.centerIn: parent; text: "󰅙"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 + root.uiFontBump; color: Style.red }
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
                  color: Style.textMuted; font.pixelSize: 10 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"
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
                    font.pixelSize: 12 + root.uiFontBump; color: Style.green; font.family: "JetBrainsMono Nerd Font"; font.bold: true
                  }
                  Text {
                    text: root.monitorStatus || "Live layout"
                    color: root.monitorStatus.indexOf("failed") >= 0 || root.monitorStatus.indexOf("can't") >= 0 ? Style.red : Style.textMuted
                    font.pixelSize: 9 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"
                    Layout.fillWidth: true; elide: Text.ElideRight
                  }
                  Rectangle {
                    width: 76; height: 26; radius: 5; color: mirrorMouse.containsMouse ? Style.hoverBg : (Style.moduleBg || "#313244")
                    border.color: Style.border; border.width: 1
                    Text { anchors.centerIn: parent; text: "Mirror"; font.pixelSize: 9 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea {
                      id: mirrorMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.mirrorMonitors()
                    }
                  }
                  Rectangle {
                    width: 76; height: 26; radius: 5; color: extendMouse.containsMouse ? Style.hoverBg : (Style.moduleBg || "#313244")
                    border.color: Style.border; border.width: 1
                    Text { anchors.centerIn: parent; text: "Extend"; font.pixelSize: 9 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea {
                      id: extendMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.extendMonitors()
                    }
                  }
                  Rectangle {
                    width: 76; height: 26; radius: 5; color: externalMouse.containsMouse ? Style.hoverBg : (Style.moduleBg || "#313244")
                    border.color: Style.border; border.width: 1
                    Text { anchors.centerIn: parent; text: "External"; font.pixelSize: 9 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea {
                      id: externalMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.externalOnlyMonitors()
                    }
                  }
                  Rectangle {
                    width: 76; height: 26; radius: 5; color: rescanMouse.containsMouse ? Style.hoverBg : (Style.moduleBg || "#313244")
                    border.color: Style.border; border.width: 1
                    Text { anchors.centerIn: parent; text: "Rescan"; font.pixelSize: 9 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea {
                      id: rescanMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: root.rescanMonitors()
                    }
                  }
                }
                // Layout visualization (normalized rects from hyprctl coords)
                Rectangle {
                  Layout.fillWidth: true; Layout.preferredHeight: 360
                  radius: 6; color: Style.surface || "#313244"; border.color: Style.border; border.width: 1
                  Canvas {
                    anchors.fill: parent; anchors.margins: 10
                    property int v: root.monitorVersion
                    onVChanged: requestPaint()
                    onPaint: {
                      const ctx = getContext("2d"); ctx.reset()
                      const mons = root.monitorList || []
                      if (!mons.length) {
                        ctx.fillStyle=Style.textMuted; ctx.font="12px JetBrainsMono Nerd Font"
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
                        ctx.strokeStyle = Style.blue || "#89b4fa"; ctx.lineWidth=1
                        ctx.strokeRect(x, y, w, h)
                        ctx.fillStyle = m.focused ? "rgba(137,180,250,0.25)" : "rgba(49,50,68,0.5)"
                        ctx.fillRect(x+1,y+1,w-2,h-2)
                        ctx.fillStyle = Style.text || "#cdd6f4"; ctx.font="13px JetBrainsMono Nerd Font"
                        ctx.fillText((m.name||"mon").slice(0,14), x+8, y+18)
                        ctx.font="11px JetBrainsMono Nerd Font"
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
                  color: Style.textMuted; font.pixelSize: 9 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; Layout.alignment: Qt.AlignHCenter
                }
                Flickable { Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentHeight: monListCol.height
                  Column { id: monListCol; width: parent.width; spacing: 6
                    Repeater {
                      model: root.monitorList || []
                      delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 44; radius: 6
                        color: modelData.focused ? Qt.rgba(Style.blue.r, Style.blue.g, Style.blue.b, 0.16) : Qt.rgba(0,0,0,0.12)
                        border.color: modelData.focused ? Style.blueAlt : Style.border; border.width: 1
                        RowLayout {
                          anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 9; spacing: 10
                          Text {
                            text: modelData.focused ? "󰍹" : "󰌢"
                            color: modelData.focused ? Style.blueAlt : Style.textMuted
                            font.pixelSize: 14 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"
                          }
                          ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text {
                              text: (modelData.name || "?")
                                + (modelData.mirrorOf && modelData.mirrorOf !== "none" ? (" mirrors " + modelData.mirrorOf) : "")
                              color: Style.text; font.pixelSize: 10 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: modelData.focused
                              elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Text {
                              text: root.monitorMode(modelData) + "  scale " + (modelData.scale || 1)
                                + "  pos " + (modelData.x || 0) + "," + (modelData.y || 0)
                              color: Style.textMuted; font.pixelSize: 8 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"
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
                  radius: 6; color: Style.surface || "#313244"; border.color: Style.border; border.width: 1
                  Flickable {
                    anchors.fill: parent; anchors.margins: 8; clip: true
                    contentHeight: tempCol.height; boundsBehavior: Flickable.StopAtBounds
                    Column {
                      id: tempCol
                      width: parent.width; spacing: 8
                      Text {
                        visible: root.tempSensors.length === 0
                        text: root.tempOutput ? "No sensors parsed. Raw script output unavailable here." : "Loading sensors..."
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10 + root.uiFontBump; color: Style.textMuted
                        wrapMode: Text.Wrap; width: parent.width
                      }
                      Repeater {
                        model: root.tempGroups
                        delegate: Rectangle {
                          required property var modelData
                          width: parent.width; height: groupCol.height + 14; radius: 6
                          color: Qt.rgba(0,0,0,0.12); border.color: Style.border; border.width: 1
                          Column {
                            id: groupCol
                            width: parent.width - 16; x: 8; y: 7; spacing: 5
                            RowLayout {
                              width: parent.width
                              Text {
                                text: modelData.name
                                color: Style.text; font.pixelSize: 11 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true
                                Layout.fillWidth: true; elide: Text.ElideRight
                              }
                              Text {
                                text: modelData.max.toFixed(1) + "°C"
                                color: root.tempColor(modelData.max); font.pixelSize: 10 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true
                              }
                            }
                            Repeater {
                              model: modelData.sensors
                              delegate: Column {
                                required property var modelData
                                width: parent.width; spacing: 2
                                RowLayout {
                                  width: parent.width
                                  Text {
                                    text: modelData.label
                                    color: Style.textAlt; font.pixelSize: 9 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                  }
                                  Text {
                                    text: modelData.value.toFixed(1) + "°C"
                                    color: root.tempColor(modelData.value); font.pixelSize: 9 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true
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
                                  visible: !!modelData.desc
                                  text: modelData.desc
                                  color: Style.textMuted; font.pixelSize: 8 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"
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
                    color: root.bluetoothPowered ? Style.green : Style.textMuted
                    font.pixelSize: 11 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; font.bold: true
                  }
                  Item { Layout.fillWidth: true }
                  Rectangle {
                    width: 70; height: 24; radius: 6; color: Style.moduleBg || "#313244"
                    border.color: Style.border; border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: root.bluetoothPowered ? "Turn Off" : "Turn On"
                      font.pixelSize: 10 + root.uiFontBump
                      color: Style.text
                      font.family: "JetBrainsMono Nerd Font"
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: root.toggleBluetoothPower()
                    }
                  }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Style.border; opacity: 0.4 }

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
                        width: parent.width; height: 36; radius: 6
                        color: bth.containsMouse ? Style.moduleBg : "transparent"

                        RowLayout {
                          anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                          Text { text: modelData.connected ? "󰂱" : "󰂯"; font.pixelSize: 14 + root.uiFontBump; color: modelData.connected ? Style.green : Style.textMuted }

                          ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text { text: modelData.name || modelData.alias || modelData.address; font.pixelSize: 11 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight; font.bold: modelData.connected }
                            Text { text: modelData.batteryAvailable ? ("Battery: " + modelData.battery + "%") : (modelData.paired ? "Paired" : "Nearby Device"); font.pixelSize: 9 + root.uiFontBump; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
                          }
                          Item { Layout.fillWidth: true }
                          Rectangle {
                            width: 64; height: 20; radius: 4
                            color: Style.surface
                            border.color: Style.border; border.width: 1
                            Text { anchors.centerIn: parent; text: modelData.connected ? "󰂲" : (modelData.paired ? "󰂱" : "󰂯"); font.pixelSize: 14 + root.uiFontBump; color: Style.blue; font.family: "JetBrainsMono Nerd Font" }
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
                Text { visible: (!Bluetooth.devices || Bluetooth.devices.values.length === 0); text: "No devices found"; color: Style.textMuted; font.pixelSize: 11 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; Layout.alignment: Qt.AlignHCenter }
              }

              // ----------------------------------------------------
              // POWER VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "power"
                spacing: 12

                Text { text: root.pendingConfirm ? "Confirm action: " + root.pendingConfirm + "?" : "Select Power Action"; color: Style.textMuted; font.pixelSize: 12 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"; Layout.alignment: Qt.AlignHCenter }

                GridLayout {
                  Layout.fillWidth: true
                  columns: 2
                  rowSpacing: 12
                  columnSpacing: 12
                  Repeater {
                    model: [
                      { icon: "󰌾", label: "Lock Session", act: () => root.doLock(), danger: false },
                      { icon: "󰒲", label: "Suspend", act: () => root.doSuspend(), danger: false },
                      { icon: "󰑓", label: "Reboot System", act: () => root.doReboot(), danger: true },
                      { icon: "󰐥", label: "Shutdown Power", act: () => root.doShutdown(), danger: true }
                    ]
                    delegate: Rectangle {
                      required property var modelData
                      Layout.fillWidth: true; height: 50; radius: 10
                      color: modelData.danger ? (Style.red ? Qt.rgba(0.95,0.55,0.65,0.1) : "#2a1e1e") : (Style.moduleBg || "#313244")
                      border.color: pma.containsMouse ? (modelData.danger ? Style.red : Style.blue) : Style.border || "transparent"
                      border.width: 1

                      Row { anchors.centerIn: parent; spacing: 8; Text { text: modelData.icon; font.pixelSize: 20 + root.uiFontBump; color: modelData.danger ? Style.red : Style.blue; font.family: "JetBrainsMono Nerd Font" } Text { text: modelData.label; font.pixelSize: 12 + root.uiFontBump; color: Style.text; font.family: "JetBrainsMono Nerd Font"; font.bold: true } }
                      MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.act() }
                    }
                  }
                }

                RowLayout {
                  visible: !!root.pendingConfirm
                  Layout.alignment: Qt.AlignHCenter
                  spacing: 12

                  Rectangle { width: 90; height: 30; radius: 6; color: Style.green ? Qt.rgba(0.6,0.8,0.5,0.2) : "#1e2a1e"
                    Text { anchors.centerIn: parent; text: "Confirm"; color: Style.green; font.pixelSize: 12 + root.uiFontBump; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.pendingConfirm === "reboot") root.doReboot(); else if (root.pendingConfirm === "shutdown") root.doShutdown() } }
                  }
                  Rectangle { width: 90; height: 30; radius: 6; color: Style.surface || "#313244"
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Style.textMuted; font.pixelSize: 12 + root.uiFontBump }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cancelConfirm() }
                  }
                }
              }
            }
          }
        }
      }
    }

    // WIDESCREEN WALLPAPER PICKER PREVIEW OVERLAY
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.85)
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
        color: Style.blue || "#89b4fa"

        RowLayout {
          id: applyRow
          anchors.centerIn: parent
          spacing: 10
          Text { text: "✓"; color: Style.crust || "#11111b"; font.pixelSize: 14 + root.uiFontBump; font.bold: true }
          Text { text: "Apply Wallpaper"; color: Style.crust || "#11111b"; font.pixelSize: 12 + root.uiFontBump; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
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
        text: "Press ESC or click anywhere to exit preview"; color: Style.textMuted; font.pixelSize: 11 + root.uiFontBump; font.family: "JetBrainsMono Nerd Font"
      }
    }
  }
}
