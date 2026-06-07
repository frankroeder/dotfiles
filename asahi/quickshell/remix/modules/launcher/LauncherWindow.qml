import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../wallpaper" as Wallpaper
import "../menu" as Menu
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import "../../"
import "Data.js" as Data

Scope {
  id: root

  property var theme: Wallpaper.DefaultTheme
  property bool shouldShow: false
  property string query: ""
  property int selectedIndex: 0
  property var launcherScreen: null
  property int launcherWorkspaceId: 1
  property int resultCount: 0
  property int deVersion: 0
  property int dictVersion: 0
  property string dictStatus: ""
  property string dictPendingTerm: ""
  property string dictRunningTerm: ""
  property string dictCopyLang: ""
  property string dictError: ""
  property var dictItems: []
  property int fileVersion: 0
  property string fileStatus: ""
  property string filePendingTerm: ""
  property string fileRunningTerm: ""
  property var fileItems: []
  property var appUsage: ({})
  property int appUsageVersion: 0

  // Launcher palette state (category overview + drills + query shapes)
  property string categoryFilter: ""
  readonly property bool fileMode: root.categoryFilter === Data.fileCategory || root.fileTerm(root.query) !== null
  readonly property bool previewActive: root.fileMode
  readonly property bool quickMode: root.categoryFilter === "Quick"
  property string expandedQuickKey: ""
  readonly property bool quickDetailActive: root.quickMode && root.expandedQuickKey !== ""
  readonly property bool sideActive: root.previewActive || root.quickDetailActive
  readonly property int quickGridCols: root.quickDetailActive ? 1 : 3

  // Scoring (ported from launcher ref, tuned for small set)
  readonly property int scPrefix: 100
  readonly property int scTitle: 60
  readonly property int scKw: 20
  readonly property int scCat: 10
  readonly property int maxResults: 200

  readonly property string homeDir: Quickshell.env("HOME")

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property string uiFont: "Hack Nerd Font"
  readonly property string dictIcon: "file://" + Quickshell.env("HOME") + "/.dotfiles/asahi/quickshell/remix/assets/dict-cc.png"
  readonly property string webIconBase: "file://" + Quickshell.env("HOME") + "/.dotfiles/asahi/quickshell/remix/assets/"
  readonly property string websearchJsonPath: Quickshell.env("HOME") + "/.dotfiles/asahi/quickshell/remix/modules/launcher/websearch.json"
  property int webVersion: 0

  // Launcher-style data (nav + local items for categories + prefix specials for files/web/docs/calc/actions)
  readonly property var launcherItems: Data.annotate(Data.localItems)

  readonly property var quickActions: [
    { key: "dashboard", aliases: ["dash", "hub"], icon: "󰕮", name: "Dashboard", comment: "Open feature dashboard", mode: "hub" },
    { key: "wallpaper", aliases: ["wall", "paper"], icon: "󰸉", name: "Wallpapers", comment: "Open wallpaper picker", mode: "wallpaper" },
    { key: "screenshots", aliases: ["shots", "ss"], icon: "󰹑", name: "Screenshots", comment: "Open screenshot gallery", mode: "screenshots" },
    { key: "media", aliases: ["music", "audio"], icon: "󰝚", name: "Media", comment: "Open media and mixer", mode: "media" },
    { key: "network", aliases: ["wifi", "net"], icon: "󰈀", name: "Network", comment: "Open network controls", mode: "network" },
    { key: "monitors", aliases: ["display", "screen"], icon: "󰍹", name: "Monitors", comment: "Open monitor layout", mode: "monitors" },
    { key: "temp", aliases: ["temps", "temperature"], icon: "󰔄", name: "Temperatures", comment: "Open sensor view", mode: "temp" },
    { key: "bluetooth", aliases: ["bt"], icon: "󰂯", name: "Bluetooth", comment: "Open Bluetooth devices", mode: "bluetooth" },
    { key: "storage", aliases: ["disk", "space"], icon: "󰋊", name: "Storage", comment: "Disk usage and home folders", mode: "storage" },
    { key: "screensaver", aliases: ["saver"], icon: "󱄄", name: "Screensaver", comment: "Shader idle display", command: [root.binDir + "/asahi-screensaver", "toggle"] },
    { key: "reload", aliases: ["qs"], icon: "󰑐", name: "Reload Quickshell", comment: "Restart QS", command: [root.binDir + "/asahi-restart-quickshell"] },
    { key: "hypr", aliases: ["hyprland"], icon: "󰑓", name: "Reload Hyprland", comment: "Reload Hyprland config", command: [root.binDir + "/asahi-reload-hyprland"] },
    { key: "lock", aliases: ["lockscreen"], icon: "󰌾", name: "Lock", comment: "Lock session", command: ["loginctl", "lock-session"] },
    { key: "scratch", aliases: ["scratchpad"], icon: "󱂬", name: "Scratchpad", comment: "Toggle scratch workspace", command: ["hyprctl", "dispatch", "togglespecialworkspace", "scratch"] }
  ]

  readonly property var quickTiles: root.quickActions.filter(function(a) {
    return !!a.mode
  }).map(function(a) {
    return { key: a.key, glyph: a.icon, label: a.name, sub: a.comment, mode: a.mode }
  })

  // --- live data + exact hub/lower + side windows (ported from old featuremenu; now the only place, module removed)
  readonly property real uiFontScale: 1.2
  function fontPx(size) { return Math.round(size * root.uiFontScale) }
  function prettyBytes(bytes) {
    let value = Number(bytes) || 0
    if (value <= 0) return "0 B"
    const units = ["B", "KiB", "MiB", "GiB", "TiB"]
    let idx = 0
    while (value >= 1024 && idx < units.length - 1) { value /= 1024; idx++ }
    return value.toFixed(idx >= 2 && value < 100 ? 1 : 0) + " " + units[idx]
  }
  function storagePct(used, total) {
    total = Number(total) || 0
    used = Number(used) || 0
    return total > 0 ? Math.round(used * 100 / total) : 0
  }
  function storageTildify(path) {
    const home = root.homeDir
    if (!path) return ""
    if (path === home) return "~"
    return path.indexOf(home + "/") === 0 ? "~" + path.substring(home.length + 1) : path
  }
  // menu* from old feature for exact tile colors/behaviors in quick ports
  readonly property color menuTileBg: Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.03)
  readonly property color menuDangerBg: Qt.rgba(Style.red.r, Style.red.g, Style.red.b, 0.16)
  readonly property color menuSuccessBg: Qt.rgba(Style.green.r, Style.green.g, Style.green.b, 0.16)
  property int sidebarCpu: 0
  property int sidebarMem: 0
  property int sidebarBat: 100
  property string sidebarBatStatus: "Discharging"
  property real sidebarCpuPrevIdle: -1
  property real sidebarCpuPrevTotal: -1
  property var shots: []
  property string copiedShot: ""
  property string shotPreviewPath: ""
  Timer { id: copyClear; interval: 1200; onTriggered: copiedShot = "" }

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
    interval: (root.quickDetailActive && root.expandedQuickKey === "hub") ? 800 : 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!sidebarProc.running) sidebarProc.running = true
  }

  function scanShots() {
    shotScan.command = [
      "sh", "-c",
      "find \"" + (Quickshell.env("HOME") + "/screenshots") + "\" -maxdepth 1 -type f -name 'screenshot-*.png' 2>/dev/null | " +
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
    root.shots = (root.shots || []).filter(s => s.path !== p)
    Quickshell.execDetached([
      "sh", "-c",
      "rm -f -- \"$1\" && notify-send -a screenshot -t 900 'Deleted' \"$(basename \"$1\")\"",
      "sh", p
    ])
    Qt.callLater(root.scanShots)
  }

  property var storageMounts: []
  property var storageHomeDirs: []
  property real storageHomeTotal: 0
  property string storageStatus: "idle"
  property string storageUpdated: ""
  property string storageError: ""
  property bool storageScanHome: true

  function parseStorageMounts(text) {
    const mounts = []
    const lines = (text || "").trim().split("\n")
    const home = root.homeDir
    for (let i = 0; i < lines.length; i++) {
      const parts = lines[i].split("|")
      if (parts.length < 5) continue
      const mount = parts[0]
      const total = Number(parts[1]) || 0
      const used = Number(parts[2]) || 0
      const avail = Number(parts[3]) || 0
      const pct = Number(parts[4]) || root.storagePct(used, total)
      mounts.push({
        mount: mount,
        total: total,
        used: used,
        avail: avail,
        pct: pct,
        highlight: mount === "/" || mount === home || mount === "/home"
      })
    }
    mounts.sort((a, b) => {
      if (a.highlight !== b.highlight) return a.highlight ? -1 : 1
      return a.mount.localeCompare(b.mount)
    })
    root.storageMounts = mounts
  }

  function parseStorageHomeDirs(text) {
    const dirs = []
    let total = 0
    const lines = (text || "").trim().split("\n")
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      if (line.indexOf("TOTAL ") === 0) {
        total = Number(line.substring(6)) || 0
        continue
      }
      const tab = line.indexOf("\t")
      if (tab < 0) continue
      const bytes = Number(line.substring(0, tab)) || 0
      const path = line.substring(tab + 1)
      if (!path) continue
      dirs.push({
        path: path,
        name: root.storageTildify(path),
        bytes: bytes,
        pct: total > 0 ? Math.round(bytes * 100 / total) : 0
      })
    }
    root.storageHomeTotal = total > 0 ? total : dirs.reduce((s, d) => s + d.bytes, 0)
    const maxBytes = dirs.length > 0 ? dirs[0].bytes : 1
    for (let j = 0; j < dirs.length; j++) {
      dirs[j].bar = maxBytes > 0 ? dirs[j].bytes / maxBytes : 0
    }
    root.storageHomeDirs = dirs
  }

  function scanStorageMountsOnly() {
    storageDfProc.running = true
  }

  function scanStorageHomeDirs() {
    const home = root.homeDir
    storageDuProc.command = [
      "sh", "-c",
      "home=\"" + home.replace(/"/g, '\\"') + "\"; " +
      "printf 'TOTAL %s\\n' \"$(du -sb \"$home\" 2>/dev/null | awk '{print $1}')\"; " +
      "for e in \"$home\"/* \"$home\"/.[!.]*; do " +
      "[ -e \"$e\" ] || continue; du -sb \"$e\" 2>/dev/null; done | sort -rn | head -20"
    ]
    storageDuProc.running = true
  }

  function scanStorage() {
    if (storageDfProc.running || storageDuProc.running) return
    root.storageStatus = "scanning"
    root.storageError = ""
    root.storageScanHome = true
    storageDfProc.running = true
  }

  Process {
    id: storageDfProc
    running: false
    command: [
      "sh", "-c",
      "df -B1 -P 2>/dev/null | awk 'NR>1 && $1 !~ /^(tmpfs|devtmpfs|squashfs|efivarfs|overlay|none|vendorfw)$/ { " +
      "mount=$6; for (i=7; i<=NF; i++) mount=mount\" \"$i; " +
      "if (mount ~ /^\\/(run|dev|proc|sys)(\\/|$)/) next; " +
      "gsub(/%/, \"\", $5); print mount \"|\" $2 \"|\" $3 \"|\" $4 \"|\" $5 }'"
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.parseStorageMounts(text)
          if (root.storageScanHome) root.scanStorageHomeDirs()
          else {
            root.storageStatus = "ready"
            root.storageUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
          }
        } catch (e) {
          root.storageError = "Failed to parse mounts"
          root.storageStatus = "error"
        }
      }
    }
    onExited: (code) => {
      if (code !== 0 && root.storageMounts.length === 0) {
        root.storageError = "df failed"
        root.storageStatus = "error"
      }
    }
  }

  Process {
    id: storageDuProc
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.parseStorageHomeDirs(text)
          root.storageStatus = "ready"
          root.storageUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
        } catch (e) {
          root.storageError = "Failed to parse home folders"
          root.storageStatus = "error"
        }
      }
    }
    onExited: (code) => {
      if (code !== 0 && root.storageHomeDirs.length === 0 && root.storageStatus === "scanning") {
        root.storageError = "du failed"
        root.storageStatus = "error"
      }
    }
  }

  Timer {
    interval: 30000
    running: root.quickDetailActive && root.expandedQuickKey === "storage"
    repeat: true
    onTriggered: {
      if (!storageDfProc.running && !storageDuProc.running) {
        root.storageScanHome = false
        root.scanStorageMountsOnly()
      }
    }
  }

  // end duplicated procs/data

  // Components for side detail "feature popups" (show exactly the feature windows content in launcher side, per task)
  Component { id: quickHubComp; Item {
    id: quickHubRoot
    anchors.fill: parent
    property string ffTitle: "System"
    property string ffSubtitle: "fastfetch"
    property string ffUptime: ""
    property string ffUpdated: ""
    property int ffDiskPct: 0
    property int ffMemPct: 0
    property real ffMemUsedBytes: 0
    property real ffMemTotalBytes: 0
    property var ffLogoLines: []
    property var ffLeftRows: []
    property var ffRightRows: []
    readonly property int ffLabelWidth: 54
    readonly property string ffLogoText: quickHubRoot.ffLogoLines.join("\n")

    function stripAnsi(text) {
      return (text || "")
        .replace(/\u001b\[[0-9;]*[A-Za-z]/g, "")
        .replace(/\u001b\][^\u0007]*\u0007/g, "")
    }
    function prettyBytes(bytes) {
      let value = Number(bytes) || 0
      if (value <= 0) return "0 B"
      const units = ["B", "KiB", "MiB", "GiB", "TiB"]
      let idx = 0
      while (value >= 1024 && idx < units.length - 1) { value /= 1024; idx++ }
      return value.toFixed(idx >= 2 && value < 100 ? 1 : 0) + " " + units[idx]
    }
    function pct(used, total) {
      total = Number(total) || 0
      used = Number(used) || 0
      return total > 0 ? Math.round(used * 100 / total) : 0
    }
    function formatUptime(ms) {
      const sec = Math.max(0, Math.floor(Number(ms) / 1000))
      const days = Math.floor(sec / 86400)
      const hrs = Math.floor((sec % 86400) / 3600)
      const mins = Math.floor((sec % 3600) / 60)
      if (days > 0) return days + "d " + hrs + "h " + mins + "m"
      if (hrs > 0) return hrs + "h " + mins + "m"
      return mins + "m"
    }
    function parseLogo(text) {
      const lines = (text || "").split("\n")
      const logo = []
      for (let i = 0; i < lines.length; i++) {
        const line = quickHubRoot.stripAnsi(lines[i]).replace(/\r/g, "")
        if (/^-{3,}\s*$/.test(line.trim())) break
        if (line.trim().length === 0) continue
        if (line.indexOf("@") >= 0) continue
        logo.push(line)
      }
      quickHubRoot.ffLogoLines = logo
    }
    function ffRow(key, icon, accent, value) {
      return { key: key, icon: icon, accent: accent, value: value }
    }
    function parseFastfetch(text) {
      try {
        const data = JSON.parse((text || "").trim() || "[]")
        function one(type) {
          for (let i = 0; i < data.length; i++) {
            if (data[i] && data[i].type === type && data[i].result) return data[i].result
          }
          return null
        }
        const title = one("Title") || {}
        const os = one("OS") || {}
        const host = one("Host") || {}
        const kernel = one("Kernel") || {}
        const pkgs = one("Packages") || {}
        const cpu = one("CPU") || {}
        const gpus = one("GPU") || []
        const gpu = gpus.length > 0 ? gpus[0] : {}
        const mem = one("Memory") || {}
        const disks = one("Disk") || []
        const disk = disks.find(d => d.mountpoint === "/") || disks[0] || {}
        const displays = one("Display") || []
        const display = displays.length > 0 ? displays[0] : {}
        const wm = one("WM") || {}
        const shell = one("Shell") || {}
        const theme = one("Theme") || {}
        const ips = one("LocalIp") || []
        const ip = ips.find(x => x.defaultRoute && x.defaultRoute.ipv4) || ips[0] || {}
        const bats = one("Battery") || []
        const bat = bats.length > 0 ? bats[0] : {}
        const power = one("PowerAdapter") || []
        const adapter = power.length > 0 ? power[0] : {}
        const uptime = one("Uptime") || {}
        const locale = one("Locale") || ""
        const diskBytes = disk.bytes || {}
        const memUsed = Number(mem.used) || 0
        const memTotal = Number(mem.total) || 0
        const diskUsed = Number(diskBytes.used) || 0
        const diskTotal = Number(diskBytes.total) || 0
        const out = display.output || {}
        const scaled = display.scaled || out
        const phys = display.physical || {}
        const refresh = out.refreshRate ? (" @ " + Math.round(out.refreshRate) + " Hz") : ""
        const scale = (out.width && scaled.width && out.width !== scaled.width)
          ? (" @ " + (out.width / scaled.width).toFixed(2) + "x") : ""
        const diagIn = (phys.width && phys.height)
          ? Math.round(Math.sqrt(phys.width * phys.width + phys.height * phys.height) / 25.4) : 0
        const batteryStatus = Array.isArray(bat.status) ? bat.status.join(", ") : (bat.status || "")
        const cpuFreq = cpu.frequency && cpu.frequency.max
          ? (" @ " + (cpu.frequency.max / 1000).toFixed(2) + " GHz") : ""
        const gpuFreq = gpu.frequency ? (" @ " + (gpu.frequency / 1000).toFixed(2) + " GHz") : ""
        const gpuType = gpu.type ? (" [" + gpu.type + "]") : ""
        quickHubRoot.ffTitle = (title.userName && title.hostName)
          ? (title.userName + "@" + title.hostName) : (host.name || "System")
        quickHubRoot.ffSubtitle = os.prettyName || os.name || "fastfetch"
        quickHubRoot.ffUptime = quickHubRoot.formatUptime(uptime.uptime)
        quickHubRoot.ffDiskPct = quickHubRoot.pct(diskUsed, diskTotal)
        quickHubRoot.ffMemPct = quickHubRoot.pct(memUsed, memTotal)
        quickHubRoot.ffMemUsedBytes = memUsed
        quickHubRoot.ffMemTotalBytes = memTotal
        quickHubRoot.ffLeftRows = [
          quickHubRoot.ffRow("OS", "󰣇", Style.menuSeal,
            (os.prettyName || os.name || "—") + (kernel.architecture ? " " + kernel.architecture : "")),
          quickHubRoot.ffRow("Kernel", "󰣀", Style.teal,
            (kernel.name || "Linux") + " " + (kernel.release || "")),
          quickHubRoot.ffRow("Packages", "󰏖", Style.mauve,
            (pkgs.flatpakUser || 0) + " flatpak · " + (pkgs.rpm || 0) + " rpm"),
          quickHubRoot.ffRow("Display", "󰍹", Style.sapphire,
            (out.width || scaled.width || "?") + "x" + (out.height || scaled.height || "?")
              + scale + refresh + (diagIn ? (" · " + diagIn + '"') : "")
              + (display.name ? (" [" + display.name + "]") : "")),
          quickHubRoot.ffRow("CPU", "󰘚", Style.orange,
            (cpu.cpu || "—") + (cpu.cores && cpu.cores.logical ? (" (" + cpu.cores.logical + ")") : "") + cpuFreq),
          quickHubRoot.ffRow("Memory", "󰍛", Style.lavender,
            quickHubRoot.prettyBytes(memUsed) + " / " + quickHubRoot.prettyBytes(memTotal)
              + " (" + quickHubRoot.ffMemPct + "%)"),
          quickHubRoot.ffRow("Local IP", "󰩠", Style.cyan,
            (ip.name ? (ip.name + ": ") : "") + (ip.ipv4 || "—")),
          quickHubRoot.ffRow("Theme", "󰸌", Style.mauve, theme.theme2 || theme.theme1 || "—"),
          quickHubRoot.ffRow("Power", "󰚥", Style.yellow, adapter.watts ? (adapter.watts + "W adapter") : "—")
        ]
        quickHubRoot.ffRightRows = [
          quickHubRoot.ffRow("Host", "󰌢", Style.sky, host.name || host.family || "—"),
          quickHubRoot.ffRow("Uptime", "󰅐", Style.lavender, quickHubRoot.ffUptime || "—"),
          quickHubRoot.ffRow("Shell", "󰆍", Style.yellow,
            (shell.prettyName || shell.processName || "—") + (shell.version ? " " + shell.version : "")),
          quickHubRoot.ffRow("WM", "󰖯", Style.green,
            (wm.prettyName || wm.processName || "—")
              + (wm.version ? " " + wm.version : "") + (wm.protocolName ? " (" + wm.protocolName + ")" : "")),
          quickHubRoot.ffRow("GPU", "󰢮", Style.menuIndigo,
            (gpu.name || "—") + (gpu.coreCount ? (" (" + gpu.coreCount + ")") : "") + gpuFreq + gpuType),
          quickHubRoot.ffRow("Disk", "󰋊", Style.menuIndigo,
            quickHubRoot.prettyBytes(diskUsed) + " / " + quickHubRoot.prettyBytes(diskTotal)
              + " (" + quickHubRoot.ffDiskPct + "%) · " + (disk.filesystem || "—")),
          quickHubRoot.ffRow("Locale", "󰖟", Style.menuInkDeep, locale || "—"),
          quickHubRoot.ffRow("Battery", "󰁹", Style.green,
            (bat.capacity !== undefined ? (Math.round(bat.capacity) + "%") : "—")
              + (batteryStatus ? (" · " + batteryStatus) : "")
              + (bat.cycleCount ? (" · " + bat.cycleCount + " cycles") : ""))
        ]
        quickHubRoot.ffUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
      } catch (_) {
        quickHubRoot.ffLeftRows = [quickHubRoot.ffRow("fastfetch", "󰀦", Style.red, "unavailable")]
        quickHubRoot.ffRightRows = []
      }
    }
    function refreshFastfetch() {
      if (!ffProc.running) ffProc.running = true
      if (!ffLogoProc.running) ffLogoProc.running = true
    }

    Process {
      id: ffProc
      command: ["fastfetch", "--format", "json"]
      stdout: StdioCollector { onStreamFinished: quickHubRoot.parseFastfetch(text) }
    }
    Process {
      id: ffLogoProc
      command: ["fastfetch", "--logo-type", "small", "--structure", "Title"]
      stdout: StdioCollector { onStreamFinished: quickHubRoot.parseLogo(text) }
    }
    Timer {
      interval: 60000
      running: root.quickDetailActive && root.expandedQuickKey === "hub"
      repeat: true
      triggeredOnStart: true
      onTriggered: quickHubRoot.refreshFastfetch()
    }
    Component.onCompleted: Qt.callLater(quickHubRoot.refreshFastfetch)

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 4
      spacing: 6

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.menuRadius
        color: Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.04)
        border.color: Style.menuSep
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 6

          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
              text: "󰟀"
              color: Style.menuSeal
              font.pixelSize: root.fontPx(16)
              font.family: root.uiFont
            }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1
              Text {
                text: quickHubRoot.ffTitle
                color: Style.menuInk
                font.pixelSize: root.fontPx(11)
                font.family: Style.menuMono
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
              Text {
                text: quickHubRoot.ffSubtitle
                color: Style.menuInkDeep
                font.pixelSize: root.fontPx(9)
                font.family: root.uiFont
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }
            ColumnLayout {
              spacing: 1
              Text {
                text: "󰅐 " + (quickHubRoot.ffUptime || "…")
                color: Style.lavender
                font.pixelSize: root.fontPx(8)
                font.family: root.uiFont
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
              }
              Text {
                text: quickHubRoot.ffUpdated || "loading"
                color: Style.menuInkDeep
                font.pixelSize: root.fontPx(7)
                font.family: root.uiFont
                horizontalAlignment: Text.AlignRight
                opacity: 0.8
              }
            }
            Rectangle {
              Layout.alignment: Qt.AlignVCenter
              width: 22; height: 22; radius: 11
              color: hubCloseMa.containsMouse ? Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.08) : "transparent"
              border.color: Style.menuSep
              border.width: 1
              Text {
                anchors.centerIn: parent
                text: "×"
                color: Style.menuInkDeep
                font.family: root.uiFont
                font.pixelSize: 14
              }
              MouseArea {
                id: hubCloseMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expandedQuickKey = ""
              }
            }
          }

          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Style.menuSep }

          RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 10

            Text {
              Layout.alignment: Qt.AlignTop
              Layout.rightMargin: 2
              visible: quickHubRoot.ffLogoLines.length > 0
              text: quickHubRoot.ffLogoText
              color: Style.menuSeal
              font.family: "monospace"
              font.pixelSize: 7
              lineHeight: 8
              lineHeightMode: Text.FixedHeight
              wrapMode: Text.NoWrap
            }

            Rectangle {
              visible: quickHubRoot.ffLogoLines.length > 0
              Layout.preferredHeight: ffInfoBody.implicitHeight
              Layout.preferredWidth: 1
              color: Style.menuSep
            }

            Item {
              Layout.fillWidth: true
              implicitHeight: ffInfoBody.implicitHeight
              height: implicitHeight

              Row {
                id: ffInfoBody
                width: parent.width
                spacing: 14

                Column {
                  id: ffLeftCol
                  width: (parent.width - parent.spacing) / 2
                  spacing: 4
                  Repeater {
                    model: quickHubRoot.ffLeftRows
                    delegate: RowLayout {
                      required property var modelData
                      width: ffLeftCol.width
                      spacing: 4
                      Text {
                        Layout.preferredWidth: 14
                        Layout.alignment: Qt.AlignTop
                        text: modelData.icon || ""
                        color: modelData.accent || Style.menuInkDeep
                        font.pixelSize: root.fontPx(9)
                        font.family: root.uiFont
                      }
                      Text {
                        Layout.preferredWidth: quickHubRoot.ffLabelWidth
                        Layout.alignment: Qt.AlignTop
                        text: (modelData.key || "") + ":"
                        color: modelData.accent || Style.menuInkDeep
                        font.pixelSize: root.fontPx(9)
                        font.family: root.uiFont
                        font.weight: Font.Medium
                      }
                      Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        text: modelData.key === "Memory"
                          ? (quickHubRoot.prettyBytes(quickHubRoot.ffMemTotalBytes * root.sidebarMem / 100)
                            + " / " + quickHubRoot.prettyBytes(quickHubRoot.ffMemTotalBytes)
                            + " (" + root.sidebarMem + "%)")
                          : (modelData.value || "—")
                        color: Style.menuInk
                        font.pixelSize: root.fontPx(9)
                        font.family: root.uiFont
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                      }
                    }
                  }
                }

                Column {
                  id: ffRightCol
                  width: (parent.width - parent.spacing) / 2
                  spacing: 4
                  Repeater {
                    model: quickHubRoot.ffRightRows
                    delegate: RowLayout {
                      required property var modelData
                      width: ffRightCol.width
                      spacing: 4
                      Text {
                        Layout.preferredWidth: 14
                        Layout.alignment: Qt.AlignTop
                        text: modelData.icon || ""
                        color: modelData.accent || Style.menuInkDeep
                        font.pixelSize: root.fontPx(9)
                        font.family: root.uiFont
                      }
                      Text {
                        Layout.preferredWidth: quickHubRoot.ffLabelWidth
                        Layout.alignment: Qt.AlignTop
                        text: (modelData.key || "") + ":"
                        color: modelData.accent || Style.menuInkDeep
                        font.pixelSize: root.fontPx(9)
                        font.family: root.uiFont
                        font.weight: Font.Medium
                      }
                      Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        text: modelData.value || "—"
                        color: Style.menuInk
                        font.pixelSize: root.fontPx(9)
                        font.family: root.uiFont
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                      }
                    }
                  }
                }
              }
            }
          }

          Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Style.menuSep }

          Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            spacing: 6

            Repeater {
              model: [
                { label: "CPU", key: "cpu" },
                { label: "RAM", key: "ram" },
                { label: "DISK", key: "disk" },
                { label: "BAT", key: "bat" }
              ]
              delegate: Item {
                required property var modelData
                readonly property int meterValue: modelData.key === "cpu"
                  ? root.sidebarCpu
                  : (modelData.key === "ram"
                    ? root.sidebarMem
                    : (modelData.key === "disk" ? quickHubRoot.ffDiskPct : root.sidebarBat))
                readonly property color meterColor: modelData.key === "cpu"
                  ? Style.orange
                  : (modelData.key === "ram"
                    ? Style.lavender
                    : (modelData.key === "disk"
                      ? Style.menuIndigo
                      : (root.sidebarBatStatus === "Charging"
                        ? Style.yellow : (root.sidebarBat < 20 ? Style.red : Style.green))))
                width: (parent.width - 3 * parent.spacing) / 4
                height: parent.height

                Rectangle {
                  anchors.fill: parent
                  radius: 5
                  color: Style.menuControlBg
                  border.color: Style.menuSep
                  border.width: 1

                  Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 5
                    text: modelData.label
                    color: Style.menuInkDeep
                    font.pixelSize: root.fontPx(8)
                    font.family: root.uiFont
                    font.weight: Font.Medium
                  }
                  Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 5
                    text: meterValue + "%"
                    color: meterColor
                    font.pixelSize: root.fontPx(9)
                    font.family: root.uiFont
                    font.weight: Font.Medium
                  }

                  Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 5
                    height: 5
                    radius: 2
                    color: Qt.rgba(0, 0, 0, 0.22)
                    Rectangle {
                      width: parent.width * Math.max(0, Math.min(1, meterValue / 100))
                      height: parent.height
                      radius: 3
                      color: meterColor
                      Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
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
        Layout.preferredHeight: 70
        Layout.maximumHeight: 70
        radius: Style.menuRadius
        color: Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.03)
        border.color: Style.menuSep
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 6
          spacing: 4

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: "SCREENSHOTS"
              color: Style.menuInk
              font.pixelSize: root.fontPx(8)
              font.family: root.uiFont
              font.letterSpacing: 1.2
              font.weight: Font.Medium
            }
            Item { Layout.fillWidth: true }
            Text {
              text: (root.shots || []).length + " recent"
              color: Style.menuInkDeep
              font.pixelSize: root.fontPx(7)
              font.family: root.uiFont
            }
          }

          Grid {
            id: lowerShots
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            columnSpacing: 6
            rowSpacing: 4
            Repeater {
              model: (root.shots || []).slice(0, 4)
              delegate: Item {
                required property var modelData
                width: (lowerShots.width - 3 * 6) / 4
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
                    source: (modelData && modelData.path) ? ("file://" + modelData.path) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 160
                    sourceSize.height: 96
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
                      font.pixelSize: root.fontPx(6)
                      font.family: root.uiFont
                      elide: Text.ElideRight
                      width: parent.width - 4
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
                      font.pixelSize: root.fontPx(7)
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
                      if (mouse.button === Qt.RightButton) root.previewShot(modelData.path)
                      else root.copyShot(modelData.path)
                    }
                  }

                  Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 4
                    width: 20
                    height: 20
                    radius: 10
                    z: 2
                    visible: shotMa.containsMouse
                    color: Style.menuControlBg
                    border.width: 1
                    border.color: Style.menuSep
                    Text {
                      anchors.centerIn: parent
                      text: "󰋲"
                      color: Style.menuSeal
                      font.pixelSize: root.fontPx(10)
                      font.family: root.uiFont
                    }
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.previewShot(modelData.path)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  } }
  Component { id: quickWallpaperComp; Item {
    id: quickWallpaperRoot
    anchors.fill: parent
    // full port of wallpaper from old (grid/search/apply service/current 2px border/160 OutCubic scale/hover/ready/filename/L apply/R preview/count)
    property string wpSearch: ""
    readonly property var wps: (Wallpaper.WallpaperService && Wallpaper.WallpaperService.wallpapers) || []
    readonly property var filtered: {
      const q = (wpSearch || "").toLowerCase().trim()
      const list = wps || []
      if (!q) return list
      return list.filter(function(p){ const n = ((p || "").split("/").pop() || "").toLowerCase(); return n.indexOf(q) >= 0 })
    }
    Component.onCompleted: {
      try { if (Wallpaper.WallpaperService && (Wallpaper.WallpaperService.wallpapers || []).length < 1) Wallpaper.WallpaperService.rescan() } catch(_) {}
    }
    ColumnLayout {
      anchors.fill: parent
      spacing: 6
      Item {
        Layout.fillWidth: true; Layout.preferredHeight: 22
        Rectangle {
          anchors.fill: parent; radius: 4; color: Style.menuControlBg; border.color: Style.menuSep; border.width: 1
          TextInput {
            id: wpIn; anchors.fill: parent; anchors.margins: 3
            color: Style.menuInk; font.pixelSize: root.fontPx(10); font.family: root.uiFont
            text: quickWallpaperRoot.wpSearch
            onTextChanged: quickWallpaperRoot.wpSearch = text
            Keys.onEscapePressed: { quickWallpaperRoot.wpSearch = ""; wpIn.text = "" }
          }
          Text { anchors.centerIn: parent; text: "search wallpapers..."; color: Style.menuInkDeep; font.pixelSize: root.fontPx(9); font.family: root.uiFont; visible: wpIn.text === "" && !wpIn.activeFocus }
        }
      }
      Text {
        visible: (quickWallpaperRoot.filtered || []).length === 0
        text: quickWallpaperRoot.wpSearch ? "No matching wallpapers" : "No wallpapers (rescan in bg)"
        color: Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont
        Layout.alignment: Qt.AlignHCenter; Layout.preferredHeight: 20
      }
      GridView {
        Layout.fillWidth: true; Layout.fillHeight: (quickWallpaperRoot.filtered || []).length > 0
        cellWidth: Math.floor((width - 6) / 3); cellHeight: cellWidth * 0.62 + 4
        clip: true; model: quickWallpaperRoot.filtered
        delegate: Item {
          required property string modelData; required property int index
          width: GridView.view.cellWidth; height: GridView.view.cellHeight
          Rectangle {
            anchors.fill: parent; anchors.margins: 2; radius: 6; clip: true
            color: wma.containsMouse ? Style.menuRowHi : Style.menuControlBg
            border.color: (Wallpaper.WallpaperService.currentWallpaper === modelData) ? Style.green : (wma.containsMouse ? Style.menuSep : Style.menuSep)
            border.width: (Wallpaper.WallpaperService.currentWallpaper === modelData) ? 2 : 1
            scale: wma.containsMouse ? 1.025 : 1.0
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Image {
              anchors.fill: parent; anchors.margins: (Wallpaper.WallpaperService.currentWallpaper === modelData) ? 2 : 1; source: modelData ? ("file://" + modelData) : ""
              fillMode: Image.PreserveAspectCrop
              sourceSize.width: 160; sourceSize.height: 96; asynchronous: true
              Rectangle {
                anchors.fill: parent; color: Style.menuControlBg; visible: parent.status !== Image.Ready
                Text { anchors.centerIn: parent; text: "󰋩"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(18); font.family: root.uiFont }
              }
            }
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 14; color: Qt.rgba(0,0,0,0.55)
              Text {
                anchors.centerIn: parent
                text: (modelData || "").split("/").pop()
                color: "#fff"; font.pixelSize: root.fontPx(7); font.family: root.uiFont
                elide: Text.ElideMiddle; width: parent.width-4; horizontalAlignment: Text.AlignHCenter
              }
            }
            Rectangle {
              anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 3
              width: 14; height: 14; radius: 7; color: Style.green
              visible: Wallpaper.WallpaperService.currentWallpaper === modelData
              Text { anchors.centerIn: parent; text: "✓"; color: "#fff"; font.pixelSize: 9; font.bold: true }
            }
            MouseArea {
              id: wma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: function(e) {
                if (e.button === Qt.RightButton) {
                  if (modelData) Quickshell.execDetached(["xdg-open", modelData])  // preview action
                } else {
                  if (modelData) Wallpaper.WallpaperService.setWallpaper(modelData)
                  root.expandedQuickKey = ""
                }
              }
            }
          }
        }
      }
      RowLayout {
        Layout.fillWidth: true; spacing: 8
        Text { text: "L: apply • R: preview"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont }
        Item { Layout.fillWidth: true }
        Text { text: ((quickWallpaperRoot.wps || []).length || 0) + " wallpapers"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont }
      }
    }
  } }
  Component { id: quickScreenshotsComp; Item {
    anchors.fill: parent
    ColumnLayout {
      anchors.fill: parent
      spacing: 8

      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
          text: "SCREENSHOTS"
          color: Style.menuInk
          font.pixelSize: root.fontPx(9)
          font.family: root.uiFont
          font.letterSpacing: 1.2
          font.weight: Font.Medium
        }
        Item { Layout.fillWidth: true }
        Text {
          text: (root.shots || []).length + " recent"
          color: Style.menuInkDeep
          font.pixelSize: root.fontPx(8)
          font.family: root.uiFont
        }
      }

      GridView {
        id: shotGrid
        Layout.fillWidth: true
        Layout.fillHeight: true
        cellWidth: Math.max(80, Math.floor((width - 10) / 3))
        cellHeight: cellWidth * 0.6 + 6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        model: root.shots || []

        delegate: Item {
          required property var modelData
          required property int index
          width: shotGrid.cellWidth
          height: shotGrid.cellHeight

          Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 8
            clip: true
            color: hma.containsMouse ? Style.menuRowHi : Style.menuControlBg
            border.color: root.copiedShot === modelData.path ? Style.green : Style.menuSep
            border.width: root.copiedShot === modelData.path ? 2 : 1
            scale: hma.containsMouse ? 1.02 : 1.0
            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Image {
              anchors.fill: parent
              anchors.margins: 1
              source: modelData.path ? ("file://" + modelData.path) : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              sourceSize.width: 200
              sourceSize.height: 120
            }

            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              height: 18
              color: Qt.rgba(0, 0, 0, 0.55)
              Text {
                anchors.centerIn: parent
                text: modelData.label
                color: "#ffffff"
                font.pixelSize: root.fontPx(9)
                font.family: root.uiFont
                elide: Text.ElideRight
                width: parent.width - 6
                horizontalAlignment: Text.AlignHCenter
              }
            }

            Rectangle {
              anchors.fill: parent
              anchors.margins: 1
              radius: 6
              color: Qt.rgba(0.4, 0.8, 0.5, 0.32)
              visible: root.copiedShot === modelData.path
              Text {
                anchors.centerIn: parent
                text: "COPIED"
                color: "#ffffff"
                font.pixelSize: root.fontPx(12)
                font.family: root.uiFont
                font.bold: true
              }
            }

            MouseArea {
              id: hma
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) root.previewShot(modelData.path)
                else root.copyShot(modelData.path)
              }
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
              Text {
                anchors.centerIn: parent
                text: "󰋲"
                color: Style.menuSeal
                font.pixelSize: root.fontPx(12)
                font.family: root.uiFont
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => { mouse.accepted = true; root.previewShot(modelData.path) }
              }
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
              Text {
                anchors.centerIn: parent
                text: "󰆴"
                color: Style.red
                font.pixelSize: root.fontPx(12)
                font.family: root.uiFont
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => { mouse.accepted = true; root.deleteShot(modelData.path) }
              }
            }
          }
        }
      }

      Text {
        visible: (root.shots || []).length === 0
        text: "No screenshots in ~/screenshots"
        color: Style.menuInkDeep
        font.pixelSize: root.fontPx(11)
        font.family: root.uiFont
        Layout.alignment: Qt.AlignHCenter
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Rectangle {
          Layout.fillWidth: true
          height: 32
          radius: 8
          color: smartCapMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
          border.color: Style.menuSep
          Text {
            anchors.centerIn: parent
            text: "󰄀  smart"
            font.pixelSize: root.fontPx(11)
            font.family: root.uiFont
            color: Style.menuInk
            font.weight: Font.Medium
          }
          MouseArea {
            id: smartCapMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              Quickshell.execDetached([root.binDir + "/asahi-cmd-screenshot", "smart"])
              Qt.callLater(root.scanShots)
            }
          }
        }
        Rectangle {
          Layout.fillWidth: true
          height: 32
          radius: 8
          color: areaCapMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
          border.color: Style.menuSep
          Text {
            anchors.centerIn: parent
            text: "󰹑  area"
            font.pixelSize: root.fontPx(11)
            font.family: root.uiFont
            color: Style.menuInk
            font.weight: Font.Medium
          }
          MouseArea {
            id: areaCapMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              Quickshell.execDetached([root.binDir + "/asahi-cmd-screenshot", "area"])
              Qt.callLater(root.scanShots)
            }
          }
        }
      }

      Text {
        Layout.fillWidth: true
        text: "L: copy  ·  R: preview"
        color: Style.menuInkDeep
        font.pixelSize: root.fontPx(8)
        font.family: root.uiFont
        horizontalAlignment: Text.AlignHCenter
        opacity: 0.7
      }
    }
  } }
  Component { id: quickMediaComp; Item {
    id: quickMediaRoot
    anchors.fill: parent
    // fuller media port (Mpris+controls+active, wpctl, cava, streams; procs/timers/guards)
    property var cavaValues: []
    property bool cavaRunning: false
    property string cavaStatus: "idle"
    property real cavaLast: 0
    readonly property string cavaDir: "/tmp/quickshell-remix-" + (Quickshell.env("USER") || "user")
    readonly property string cavaCfg: quickMediaRoot.cavaDir + "/cava.conf"
    readonly property string cavaFrame: quickMediaRoot.cavaDir + "/cava-frame"
    readonly property var activeP: {
      const list = (Mpris.players && Mpris.players.values) ? Mpris.players.values : []
      for (let i=0; i<list.length; i++) if (list[i] && list[i].isPlaying) return list[i]
      return list.length > 0 ? list[0] : null
    }
    property string sinkVol: "—"; property string srcVol: "—"; property bool sinkM: false; property bool srcM: false
    property var audioSinks: []
    property var audioSources: []
    property var audioStreams: []

    function parseVol(l) { const v = (l||"").match(/[0-9.]+/); return v ? Math.round(parseFloat(v[0])*100)+"%" : "—" }
    function pollVol() {
      volProc.command = ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null ; wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null"]
      volProc.running = true
    }
    function volAdj(tgt, up) {
      const ts = Array.isArray(tgt)?tgt:[tgt]
      for (let i=0;i<ts.length;i++) Quickshell.execDetached(["wpctl","set-volume","-l","1",String(ts[i]), up?"5%+":"5%-"])
      volDelay.restart()
    }
    function togMute(tgt) {
      const ts = Array.isArray(tgt)?tgt:[tgt]
      for (let i=0;i<ts.length;i++) Quickshell.execDetached(["wpctl","set-mute",String(ts[i]),"toggle"])
      volDelay.restart()
    }
    function startCava() {
      if (quickMediaRoot.cavaRunning) return
      quickMediaRoot.cavaRunning = true; quickMediaRoot.cavaStatus = "starting"; quickMediaRoot.cavaLast=0; quickMediaRoot.cavaValues=[]
      Quickshell.execDetached([
        "sh", "-c",
        "dir=$1;cfg=$2;frm=$3; if ! command -v cava >/dev/null 2>&1; then echo 'cava missing' >/tmp/quickshell-cava.err; exit 0; fi; " +
        "pkill -f \"cava -p $cfg\" 2>/dev/null||true; mkdir -p \"$dir\"; " +
        "printf '%s\n' '[general]' 'bars=24' 'framerate=30' 'autosens=1' 'sensitivity=180' '' '[input]' 'method=pulse' 'source=auto' '' " +
        "'[output]' 'method=raw' 'raw_target=/dev/stdout' 'data_format=ascii' 'ascii_max_range=100' 'bar_delimiter=59' 'frame_delimiter=10' > \"$cfg\"; " +
        ": > \"$frm\"; (stdbuf -oL cava -p \"$cfg\" 2>/dev/null | while IFS= read -r ln; do printf '%s\n' \"$ln\" > \"$frm\"; done) &",
        "sh", quickMediaRoot.cavaDir, quickMediaRoot.cavaCfg, quickMediaRoot.cavaFrame
      ])
    }
    function stopCava() {
      if (!quickMediaRoot.cavaRunning) return
      quickMediaRoot.cavaRunning=false; quickMediaRoot.cavaStatus="idle"; quickMediaRoot.cavaLast=0
      Quickshell.execDetached(["pkill","-f","cava -p "+quickMediaRoot.cavaCfg])
    }
    function updCava(ln) {
      ln=(ln||"").trim(); if(!ln) return
      const ps = ln.split(/[;,\t ]+/); const vs=[]
      for (let i=0; i<ps.length && i<24; i++) vs.push( Math.max(0,Math.min(100, parseInt(ps[i])||0 )) )
      while(vs.length<24) vs.push(0)
      quickMediaRoot.cavaValues=vs; quickMediaRoot.cavaLast=Date.now()
      quickMediaRoot.cavaStatus = vs.some(v => v > 0) ? "active" : "waiting for audio"
    }
    function refreshAudioMixer() { if (!mixerProc.running) mixerProc.running = true }
    function parseAudioSimple(out) {
      const sinks = []
      const sources = []
      const streams = []
      let section = ""
      const ls = (out || "").split("\n")
      for (const line of ls) {
        if (line.indexOf("├─ Sinks:") >= 0) { section = "sinks"; continue }
        if (line.indexOf("├─ Sources:") >= 0) { section = "sources"; continue }
        if (line.indexOf("└─ Streams:") >= 0) { section = "streams"; continue }
        if (line.indexOf("├─ Devices:") >= 0 || line.indexOf("├─ Filters:") >= 0 || line.indexOf("Video") === 0 || line.indexOf("Settings") === 0) {
          section = ""
          continue
        }
        const m = line.match(/(\*)?\s*(\d+)\.\s+(.+?)(?:\s+\[(.+)\])?\s*$/)
        if (!m || !section) continue
        const info = (m[4] || "").trim()
        const vm = info.match(/vol:\s*([0-9.]+)/)
        const item = {
          id: m[2],
          name: m[3].trim(),
          info: info,
          active: line.indexOf("*") >= 0,
          muted: line.indexOf("MUTED") >= 0,
          volume: vm ? Math.round(parseFloat(vm[1]) * 100) + "%" : ""
        }
        if (section === "sinks") sinks.push(item)
        else if (section === "sources") sources.push(item)
        else if (section === "streams") streams.push(item)
      }
      quickMediaRoot.audioSinks = sinks.slice(0, 8)
      quickMediaRoot.audioSources = sources.slice(0, 8)
      quickMediaRoot.audioStreams = streams.slice(0, 12)
    }
    function setAudioDefault(id) {
      if (!id) return
      Quickshell.execDetached(["wpctl", "set-default", String(id)])
      volDelay.restart()
      Qt.callLater(quickMediaRoot.refreshAudioMixer)
    }

    Process { id: volProc; stdout: StdioCollector { onStreamFinished: { const ls=(text||"").trim().split("\n"); quickMediaRoot.sinkVol=quickMediaRoot.parseVol(ls[0]); quickMediaRoot.srcVol=quickMediaRoot.parseVol(ls[1]); quickMediaRoot.sinkM=(ls[0]||"").indexOf("MUTED")!==-1; quickMediaRoot.srcM=(ls[1]||"").indexOf("MUTED")!==-1 } } }
    Timer { id: volDelay; interval: 400; onTriggered: quickMediaRoot.pollVol() }
    Process {
      id: mixerProc
      command: ["sh", "-c", "wpctl status 2>/dev/null || true"]
      stdout: StdioCollector { onStreamFinished: quickMediaRoot.parseAudioSimple(text) }
    }
    Process {
      id: cavaRd
      command: ["sh","-c","cat \"$1\" 2>/dev/null || true", "sh", quickMediaRoot.cavaFrame]
      stdout: StdioCollector { onStreamFinished: quickMediaRoot.updCava(text) }
    }
    Timer {
      interval: 90; running: root.quickDetailActive && root.expandedQuickKey === "media"; repeat: true; triggeredOnStart: true
      onTriggered: {
        if (quickMediaRoot.cavaRunning && quickMediaRoot.cavaLast>0 && Date.now()-quickMediaRoot.cavaLast > 3000) quickMediaRoot.cavaRunning=false
        if (!quickMediaRoot.cavaRunning) quickMediaRoot.startCava()
        if (!cavaRd.running) cavaRd.running = true
      }
    }
    Timer {
      interval: 3000
      running: root.quickDetailActive && root.expandedQuickKey === "media"
      repeat: true
      triggeredOnStart: true
      onTriggered: quickMediaRoot.refreshAudioMixer()
    }
    Component.onCompleted: { quickMediaRoot.pollVol(); quickMediaRoot.startCava(); quickMediaRoot.refreshAudioMixer() }
    Component.onDestruction: quickMediaRoot.stopCava()

    ColumnLayout {
      id: mediaCol
      anchors.fill: parent
      spacing: 8

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 72
        radius: 10
        color: root.menuTileBg
        border.color: Style.menuSep
        border.width: 1
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 6
          Text {
            text: "󰎈  Now Playing"
            color: Style.menuIndigo
            font.pixelSize: root.fontPx(11)
            font.family: root.uiFont
            font.bold: true
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
              Layout.fillWidth: true
              text: {
                const p = quickMediaRoot.activeP
                if (!p) return "No active media player"
                return (p.trackArtist || "Unknown Artist") + " — " + (p.trackTitle || "Unknown Track")
              }
              color: Style.menuInk
              font.pixelSize: root.fontPx(11)
              font.family: root.uiFont
              font.bold: true
              elide: Text.ElideRight
            }
            MouseArea {
              width: 24
              height: 24
              cursorShape: Qt.PointingHandCursor
              onClicked: { const p = quickMediaRoot.activeP; if (p && p.canGoPrevious) p.previous() }
              Text { anchors.centerIn: parent; text: "󰒮"; font.pixelSize: root.fontPx(16); color: Style.menuInk; font.family: root.uiFont }
            }
            Rectangle {
              width: 30
              height: 30
              radius: 15
              color: Qt.rgba(Style.green.r, Style.green.g, Style.green.b, 0.18)
              Text {
                anchors.centerIn: parent
                text: { const p = quickMediaRoot.activeP; return (p && p.isPlaying) ? "󰏤" : "󰐊" }
                font.pixelSize: root.fontPx(15)
                color: Style.green
                font.family: root.uiFont
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { const p = quickMediaRoot.activeP; if (p && p.canTogglePlaying) p.togglePlaying() }
              }
            }
            MouseArea {
              width: 24
              height: 24
              cursorShape: Qt.PointingHandCursor
              onClicked: { const p = quickMediaRoot.activeP; if (p && p.canGoNext) p.next() }
              Text { anchors.centerIn: parent; text: "󰒭"; font.pixelSize: root.fontPx(16); color: Style.menuInk; font.family: root.uiFont }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        spacing: 10
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: 8
          color: root.menuTileBg
          border.color: Style.menuSep
          border.width: 1
          RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6
            Text { text: quickMediaRoot.sinkM ? "󰖁  Speakers" : "󰕾  Speakers"; color: quickMediaRoot.sinkM ? Style.red : Style.menuInk; font.pixelSize: root.fontPx(11); font.family: root.uiFont; font.bold: true }
            Item { Layout.fillWidth: true }
            Text { text: quickMediaRoot.sinkVol; color: quickMediaRoot.sinkM ? Style.red : Style.menuIndigo; font.pixelSize: root.fontPx(11); font.family: root.uiFont; font.bold: true }
            Rectangle {
              width: 22; height: 22; radius: 4; color: Style.menuControlBg
              Text { anchors.centerIn: parent; text: quickMediaRoot.sinkM ? "󰖁" : "󰕾"; color: Style.menuInk; font.pixelSize: root.fontPx(12) }
              MouseArea { anchors.fill: parent; onClicked: quickMediaRoot.togMute("@DEFAULT_AUDIO_SINK@") }
            }
            Rectangle {
              width: 22; height: 22; radius: 4; color: Style.menuControlBg
              Text { anchors.centerIn: parent; text: "−"; color: Style.menuInk; font.pixelSize: root.fontPx(12) }
              MouseArea { anchors.fill: parent; onClicked: quickMediaRoot.volAdj("@DEFAULT_AUDIO_SINK@", false) }
            }
            Rectangle {
              width: 22; height: 22; radius: 4; color: Style.menuControlBg
              Text { anchors.centerIn: parent; text: "+"; color: Style.menuInk; font.pixelSize: root.fontPx(12) }
              MouseArea { anchors.fill: parent; onClicked: quickMediaRoot.volAdj("@DEFAULT_AUDIO_SINK@", true) }
            }
          }
        }
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: 8
          color: root.menuTileBg
          border.color: Style.menuSep
          border.width: 1
          RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6
            Text { text: quickMediaRoot.srcM ? "󰍭  Microphone" : "󰍬  Microphone"; color: quickMediaRoot.srcM ? Style.red : Style.menuInk; font.pixelSize: root.fontPx(11); font.family: root.uiFont; font.bold: true }
            Item { Layout.fillWidth: true }
            Text { text: quickMediaRoot.srcVol; color: quickMediaRoot.srcM ? Style.red : Style.menuIndigo; font.pixelSize: root.fontPx(11); font.family: root.uiFont; font.bold: true }
            Rectangle {
              width: 22; height: 22; radius: 4; color: Style.menuControlBg
              Text { anchors.centerIn: parent; text: quickMediaRoot.srcM ? "󰍭" : "󰍬"; color: Style.menuInk; font.pixelSize: root.fontPx(12) }
              MouseArea { anchors.fill: parent; onClicked: quickMediaRoot.togMute("@DEFAULT_AUDIO_SOURCE@") }
            }
            Rectangle {
              width: 22; height: 22; radius: 4; color: Style.menuControlBg
              Text { anchors.centerIn: parent; text: "−"; color: Style.menuInk; font.pixelSize: root.fontPx(12) }
              MouseArea { anchors.fill: parent; onClicked: quickMediaRoot.volAdj("@DEFAULT_AUDIO_SOURCE@", false) }
            }
            Rectangle {
              width: 22; height: 22; radius: 4; color: Style.menuControlBg
              Text { anchors.centerIn: parent; text: "+"; color: Style.menuInk; font.pixelSize: root.fontPx(12) }
              MouseArea { anchors.fill: parent; onClicked: quickMediaRoot.volAdj("@DEFAULT_AUDIO_SOURCE@", true) }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        ColumnLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            Repeater {
              model: [
                { title: "󰕾  Output devices", empty: "No outputs", items: quickMediaRoot.audioSinks },
                { title: "󰍬  Input sources", empty: "No inputs", items: quickMediaRoot.audioSources }
              ]
              delegate: Rectangle {
                id: devCard
                required property var modelData
                readonly property var devItems: modelData.items || []
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                color: root.menuTileBg
                border.color: Style.menuSep
                border.width: 1
                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 10
                  spacing: 4
                  Text {
                    text: modelData.title
                    color: Style.menuInkDeep
                    font.pixelSize: root.fontPx(10)
                    font.family: root.uiFont
                    font.bold: true
                  }
                  Text {
                    visible: devCard.devItems.length === 0
                    text: modelData.empty
                    color: Style.menuInkDeep
                    font.pixelSize: root.fontPx(9)
                    font.family: root.uiFont
                  }
                  Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: devCard.devItems.length > 0
                    clip: true
                    contentHeight: deviceCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    Column {
                      id: deviceCol
                      width: parent.width
                      spacing: 3
                      Repeater {
                        model: devCard.devItems
                        delegate: Rectangle {
                          required property var modelData
                          width: parent.width
                          height: 30
                          radius: 6
                          color: modelData.active ? Qt.rgba(Style.menuIndigo.r, Style.menuIndigo.g, Style.menuIndigo.b, 0.18) : (devMa.containsMouse ? Style.menuRowHi : "transparent")
                          border.color: modelData.active ? Style.menuIndigo : (devMa.containsMouse ? Style.menuSep : "transparent")
                          border.width: 1
                          RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6
                            Text { text: modelData.active ? "●" : "○"; color: modelData.active ? Style.green : Style.menuInkDeep; font.pixelSize: root.fontPx(8) }
                            Text { Layout.fillWidth: true; text: modelData.name; color: Style.menuInk; font.pixelSize: root.fontPx(9); font.family: root.uiFont; elide: Text.ElideRight }
                            Text { text: modelData.volume || ("#" + modelData.id); color: Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont }
                          }
                          MouseArea {
                            id: devMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: quickMediaRoot.setAudioDefault(modelData.id)
                          }
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
            Layout.fillHeight: true
            radius: 10
            color: root.menuTileBg
            border.color: Style.menuSep
            border.width: 1
            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 10
              spacing: 4
              Text {
                text: "󰝚  Stream mixer"
                color: Style.menuInkDeep
                font.pixelSize: root.fontPx(10)
                font.family: root.uiFont
                font.bold: true
              }
              Text {
                visible: (quickMediaRoot.audioStreams || []).length === 0
                text: "No active streams"
                color: Style.menuInkDeep
                font.pixelSize: root.fontPx(9)
                font.family: root.uiFont
              }
              Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: (quickMediaRoot.audioStreams || []).length > 0
                clip: true
                contentHeight: streamCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                Column {
                  id: streamCol
                  width: parent.width
                  spacing: 5
                  Repeater {
                    model: quickMediaRoot.audioStreams || []
                    delegate: Rectangle {
                      id: streamRow
                      required property var modelData
                      width: parent.width
                      height: 34
                      radius: 6
                      color: modelData.muted ? root.menuDangerBg : Style.menuControlBg
                      border.color: modelData.muted ? Style.red : Style.menuSep
                      border.width: 1
                      RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6
                        Text { text: "󰝚"; color: Style.green; font.pixelSize: root.fontPx(11); font.family: root.uiFont }
                        Text { Layout.fillWidth: true; text: modelData.name; color: modelData.muted ? Style.menuInkDeep : Style.menuInk; font.pixelSize: root.fontPx(10); font.family: root.uiFont; elide: Text.ElideRight }
                        Text { text: modelData.volume || ("#" + modelData.id); color: modelData.muted ? Style.red : Style.menuIndigo; font.pixelSize: root.fontPx(9); font.family: root.uiFont; font.bold: true }
                        Rectangle {
                          width: 22; height: 22; radius: 4; color: Style.menuControlBg
                          Text { anchors.centerIn: parent; text: streamRow.modelData.muted ? "󰖁" : "󰕾"; font.pixelSize: root.fontPx(10); color: streamRow.modelData.muted ? Style.red : Style.menuInk }
                          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: quickMediaRoot.togMute(streamRow.modelData.id) }
                        }
                        Rectangle {
                          width: 22; height: 22; radius: 4; color: Style.menuControlBg
                          Text { anchors.centerIn: parent; text: "−"; font.pixelSize: root.fontPx(10); color: Style.menuInk }
                          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: quickMediaRoot.volAdj(streamRow.modelData.id, false) }
                        }
                        Rectangle {
                          width: 22; height: 22; radius: 4; color: Style.menuControlBg
                          Text { anchors.centerIn: parent; text: "+"; font.pixelSize: root.fontPx(10); color: Style.menuInk }
                          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: quickMediaRoot.volAdj(streamRow.modelData.id, true) }
                        }
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
          Layout.fillHeight: true
          radius: 12
          color: root.menuTileBg
          border.color: Style.menuSep
          border.width: 1
          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "󰎈  Cava Spectrum"
                color: Style.menuInkDeep
                font.pixelSize: root.fontPx(10)
                font.family: root.uiFont
                font.bold: true
              }
              Item { Layout.fillWidth: true }
              Text {
                text: quickMediaRoot.cavaStatus
                color: quickMediaRoot.cavaStatus === "active" ? Style.green : Style.menuInkDeep
                font.pixelSize: root.fontPx(9)
                font.family: root.uiFont
              }
            }
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Row {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 5
                Repeater {
                  model: 24
                  delegate: Item {
                    required property int index
                    width: (parent.width - 23 * parent.spacing) / 24
                    height: parent.height
                    Rectangle {
                      anchors.bottom: parent.bottom
                      width: parent.width
                      radius: 3
                      height: Math.max(4, parent.height * (((quickMediaRoot.cavaValues && quickMediaRoot.cavaValues[index]) || 0) / 100))
                      color: Style.green
                      Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                    }
                  }
                }
              }
            }
          }
        }
      }

      Text {
        Layout.fillWidth: true
        text: "pavucontrol for full mixer"
        color: Style.menuInkDeep
        font.pixelSize: root.fontPx(7)
        font.family: root.uiFont
        opacity: 0.7
      }
    }
  } }
  Component { id: quickNetworkComp; Item {
    id: quickNetworkRoot
    anchors.fill: parent
    // full port of network from old (wifi enable/scan/list/conn + tooltip/ssid, eth toggle, refresh, traffic, state/procs; compressed)
    property var wifiNetworks: []
    property bool wifiEnabled: true
    property string currentWifiSsid: ""
    property bool wifiScanning: false
    property string wifiDevice: ""
    property string wifiLabel: "WiFi"
    property string wifiTooltip: ""
    property string netDevice: ""
    property string ethDevice: ""
    property string ethState: ""
    property string ethConnection: ""
    property bool ethConnected: false
    property var ethDevices: []
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
      let unit = "K"; let value = bytes / 1024
      if (value >= 1024) { unit = "M"; value /= 1024 }
      if (value >= 1024) { unit = "G"; value /= 1024 }
      return Math.min(999, Math.round(value)).toString().padStart(3, "0") + " " + unit + "/s"
    }
    function resetNetSpeed(device) {
      quickNetworkRoot.netSpeedDevice = device || ""
      quickNetworkRoot.netRxSpeed = 0; quickNetworkRoot.netTxSpeed = 0
      quickNetworkRoot.netPreviousRxBytes = -1; quickNetworkRoot.netPreviousTxBytes = -1
      quickNetworkRoot.netPreviousSampleMs = 0
      quickNetworkRoot.netRxHistory = []; quickNetworkRoot.netTxHistory = []
    }
    function activeNetDevice() { return quickNetworkRoot.netDevice || quickNetworkRoot.wifiDevice || quickNetworkRoot.ethDevice || "" }
    function refreshNetSpeed() {
      const dev = quickNetworkRoot.activeNetDevice()
      if (!dev || netSpeedProc.running) return
      if (dev !== quickNetworkRoot.netSpeedDevice) quickNetworkRoot.resetNetSpeed(dev)
      netSpeedProc.command = ["cat", "/sys/class/net/" + dev + "/statistics/rx_bytes", "/sys/class/net/" + dev + "/statistics/tx_bytes"]
      netSpeedProc.running = true
    }
    function updateNetSpeed(out) {
      const values = (out || "").trim().split(/\s+/)
      if (values.length < 2) return
      const now = Date.now()
      const rxBytes = Number(values[0]); const txBytes = Number(values[1])
      const seconds = (now - quickNetworkRoot.netPreviousSampleMs) / 1000
      if (quickNetworkRoot.netPreviousSampleMs > 0 && seconds > 0) {
        quickNetworkRoot.netRxSpeed = Math.max(0, (rxBytes - quickNetworkRoot.netPreviousRxBytes) / seconds)
        quickNetworkRoot.netTxSpeed = Math.max(0, (txBytes - quickNetworkRoot.netPreviousTxBytes) / seconds)
        const rx = quickNetworkRoot.netRxHistory.slice(-quickNetworkRoot.netHistoryLimit + 1)
        const tx = quickNetworkRoot.netTxHistory.slice(-quickNetworkRoot.netHistoryLimit + 1)
        rx.push(quickNetworkRoot.netRxSpeed); tx.push(quickNetworkRoot.netTxSpeed)
        quickNetworkRoot.netRxHistory = rx; quickNetworkRoot.netTxHistory = tx
      }
      quickNetworkRoot.netPreviousRxBytes = rxBytes; quickNetworkRoot.netPreviousTxBytes = txBytes
      quickNetworkRoot.netPreviousSampleMs = now
    }
    function scanWifi() {
      quickNetworkRoot.wifiScanning = true
      wifiListProc.command = quickNetworkRoot.wifiDevice
        ? ["nmcli", "-w", "8", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "ifname", quickNetworkRoot.wifiDevice, "--rescan", "yes"]
        : ["nmcli", "-w", "8", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"]
      if (typeof wifiProc !== 'undefined' && wifiProc) wifiProc.running = true
      if (!wifiListProc.running) wifiListProc.running = true
      if (typeof wifiPowerCheck !== 'undefined' && wifiPowerCheck) wifiPowerCheck.running = true
      if (typeof ethCheck !== 'undefined' && ethCheck) ethCheck.running = true
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
            quickNetworkRoot.netDevice = d.device || ""
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
            const p = line.split(":")
            if (p.length < 3) continue
            const ssid = p[1] || ""
            if (!ssid || seen[ssid]) continue
            seen[ssid] = true
            const inUse = p[0] === "*"
            const isCurrent = inUse || (ssid === quickNetworkRoot.currentWifiSsid)
            out.push({ ssid: ssid, signal: parseInt(p[2])||0, sec: p[3]||"", active: isCurrent })
          }
          const ai = out.findIndex(n => n.active)
          if (ai > 0) { const a = out.splice(ai, 1)[0]; out.unshift(a) }
          const next = out.slice(0, 12)
          if (next.length === 1 && next[0].active && (quickNetworkRoot.wifiNetworks || []).length > 1) {
            quickNetworkRoot.wifiNetworks = [next[0]].concat( (quickNetworkRoot.wifiNetworks || []).filter(n => n.ssid !== next[0].ssid) ).slice(0, 12)
          } else {
            quickNetworkRoot.wifiNetworks = next
          }
        }
      }
      stderr: StdioCollector {}
      onExited: (code) => { if (code !== 0) quickNetworkRoot.wifiScanning = false }
    }
    Process {
      id: wifiPowerCheck
      command: ["nmcli", "radio", "wifi"]
      stdout: StdioCollector {
        onStreamFinished: { quickNetworkRoot.wifiEnabled = (text || "").trim().indexOf("enabled") !== -1 }
      }
    }
    Process {
      id: netSpeedProc
      command: ["true"]
      stdout: StdioCollector { onStreamFinished: quickNetworkRoot.updateNetSpeed(text) }
    }
    Process {
      id: ethCheck
      command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
      stdout: StdioCollector {
        onStreamFinished: {
          const devices = []
          const lines = (text || "").trim().split("\n").filter(l => l)
          for (const line of lines) {
            const p = line.split(":")
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
        }
      }
    }

    Timer { interval: 6000; running: root.quickDetailActive && root.expandedQuickKey === "network"; repeat: true; triggeredOnStart: true; onTriggered: quickNetworkRoot.scanWifi() }
    Timer { interval: 1000; running: root.quickDetailActive && root.expandedQuickKey === "network"; repeat: true; triggeredOnStart: true; onTriggered: quickNetworkRoot.refreshNetSpeed() }

    Component.onCompleted: Qt.callLater(quickNetworkRoot.scanWifi)

    ColumnLayout {
      anchors.fill: parent; spacing: 6
      RowLayout {
        Layout.fillWidth: true
        Text { text: "󰈀 Network"; font.pixelSize: root.fontPx(11); color: Style.green; font.family: root.uiFont; font.bold: true }
        Text { text: (quickNetworkRoot.wifiNetworks || []).length + " Wi-Fi"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(9); font.family: root.uiFont }
        Item { Layout.fillWidth: true }
        Rectangle {
          width: 58; height: 20; radius: 4; color: refreshMa.containsMouse ? Style.menuRowHi : root.menuTileBg
          border.color: Style.menuSep; border.width: 1
          Text { anchors.centerIn: parent; text: "Refresh"; font.pixelSize: root.fontPx(9); color: Style.menuInk; font.family: root.uiFont }
          Behavior on color { ColorAnimation { duration: 140 } }
          MouseArea { id: refreshMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { quickNetworkRoot.scanWifi(); if (typeof ethCheck !== 'undefined' && ethCheck) ethCheck.running = true } }
        }
      }

      RowLayout {
        Layout.fillWidth: true; spacing: 6
        Rectangle {
          Layout.fillWidth: true; Layout.preferredHeight: 118
          radius: 6; color: root.menuTileBg; border.color: Style.menuSep; border.width: 1
          ColumnLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 4
            RowLayout {
              Layout.fillWidth: true
              Text { text: "󰤨 Wi-Fi"; color: Style.menuIndigo; font.pixelSize: root.fontPx(10); font.family: root.uiFont; font.bold: true }
              Text { text: quickNetworkRoot.wifiEnabled ? "enabled" : "disabled"; color: quickNetworkRoot.wifiEnabled ? Style.green : Style.red; font.pixelSize: root.fontPx(9); font.family: root.uiFont; font.bold: true }
              Item { Layout.fillWidth: true }
              Rectangle {
                width: 58; height: 18; radius: 4
                color: quickNetworkRoot.wifiEnabled ? Qt.rgba(Style.red.r, Style.red.g, Style.red.b, 0.18) : Qt.rgba(Style.green.r, Style.green.g, Style.green.b, 0.18)
                border.color: quickNetworkRoot.wifiEnabled ? Style.red : Style.green; border.width: 1
                Text { anchors.centerIn: parent; text: quickNetworkRoot.wifiEnabled ? "Disable" : "Enable"; color: quickNetworkRoot.wifiEnabled ? Style.red : Style.green; font.pixelSize: root.fontPx(8); font.family: root.uiFont; font.bold: true }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    const tgt = quickNetworkRoot.wifiEnabled ? "off" : "on"
                    Quickshell.execDetached(["nmcli", "radio", "wifi", tgt])
                    quickNetworkRoot.wifiEnabled = !quickNetworkRoot.wifiEnabled
                    Qt.callLater(quickNetworkRoot.scanWifi)
                  }
                }
              }
            }
            Text {
              Layout.fillWidth: true
              text: quickNetworkRoot.currentWifiSsid ? quickNetworkRoot.currentWifiSsid : quickNetworkRoot.wifiLabel
              color: Style.menuInk; font.pixelSize: root.fontPx(10); font.family: root.uiFont; font.bold: true; elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              text: {
                let t = quickNetworkRoot.wifiTooltip || "No Wi-Fi details"
                t = t.replace(/^Connected to [^\n]*\n?/, "")
                return t.trim() || "No Wi-Fi connection details"
              }
              color: Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; verticalAlignment: Text.AlignTop
            }
          }
        }
        Rectangle {
          Layout.fillWidth: true; Layout.preferredHeight: 118
          radius: 6; color: root.menuTileBg; border.color: Style.menuSep; border.width: 1
          ColumnLayout {
            anchors.fill: parent; anchors.margins: 8; spacing: 4
            RowLayout {
              Layout.fillWidth: true
              Text { text: "󰈀 LAN"; color: Style.menuIndigo; font.pixelSize: root.fontPx(10); font.family: root.uiFont; font.bold: true }
              Text { text: quickNetworkRoot.ethDevice ? quickNetworkRoot.ethState : "missing"; color: quickNetworkRoot.ethConnected ? Style.green : Style.menuInkDeep; font.pixelSize: root.fontPx(9); font.family: root.uiFont; font.bold: true }
              Item { Layout.fillWidth: true }
              Rectangle {
                visible: !!quickNetworkRoot.ethDevice
                width: 58; height: 18; radius: 4
                color: quickNetworkRoot.ethConnected ? Qt.rgba(Style.red.r, Style.red.g, Style.red.b, 0.18) : Qt.rgba(Style.green.r, Style.green.g, Style.green.b, 0.18)
                border.color: quickNetworkRoot.ethConnected ? Style.red : Style.green; border.width: 1
                Text { anchors.centerIn: parent; text: quickNetworkRoot.ethConnected ? "Disable" : "Enable"; color: quickNetworkRoot.ethConnected ? Style.red : Style.green; font.pixelSize: root.fontPx(8); font.family: root.uiFont; font.bold: true }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (quickNetworkRoot.ethConnected) Quickshell.execDetached(["nmcli", "device", "disconnect", quickNetworkRoot.ethDevice])
                    else Quickshell.execDetached(["nmcli", "device", "connect", quickNetworkRoot.ethDevice])
                    Qt.callLater(function(){ if (typeof ethCheck !== 'undefined' && ethCheck) ethCheck.running = true })
                  }
                }
              }
            }
            Text { Layout.fillWidth: true; text: quickNetworkRoot.ethDevice ? quickNetworkRoot.ethDevice : "No ethernet device"; color: Style.menuInk; font.pixelSize: root.fontPx(10); font.family: root.uiFont; font.bold: true; elide: Text.ElideRight }
            Text { Layout.fillWidth: true; text: quickNetworkRoot.ethConnection || ((quickNetworkRoot.ethDevices || []).length > 1 ? ((quickNetworkRoot.ethDevices || []).length + " ethernet") : "No active LAN"); color: Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont; elide: Text.ElideRight }
          }
        }
      }

      // traffic compact
      Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 72
        radius: 6; color: root.menuTileBg; border.color: Style.menuSep; border.width: 1
        ColumnLayout {
          anchors.fill: parent; anchors.margins: 6; spacing: 2
          RowLayout {
            Layout.fillWidth: true
            Text { text: "Traffic"; color: Style.menuInk; font.pixelSize: root.fontPx(9); font.family: root.uiFont }
            Item { Layout.fillWidth: true }
            Text { text: "↑ " + quickNetworkRoot.formatNetSpeed(quickNetworkRoot.netTxSpeed); color: quickNetworkRoot.netTxSpeed >= 1024 ? Style.green : Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont }
            Text { text: "↓ " + quickNetworkRoot.formatNetSpeed(quickNetworkRoot.netRxSpeed); color: quickNetworkRoot.netRxSpeed >= 1024 ? Style.menuIndigo : Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont }
          }
          Canvas {
            id: netCanvas
            Layout.fillWidth: true; Layout.fillHeight: true
            Connections {
              target: quickNetworkRoot
              function onNetRxHistoryChanged() { netCanvas.requestPaint() }
              function onNetTxHistoryChanged() { netCanvas.requestPaint() }
            }
            onPaint: {
              const ctx = getContext("2d"); ctx.reset()
              const w = width; const h = height
              const rx = quickNetworkRoot.netRxHistory || []; const tx = quickNetworkRoot.netTxHistory || []
              const n = Math.max(rx.length, tx.length); let maxValue = 1024
              for (let i=0; i<rx.length; i++) maxValue = Math.max(maxValue, rx[i])
              for (let i=0; i<tx.length; i++) maxValue = Math.max(maxValue, tx[i])
              ctx.strokeStyle = Qt.rgba(Style.menuInkDeep.r, Style.menuInkDeep.g, Style.menuInkDeep.b, 0.22); ctx.lineWidth = 1
              for (let i=1; i<4; i++) { const y = Math.round(h * i / 4) + 0.5; ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(w,y); ctx.stroke() }
              function drawLine(vals, color) {
                if (vals.length < 2) return
                ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.beginPath()
                for (let i=0; i<vals.length; i++) {
                  const x = vals.length === 1 ? w : i * w / (vals.length - 1)
                  const y = h - Math.max(0, Math.min(1, vals[i] / maxValue)) * h
                  if (i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y)
                }
                ctx.stroke()
              }
              if (n === 0) { ctx.fillStyle = Style.menuInkDeep; ctx.font = root.fontPx(8) + "px sans-serif"; ctx.fillText("waiting for traffic", 4, Math.round(h/2)) }
              else { drawLine(tx, Style.green); drawLine(rx, Style.menuIndigo) }
            }
          }
        }
      }

      Text { text: "Available networks" + (quickNetworkRoot.wifiScanning ? " (scanning...)" : ""); font.pixelSize: root.fontPx(9); color: Style.menuInkDeep; font.family: root.uiFont }

      Rectangle { Layout.fillWidth: true; height: 1; color: Style.menuSep }

      Flickable {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
        contentHeight: wifiCol.height; boundsBehavior: Flickable.StopAtBounds
        Column {
          id: wifiCol; width: parent.width; spacing: 3
          Repeater {
            model: quickNetworkRoot.wifiNetworks || []
            delegate: Rectangle {
              required property var modelData
              width: parent.width - 4; x: 2; height: 36; radius: 4
              color: modelData.active ? Qt.rgba(Style.menuIndigo.r, Style.menuIndigo.g, Style.menuIndigo.b, 0.14) : (netMa.containsMouse ? Style.menuRowHi : "transparent")
              border.color: modelData.active ? Style.menuIndigo : (netMa.containsMouse ? Style.menuSep : "transparent"); border.width: 1
              scale: netMa.containsMouse && !modelData.active ? 1.01 : 1.0
              Behavior on color { ColorAnimation { duration: 140 } }
              Behavior on border.color { ColorAnimation { duration: 140 } }
              Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
              RowLayout {
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; anchors.topMargin: 4; anchors.bottomMargin: 4; spacing: 6
                Text { text: modelData.signal > 75 ? "󰤨" : (modelData.signal > 50 ? "󰤥" : (modelData.signal > 25 ? "󰤢" : "󰤟")); font.family: root.uiFont; font.pixelSize: root.fontPx(12); color: modelData.active ? Style.menuIndigo : Style.menuInkDeep }
                ColumnLayout { spacing: 1; Layout.fillWidth: true
                  Text { text: modelData.ssid; font.family: root.uiFont; font.pixelSize: root.fontPx(9); font.bold: modelData.active; color: modelData.active ? Style.menuIndigo : Style.menuInk; elide: Text.ElideRight; Layout.fillWidth: true }
                  Text { text: modelData.active ? "Connected" : (modelData.sec ? "Secure" : "Open"); font.family: root.uiFont; font.pixelSize: root.fontPx(7); color: modelData.active ? Style.menuIndigo : Style.menuInkDeep }
                }
                Text { text: modelData.sec ? "󰌾" : ""; font.family: root.uiFont; font.pixelSize: root.fontPx(10); color: Style.menuInkDeep }
                Text { text: modelData.signal + "%"; font.family: root.uiFont; font.pixelSize: root.fontPx(8); color: Style.menuInkDeep }
                MouseArea {
                  visible: modelData.active; width: 16; height: 16
                  onClicked: { Quickshell.execDetached(["nmcli", "con", "down", "id", modelData.ssid]); quickNetworkRoot.scanWifi() }
                  Text { anchors.centerIn: parent; text: "󰅙"; font.family: root.uiFont; font.pixelSize: root.fontPx(12); color: Style.red }
                }
              }
              MouseArea {
                id: netMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: -1
                onClicked: {
                  if (modelData.active) { Quickshell.execDetached(["nmcli", "con", "down", "id", modelData.ssid]); quickNetworkRoot.scanWifi(); return }
                  Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", modelData.ssid])
                  Qt.callLater(quickNetworkRoot.scanWifi)
                }
              }
            }
          }
          Text {
            visible: (quickNetworkRoot.wifiNetworks || []).length === 0
            text: quickNetworkRoot.wifiScanning ? "Scanning..." : "No networks. Tap Refresh."
            color: Style.menuInkDeep; font.pixelSize: root.fontPx(9); font.family: root.uiFont; horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  } }
  Component { id: quickMonitorsComp; Item {
    id: quickMonitorsRoot
    anchors.fill: parent
    implicitHeight: monLayout.implicitHeight
    // full port monitors (hypr all-j, list, mirror/extend/external/rescan, status, canvas, procs, guards; exact)
    property var mons: []
    property int monVersion: 0
    property string monStatus: ""

    function luaString(value) { return "\"" + String(value || "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"" }
    function monitorMode(m) {
      if (!m) return "preferred"
      const rr = m.refreshRate ? "@" + Number(m.refreshRate).toFixed(3) : ""
      return (m.width || 0) + "x" + (m.height || 0) + rr
    }
    function monitorPrimary() {
      const list = quickMonitorsRoot.mons || []
      return list.find(m => m.name === "eDP-1") || list.find(m => m.focused) || list[0] || null
    }
    function monitorLogicalWidth(m) { return (m.width || 1920) / Math.max(0.25, m.scale || 1) }
    function monitorLogicalHeight(m) { return (m.height || 1080) / Math.max(0.25, m.scale || 1) }
    function mirrorMonitors() {
      const primary = quickMonitorsRoot.monitorPrimary()
      if (!primary) { quickMonitorsRoot.monStatus = "No primary"; return }
      const calls = []
      for (const m of (quickMonitorsRoot.mons || [])) {
        if (!m || m.name === primary.name || m.disabled) continue
        calls.push("hl.monitor({ output = " + quickMonitorsRoot.luaString(m.name) + ", mode = \"preferred\", position = \"0x0\", scale = " + (m.scale || 1) + ", mirror = " + quickMonitorsRoot.luaString(primary.name) + " })")
      }
      if (!calls.length) { quickMonitorsRoot.monStatus = "No external to mirror"; return }
      quickMonitorsRoot.monStatus = "Mirroring to " + primary.name + "..."
      monAction.command = ["hyprctl", "eval", calls.join("\n")]; monAction.running = true
    }
    function extendMonitors() {
      quickMonitorsRoot.monStatus = "Reloading monitors..."
      monAction.command = ["hyprctl", "reload"]; monAction.running = true
    }
    function externalOnlyMonitors() {
      const external = (quickMonitorsRoot.mons || []).find(m => m && m.name !== "eDP-1")
      if (!external) { quickMonitorsRoot.monStatus = "No external"; return }
      quickMonitorsRoot.monStatus = "External only..."
      monAction.command = ["hyprctl", "eval", "hl.monitor({ output = " + quickMonitorsRoot.luaString(external.name) + ", mode = \"preferred\", position = \"0x0\", scale = " + (external.scale || 1) + " })\nhl.monitor({ output = \"eDP-1\", disabled = true })" ]
      monAction.running = true
    }
    function rescanMonitors() {
      quickMonitorsRoot.monStatus = "Rescanning..."
      if (!monScan.running) monScan.running = true
    }

    Process {
      id: monScan
      command: ["hyprctl", "monitors", "all", "-j"]
      stdout: StdioCollector {
        onStreamFinished: {
          try { quickMonitorsRoot.mons = JSON.parse((text || "").trim() || "[]") } catch(_) { quickMonitorsRoot.mons = [] }
          quickMonitorsRoot.monVersion = (quickMonitorsRoot.monVersion + 1) % 1000
        }
      }
    }
    Process {
      id: monAction
      stdout: StdioCollector { id: monOut }
      stderr: StdioCollector { id: monErr }
      onExited: (code) => {
        const out = ((monOut.text || "") + (monErr.text || "")).trim()
        quickMonitorsRoot.monStatus = (code === 0 ? (out || "ok") : (out || ("fail " + code)))
        Qt.callLater(function(){ if (!monScan.running) monScan.running = true })
      }
    }
    Timer { interval: 900; id: monDelay; onTriggered: monScan.running = true }
    Timer { interval: 3000; running: root.quickDetailActive && root.expandedQuickKey === "monitors"; repeat: true; triggeredOnStart: true; onTriggered: if (!monScan.running) monScan.running = true }

    Component.onCompleted: Qt.callLater(function(){ if (!monScan.running) monScan.running = true })

    ColumnLayout {
      id: monLayout
      anchors.fill: parent; spacing: 8
      RowLayout {
        Layout.fillWidth: true; spacing: 6
        Text { text: "󰍹 Monitors (" + ((quickMonitorsRoot.mons || []).length || 0) + ")"; color: Style.green; font.pixelSize: root.fontPx(12); font.family: root.uiFont; font.bold: true }
        Text { text: quickMonitorsRoot.monStatus || "Live layout"; color: (quickMonitorsRoot.monStatus.indexOf("fail")>=0 || quickMonitorsRoot.monStatus.indexOf("No ")>=0 ? Style.red : Style.menuInkDeep); font.pixelSize: root.fontPx(9); font.family: root.uiFont; Layout.fillWidth: true; elide: Text.ElideRight }
        Rectangle { width: 76; height: 26; radius: 5; color: mirrMa.containsMouse ? Style.menuRowHi : root.menuTileBg; border.color: Style.menuSep; border.width: 1
          Text { anchors.centerIn: parent; text: "Mirror"; font.pixelSize: root.fontPx(9); color: Style.menuInk; font.family: root.uiFont }
          Behavior on color { ColorAnimation { duration: 140 } }
          MouseArea { id: mirrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: quickMonitorsRoot.mirrorMonitors() }
        }
        Rectangle { width: 76; height: 26; radius: 5; color: extMa.containsMouse ? Style.menuRowHi : root.menuTileBg; border.color: Style.menuSep; border.width: 1
          Text { anchors.centerIn: parent; text: "Extend"; font.pixelSize: root.fontPx(9); color: Style.menuInk; font.family: root.uiFont }
          Behavior on color { ColorAnimation { duration: 140 } }
          MouseArea { id: extMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: quickMonitorsRoot.extendMonitors() }
        }
        Rectangle { width: 76; height: 26; radius: 5; color: extnMa.containsMouse ? Style.menuRowHi : root.menuTileBg; border.color: Style.menuSep; border.width: 1
          Text { anchors.centerIn: parent; text: "External"; font.pixelSize: root.fontPx(9); color: Style.menuInk; font.family: root.uiFont }
          Behavior on color { ColorAnimation { duration: 140 } }
          MouseArea { id: extnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: quickMonitorsRoot.externalOnlyMonitors() }
        }
        Rectangle { width: 76; height: 26; radius: 5; color: resMa.containsMouse ? Style.menuRowHi : root.menuTileBg; border.color: Style.menuSep; border.width: 1
          Text { anchors.centerIn: parent; text: "Rescan"; font.pixelSize: root.fontPx(9); color: Style.menuInk; font.family: root.uiFont }
          Behavior on color { ColorAnimation { duration: 140 } }
          MouseArea { id: resMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: quickMonitorsRoot.rescanMonitors() }
        }
      }
      // compact layout viz
      Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 420
        radius: 6; color: Style.menuControlBg; border.color: Style.menuSep; border.width: 1
        Canvas {
          anchors.fill: parent; anchors.margins: 10
          property int v: quickMonitorsRoot.monVersion
          onVChanged: requestPaint()
          onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            const mons = quickMonitorsRoot.mons || []
            if (!mons.length) { ctx.fillStyle = Style.menuInkDeep; ctx.font = root.fontPx(8)+"px monospace"; ctx.fillText("Loading... rescan", 4, 12); return }
            let minX=0, minY=0, maxX=0, maxY=0
            for (const m of mons) { minX=Math.min(minX, m.x||0); minY=Math.min(minY, m.y||0); maxX=Math.max(maxX, (m.x||0)+quickMonitorsRoot.monitorLogicalWidth(m)); maxY=Math.max(maxY, (m.y||0)+quickMonitorsRoot.monitorLogicalHeight(m)) }
            const W=width, H=height, pad=10
            const sx=(W-2*pad)/Math.max(1,maxX-minX), sy=(H-2*pad)/Math.max(1,maxY-minY)
            for (const m of mons) {
              const x=pad+((m.x||0)-minX)*sx, y=pad+((m.y||0)-minY)*sy
              const w=quickMonitorsRoot.monitorLogicalWidth(m)*sx, h=quickMonitorsRoot.monitorLogicalHeight(m)*sy
              ctx.strokeStyle = Style.menuIndigo; ctx.lineWidth = 1; ctx.strokeRect(x, y, w, h)
              ctx.fillStyle = m.focused ? Qt.rgba(Style.menuIndigo.r, Style.menuIndigo.g, Style.menuIndigo.b, 0.24) : root.menuTileBg
              ctx.fillRect(x+1, y+1, w-2, h-2)
              ctx.fillStyle = Style.menuInk; ctx.font = root.fontPx(13)+"px monospace"
              ctx.fillText((m.name||"mon").slice(0,14), x+8, y+18)
              ctx.font = root.fontPx(11)+"px monospace"
              ctx.fillText(Math.round(quickMonitorsRoot.monitorLogicalWidth(m))+"x"+Math.round(quickMonitorsRoot.monitorLogicalHeight(m))+" logical", x+8, y+34)
              ctx.fillText("scale " + (m.scale || 1) + "  " + (m.x || 0) + "," + (m.y || 0), x+8, y+48)
            }
          }
        }
      }
      Text { text: "Mirror uses eDP-1 as source when present. Extend reloads monitors.lua. Layout drawn in logical coordinates."; color: Style.menuInkDeep; font.pixelSize: root.fontPx(9); font.family: root.uiFont; Layout.alignment: Qt.AlignHCenter }
      Flickable {
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
        contentHeight: monList.height
        Column { id: monList; width: parent.width; spacing: 6
          Repeater {
            model: quickMonitorsRoot.mons || []
            delegate: Rectangle {
              required property var modelData
              width: parent.width; height: 46; radius: 6
              color: modelData.focused ? Qt.rgba(Style.menuIndigo.r, Style.menuIndigo.g, Style.menuIndigo.b, 0.16) : root.menuTileBg
              border.color: modelData.focused ? Style.menuIndigo : Style.menuSep; border.width: 1
              Behavior on color { ColorAnimation { duration: 140 } }
              RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                Text { text: modelData.focused ? "󰍹" : "󰌢"; color: modelData.focused ? Style.menuIndigo : Style.menuInkDeep; font.pixelSize: root.fontPx(14); font.family: root.uiFont }
                ColumnLayout {
                  Layout.fillWidth: true; spacing: 0
                  Text { text: (modelData.name || "?") + (modelData.mirrorOf && modelData.mirrorOf !== "none" ? (" mirrors " + modelData.mirrorOf) : ""); color: Style.menuInk; font.pixelSize: root.fontPx(10); font.family: root.uiFont; font.bold: modelData.focused; elide: Text.ElideRight; Layout.fillWidth: true }
                  Text { text: quickMonitorsRoot.monitorMode(modelData) + "  scale " + (modelData.scale||1) + "  pos " + (modelData.x||0) + "," + (modelData.y||0); color: Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont; elide: Text.ElideRight; Layout.fillWidth: true }
                }
              }
            }
          }
        }
      }
    }
  } }
  Component { id: quickTempComp; Item {
    id: quickTempRoot
    anchors.fill: parent
    // full port of temp: parse/groups/hottest/bars/color/percent/proc/timer/UI (exact old, guards, live)
    property string tempOutput: ""
    property var tempSensors: []
    property var tempGroups: []
    property var hottestSensor: null
    property string tempUpdated: ""

    function parseTemperatures(out) {
      const sensors = []
      let groupName = ""; let groupPath = ""; let last = null
      const lines = (out || "").split("\n")
      for (const line of lines) {
        if (line.indexOf("Hottest:") === 0) break
        const gm = line.match(/^>>> (.+?) \((.+)\)$/)
        if (gm) { groupName = gm[1]; groupPath = gm[2]; continue }
        const sm = line.match(/^\s*(\S+)\s+(.+?)\s+(-?\d+(?:\.\d+)?)°C\s+(.+)$/)
        if (sm) {
          const keyName = groupName || sm[1]
          const keyPath = groupPath || sm[4].trim().replace(/\/temp[^/]+$/, "")
          last = { group: keyName, groupPath: keyPath, groupKey: keyName + "|" + keyPath, name: sm[1], label: sm[2].trim(), displayLabel: sm[2].trim(), value: Number(sm[3]), path: sm[4].trim(), desc: "" }
          sensors.push(last); continue
        }
        const dm = line.match(/^\s{4}(.+)$/)
        if (dm && last) last.desc = dm[1].trim()
      }
      const groups = []
      for (const sensor of sensors) {
        let g = groups.find(item => item.key === sensor.groupKey)
        if (!g) { g = { key: sensor.groupKey, name: sensor.group, path: sensor.groupPath, sensors: [], max: sensor.value, sum: 0 }; groups.push(g) }
        g.sensors.push(sensor); g.max = Math.max(g.max, sensor.value); g.sum = (g.sum || 0) + sensor.value
      }
      for (const g of groups) { g.avg = g.sum / Math.max(1, g.sensors.length) }
      const groupNameMap = { "macsmc_hwmon": "SMC Sensors", "tas2764": "Speaker Amps", "macsmc_battery": "Battery", "nvme": "NVMe SSD" }
      const sourceCounts = {}; for (const g of groups) sourceCounts[g.name] = (sourceCounts[g.name] || 0) + 1
      const sourceSeen = {}
      for (const g of groups) {
        const baseName = groupNameMap[g.name] || g.name
        sourceSeen[g.name] = (sourceSeen[g.name] || 0) + 1
        g.displayName = sourceCounts[g.name] > 1 ? (baseName + " " + sourceSeen[g.name]) : baseName
        const labelCounts = {}; for (const s of g.sensors) labelCounts[s.label] = (labelCounts[s.label] || 0) + 1
        const labelSeen = {}
        for (const s of g.sensors) {
          labelSeen[s.label] = (labelSeen[s.label] || 0) + 1
          s.displayLabel = labelCounts[s.label] > 1 ? (s.label + " " + labelSeen[s.label]) : s.label
          s.groupDisplayName = g.displayName
        }
        const descs = g.sensors.map(s => s.desc || "").filter(d => d)
        let shared = null
        if (descs.length > 0) { shared = descs[0]; for (let i=1; i<descs.length; i++) if (descs[i] !== shared) { shared = null; break } }
        g.sharedDesc = shared; for (const s of g.sensors) s.sharedDesc = g.sharedDesc
      }
      groups.sort((a, b) => b.max - a.max)
      quickTempRoot.tempSensors = sensors
      quickTempRoot.tempGroups = groups
      quickTempRoot.hottestSensor = sensors.reduce((best, sensor) => !best || sensor.value > best.value ? sensor : best, null)
      quickTempRoot.tempUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
    }
    function tempColor(value) {
      if (value >= 70) return Style.red
      if (value >= 55) return Style.orange
      if (value >= 45) return Style.yellow
      return Style.green
    }
    function tempPercent(value) { return Math.max(0, Math.min(1, (value - 25) / 55)) }

    Process {
      id: tProc
      command: [root.binDir + "/asahi-temperature"]
      stdout: StdioCollector {
        onStreamFinished: {
          quickTempRoot.tempOutput = (text || "").trim()
          quickTempRoot.parseTemperatures(quickTempRoot.tempOutput)
        }
      }
    }
    Timer { interval: 2500; running: root.quickDetailActive && root.expandedQuickKey === "temp"; repeat: true; triggeredOnStart: true; onTriggered: if (!tProc.running) tProc.running = true }

    Component.onCompleted: Qt.callLater(function(){ if (!tProc.running) tProc.running = true })

    ColumnLayout {
      anchors.fill: parent; spacing: 4
      Text { text: "TEMPERATURES"; color: Style.menuInk; font.pixelSize: root.fontPx(9); font.family: root.uiFont; font.letterSpacing: 1.2 }
      Rectangle {
        Layout.fillWidth: true; Layout.fillHeight: true
        radius: 4; color: Style.menuControlBg; border.color: Style.menuSep; border.width: 1
        Flickable {
          anchors.fill: parent; anchors.margins: 6; clip: true
          contentHeight: tempCol.implicitHeight; boundsBehavior: Flickable.StopAtBounds
          Column {
            id: tempCol; width: parent.width; spacing: 6
            Text {
              visible: (quickTempRoot.tempGroups || []).length === 0
              text: quickTempRoot.tempOutput ? "No sensors parsed." : "Loading sensors..."
              color: Style.menuInkDeep; font.pixelSize: root.fontPx(9); font.family: root.uiFont; wrapMode: Text.Wrap; width: parent.width
            }
            Text {
              visible: !!quickTempRoot.hottestSensor && (quickTempRoot.tempGroups || []).length > 0
              text: quickTempRoot.hottestSensor
                ? "Hottest: " + (quickTempRoot.hottestSensor.groupDisplayName || quickTempRoot.hottestSensor.group) + " / "
                  + quickTempRoot.hottestSensor.displayLabel + " " + quickTempRoot.hottestSensor.value.toFixed(1) + "°C"
                : ""
              color: quickTempRoot.hottestSensor ? quickTempRoot.tempColor(quickTempRoot.hottestSensor.value) : Style.menuInkDeep
              font.pixelSize: root.fontPx(9); font.family: root.uiFont; font.bold: true
              width: parent.width; elide: Text.ElideRight
            }
            Repeater {
              model: quickTempRoot.tempGroups || []
              delegate: Rectangle {
                required property var modelData
                width: parent.width; height: groupCol.implicitHeight + 10; radius: 4
                color: root.menuTileBg; border.color: Style.menuSep; border.width: 1
                Column {
                  id: groupCol; width: parent.width - 12; x: 6; y: 5; spacing: 3
                  RowLayout {
                    width: parent.width
                    Text { text: modelData.displayName || modelData.name; color: Style.menuInk; font.pixelSize: root.fontPx(9); font.family: root.uiFont; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                    Text { text: "avg " + modelData.avg.toFixed(1) + "°C"; color: quickTempRoot.tempColor(modelData.avg); font.pixelSize: root.fontPx(8); font.family: root.uiFont; font.bold: true }
                  }
                  Repeater {
                    model: modelData.sensors || []
                    delegate: Column {
                      required property var modelData; required property int index
                      width: groupCol.width; spacing: 1
                      RowLayout {
                        width: parent.width
                        Text { text: modelData.displayLabel || modelData.label; color: Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: modelData.value.toFixed(1) + "°C"; color: quickTempRoot.tempColor(modelData.value); font.pixelSize: root.fontPx(8); font.family: root.uiFont; font.bold: true }
                      }
                      Rectangle {
                        width: parent.width; height: 4; radius: 2; color: Qt.rgba(0,0,0,0.2)
                        Rectangle { width: parent.width * quickTempRoot.tempPercent(modelData.value); height: parent.height; radius: parent.radius; color: quickTempRoot.tempColor(modelData.value) }
                      }
                      Text {
                        visible: !!modelData.desc && (index === 0 || !modelData.sharedDesc)
                        text: modelData.sharedDesc || modelData.desc; color: Style.menuInkDeep; font.pixelSize: root.fontPx(7); font.family: root.uiFont; width: parent.width; elide: Text.ElideRight
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      Text { text: quickTempRoot.tempUpdated ? ("updated " + quickTempRoot.tempUpdated) : "asahi-temperature"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(7); font.family: root.uiFont }
    }
  } }
  Component { id: quickBtComp; Item {
    id: quickBtRoot
    anchors.fill: parent
    implicitHeight: btLayout.implicitHeight
    // bt enhanced (power toggle rfkill like old, dev list conn/pair, procs)
    property bool btOn: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
    property var btDevs: (Bluetooth.devices && Bluetooth.devices.values) ? Bluetooth.devices.values : []

    Process {
      id: btStat
      command: ["sh", "-c", "bluetoothctl show 2>/dev/null || true"]
      stdout: StdioCollector { onStreamFinished: quickBtRoot.btOn = (text || "").indexOf("Powered: yes") !== -1 }
    }
    Timer { id: btDelay; interval: 500; onTriggered: if (btStat) btStat.running = true }
    function refreshBt() { if (btStat && !btStat.running) btStat.running = true }
    function toggleBt() {
      const next = quickBtRoot.btOn ? "off" : "on"
      Quickshell.execDetached(["sh", "-c", "if [ \"$1\" = on ]; then rfkill unblock bluetooth 2>/dev/null || true; fi; bluetoothctl power \"$1\"", "sh", next])
      quickBtRoot.btOn = !quickBtRoot.btOn
      btDelay.restart()
    }

    Component.onCompleted: quickBtRoot.refreshBt()

    ColumnLayout {
      id: btLayout
      anchors.left: parent.left
      anchors.top: parent.top
      width: Math.min(parent.width, 880)
      spacing: 12

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "Bluetooth Radio: " + (quickBtRoot.btOn ? "Active" : "Off")
          color: quickBtRoot.btOn ? Style.green : Style.menuInkDeep
          font.pixelSize: root.fontPx(11); font.family: root.uiFont; font.bold: true
        }
        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: 82; height: 26; radius: 6
          color: btPwr.containsMouse ? Style.menuRowHi : root.menuTileBg
          border.color: Style.menuSep; border.width: 1
          Behavior on color { ColorAnimation { duration: 140 } }
          Text { anchors.centerIn: parent; text: quickBtRoot.btOn ? "Turn Off" : "Turn On"; font.pixelSize: root.fontPx(10); color: Style.menuInk; font.family: root.uiFont }
          MouseArea { id: btPwr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: quickBtRoot.toggleBt() }
        }
      }

      Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Style.menuSep }

      Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(340, Math.max(88, btCol.implicitHeight))
        clip: true
        contentHeight: btCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: btCol; width: parent.width; spacing: 5
          Repeater {
            model: (quickBtRoot.btDevs || [])
            delegate: Rectangle {
              id: btRow
              required property var modelData
              width: parent.width; height: 42; radius: 6
              color: modelData.connected ? Style.menuRowSel : (btd.containsMouse ? Style.menuRowHi : "transparent")
              border.color: modelData.connected ? Style.menuSeal : (btd.containsMouse ? Style.menuSep : "transparent")
              border.width: 1
              Behavior on color { ColorAnimation { duration: 140 } }
              Behavior on border.color { ColorAnimation { duration: 140 } }

              MouseArea { id: btd; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

              Text {
                id: btIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                text: modelData.connected ? "󰂱" : "󰂯"
                font.pixelSize: root.fontPx(14)
                color: modelData.connected ? Style.green : Style.menuInkDeep
                font.family: root.uiFont
                horizontalAlignment: Text.AlignHCenter
              }

              Column {
                anchors.left: btIcon.right
                anchors.leftMargin: 12
                anchors.right: btAction.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                  width: parent.width
                  text: modelData.name || modelData.alias || modelData.address || "Device"
                  color: Style.menuInk; font.pixelSize: root.fontPx(11); font.family: root.uiFont
                  elide: Text.ElideRight; font.bold: modelData.connected
                }
                Text {
                  width: parent.width
                  text: modelData.connected ? "Connected" : (modelData.batteryAvailable ? ("Battery: " + modelData.battery + "%") : (modelData.paired ? "Paired" : "Nearby Device"))
                  color: modelData.connected ? Style.green : Style.menuInkDeep; font.pixelSize: root.fontPx(9); font.family: root.uiFont
                  elide: Text.ElideRight
                }
              }

              Rectangle {
                id: btAction
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 108; height: 24; radius: 5
                color: btActionMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
                border.color: Style.menuSep; border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                  anchors.centerIn: parent
                  text: modelData.connected ? "󰂲  Disconnect" : (modelData.paired ? "󰂱  Connect" : "󰂯  Pair")
                  font.pixelSize: root.fontPx(8); color: Style.menuIndigo; font.family: root.uiFont
                  elide: Text.ElideRight
                  width: parent.width - 8
                  horizontalAlignment: Text.AlignHCenter
                }
                MouseArea {
                  id: btActionMa
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: { if (btRow.modelData.connected) btRow.modelData.disconnect(); else if (btRow.modelData.paired) btRow.modelData.connect(); else btRow.modelData.pair() }
                }
              }
            }
          }
          Text {
            visible: (!quickBtRoot.btDevs || quickBtRoot.btDevs.length === 0)
            text: "No devices found"
            color: Style.menuInkDeep; font.pixelSize: root.fontPx(11); font.family: root.uiFont
            width: parent.width; horizontalAlignment: Text.AlignHCenter
          }
        }
      }
      Text {
        Layout.fillWidth: true
        text: "󰂯 " + ((quickBtRoot.btDevs||[]).length||0) + " devices" + (quickBtRoot.btOn ? "" : " · radio off")
        color: Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont
        horizontalAlignment: Text.AlignLeft
      }
    }
  } }
  Component { id: quickStorageComp; Item {
    id: quickStorageRoot
    anchors.fill: parent

    function mountColor(pct) {
      if (pct >= 90) return Style.red
      if (pct >= 75) return Style.orange
      return Style.menuIndigo
    }

    Component.onCompleted: Qt.callLater(root.scanStorage)

    ColumnLayout {
      anchors.fill: parent
      spacing: 6

      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
          text: "STORAGE"
          color: Style.menuInk
          font.pixelSize: root.fontPx(9)
          font.family: root.uiFont
          font.letterSpacing: 1.2
          font.weight: Font.Medium
        }
        Item { Layout.fillWidth: true }
        Text {
          text: root.storageStatus === "scanning"
            ? "scanning…"
            : (root.storageUpdated ? ("updated " + root.storageUpdated) : "")
          color: Style.menuInkDeep
          font.pixelSize: root.fontPx(8)
          font.family: root.uiFont
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 4
        color: Style.menuControlBg
        border.color: Style.menuSep
        border.width: 1
        clip: true

        Flickable {
          anchors.fill: parent
          anchors.margins: 6
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          contentHeight: storageCol.implicitHeight
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: storageCol
            width: parent.width
            spacing: 8

            Text {
              visible: root.storageError !== ""
              text: root.storageError
              color: Style.red
              font.pixelSize: root.fontPx(9)
              font.family: root.uiFont
              width: parent.width
              wrapMode: Text.Wrap
            }

            Text {
              text: "FILESYSTEMS"
              color: Style.menuInkDeep
              font.pixelSize: root.fontPx(8)
              font.family: root.uiFont
              font.letterSpacing: 1
            }

            Text {
              visible: (root.storageMounts || []).length === 0 && root.storageStatus === "scanning"
              text: "Reading mount points…"
              color: Style.menuInkDeep
              font.pixelSize: root.fontPx(9)
              font.family: root.uiFont
              width: parent.width
            }

            Repeater {
              model: root.storageMounts || []
              delegate: Rectangle {
                required property var modelData
                width: storageCol.width
                height: mountRow.implicitHeight + 10
                radius: 4
                color: mma.containsMouse ? Style.menuRowHi : (modelData.highlight ? root.menuTileBg : "transparent")
                border.color: modelData.highlight ? Style.menuSep : "transparent"
                border.width: modelData.highlight ? 1 : 0

                Column {
                  id: mountRow
                  x: 6
                  y: 5
                  width: parent.width - 12
                  spacing: 3

                  RowLayout {
                    width: parent.width
                    spacing: 6
                    Text {
                      text: modelData.mount
                      color: modelData.highlight ? Style.menuInk : Style.menuInkDeep
                      font.pixelSize: root.fontPx(9)
                      font.family: root.uiFont
                      font.weight: modelData.highlight ? Font.Medium : Font.Light
                      Layout.fillWidth: true
                      elide: Text.ElideRight
                    }
                    Text {
                      text: modelData.pct + "%"
                      color: quickStorageRoot.mountColor(modelData.pct)
                      font.pixelSize: root.fontPx(8)
                      font.family: root.uiFont
                      font.bold: true
                    }
                  }

                  Text {
                    text: root.prettyBytes(modelData.used) + " used · "
                      + root.prettyBytes(modelData.avail) + " free · "
                      + root.prettyBytes(modelData.total) + " total"
                    color: Style.menuInkDeep
                    font.pixelSize: root.fontPx(7)
                    font.family: root.uiFont
                    width: parent.width
                    elide: Text.ElideRight
                  }

                  Rectangle {
                    width: parent.width
                    height: 5
                    radius: 2
                    color: Qt.rgba(0, 0, 0, 0.2)
                    Rectangle {
                      width: parent.width * Math.max(0, Math.min(1, modelData.pct / 100))
                      height: parent.height
                      radius: parent.radius
                      color: quickStorageRoot.mountColor(modelData.pct)
                    }
                  }
                }

                MouseArea {
                  id: mma
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: Quickshell.execDetached(["xdg-open", modelData.mount])
                }
              }
            }

            Rectangle {
              width: storageCol.width
              height: 1
              color: Style.menuSep
              visible: (root.storageMounts || []).length > 0
            }

            RowLayout {
              width: storageCol.width
              spacing: 6
              Text {
                text: "HOME (~" + root.prettyBytes(root.storageHomeTotal) + ")"
                color: Style.menuInkDeep
                font.pixelSize: root.fontPx(8)
                font.family: root.uiFont
                font.letterSpacing: 1
                Layout.fillWidth: true
              }
              Text {
                visible: root.storageStatus === "scanning" && (root.storageHomeDirs || []).length === 0
                text: "sizing folders…"
                color: Style.menuInkDeep
                font.pixelSize: root.fontPx(7)
                font.family: root.uiFont
                opacity: 0.7
              }
            }

            Repeater {
              model: root.storageHomeDirs || []
              delegate: Rectangle {
                required property var modelData
                width: storageCol.width
                height: dirRow.implicitHeight + 8
                radius: 4
                color: dma.containsMouse ? Style.menuRowHi : "transparent"

                Column {
                  id: dirRow
                  x: 6
                  y: 4
                  width: parent.width - 12
                  spacing: 2

                  RowLayout {
                    width: parent.width
                    spacing: 6
                    Text {
                      text: modelData.name
                      color: Style.menuInk
                      font.pixelSize: root.fontPx(9)
                      font.family: root.uiFont
                      Layout.fillWidth: true
                      elide: Text.ElideRight
                    }
                    Text {
                      text: root.prettyBytes(modelData.bytes)
                      color: Style.menuSeal
                      font.pixelSize: root.fontPx(8)
                      font.family: root.uiFont
                      font.bold: true
                    }
                    Text {
                      text: modelData.pct + "%"
                      color: Style.menuInkDeep
                      font.pixelSize: root.fontPx(7)
                      font.family: root.uiFont
                      opacity: 0.75
                    }
                  }

                  Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.rgba(0, 0, 0, 0.2)
                    Rectangle {
                      width: parent.width * Math.max(0, Math.min(1, modelData.bar || 0))
                      height: parent.height
                      radius: parent.radius
                      color: Style.sapphire
                    }
                  }
                }

                MouseArea {
                  id: dma
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: Quickshell.execDetached(["xdg-open", modelData.path])
                }
              }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Rectangle {
          Layout.preferredWidth: 72
          height: 26
          radius: 6
          color: storageRefreshMa.containsMouse ? Style.menuRowHi : Style.menuControlBg
          border.color: Style.menuSep
          Text {
            anchors.centerIn: parent
            text: "󰑐  Refresh"
            color: Style.menuInk
            font.pixelSize: root.fontPx(9)
            font.family: root.uiFont
          }
          MouseArea {
            id: storageRefreshMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.scanStorage()
          }
        }
        Text {
          Layout.fillWidth: true
          text: "Click mount or folder to open in files"
          color: Style.menuInkDeep
          font.pixelSize: root.fontPx(7)
          font.family: root.uiFont
          opacity: 0.7
          elide: Text.ElideRight
        }
      }
    }
  } }
  Component { id: quickDefaultComp; Item {
    anchors.fill: parent
    Text { anchors.centerIn: parent; text: "select a quick tile"; color: Style.menuInkDeep; font.pixelSize: 10; font.family: root.uiFont }
  } }

  function quickDetailFor(key) {
    const k = (key === "dashboard" || key === "hub") ? "hub" : key
    switch (k) {
      case "hub": return quickHubComp
      case "wallpaper": return quickWallpaperComp
      case "screenshots": return quickScreenshotsComp
      case "media": return quickMediaComp
      case "network": return quickNetworkComp
      case "monitors": return quickMonitorsComp
      case "temp": return quickTempComp
      case "bluetooth": return quickBtComp
      case "storage": return quickStorageComp
      default: return quickDefaultComp
    }
  }

  readonly property string headerText: {
    const q = root.query.trim()
    if (root.categoryFilter !== "") return "› " + root.categoryFilter.toUpperCase()
    if (q.startsWith("=")) return "Calculator"
    if (q.startsWith("!")) return "Web Search"
    if (q.startsWith("@")) return "Documentation"
    if (q.startsWith(":")) return "Actions"
    if (root.fileTerm(q) !== null) return "File Search"
    if (root.dictTerm(q) !== null) return "Dictionary"
    return "LAUNCHER"
  }

  readonly property string resultText: {
    const c = root.resultCount
    const s = c !== 1 ? "s" : ""
    const qq = root.query.trim()
    if (root.fileTerm(qq) !== null) {
      if (root.fileStatus === "loading") return "Searching files..."
      if (root.fileStatus === "error") return "fd search failed"
      if (root.fileStatus === "prompt") return "Type after > to search ~"
      if (root.fileStatus === "no-results") return "No files found"
      const count = root.fileItems.length
      return count + (count === 200 ? "+" : "") + " match" + (count !== 1 ? "es" : "") + " · Enter opens"
    }
    if (root.dictTerm(qq) !== null) {
      if (root.dictStatus === "loading") return "Loading dict.cc"
      if (root.dictStatus === "error") return "dict.cc lookup failed"
      if (root.dictStatus === "prompt") return "Type after dict to translate"
      if (root.dictStatus === "no-results") return "No translations"
      const lang = root.dictCopyLang === "en" ? "English" : (root.dictCopyLang === "de" ? "German" : "translation")
      return c + " result" + s + " · Return copies " + lang
    }
    if (qq.startsWith(":")) return c + " action" + s
    if (qq.startsWith("=") || qq.startsWith("!") || qq.startsWith("@")) return c + " result" + s
    if (root.categoryFilter !== "") {
      if (root.quickMode) {
        const n = (root.quickTiles || []).length
        return n + " tiles · " + n + " total"
      }
      if (root.categoryFilter === "App") {
        const n = (DesktopEntries.applications.values || []).filter(d => !d.noDisplay).length
        return c + " match" + s + " · " + n + " total"
      }
      if (root.categoryFilter === "Actions") {
        const n = (root.quickActions || []).length
        return c + " action" + s + " · " + n + " total"
      }
      if (root.categoryFilter === "Websearch") {
        const n = (root.webEngines || []).length
        return c + " engine" + s + " · " + n + " total"
      }
      const n = (root.launcherItems || []).filter(x => x.category === root.categoryFilter).length
      return c + " match" + s + " · " + n + " total"
    }
    if (qq.length === 0) {
      const total = (root.launcherItems || []).length + (DesktopEntries.applications.values || []).length
      return c + " entries · " + total + " total"
    }
    return c + " match" + s
  }

  onResultCountChanged: {
    const max = Math.max(0, root.resultCount - 1)
    if (!root.quickMode && resultsList && (resultsList.currentIndex > max || resultsList.currentIndex < 0)) {
      resultsList.currentIndex = 0
    }
  }
  onDictVersionChanged: root.resetDictSelection()
  onFileVersionChanged: { root.resetFileSelection(); if (root.fileMode) Qt.callLater(root.updateFilePreview) }
  onDeVersionChanged: { if (resultsList) resultsList.currentIndex = 0; root.selectedIndex = 0 }
  onShouldShowChanged: {
    if (root.shouldShow) root.focusLauncherInput()
    else root.shotPreviewPath = ""
  }

  onCategoryFilterChanged: {
    if (resultsList) resultsList.currentIndex = 0
    root.selectedIndex = 0
    if (root.fileMode) root.scheduleFileLookup()
    else { root.fileItems=[]; root.fileStatus=""; root.filePreviewText=""; root.filePreviewMeta=""; root.pdfPreviewPath=""; root.pdfPreviewVersion=0 }
    if (root.categoryFilter === "Quick") {
      root.query = ""
      if (searchInput) searchInput.text = ""
      root.expandedQuickKey = ""
      Qt.callLater(function(){ if (root.scanShots) root.scanShots() })
    } else {
      root.expandedQuickKey = ""
    }
    if (root.categoryFilter === Data.fileCategory && (root.query || "").trim() === "") {
      root.query = ">"
      if (searchInput) searchInput.text = ">"
    }
    if (root.categoryFilter === "Actions" && !(root.query || "").trim().startsWith(":")) {
      root.query = ":"
      if (searchInput) searchInput.text = ":"
    }
    if (root.categoryFilter === "Websearch" && !(root.query || "").trim().startsWith("@")) {
      root.query = "@"
      if (searchInput) searchInput.text = "@"
    }
    if (root.shouldShow) root.focusLauncherInput()
  }

  function launchCurrent() {
    if (root.quickMode) {
      const t = (root.quickTiles || [])[root.selectedIndex]
      if (!t) return
      if (t.mode) root.expandQuick(t.key)
      else if (t.command && t.command.length) { Quickshell.execDetached(root.resolveCmd(t.command)); root.shouldShow = false }
      return
    }
    let entry = null
    if (resultsList && resultsList.currentItem && resultsList.currentItem.modelData) {
      entry = resultsList.currentItem.modelData
    } else if (filteredApps && filteredApps.values && resultsList.currentIndex < filteredApps.values.length) {
      entry = filteredApps.values[resultsList.currentIndex]
    }
    if (entry) root.launchApp(entry)
  }

  function focusLauncherInput() {
    Qt.callLater(function() {
      if (!root.quickMode && searchInput) searchInput.forceActiveFocus()
      else if (launcherBox) launcherBox.forceActiveFocus()
    })
  }

  function openLauncher() {
    const mon = Hyprland.focusedMonitor
    launcherScreen = mon
      ? (Quickshell.screens.find(s => s.name === mon.name) ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null))
      : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    launcherWorkspaceId = Hyprland.focusedWorkspace?.id ?? 1
    shouldShow = true
    root.categoryFilter = ""
    root.expandedQuickKey = ""
    if (searchInput) searchInput.text = ""
    else root.query = ""
    if (resultsList) resultsList.currentIndex = 0
    root.focusLauncherInput()
  }

  function openFileSearch(term) {
    if (!root.shouldShow) root.openLauncher()
    const q = ">" + (term || "")
    root.query = q
    if (searchInput) searchInput.text = q
    root.focusLauncherInput()
  }

  function openCategory(cat) {
    if (!root.shouldShow) root.openLauncher()
    root.categoryFilter = cat || ""
    root.query = root.categoryFilter === Data.fileCategory ? ">"
      : (root.categoryFilter === "Actions" ? ":"
        : (root.categoryFilter === "Websearch" ? "@" : ""))
    if (searchInput) searchInput.text = root.query
    root.selectedIndex = 0
    root.expandedQuickKey = ""
    root.focusLauncherInput()
  }

  function openQuick(key) {
    if (!root.shouldShow) root.openLauncher()
    root.categoryFilter = "Quick"
    root.query = ""
    if (searchInput) searchInput.text = ""
    const k = key === "dashboard" ? "hub" : (key || "hub")
    root.expandedQuickKey = k
    const idx = (root.quickTiles || []).findIndex(function(t) { return t.mode === k || t.key === k })
    root.selectedIndex = Math.max(0, idx)
  }

  function closeLauncher() {
    shouldShow = false
  }

  // Register for direct Hyprland global shortcut (more reliable than spawning `qs ipc` each time).
  // Bound in hypr/conf.d/bindings.lua as hl.dsp.global("quickshell:launcher-toggle")
  GlobalShortcut {
    appid: "quickshell"
    name: "launcher-toggle"
    description: "Toggle launcher"
    onPressed: root.shouldShow ? root.closeLauncher() : root.openLauncher()
  }

  function shQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
  }

  function luaQuote(s) {
    return JSON.stringify(String(s))
  }

  function appKey(entry) {
    return String(entry?.id || entry?.name || entry?.execString || "")
  }

  function appScore(entry) {
    root.appUsageVersion
    return root.appUsage[root.appKey(entry)] || 0
  }

  function bumpAppUsage(entry) {
    const key = root.appKey(entry)
    if (!key) return
    const next = Object.assign({}, root.appUsage)
    next[key] = (next[key] || 0) + 1
    root.appUsage = next
    root.appUsageVersion++
  }

  function expandQuick(key) {
    const k = (key === "dashboard" || key === "hub") ? "hub" : key
    if (!root.quickMode) { root.categoryFilter = "Quick"; root.query = ""; if (searchInput) searchInput.text = "" }
    root.expandedQuickKey = (root.expandedQuickKey === k ? "" : k)
    if (root.expandedQuickKey === "screenshots" || root.expandedQuickKey === "hub") root.scanShots()
    if (root.expandedQuickKey === "storage") root.scanStorage()
  }

  function resolveCmd(c) {
    if (!c || c.length === 0) return c
    const first = c[0]
    if (typeof first === "string" && first.indexOf("asahi-") === 0 && first.indexOf("/") < 0) {
      return [root.binDir + "/" + first].concat(c.slice(1))
    }
    return c
  }

  function resolveIconUrl(raw) {
    if (!raw) return ""
    const icon = String(raw)
    if (icon.startsWith("file://")) return icon
    if (icon.charAt(0) === "/") return "file://" + icon
    if (icon.indexOf(".") >= 0 && icon.indexOf("/") >= 0) return icon
    return Quickshell.iconPath(icon, "")
  }

  function actionMatches(action, term) {
    if (!term) return true
    const values = [action.key, action.name].concat(action.aliases || [])
    return values.some(v => String(v || "").toLowerCase().includes(term))
  }

  function getActionResults(q) {
    const value = (q || "").trim()
    if (!value.startsWith(":")) return null
    const term = value.substring(1).trim().toLowerCase()
    const actions = root.quickActions.filter(a => root.actionMatches(a, term))
    if (actions.length === 0) {
      return [{ id: "action-empty", name: "No action found", comment: term, glyph: "󰅙", special: "noop" }]
    }
    return actions.map(a => ({
      id: "action-" + a.key,
      name: a.name,
      comment: a.comment || "",
      glyph: a.icon,
      special: "action",
      mode: a.mode || "",
      command: a.command || []
    }))
  }

  function launchDesktopEntry(entry) {
    root.bumpAppUsage(entry)
    const command = Array.from(entry.command || [])
    const exec = command.length > 0 ? command.map(root.shQuote).join(" ") : String(entry.execString || "")
    if (exec === "") {
      entry.execute()
      return
    }

    const ws = root.launcherWorkspaceId || Hyprland.focusedWorkspace?.id || 1
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + ws + " })"])
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd(" + root.luaQuote("[workspace " + ws + "] " + exec) + ")"])
  }

  function launchApp(entry) {
    if (!entry) { shouldShow = false; return }
    if (entry.isCategory || entry.target) {
      // Drill into category overview (launcher style) or quick action target
      const tgt = entry.target || entry.category || ""
      if (tgt) {
        root.categoryFilter = tgt
        root.query = tgt === Data.fileCategory ? ">"
          : (tgt === "Actions" ? ":"
            : (tgt === "Websearch" ? "@" : ""))
        if (searchInput) searchInput.text = root.query
        root.selectedIndex = 0
        root.expandedQuickKey = ""
        if (tgt === Data.fileCategory) root.scheduleFileLookup()
        return
      }
    }
    if (entry.special === "noop") {
      return
    } else if (entry.special === "calc") {
      const res = entry.result || ""
      if (res) Quickshell.execDetached(["bash", "-c", "echo -n '" + res.replace(/'/g, "'\\''") + "' | wl-copy"])
    } else if (entry.special === "dict") {
      const copy = entry.copy || ""
      if (copy) Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", copy])
    } else if (entry.special === "file" && entry.path) {
      Quickshell.execDetached(["xdg-open", entry.path])
    } else if (entry.special === "action") {
      if (entry.mode) {
        root.categoryFilter = "Quick"
        root.query = ""
        if (searchInput) searchInput.text = ""
        root.expandQuick(entry.mode)
        return
      } else if (entry.command && entry.command.length > 0) {
        Quickshell.execDetached(root.resolveCmd(entry.command))
        root.shouldShow = false
      }
    } else if ((entry.special === "web" || entry.special === "doc") && entry.url) {
      if (entry.prefix) {
        // selected engine from @ fuzzy list: autofill shortcut like "jaxdoc " so user types the term at _
        root.query = "@" + entry.prefix + " "
        if (searchInput) searchInput.text = root.query
        root.selectedIndex = 0
        return // keep open for term input
      }
      let u = entry.url
      if (u.includes("%TERM%")) u = u.replace("%TERM%", "")
      u = u.replace(/\?q=$/, "").replace(/\?s=$/, "").replace(/&text=$/, "").replace(/search\?q=$/, "")
      Quickshell.execDetached(["xdg-open", u])
    } else if (entry.special === "app" && entry.raw) {
      shouldShow = false
      Qt.callLater(() => root.launchDesktopEntry(entry.raw))
      return
    } else if (entry.execute) {
      shouldShow = false
      Qt.callLater(() => root.launchDesktopEntry(entry))
      return
    } else if (entry.command && entry.command.length > 0) {
      Quickshell.execDetached(entry.command)
    } else if (entry.exec) {
      if (entry.exec.indexOf("asahi-") === 0 && entry.exec.indexOf(" ") < 0) {
        Quickshell.execDetached([root.binDir + "/" + entry.exec])
      } else {
        Quickshell.execDetached(["sh", "-c", entry.exec])
      }
    }
    shouldShow = false
  }

  function dictTerm(q) {
    const value = (q || "").trim()
    const m = value.match(/^dict(?:\s+(.*))?$/i)
    return m ? (m[1] || "").trim() : null
  }

  function fileTerm(q) {
    const value = (q || "").trim()
    return value.startsWith(">") ? value.substring(1).trim() : null
  }

  function isPrefixSpecial(q) {
    const t = (q || "").trim()
    if (!t) return false
    if (t.startsWith(">") || t.startsWith("@") || t.startsWith(":") || t.startsWith("=") || t.startsWith("!")) return true
    return root.dictTerm(t) !== null
  }

  function resetFileSelection() {
    if (!resultsList || fileTerm(root.query) === null) return
    resultsList.currentIndex = 0
    resultsList.positionViewAtBeginning()
  }

  function scheduleFileLookup() {
    const term = fileTerm(root.query)
    fileDebounce.stop()
    if (term === null) {
      root.filePendingTerm = ""
      root.fileStatus = ""
      root.fileItems = []
      root.fileVersion++
      return
    }
    root.filePendingTerm = term
    if (!term) {
      root.fileStatus = "prompt"
      root.fileItems = []
      root.fileVersion++
      return
    }
    root.fileStatus = "loading"
    root.fileVersion++
    fileDebounce.restart()
  }

  function startFileLookup() {
    const term = root.filePendingTerm
    if (!term || fileProc.running) return
    root.fileRunningTerm = term
    root.fileStatus = "loading"
    root.fileVersion++
    fileProc.command = [
      "fd",
      "--type", "f",
      "--type", "d",
      "--max-results", "200",
      "--absolute-path",
      "--color", "never",
      "--fixed-strings",
      "--", term, Quickshell.env("HOME")
    ]
    fileProc.running = true
  }

  function finishFileLookup(exitCode, stdoutText, stderrText) {
    const term = root.fileRunningTerm
    if (term === root.filePendingTerm && term === fileTerm(root.query)) {
      if (exitCode !== 0) {
        root.fileStatus = "error"
        root.fileItems = [{
          id: "file-error",
          name: "File search failed",
          comment: stderrText.trim() || ("fd exited " + exitCode),
          icon: "",
          glyph: "󰅙",
          special: "noop"
        }]
      } else {
        const paths = stdoutText.split("\n").filter(line => line.length > 0)
        root.fileItems = root.sortFileResults(paths.map(root.formatFileResult), term)
        root.fileStatus = root.fileItems.length > 0 ? "ready" : "no-results"
      }
      root.fileVersion++
    }
    if (root.filePendingTerm && root.filePendingTerm !== term) fileDebounce.restart()
  }

  function getFileResults(q) {
    const term = fileTerm(q)
    if (term === null) return null
    if (!term) {
      return [{ id: "file-prompt", name: "Search files and folders", comment: "Type > followed by a filename", icon: "", glyph: "󰍉", special: "noop" }]
    }
    if (root.fileStatus === "loading") {
      return [{ id: "file-loading", name: "Searching " + term, comment: "Searching ~ with fd", icon: "", glyph: "󰍉", special: "noop" }]
    }
    if (root.fileStatus === "error") return root.fileItems
    if (root.fileItems.length === 0) {
      return [{ id: "file-empty", name: "No files found", comment: term, icon: "", glyph: "󰍉", special: "noop" }]
    }
    return root.fileItems
  }

  function formatFileResult(rawPath) {
    const isDirectory = rawPath.length > 1 && rawPath.endsWith("/")
    const path = isDirectory ? rawPath.substring(0, rawPath.length - 1) : rawPath
    const parts = path.split("/")
    const name = parts.pop() || path
    const parent = parts.join("/") || "/"
    return {
      id: "file-" + path,
      name: name,
      comment: root.displayFilePath(parent),
      accessory: isDirectory ? "DIR" : "",
      icon: "",
      glyph: root.fileGlyph(name, isDirectory),
      special: "file",
      path: path,
      isDirectory: isDirectory
    }
  }

  function displayFilePath(path) {
    const home = Quickshell.env("HOME")
    if (path === home) return "~"
    return path.startsWith(home + "/") ? "~" + path.substring(home.length) : path
  }

  function sortFileResults(items, term) {
    const query = term.toLowerCase()
    return items.sort((a, b) => {
      const ar = root.fileRank(a.name.toLowerCase(), query)
      const br = root.fileRank(b.name.toLowerCase(), query)
      if (ar !== br) return ar - br
      if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1
      if (a.name.toLowerCase() !== b.name.toLowerCase()) return a.name.toLowerCase().localeCompare(b.name.toLowerCase())
      return a.path.length - b.path.length
    })
  }

  function fileRank(name, query) {
    if (name === query) return 0
    if (name.startsWith(query)) return 1
    if (name.includes(query)) return 2
    return 3
  }

  function fileGlyph(name, isDirectory) {
    if (isDirectory) return Data.fileIcons.dir || "󰉋"
    const ext = name.includes(".") ? name.split(".").pop().toLowerCase() : ""
    return Data.fileIcons[ext] || Data.fileIcons.file || "󰈔"
  }

  Timer {
    id: fileDebounce
    interval: 250
    onTriggered: root.startFileLookup()
  }

  Process {
    id: fileProc
    stdout: StdioCollector { id: fileStdout }
    stderr: StdioCollector { id: fileStderr }
    onExited: code => root.finishFileLookup(code, fileStdout.text, fileStderr.text)
  }

  function resetDictSelection() {
    if (!resultsList || dictTerm(root.query) === null) return
    resultsList.currentIndex = 0
    resultsList.positionViewAtBeginning()
  }

  function scheduleDictLookup() {
    const term = dictTerm(root.query)
    dictDebounce.stop()
    if (term === null) {
      root.dictPendingTerm = ""
      root.dictStatus = ""
      root.dictCopyLang = ""
      root.dictError = ""
      root.dictItems = []
      root.dictVersion++
      return
    }
    root.dictPendingTerm = term
    if (!term) {
      root.dictStatus = "prompt"
      root.dictCopyLang = ""
      root.dictError = ""
      root.dictItems = []
      root.dictVersion++
      return
    }
    root.dictStatus = "loading"
    root.dictCopyLang = ""
    root.dictError = ""
    root.dictItems = []
    root.dictVersion++
    dictDebounce.restart()
  }

  function startDictLookup() {
    const term = root.dictPendingTerm
    if (!term || dictProc.running) return
    root.dictRunningTerm = term
    root.dictStatus = "loading"
    root.dictVersion++
    dictProc.running = true
  }

  function finishDictLookup(text) {
    const term = root.dictRunningTerm
    if (term === root.dictPendingTerm && term === dictTerm(root.query)) {
      try {
        const data = JSON.parse((text || "").trim())
        root.dictStatus = data.status || "error"
        root.dictCopyLang = data.copyLang || ""
        root.dictError = data.error || ""
        root.dictItems = data.items || []
      } catch (_) {
        root.dictStatus = "error"
        root.dictCopyLang = ""
        root.dictError = "Invalid lookup response"
        root.dictItems = []
      }
      root.dictVersion++
    }
    if (root.dictPendingTerm && root.dictPendingTerm !== term) dictDebounce.restart()
  }

  function formatDictMeta(meta) {
    if (!meta || typeof meta !== "object") return ""
    const join = parts => (parts || []).filter(Boolean).join(", ")
    return [
      join(meta.abbreviations),
      join(meta.wordClassDefinitions),
      join(meta.comments),
      join(meta.optionalData)
    ].filter(s => s.length > 0).join(" · ")
  }

  function getDictResults(q) {
    const term = dictTerm(q)
    if (term === null) return null
    if (!term) {
      return [{
        id: "dict-prompt",
        name: "Translate with dict.cc",
        comment: "Type dict followed by a word · en de Term for language override",
        icon: root.dictIcon,
        special: "noop"
      }]
    }
    if (root.dictStatus === "loading") {
      return [{ id: "dict-loading", name: "Looking up " + term, comment: "dict.cc DE↔EN", icon: root.dictIcon, special: "noop" }]
    }
    if (root.dictStatus === "error") {
      return [{
        id: "dict-error",
        name: "dict.cc lookup failed",
        comment: root.dictError || "Network or parser error",
        icon: root.dictIcon,
        special: "noop"
      }]
    }
    if (root.dictStatus === "no-results" || root.dictItems.length === 0) {
      return [{ id: "dict-empty", name: "No dict.cc results", comment: term, icon: root.dictIcon, special: "noop" }]
    }
    return root.dictItems.map((it, i) => {
      const metaLine = root.formatDictMeta(it.meta)
      return {
        id: "dict-" + i,
        name: it.target || it.copy || "",
        comment: (it.source || "") + (metaLine ? " · " + metaLine : ""),
        accessory: (it.copyLang || root.dictCopyLang || "").toUpperCase(),
        icon: root.dictIcon,
        special: "dict",
        copy: it.copy || it.target || ""
      }
    })
  }

  Timer {
    id: dictDebounce
    interval: 250
    onTriggered: root.startDictLookup()
  }

  Process {
    id: dictProc
    command: ["uv", "run", "python", root.binDir + "/asahi-dictcc.py", root.dictRunningTerm]
    stdout: StdioCollector { id: dictStdout }
    onExited: () => root.finishDictLookup(dictStdout.text)
  }

  // websearch: @ uses engines[] (fuzzy lists + prefix direct). ! passes the literal text to Kagi via defaultSearchUrl.
  // Icons prepared exactly like dictIcon so they render in the launcher results list.
  property var webEngines: [
    { name: "Kagi", prefix: "kagi", url: "https://kagi.com/search?q=%TERM%", icon: root.webIconBase + "kagi.png" },
    { name: "Jax Documentation", prefix: "jaxdoc", url: "https://docs.jax.dev/en/latest/search.html?q=%TERM%", icon: root.webIconBase + "jax.png" },
    { name: "Flax Documentation", prefix: "flaxdoc", url: "https://flax.readthedocs.io/en/stable/search.html?q=%TERM%", icon: root.webIconBase + "flax.png" },
    { name: "dict.cc", prefix: "dcc", url: "https://www.dict.cc/?s=%TERM%", icon: root.webIconBase + "dict-cc.png" },
    { name: "NumPy Documentation", prefix: "npdoc", url: "https://numpy.org/doc/stable/search.html?q=%TERM%", icon: root.webIconBase + "numpy.png" },
    { name: "Kagi Translate", prefix: "kt", url: "https://translate.kagi.com/?from=auto&to=en_us&text=%TERM%", icon: root.webIconBase + "kagi.png" },
    { name: "PyTorch Documentation", prefix: "ptdoc", url: "https://docs.pytorch.org/docs/stable/search.html?q=%TERM%", icon: root.webIconBase + "pytorch.png" },
    { name: "Optax Documentation", prefix: "optax", url: "https://optax.readthedocs.io/en/latest/search.html?q=%TERM%", icon: root.webIconBase + "optax.png" },
    { name: "Grokipedia", prefix: "grokip", url: "https://grokipedia.com/search?q=%TERM%", icon: root.webIconBase + "grokipedia.png" }
  ]
  property string defaultSearchUrl: "https://kagi.com/search?q=%s"

  // Robust loading of websearch engines + icons from json (better than XHR).
  // Edit the json to add/remove engines; put matching PNGs in assets/.
  // Icons resolved at load time using the same base as dictIcon.
  FileView {
    id: websearchConfig
    path: root.websearchJsonPath
    watchChanges: true
    onLoaded: root.parseWebsearchConfig(text)
    onTextChanged: if (root) root.parseWebsearchConfig(text)
  }

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() { root.deVersion++ }
  }

  function calculate(expr) {
    expr = (expr || "").trim()
    if (!expr) return null
    try {
      let e = expr.replace(/π/g, "Math.PI").replace(/pi/gi, "Math.PI")
      e = e.replace(/e\b/g, "Math.E")
      e = e.replace(/sqrt\(/gi, "Math.sqrt(")
      e = e.replace(/\^/g, "**")
      const val = eval(e)
      if (typeof val === "number" && isFinite(val)) {
        return Number.isInteger(val) ? val.toString() : parseFloat(val.toFixed(8)).toString()
      }
      return null
    } catch (_) { return null }
  }

  function parseWebsearchConfig(text) {
    try {
      const body = (text || "").trim()
      if (!body) return
      var data = JSON.parse(body)
      if (data.engines && data.engines.length > 0) {
        var base = root.webIconBase
        webEngines = data.engines.map(function(e) {
          var ic = e.icon || ""
          var iconPath = ic
          if (ic && ic.indexOf(".") > 0 && !ic.startsWith("file://")) {
            iconPath = base + ic
          }
          var r = { name: e.name, prefix: e.prefix, url: e.url, icon: iconPath }
          if (e.description) r.description = e.description
          return r
        })
      }
      if (data.defaultSearchUrl) defaultSearchUrl = data.defaultSearchUrl
      webVersion++
    } catch (e) {
      webVersion++
    }
  }

  function getSpecialResults(qq) {
    const q = (qq || "").trim()
    if (!q) return null
    const actionResults = getActionResults(q)
    if (actionResults) return actionResults
    const fileResults = getFileResults(q)
    if (fileResults) return fileResults
    const dictResults = getDictResults(q)
    if (dictResults) return dictResults
    if (q.startsWith("=")) {
      const res = calculate(q.substring(1))
      if (res !== null) {
        return [{ id: "calc-" + res, name: "= " + res, comment: "Calculator — Enter to copy", icon: "󰃀", special: "calc", result: res }]
      }
      return null
    }
    if (q.startsWith("!")) {
      // Literal pass-through to Kagi (defaultSearchUrl). Whatever you type after ! is sent as the query string.
      const t = q.trim()
      if (t) {
        const tpl = root.defaultSearchUrl
        return [{
          id: "web",
          name: t,
          comment: "Kagi — Enter to search",
          icon: "󰖟",
          special: "web",
          url: tpl.replace("%s", encodeURIComponent(t))
        }]
      }
      return null
    }
    if (q.startsWith("@")) {
      const after = q.substring(1).trim()
      const la = after.toLowerCase()

      const engines = root.webEngines.length > 0 ? root.webEngines : [{
        name: "Kagi", prefix: "kagi", url: "https://kagi.com/search?q=%TERM%", icon: root.webIconBase + "kagi.png"
      }]

      // tiny subsequence fuzzy (for suggestion lists when typing partial @)
      const fuzzy = (hay, ned) => {
        if (!ned) return true
        hay = hay.toLowerCase(); ned = ned.toLowerCase()
        let i = 0
        for (const c of hay) { if (c === ned[i]) i++; if (i === ned.length) return true }
        return false
      }

      // exact prefix match for direct search (e.g. @ptdoc hello → PyTorch docs with the term)
      for (const e of engines) {
        const p = e.prefix
        if (la === p || la.startsWith(p + " ")) {
          let raw = after.substring(p.length).trim()
          const term = raw.replace(/^["'\s]+|["'\s]+$/g, "")
          let u = e.url
          if (term) u = u.replace("%TERM%", encodeURIComponent(term))
          else u = u.replace("%TERM%", "").replace(/\?q=$/, "").replace(/\?s=$/, "").replace(/&text=$/, "").replace(/search\?q=$/, "")
          return [{
            id: "doc-" + p,
            name: e.name + (term ? " — " + term : ""),
            comment: "Docs search — Enter to open",
            icon: e.icon,
            special: "doc",
            url: u
          }]
        }
      }

      // fuzzy list (matches prefix or name via subsequence) for @partial
      const f = engines.filter(e => fuzzy(e.prefix, la) || fuzzy(e.name, la) || la === "")
      if (f.length > 0) {
        return f.map(e => ({
          id: "doclist-" + e.prefix,
          name: e.name,
          comment: e.description || ("@" + e.prefix + " — select to search"),
          icon: e.icon,
          special: "doc",
          url: e.url.replace("%TERM%", ""),
          prefix: e.prefix
        }))
      }

      // fallback
      const t = after || ""
      const u = root.defaultSearchUrl.replace("%s", encodeURIComponent(t))
      return [{ id: "docdef", name: "Kagi — " + t, comment: "Enter to search", icon: "󰖟", special: "doc", url: u }]
    }
    return null
  }

  function handleEscape() {
    if (root.shotPreviewPath !== "") {
      root.shotPreviewPath = ""
      return
    }
    if (root.quickDetailActive) {
      root.expandedQuickKey = ""
      root.focusLauncherInput()
      return
    }
    if (root.quickMode || root.categoryFilter !== "") {
      root.categoryFilter = ""
      root.query = ""
      root.selectedIndex = 0
      root.expandedQuickKey = ""
      if (searchInput) searchInput.text = ""
      root.focusLauncherInput()
      return
    }
    root.shouldShow = false
  }

  // ---------- Launcher port: scoring + category overview (following bjarneo launcher ref style) ----------
  function goUp() {
    if (root.quickDetailActive) {
      root.expandedQuickKey = ""
      return true
    }
    if (root.categoryFilter !== "") {
      root.categoryFilter = ""
      root.query = ""
      root.selectedIndex = 0
      root.expandedQuickKey = ""
      if (searchInput) searchInput.text = ""
      return true
    }
    return false
  }

  function actionSearchTerm() {
    let t = (root.query || "").trim()
    if (t.startsWith(":")) t = t.substring(1).trim()
    return t.toLowerCase()
  }

  function mapActionEntry(a) {
    return {
      id: "action-" + a.key,
      title: a.name,
      comment: a.comment || "",
      glyph: a.icon,
      category: "Actions",
      special: "action",
      mode: a.mode || "",
      command: a.command || [],
      _t: (a.name || "").toLowerCase(),
      _k: ((a.key || "") + " " + (a.aliases || []).join(" ")).toLowerCase(),
      _c: "actions"
    }
  }

  function mapWebEntry(e) {
    const icon = e.icon || (root.webIconBase + "kagi.png")
    return {
      id: "web-" + e.prefix,
      title: e.name,
      comment: e.description || ("Search with @" + e.prefix),
      icon: icon,
      category: "Websearch",
      special: "doc",
      url: e.url,
      prefix: e.prefix,
      _t: (e.name || "").toLowerCase(),
      _k: ((e.prefix || "") + " " + (e.description || "")).toLowerCase(),
      _c: "websearch"
    }
  }

  function primaryScore(item, tokens) {
    const title = item._t || ""
    let total = 0
    for (let i = 0; i < tokens.length; i++) {
      const t = tokens[i]
      if (title.indexOf(t) === 0) total += root.scPrefix
      else if (title.indexOf(t) >= 0) total += root.scTitle
    }
    return total
  }

  function scoreItem(item, tokens) {
    const title = item._t || ""
    const kw = item._k || ""
    const cat = item._c || ""
    let total = 0
    for (let i = 0; i < tokens.length; i++) {
      const t = tokens[i]
      let sub = 0
      if (title.indexOf(t) === 0) sub += root.scPrefix
      else if (title.indexOf(t) >= 0) sub += root.scTitle
      if (kw.indexOf(t) >= 0) sub += root.scKw
      if (cat.indexOf(t) >= 0) sub += root.scCat
      if (sub === 0) return 0
      total += sub
    }
    return total
  }

  readonly property var queryTokens: {
    const q = (root.query || "").trim().toLowerCase()
    return q.length === 0 ? [] : q.split(/\s+/)
  }

  readonly property var navRows: Data.categoryNav

  function computeFiltered() {
    root.deVersion; root.dictVersion; root.fileVersion; root.webVersion; root.appUsageVersion

    const tokens = root.queryTokens
    const filter = root.categoryFilter

    // Prefix specials still win (calc/web/@/dict/>/: ) for muscle memory + power
    const specials = root.getSpecialResults(root.query)
    if (specials && specials.length > 0) return specials

    if (filter === "Actions") {
      const term = root.actionSearchTerm()
      const acts = (root.quickActions || []).filter(a => root.actionMatches(a, term))
      const out = acts.map(a => root.mapActionEntry(a))
      return out.length <= root.maxResults ? out : out.slice(0, root.maxResults)
    }
    if (filter === "Websearch") {
      const after = (root.query || "").trim()
      const la = after.startsWith("@") ? after.substring(1).trim().toLowerCase() : after.toLowerCase()
      const engines = root.webEngines.length > 0 ? root.webEngines : [{
        name: "Kagi", prefix: "kagi", url: "https://kagi.com/search?q=%TERM%",
        icon: root.webIconBase + "kagi.png", description: "Web search"
      }]
      const webs = engines.filter(e => {
        if (!la) return true
        const p = (e.prefix || "").toLowerCase()
        const n = (e.name || "").toLowerCase()
        return p.indexOf(la) >= 0 || n.indexOf(la) >= 0 || p.startsWith(la) || n.startsWith(la)
      }).map(e => root.mapWebEntry(e))
      return webs.length <= root.maxResults ? webs : webs.slice(0, root.maxResults)
    }

    if (root.quickMode) return []
    let pool = []
    if (filter !== "" && filter !== "Quick") {
      pool = (root.launcherItems || []).filter(it => it.category === filter)
    } else {
      pool = (root.navRows || []).concat(root.launcherItems || [])
    }

    // desktops ONLY for root search (tokens>0 && no drill or App) + App drill (per review)
    if ((tokens.length > 0 && (filter === "" || filter === "App")) || filter === "App") {
      const vals = DesktopEntries.applications.values || []
      for (let i = 0; i < vals.length; i++) {
        const a = vals[i]
        if (a.noDisplay) continue
        const t = String(a.name || "").toLowerCase()
        const k = String((a.genericName || "") + " " + (a.comment || "")).toLowerCase()
        const aid = "app-" + (a.id || a.name || i)
        pool.push({
          id: aid, title: a.name, accessory: "APP",
          _t: t, _k: k, _c: "app", category: "App", icon: "󰀻", rawIcon: a.icon || "", special: "app", raw: a
        })
      }
    }

    // Empty query: for App drill use limited usage tail (no flood); for other drills use pool; root: nav only
    if (tokens.length === 0) {
      if (filter !== "" && filter !== "Quick") {
        if (filter === "App") {
          const tail = []
          let allApps = (DesktopEntries.applications.values || []).filter(d => !d.noDisplay)
          allApps = allApps.sort((a, b) => {
            const au = root.appScore(a); const bu = root.appScore(b)
            if (au !== bu) return bu - au
            return (a.name || "").localeCompare(b.name || "")
          })
          for (let i = 0; i < allApps.length && tail.length < 20; i++) {
            const a = allApps[i]
            tail.push({
              id: "app-" + (a.id || a.name), title: a.name, accessory: "APP",
              icon: "󰀻", rawIcon: a.icon || "",
              category: "App", special: "app", raw: a
            })
          }
          return tail.length <= root.maxResults ? tail : tail.slice(0, root.maxResults)
        }
        return pool.length <= root.maxResults ? pool : pool.slice(0, root.maxResults)
      }
      // Overview root empty: categories only (no apps shown by default)
      const out = root.navRows
      return out.length <= root.maxResults ? out : out.slice(0, root.maxResults)
    }

    const scored = []
    for (let i = 0; i < pool.length; i++) {
      const it = pool[i]
      const s = root.scoreItem(it, tokens)
      if (s > 0) scored.push({ s: s, p: root.primaryScore(it, tokens), item: it })
    }
    scored.sort((a, b) => {
      if (b.p !== a.p) return b.p - a.p
      const aCat = a.item.isCategory ? 0 : 1
      const bCat = b.item.isCategory ? 0 : 1
      if (aCat !== bCat) return aCat - bCat
      if (b.s !== a.s) return b.s - a.s
      return (a.item.title || "").localeCompare(b.item.title || "")
    })
    const lim = Math.min(scored.length, root.maxResults)
    const out = []
    for (let j = 0; j < lim; j++) out.push(scored[j].item)
    return out
  }

  function isImageFile(p) {
    if (!p) return false
    const e = Data.fileExt(p)
    return Data.imageExts.indexOf(e) >= 0
  }
  function isTextFile(p) {
    if (!p) return false
    const e = Data.fileExt(p)
    return Data.textExts.indexOf(e) >= 0
  }

  function isPdfFile(p) {
    if (!p) return false
    const e = Data.fileExt(p)
    return e === "pdf"
  }

  property string filePreviewText: ""
  property string filePreviewMeta: ""
  property string pdfPreviewPath: ""
  property int pdfPreviewVersion: 0

  function updateFilePreview() {
    if (!root.fileMode) { root.filePreviewText = ""; root.filePreviewMeta = ""; root.pdfPreviewPath = ""; root.pdfPreviewVersion=0; return }
    const it = resultsList.currentItem ? resultsList.currentItem.modelData : null
    const p = it && it.path ? it.path : ""
    if (!p) { root.filePreviewText = ""; root.filePreviewMeta = ""; root.pdfPreviewPath = ""; root.pdfPreviewVersion=0; return }
    if (root.isImageFile(p)) { root.filePreviewText = ""; root.filePreviewMeta = ""; root.pdfPreviewPath = ""; root.pdfPreviewVersion=0; return }
    if (root.isTextFile(p)) {
      // fire head for preview text (reuse style from file logic)
      root.filePreviewMeta = ""
      root.pdfPreviewPath = ""
      root.pdfPreviewVersion = 0
      headProc.command = ["head", "-c", "2048", p]
      headProc.running = true
      return
    }
    if (root.isPdfFile(p)) {
      root.filePreviewText = ""
      root.filePreviewMeta = "PDF preview..."
      root.pdfPreviewVersion = 0
      root.pdfPreviewPath = ""
      const base = "/tmp/launcher-pdf-" + (p ? Qt.md5(p) : Date.now())
      pdfProc.command = ["pdftoppm", "-png", "-f", "1", "-l", "1", "-r", "100", "-singlefile", p, base]
      pdfProc.running = true
      // on success, pdfProc onExited sets pdfPreviewPath and bumps version
      return
    }
    // meta
    root.filePreviewText = ""
    root.pdfPreviewPath = ""
    root.pdfPreviewVersion = 0
    metaProc.command = ["sh", "-c", "stat -c 'SIZE %s B  MTIME %y' \"$1\" 2>/dev/null; printf 'MIME '; file -b --mime-type \"$1\" 2>/dev/null", "sh", p]
    metaProc.running = true
  }

  Process {
    id: headProc
    stdout: StdioCollector { id: headOut }
    onExited: code => {
      if (code === 0) root.filePreviewText = (headOut.text || "").replace(/\0/g, "")
    }
  }
  Process {
    id: metaProc
    stdout: StdioCollector { id: metaOut }
    onExited: code => {
      if (code === 0) root.filePreviewMeta = (metaOut.text || "").trim()
    }
  }

  Process {
    id: pdfProc
    onExited: code => {
      if (code !== 0) {
        root.filePreviewMeta = "PDF preview failed (need pdftoppm?)"
        root.pdfPreviewPath = ""
      } else {
        // file now exists; set path to trigger Image load (no pre-load cannot-open)
        const base = (pdfProc.command && pdfProc.command.length > 1) ? pdfProc.command[pdfProc.command.length-1] : ""
        if (base) root.pdfPreviewPath = "file://" + base + ".png"
        root.filePreviewMeta = ""
        root.pdfPreviewVersion = (root.pdfPreviewVersion || 0) + 1
      }
    }
  }

  // call preview update on selection for files
  Connections {
    target: resultsList
    function onCurrentIndexChanged() { if (root.fileMode) root.updateFilePreview() }
  }

  ScriptModel {
    id: filteredApps
    objectProp: "id"
    values: {
      root.deVersion
      root.dictVersion
      root.fileVersion
      root.webVersion
      root.appUsageVersion
      root.categoryFilter
      root.query
      return root.computeFiltered()
    }
  }

  PanelWindow {
    id: launcherPanel
    visible: root.shouldShow
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-launcher"
    exclusionMode: ExclusionMode.Ignore

    screen: root.launcherScreen

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    Menu.MenuBackdrop {
      reveal: root.shouldShow ? 1 : 0
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.shouldShow = false
    }

    Menu.MenuCard {
      id: launcherBox
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height * 0.18
      width: root.sideActive ? 980 : 680
      Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
      height: Math.min(launcherCol.implicitHeight + 34, parent.height * 0.72)
      cardMargin: 17
      focus: true
      activeFocusOnTab: true
      Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
          root.handleEscape()
          event.accepted = true
        }
      }

      Column {
        id: launcherCol
        width: parent.width - 34
        spacing: 12

        Menu.MenuHeader {
          width: parent.width
          fontFamily: root.uiFont
          title: "LAUNCHER"
          subtitle: root.headerText.toUpperCase() + "  ·  " + root.resultText.toUpperCase()
        }

        Menu.MenuDivider { width: parent.width }

        // search hidden in quickMode (bjarneo: no search bar; grid+side is the view;
        // prevents typing pollution of query/cat/schedules while grid+side shown)
        Item {
          width: parent.width
          height: root.quickMode ? 0 : 36
          visible: !root.quickMode
          clip: true

          Text {
            id: searchPrompt
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍉"
            color: searchInput.activeFocus ? Style.menuSeal : Style.menuInkDeep
            font.family: root.uiFont
            font.pixelSize: 16
            Behavior on color { ColorAnimation { duration: 120 } }
          }

          TextInput {
            id: searchInput
            anchors.left: searchPrompt.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: text.length > 0 ? Style.menuInk : Style.menuInkDeep
            opacity: text.length > 0 ? 1 : 0.55
            font.family: root.uiFont
            font.pixelSize: 14
            font.letterSpacing: 1
            clip: true
            focus: true
            Accessible.role: Accessible.EditableText
            Accessible.name: "Search applications"

            Text {
              anchors.fill: parent
              text: "Type to search apps (or >files @web :act =calc !web dict)"
              color: Style.menuInkDeep
              font: parent.font
              opacity: 0.5
              visible: !parent.text && !parent.activeFocus
              verticalAlignment: Text.AlignVCenter
            }

            onTextChanged: {
              root.query = text
              if (root.quickMode) {
                // no schedules, no auto-cat from search while quick grid is active (hidden input; internal cat sets still ok)
                if (resultsList) resultsList.currentIndex = 0
                return
              }
              const ft = root.fileTerm(text)
              if (ft !== null && root.categoryFilter !== Data.fileCategory) {
                root.categoryFilter = Data.fileCategory
              }
              if (text.trim().startsWith(":") && root.categoryFilter !== "Actions") {
                root.categoryFilter = "Actions"
              }
              if (text.trim().startsWith("@") && root.categoryFilter !== "Websearch") {
                root.categoryFilter = "Websearch"
              }
              if (text.trim() && !root.isPrefixSpecial(text) && root.categoryFilter === "" && !root.quickMode) {
                root.categoryFilter = "App"
              }
              root.scheduleDictLookup()
              root.scheduleFileLookup()
              if (resultsList) resultsList.currentIndex = 0
              if (root.fileMode) root.updateFilePreview()
            }

            Keys.onEscapePressed: root.handleEscape()
            Keys.onReturnPressed: root.launchCurrent()
            Keys.onEnterPressed: root.launchCurrent()

            Keys.onPressed: event => {
              // Esc: unwind category (like launcher) then close
              // cascade: first collapse quick side detail (bjarneo: if(quickExpanded) clear
              // else if(query) else if(!goUp)close), then cat, then close
              if (event.key === Qt.Key_Escape) {
                root.handleEscape()
                event.accepted = true
                return
              }
              if (event.key === Qt.Key_Backspace && (root.query || "").trim() === "") {
                if (root.goUp()) { event.accepted = true; return; }
              }
              const max = Math.max(0, root.resultCount - 1)
              if (root.quickMode) {
                const cols = root.quickGridCols
                if (event.key === Qt.Key_Down) {
                  event.accepted = true; root.selectedIndex = Math.min(root.selectedIndex + cols, max)
                } else if (event.key === Qt.Key_Up) {
                  event.accepted = true; root.selectedIndex = Math.max(root.selectedIndex - cols, 0)
                } else if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) {
                  event.accepted = true; root.selectedIndex = Math.min(root.selectedIndex + 1, max)
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                  event.accepted = true; root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                }
                return
              }
              if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                event.accepted = true
                resultsList.currentIndex = Math.min(resultsList.currentIndex + 1, max)
                resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
              } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
                || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                event.accepted = true
                resultsList.currentIndex = Math.max(resultsList.currentIndex - 1, 0)
                resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
              }
            }
          }
        }

        Menu.MenuDivider { width: parent.width; visible: !root.quickMode }

        // List area (with optional file preview split)
        Item {
          id: listArea
          width: parent.width
          height: visible ? Math.max(240, launcherPanel.height * (root.expandedQuickKey === "hub"
            ? 0.46 : (root.sideActive ? 0.48 : 0.42))) : 0
          visible: true
          clip: true

          // Normal results list (or split when preview for files)
          Item {
            anchors.fill: parent

            readonly property real listFrac: root.quickDetailActive ? 0.12 : (root.sideActive ? (root.quickMode ? 0.32 : 0.52) : 1.0)

            ListView {
              id: resultsList
              visible: !root.quickMode
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              width: parent.width * parent.listFrac
              model: filteredApps
              spacing: 0
              boundsBehavior: Flickable.StopAtBounds
              currentIndex: 0
              highlightFollowsCurrentItem: false
              pixelAligned: true

              onCountChanged: if (!root.quickMode) root.resultCount = count
              onCurrentIndexChanged: if (currentIndex >= 0) root.selectedIndex = currentIndex

              delegate: Item {
                id: delegateRoot
                required property var modelData
                required property int index
                width: resultsList.width
                readonly property string dName: modelData.name || modelData.title || "?"
                readonly property string dSub: modelData.comment || ""
                readonly property bool dCat: !!modelData.isCategory
                height: dCat || dSub === "" ? 38 : 50
                readonly property bool isSelected: resultsList.currentIndex === index
                readonly property string dIcon: modelData.icon || ""
                readonly property string dRawIcon: modelData.rawIcon || ""
                readonly property string dImage: root.resolveIconUrl(dRawIcon || (dIcon.startsWith("file://") || dIcon.charAt(0) === "/" ? dIcon : ""))
                readonly property string dGlyph: modelData.glyph || (dImage === "" && dIcon !== "" ? dIcon : "")
                readonly property string dAcc: modelData.accessory || (modelData.isCategory ? "›" : "")

                Accessible.role: Accessible.Button
                Accessible.name: dName

                Rectangle {
                  anchors.fill: parent
                  color: delegateRoot.isSelected ? Style.menuRowSel
                        : rowMa.containsMouse ? Style.menuRowHi : "transparent"
                  Behavior on color { ColorAnimation { duration: 40 } }
                }
                Rectangle {
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  width: 2
                  color: Style.menuSeal
                  visible: delegateRoot.isSelected
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 14
                  anchors.rightMargin: 14
                  spacing: 12

                  Item {
                    id: iconSlot
                    width: 26
                    height: 26
                    Layout.alignment: Qt.AlignVCenter
                    Image {
                      id: rowIcon
                      anchors.fill: parent
                      source: delegateRoot.dImage
                      fillMode: Image.PreserveAspectFit
                      sourceSize.width: 52
                      sourceSize.height: 52
                      smooth: true
                      asynchronous: true
                      visible: delegateRoot.dImage !== "" && status === Image.Ready
                    }
                    Text {
                      anchors.centerIn: parent
                      text: delegateRoot.dGlyph !== "" ? delegateRoot.dGlyph : delegateRoot.dName.charAt(0).toUpperCase()
                      color: delegateRoot.dCat ? Style.menuSeal : (delegateRoot.isSelected ? Style.menuSeal : (delegateRoot.dGlyph === "󰉋" ? "#89b4fa" : Style.menuInkDeep))
                      font.pixelSize: delegateRoot.dGlyph !== "" ? 18 : 14
                      font.family: root.uiFont
                      visible: rowIcon.status !== Image.Ready
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                      Layout.fillWidth: true
                      text: delegateRoot.dName + (delegateRoot.dCat ? "  ›" : "")
                      color: delegateRoot.isSelected ? Style.menuInk : Style.menuInkDeep
                      font.pixelSize: 13
                      font.family: root.uiFont
                      font.weight: delegateRoot.isSelected ? Font.Medium : Font.Light
                      font.letterSpacing: 1
                      elide: Text.ElideRight
                    }

                    Text {
                      Layout.fillWidth: true
                      visible: delegateRoot.dSub !== "" && !delegateRoot.dCat
                      text: delegateRoot.dSub
                      color: delegateRoot.isSelected ? Style.menuInk : Style.menuInkDeep
                      opacity: delegateRoot.isSelected ? 0.75 : 0.5
                      font.pixelSize: 10
                      font.family: root.uiFont
                      font.letterSpacing: 0.5
                      elide: Text.ElideRight
                      maximumLineCount: 1
                    }
                  }

                  Text {
                    text: delegateRoot.dAcc.toUpperCase()
                    visible: text !== ""
                    color: delegateRoot.isSelected ? Style.menuSeal : Style.menuInkDeep
                    opacity: delegateRoot.isSelected ? 0.95 : 0.65
                    font.pixelSize: 10
                    font.family: root.uiFont
                    font.letterSpacing: 2
                    elide: Text.ElideLeft
                    maximumLineCount: 1
                    Layout.maximumWidth: 180
                  }
                }

                MouseArea {
                  id: rowMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPositionChanged: resultsList.currentIndex = delegateRoot.index
                  onClicked: root.launchApp(delegateRoot.modelData)
                }
              }

              Text {
                anchors.centerIn: parent
                text: (root.resultCount === 0 && searchInput.text !== "" ? "NOTHING MATCHES" : "")
                color: Style.menuInkDeep
                font.family: root.uiFont
                font.pixelSize: 11
                font.letterSpacing: 3
                opacity: 0.6
                visible: root.resultCount === 0 && searchInput.text !== ""
              }
            }

            // Quick grid (exact ref bjarneo style: compress width+cols+tileH on detail; 1 hairline sep; grid nav; sub hidden colmode)
            Grid {
              id: quickGrid
              visible: root.quickMode
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              width: parent.width * parent.listFrac
              columns: root.quickGridCols
              rowSpacing: root.quickDetailActive ? 4 : 8
              columnSpacing: root.quickDetailActive ? 4 : 8
              clip: true
              readonly property bool colMode: root.quickDetailActive
              readonly property int tileH: colMode ? 48 : 72
              Timer { interval: 0; running: root.quickMode; repeat: false; onTriggered: root.resultCount = (root.quickTiles || []).length }

              Repeater {
                model: root.quickTiles || []
                delegate: Item {
                  id: qtile
                  required property var modelData
                  required property int index
                  readonly property bool isSel: root.selectedIndex === index
                  readonly property var t: modelData || {}
                  width: (quickGrid.width - (quickGrid.columns-1)*quickGrid.columnSpacing) / quickGrid.columns
                  height: quickGrid.tileH
                  Rectangle {
                    anchors.fill: parent
                    radius: Style.menuRadius
                    color: isSel
                      ? Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.08)
                      : qma.containsMouse
                        ? Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.05)
                        : Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.03)
                    border.color: isSel ? Style.menuSeal : Style.menuSep
                    border.width: isSel ? 2 : 1
                    Behavior on color { ColorAnimation { duration: 50 } }
                    Behavior on border.color { ColorAnimation { duration: 50 } }
                    Behavior on border.width { NumberAnimation { duration: 50 } }
                  }
                  Column {
                    anchors.fill: parent
                    anchors.margins: quickGrid.colMode ? 3 : 6
                    spacing: quickGrid.colMode ? 0 : 2
                    Text {
                      text: t.glyph || "󰘔"; color: isSel ? Style.menuSeal : Style.menuInk
                      font.pixelSize: (quickGrid.colMode ? 14 : 18) ; font.family: root.uiFont; anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      width: parent.width - 4
                      text: (t.label || "").toUpperCase()
                      color: isSel ? Style.menuInk : Style.menuInkDeep
                      font.pixelSize: (quickGrid.colMode ? 7 : 9) ; font.family: root.uiFont; font.letterSpacing: quickGrid.colMode ? 0.8 : 1.2
                      font.weight: Font.Medium
                      elide: Text.ElideRight
                      horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                      visible: !quickGrid.colMode
                      anchors.horizontalCenter: parent.horizontalCenter
                      width: parent.width - 4
                      text: t.sub || ""
                      color: Style.menuInkDeep; font.pixelSize: 7; font.family: root.uiFont
                      opacity: 0.8; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                    }
                  }
                  MouseArea {
                    id: qma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: { root.selectedIndex = index; if (resultsList) resultsList.currentIndex = index }
                    onClicked: {
                      root.selectedIndex = index
                      if (modelData.mode) root.expandQuick(modelData.key)
                      else if (modelData.command && modelData.command.length > 0) {
                        Quickshell.execDetached(root.resolveCmd(modelData.command)); root.shouldShow = false
                      }
                    }
                  }
                }
              }
            }

            // mid hairline sep (ref style between compressed grid and detail)
            Rectangle {
              id: quickSep
              visible: root.quickDetailActive
              anchors.top: parent.top; anchors.bottom: parent.bottom
              anchors.left: quickGrid.right; anchors.leftMargin: 8
              width: 1; color: Style.menuSep
            }

            // Preview pane (file only for now, launcher style split; or quick feature detail when expanded)
            Item {
              visible: root.sideActive
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.left: root.quickMode && root.quickDetailActive ? quickSep.right : (root.quickMode ? quickGrid.right : resultsList.right)
              anchors.leftMargin: root.quickDetailActive ? 10 : 8
              anchors.right: parent.right

              // quick detail side (exact ref: header glyph26 + label13 lSp2 + sub10 + round×22; topM6; no mid hairline in detail; flick topM10; bodies are feature windows content)
              Item {
                id: qDetailSide
                visible: root.quickDetailActive
                anchors.fill: parent
                readonly property bool hubMode: root.expandedQuickKey === "hub"
                readonly property var qtile: (root.quickTiles || []).find(function(x){ return x.key === root.expandedQuickKey }) || {}
                RowLayout {
                  id: qDetailHeader
                  visible: !qDetailSide.hubMode
                  anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 6; spacing: 10
                  Text {
                    text: qDetailSide.qtile.glyph || "󰘔"
                    color: Style.menuSeal
                    font.family: root.uiFont
                    font.pixelSize: 24
                    Layout.alignment: Qt.AlignVCenter
                  }
                  Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1
                    Text {
                      text: (qDetailSide.qtile.label || "").toUpperCase()
                      color: Style.menuInk
                      font.family: root.uiFont
                      font.pixelSize: 12
                      font.letterSpacing: 1.6
                      font.weight: Font.Medium
                    }
                    Text {
                      text: qDetailSide.qtile.sub || ""
                      color: Style.menuInkDeep
                      font.family: root.uiFont
                      font.pixelSize: 9
                      font.letterSpacing: 0.8
                      opacity: 0.85
                      elide: Text.ElideRight
                    }
                  }
                  Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 20; height: 20; radius: 10
                    color: cqma.containsMouse ? Qt.rgba(Style.menuInk.r, Style.menuInk.g, Style.menuInk.b, 0.08) : "transparent"
                    border.color: Style.menuSep
                    border.width: 1
                    Text {
                      anchors.centerIn: parent
                      text: "×"
                      color: Style.menuInkDeep
                      font.family: root.uiFont
                      font.pixelSize: 13
                    }
                    MouseArea {
                      id: cqma
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.expandedQuickKey = ""
                    }
                  }
                }
                Flickable {
                  id: qBodyFlick
                  anchors.left: parent.left; anchors.right: parent.right
                  anchors.top: qDetailSide.hubMode ? parent.top : qDetailHeader.bottom
                  anchors.bottom: parent.bottom
                  anchors.topMargin: qDetailSide.hubMode ? 0 : 8
                  clip: true
                  contentWidth: width
                  contentHeight: Math.max(height, qdl.height || 0)
                  boundsBehavior: Flickable.StopAtBounds
                  Loader {
                    id: qdl
                    width: parent.width
                    height: parent.height
                    active: root.quickDetailActive
                    sourceComponent: root.quickDetailFor(root.expandedQuickKey)
                  }
                }
              }

              // file preview (unchanged, only when not quick detail)
              Item {
                visible: root.previewActive && !root.quickDetailActive
                anchors.fill: parent

                Text {
                  id: previewName
                  anchors.top: parent.top
                  text: {
                    const it = resultsList.currentItem ? resultsList.currentItem.modelData : null
                    return it && it.path ? Data.basename(it.path) : "File preview"
                  }
                  color: Style.menuInk
                  font.family: root.uiFont
                  font.pixelSize: 12
                  elide: Text.ElideRight
                }
                Text {
                  anchors.top: previewName.bottom
                  text: {
                    const it = resultsList.currentItem ? resultsList.currentItem.modelData : null
                    return it && it.path ? Data.tildify(Data.dirname(it.path), root.homeDir) : ""
                  }
                  color: Style.menuInkDeep
                  font.family: root.uiFont
                  font.pixelSize: 10
                  opacity: 0.7
                  elide: Text.ElideLeft
                }
                Rectangle { anchors.top: parent.top; anchors.topMargin: 32; width: parent.width; height: 1; color: Style.menuSep }

                // Simple file preview body
                Item {
                  anchors.top: parent.top
                  anchors.topMargin: 36
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left
                  anchors.right: parent.right
                  clip: true

                  Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    visible: root.fileMode && resultsList.currentItem && resultsList.currentItem.modelData && root.isImageFile(resultsList.currentItem.modelData.path || "")
                    source: root.fileMode && resultsList.currentItem && resultsList.currentItem.modelData && root.isImageFile(resultsList.currentItem.modelData.path || "") && resultsList.currentItem.modelData.path ? "file://" + resultsList.currentItem.modelData.path : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                  }

                  Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    visible: root.fileMode && resultsList.currentItem && resultsList.currentItem.modelData && root.isPdfFile(resultsList.currentItem.modelData.path || "")
                    source: root.fileMode && resultsList.currentItem && resultsList.currentItem.modelData && root.isPdfFile(resultsList.currentItem.modelData.path || "") && root.pdfPreviewPath ? root.pdfPreviewPath : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                  }

                  Text {
                    anchors.fill: parent
                    anchors.margins: 4
                    visible: root.fileMode && resultsList.currentItem && resultsList.currentItem.modelData && root.isTextFile(resultsList.currentItem.modelData.path || "")
                    text: root.filePreviewText
                    color: Style.menuInkDeep
                    font.family: root.uiFont
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 18
                  }

                  Text {
                    anchors.fill: parent
                    anchors.margins: 4
                    visible: root.fileMode && resultsList.currentItem && resultsList.currentItem.modelData && !root.isImageFile(resultsList.currentItem.modelData.path || "") && !root.isTextFile(resultsList.currentItem.modelData.path || "") && !(root.isPdfFile(resultsList.currentItem.modelData.path || "") && !root.filePreviewMeta)
                    text: root.filePreviewMeta
                    color: Style.menuInkDeep
                    font.family: root.uiFont
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                  }
                }
              }
            }
          }
        }

        Menu.MenuDivider { width: parent.width }

        Text {
          width: parent.width
          elide: Text.ElideRight
          text: {
            const it = resultsList.currentItem ? resultsList.currentItem.modelData : null
            if (root.quickMode) return ""
            if (!it) return ""
            if (it.special === "action" && it.command && it.command.length) return "$ " + it.command.join(" ")
            if (it.special === "file" && it.path) return "$ xdg-open " + it.path
            if (it.execString) return "$ " + it.execString
            if (it.exec) return "$ " + it.exec
            if (it.command) return "$ " + (it.command.join ? it.command.join(" ") : it.command)
            return it.comment || ""
          }
          color: Style.menuInkDeep
          font.family: root.uiFont
          font.pixelSize: 10
          font.letterSpacing: 1
          opacity: 0.65
        }

        Menu.MenuHintRow {
          width: parent.width
          fontFamily: root.uiFont
          hints: "!  >  :  @  dict"
        }
      }

      // Screenshot preview overlay (copy / open / delete)
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
          source: root.shotPreviewPath !== "" ? ("file://" + root.shotPreviewPath) : ""
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }

        RowLayout {
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottomMargin: 28
          spacing: 10

          Rectangle {
            width: 96
            height: 34
            radius: 17
            color: copyShotPreviewMa.containsMouse ? root.menuSuccessBg : Style.menuControlBg
            border.width: 1
            border.color: copyShotPreviewMa.containsMouse ? Style.green : Style.menuSep
            Text {
              anchors.centerIn: parent
              text: "Copy"
              color: copyShotPreviewMa.containsMouse ? Style.green : Style.menuInk
              font.pixelSize: root.fontPx(11)
              font.bold: true
              font.family: root.uiFont
            }
            MouseArea {
              id: copyShotPreviewMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: (mouse) => { mouse.accepted = true; root.copyShot(root.shotPreviewPath) }
            }
          }

          Rectangle {
            width: 96
            height: 34
            radius: 17
            color: openShotPreviewMa.containsMouse ? Style.menuRowSel : Style.menuControlBg
            border.width: 1
            border.color: openShotPreviewMa.containsMouse ? Style.menuSeal : Style.menuSep
            Text {
              anchors.centerIn: parent
              text: "Open"
              color: openShotPreviewMa.containsMouse ? Style.menuSeal : Style.menuInk
              font.pixelSize: root.fontPx(11)
              font.bold: true
              font.family: root.uiFont
            }
            MouseArea {
              id: openShotPreviewMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openShot(root.shotPreviewPath)
            }
          }

          Rectangle {
            width: 96
            height: 34
            radius: 17
            color: deleteShotPreviewMa.containsMouse ? root.menuDangerBg : Style.menuControlBg
            border.width: 1
            border.color: deleteShotPreviewMa.containsMouse ? Style.red : Style.menuSep
            Text {
              anchors.centerIn: parent
              text: "Delete"
              color: deleteShotPreviewMa.containsMouse ? Style.red : Style.menuInk
              font.pixelSize: root.fontPx(11)
              font.bold: true
              font.family: root.uiFont
            }
            MouseArea {
              id: deleteShotPreviewMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: (mouse) => {
                mouse.accepted = true
                root.deleteShot(root.shotPreviewPath)
              }
            }
          }
        }
      }

    }
  }
}
