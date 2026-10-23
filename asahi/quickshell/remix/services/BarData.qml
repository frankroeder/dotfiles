pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// What every bar shows, fetched once: with two bars each one polled, forked and parsed the same data
// (two dnf checks, two nmcli monitors, two `hyprctl clients` per window event). Bars bind to this.
Singleton {
  id: root

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  // ---- CPU / RAM / heatpipe / SMC temperature, sampled in-process every 3 s ----
  property real cpuPerc: 0
  property real memPerc: 0
  property real heatpipeW: -1
  property real tempAvg: -1
  property var cpuHistory: []
  property var memHistory: []
  readonly property int maxGraphHist: 22
  property real cpuPrevTotal: 0
  property real cpuPrevIdle: 0
  property string heatpipePath: ""
  property var tempPaths: []

  function sampleStats() {
    procStat.reload()
    const f = procStat.text().split("\n", 1)[0].trim().split(/\s+/)
    let total = 0
    for (let i = 1; i <= 8; i++) total += Number(f[i]) || 0
    const idle = (Number(f[4]) || 0) + (Number(f[5]) || 0)
    const dt = total - cpuPrevTotal
    if (cpuPrevTotal > 0 && dt > 0) cpuPerc = Math.max(0, Math.round(100 * (dt - (idle - cpuPrevIdle)) / dt))
    cpuPrevTotal = total
    cpuPrevIdle = idle
    cpuHistory.push(cpuPerc)
    if (cpuHistory.length > maxGraphHist) cpuHistory.shift()

    procMeminfo.reload()
    const mt = /MemTotal:\s+(\d+)/.exec(procMeminfo.text())
    const ma = /MemAvailable:\s+(\d+)/.exec(procMeminfo.text())
    if (mt && ma) memPerc = Math.floor(100 * (Number(mt[1]) - Number(ma[1])) / Number(mt[1]))
    memHistory.push(memPerc)
    if (memHistory.length > maxGraphHist) memHistory.shift()

    if (heatpipePath !== "") {
      heatpipeFile.reload()
      const uw = Number(heatpipeFile.text().trim())
      heatpipeW = isFinite(uw) && heatpipeFile.text().trim() !== "" ? Math.round(uw / 100000) / 10 : -1
    }

    // Average of the SMC system temperatures (Asahi exposes no SoC die °C), millidegrees.
    let sum = 0, n = 0
    for (let i = 0; i < tempFiles.count; i++) {
      const fv = tempFiles.objectAt(i)
      fv.reload()
      const v = Number(fv.text().trim())
      if (fv.text().trim() !== "" && isFinite(v)) { sum += v; n++ }
    }
    tempAvg = n > 0 ? Math.round(sum / n / 1000) : -1
  }

  Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.sampleStats() }
  FileView { id: procStat; path: "/proc/stat"; blockLoading: true }
  FileView { id: procMeminfo; path: "/proc/meminfo"; blockLoading: true }
  FileView { id: heatpipeFile; path: root.heatpipePath; blockLoading: true }
  Instantiator {
    id: tempFiles
    model: root.tempPaths
    delegate: FileView { required property string modelData; path: modelData; blockLoading: true }
  }
  Process {
    running: true
    command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do [ \"$(cat \"$d/name\")\" = macsmc_hwmon ] && ls \"$d\"/temp*_input; done"]
    stdout: StdioCollector { onStreamFinished: root.tempPaths = text.split("\n").filter(p => p !== "") }
  }
  Process {
    running: true
    command: ["sh", "-c", "for f in /sys/class/hwmon/hwmon*/power*_label; do " +
      "case $(cat \"$f\") in Heatpipe*) echo \"${f%_label}_input\"; exit;; esac; done"]
    stdout: StdioCollector { onStreamFinished: root.heatpipePath = text.trim() }
  }

  // ---- SysPanel detail: per-core list and tooltips, only while a panel asks (the scripts fork) ----
  property string cpuTooltip: ""
  property string memTooltip: ""
  property var cpuCores: []
  function refreshDetail() {
    if (!cpuScriptProc.running) cpuScriptProc.running = true
    if (!memScriptProc.running) memScriptProc.running = true
  }
  Process {
    id: cpuScriptProc
    command: [root.binDir + "/asahi-cpu"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          root.cpuTooltip = data.tooltip || ""
          root.cpuCores = data.cores || []
        } catch (e) {}
      }
    }
  }
  Process {
    id: memScriptProc
    command: [root.binDir + "/asahi-memory"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.memTooltip = JSON.parse(text.trim()).tooltip || "" } catch (e) {}
      }
    }
  }

  // ---- Apple Silicon (notch geometry) ----
  property bool appleSiliconHost: false
  Process {
    running: true
    command: ["bash", "-c", "grep -qi apple /proc/device-tree/compatible 2>/dev/null && echo yes || echo no"]
    stdout: StdioCollector { onStreamFinished: root.appleSiliconHost = text.trim() === "yes" }
  }

  // ---- Package updates, every 30 min ----
  property bool updatesAvailable: false
  Process {
    id: updatesProc
    // No --cacheonly: as a user it reads ~/.cache/libdnf5 even when days old (asahi-pkg updates).
    // Offline (exit 1) falls back to the cache, so known updates do not vanish from the bar.
    command: ["sh", "-c", "dnf check-update -q >/dev/null 2>&1; c=$?; "
      + "[ $c = 1 ] && { dnf check-update --cacheonly -q >/dev/null 2>&1; c=$?; }; [ $c = 100 ] && echo 1 || echo 0"]
    stdout: StdioCollector { onStreamFinished: root.updatesAvailable = text.trim() === "1" }
  }
  Timer {
    interval: 1800000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: if (!updatesProc.running) updatesProc.running = true
  }

  // ---- Hyprland clients for the workspace icons ----
  property var hyprClients: []
  property int wsWindowVersion: 0
  property int wsIconRefreshes: 0
  // refreshMonitors: Quickshell applies `workspace` before `focusedmon` (stale activeWorkspace).
  function refreshWorkspaceIcons(retries) {
    wsWindowVersion = (wsWindowVersion + 1) % 10000
    Hyprland.refreshMonitors()
    if (!hyprClientsProc.running) hyprClientsProc.running = true
    if (retries > wsIconRefreshes) wsIconRefreshes = retries
    if (wsIconRefreshes > 0 && !wsIconRefreshTimer.running) wsIconRefreshTimer.restart()
  }
  Process {
    id: hyprClientsProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.hyprClients = JSON.parse(text.trim())
          root.wsWindowVersion = (root.wsWindowVersion + 1) % 10000
        } catch (e) {}
      }
    }
    Component.onCompleted: root.refreshWorkspaceIcons(0)
  }
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      const n = event.name || ""
      // Not activewindow: it fires on every pointer crossing (the glyph follows activeToplevel).
      if (["openwindow", "closewindow", "movewindow", "workspace", "focusedmon", "changefloatingmode", "fullscreen", "pin",
           "togglegroup", "moveintogroup", "moveoutofgroup"].some(x => n.includes(x)))
        root.refreshWorkspaceIcons(n.includes("openwindow") ? 8 : 0)
    }
  }
  Connections {
    target: Hyprland.toplevels
    ignoreUnknownSignals: true
    function onValuesChanged() { root.refreshWorkspaceIcons(4) }
  }
  Connections {
    target: Hyprland.workspaces
    ignoreUnknownSignals: true
    function onValuesChanged() { root.refreshWorkspaceIcons(0) }
  }
  Timer {
    id: wsIconRefreshTimer
    interval: 180
    repeat: true
    onTriggered: {
      root.wsIconRefreshes--
      root.refreshWorkspaceIcons(0)
      if (root.wsIconRefreshes <= 0) stop()
    }
  }

  // ---- Network: nmcli monitor pushes changes; the slow poll only tracks Wi-Fi signal ----
  property string netText: "󰤨"
  property string netName: ""
  property bool vpnUp: false
  property string vpnName: ""
  property int vpnSince: 0
  function refreshNet() { if (!netProc.running) netProc.running = true }
  Process {
    id: netProc
    command: [root.binDir + "/asahi-network", "--bar"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          root.netText = data.text || "󰤮"
          root.netName = data.name || ""
          root.vpnUp = !!data.vpn
          root.vpnName = data.vpnName || ""
          root.vpnSince = Number(data.vpnSince) || 0
        } catch (e) {}
      }
    }
  }
  Process {
    running: true
    // pdeathsig: nmcli dies with qs (a SIGTERMed qs would orphan it).
    command: ["setpriv", "--pdeathsig", "TERM", "nmcli", "monitor"]
    stdout: SplitParser { onRead: netDebounce.restart() }
  }
  Timer { id: netDebounce; interval: 500; onTriggered: root.refreshNet() }
  Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshNet() }
}
