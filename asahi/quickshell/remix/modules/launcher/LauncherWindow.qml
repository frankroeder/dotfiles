import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../wallpaper" as Wallpaper
import "../wallpaper/wallpaper_thumbs.js" as WallThumbs
import "../menu" as Menu
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../../"
import "Data.js" as Data
import "websearch.js" as WebSearch
import "arg_commands.js" as ArgCommands
import "emoji.js" as Emoji
import "dictcc-core.mjs" as DictCC
import "launcher_layout.js" as LauncherGeom
import "temp_display.js" as TempDisplay
import "quick_models.js" as QuickModels
import "gallery.js" as Gallery
import "panes" as Panes

Scope {
  id: root

  property var theme: Wallpaper.DefaultTheme
  // Panes take the launcher as `root`; inside their scope `root` is that
  // property, so hand it over under a different name.
  readonly property var launcherSelf: root
  property bool shouldShow: false
  // Keep the layer mapped during close so blur/dim/card can animate out.
  property bool panelVisible: false
  property real chromeReveal: 0
  Timer {
    id: chromeRevealKick
    interval: 1
    onTriggered: root.chromeReveal = 1
  }
  Timer {
    id: chromeHideKick
    interval: Style.menuAnimOutMs
    onTriggered: {
      if (!root.shouldShow)
        root.panelVisible = false
    }
  }
  property string query: ""
  // Armed prefix (dict, @dcc, >, !, =). Search input then holds only the argument.
  property string argCommand: ""
  property string argPlaceholder: ""
  readonly property bool argArmed: root.argCommand !== ""
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
  property var dictXhr: null
  readonly property var dictDefaults: ({ sourceLanguage: "de", targetLanguage: "en" })
  property int fileVersion: 0
  property string fileStatus: ""
  property string filePendingTerm: ""
  property string fileRunningTerm: ""
  property var fileItems: []
  property var appUsage: ({})
  property int appUsageVersion: 0

  // Fallback icon lookup for names Qt's themed cache misses (apps installed
  // after QS started, device icons like "printer"). name -> absolute path.
  property var iconIndex: ({})
  property var pendingIconIndex: ({})

  // Desktop ids hidden from the Apps drill (launcher.hides, one id per line).
  property var hiddenAppIds: ({})
  property int hiddenVersion: 0

  // Nightlight state mirrored from ~/.local/state/asahi/nightlight.json for
  // the checkmark on the Actions row.
  property bool nightLightOn: false
  property int nightVersion: 0

  // Keyboard shortcuts drill: rows parsed from `hyprctl binds` (descriptions
  // come from the Lua binds' desc options). Rescanned on every drill entry.
  property var keyBinds: []
  property int keysVersion: 0

  // Launch feedback: injected system OSD (shell.qml) + toplevel snapshot taken
  // at launch so a slow starter can show a "Launching X…" toast.
  property var osd: null
  property string launchFeedbackName: ""
  property int launchToplevelCount: 0
  property var launchActiveToplevel: null
  property bool launchOsdOpen: false

  // Launcher palette state (category overview + drills + query shapes)
  property string categoryFilter: ""
  readonly property bool fileMode: root.categoryFilter === Data.fileCategory || root.fileTerm(root.query) !== null
  readonly property bool previewActive: root.fileMode
  readonly property bool quickMode: root.categoryFilter === "Quick"
  property string expandedQuickKey: ""
  // Wallpaper pane carousel (set while the pane is loaded) for ←/→/⏎ routing.
  property var wallCarousel: null
  readonly property string quickPaneKey: {
    if (!root.quickMode) return ""
    const k = root.expandedQuickKey
    if (k === "" || k === "dashboard") return "hub"
    return k
  }
  readonly property bool quickDetailActive: root.quickMode
  readonly property bool sideActive: root.previewActive || root.quickMode
  readonly property int quickGridCols: 1

  // Scoring (ported from launcher ref, tuned for small set)
  readonly property int scPrefix: 100
  readonly property int scTitle: 60
  readonly property int scKw: 20
  readonly property int scCat: 10
  readonly property int scAcro: 15
  readonly property int maxResults: 200

  readonly property string homeDir: Quickshell.env("HOME")

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property string uiFont: Style.menuMono
  readonly property string uiSans: Style.menuSans
  readonly property string uiDisplay: Style.menuDisplay
  readonly property string dictIcon: "file://" + Quickshell.env("HOME") + "/.dotfiles/asahi/quickshell/remix/assets/dict-cc.png"
  readonly property string webIconBase: "file://" + Quickshell.env("HOME") + "/.dotfiles/asahi/quickshell/remix/assets/"
  readonly property string websearchJsonPath: Quickshell.env("HOME") + "/.dotfiles/asahi/quickshell/remix/modules/launcher/websearch.json"
  readonly property string hidesPath: Quickshell.env("HOME") + "/.dotfiles/asahi/quickshell/remix/modules/launcher/launcher.hides"
  readonly property string nightStatePath: Quickshell.env("HOME") + "/.local/state/asahi/nightlight.json"
  property int webVersion: 0

  // Launcher-style data (nav + local items for categories + prefix specials for files/web/docs/calc/actions)
  readonly property var launcherItems: Data.annotate(Data.localItems)

  readonly property var quickActions: [
    { key: "dashboard", aliases: ["dash", "hub"], icon: "󰕮", name: "Dashboard", comment: "Open feature dashboard", mode: "hub" },
    { key: "wallpaper", aliases: ["wall", "paper"], icon: "󰸉", name: "Wallpapers", comment: "Open wallpaper picker", mode: "wallpaper" },
    { key: "screenshots", aliases: ["shots", "ss"], icon: "󰹑", name: "Screenshots", comment: "Open screenshot gallery", mode: "screenshots" },
    { key: "media", aliases: ["music", "audio"], icon: "󰝚", name: "Media", comment: "Open media and mixer", mode: "media" },
    { key: "network", aliases: ["wifi", "net", "vpn"], icon: "󰈀", name: "Network", comment: "Open network and VPN controls", mode: "network" },
    { key: "monitors", aliases: ["display", "screen"], icon: "󰍹", name: "Monitors", comment: "Open monitor layout", mode: "monitors" },
    { key: "temp", aliases: ["temps", "temperature"], icon: "󰔄", name: "Temperatures", comment: "Open sensor view", mode: "temp" },
    { key: "battery", aliases: ["bat", "power", "charge"], icon: "󰁹", name: "Battery", comment: "Battery status, health, and power", mode: "battery" },
    { key: "bluetooth", aliases: ["bt"], icon: "󰂯", name: "Bluetooth", comment: "Open Bluetooth devices", mode: "bluetooth" },
    { key: "storage", aliases: ["disk", "space"], icon: "󰋊", name: "Storage", comment: "Disk usage and home folders", mode: "storage" },
    { key: "clipboard", aliases: ["clip", "cliphist", "paste"], icon: "󰅌", name: "Clipboard", comment: "cliphist history — copy, delete, wipe", mode: "clipboard" },
    { key: "packages", aliases: ["pkg", "dnf", "pkgman"], icon: "󰏖", name: "Packages", comment: "Search and manage dnf packages", ipc: "pkgman" },
    { key: "screensaver", aliases: ["saver"], icon: "󱄄", name: "Screensaver", comment: "Shader idle display", command: [root.binDir + "/asahi-screensaver", "toggle"] },
    { key: "recorder", aliases: ["rec-panel", "screen recorder", "recordings"], icon: "󰑋", name: "Recorder", comment: "Screen recorder panel: start, stop, recent recordings", ipc: "recording" },
    { key: "record", aliases: ["rec", "wf-recorder"], icon: "󰑋", name: "Record display", comment: "Toggle focused-display recording (wf-recorder)", command: [root.binDir + "/asahi-cmd-record", "fullscreen"] },
    { key: "record-webcam", aliases: ["recam", "webcam", "facecam"], icon: "󰄀", name: "Record with webcam", comment: "Display recording plus a pinned face-cam overlay", command: [root.binDir + "/asahi-cmd-record", "webcam"] },
    { key: "ocr", aliases: ["text", "tesseract"], icon: "󰴑", name: "OCR region", comment: "Copy text from a screen region", command: [root.binDir + "/asahi-cmd-ocr"] },
    { key: "qr", aliases: ["qrcode", "zbar"], icon: "󰐲", name: "Scan QR", comment: "Copy a QR code from a screen region", command: [root.binDir + "/asahi-cmd-qr"] },
    { key: "nightlight", aliases: ["night", "warm", "hyprsunset"], icon: "󰖔", name: "Night light toggle", comment: "Super+Ctrl+N · hyprsunset.conf (identity / temperature)", command: [root.binDir + "/asahi-nightlight", "toggle"] },
    { key: "pop", aliases: ["float", "pin"], icon: "󰖲", name: "Pop window", comment: "Super+O · float, center and pin the focused window (again to retile)", command: [root.binDir + "/asahi-window-pop"] },
    { key: "scale", aliases: ["zoom", "hidpi"], icon: "󰍹", name: "Display scale", comment: "Super+Ctrl+plus/minus · cycle the focused display through legal scales", command: [root.binDir + "/asahi-monitor-scale", "cycle"] },
    { key: "reload", aliases: ["qs"], icon: "󰑐", name: "Reload Quickshell", comment: "Restart QS", command: [root.binDir + "/asahi-restart-quickshell"] },
    { key: "hypr", aliases: ["hyprland"], icon: "󰑓", name: "Reload Hyprland", comment: "Reload Hyprland config", command: [root.binDir + "/asahi-reload-hyprland"] },
    { key: "lock", aliases: ["lockscreen"], icon: "󰌾", name: "Lock", comment: "Lock session", command: ["loginctl", "lock-session"] },
    { key: "timer", aliases: ["reminder", "alarm", "countdown"], icon: "󰔛", name: "Timer", comment: ":timer 10m tea · 1:30 · 1h15m", query: ":timer " },
    { key: "scratch", aliases: ["scratchpad"], icon: "󱂬", name: "Scratchpad", comment: "Toggle scratch workspace", command: ["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special(\"scratch\")"] }
  ]

  readonly property var quickTiles: root.quickActions.filter(function(a) {
    return !!a.mode
  }).map(function(a) {
    return { key: a.key, glyph: a.icon, label: a.name, sub: a.comment, mode: a.mode }
  })
  readonly property var quickDeckHidden: ({
    packages: true,
    recorder: true,
    screensaver: true,
    record: true,
    "record-webcam": true,
    ocr: true,
    qr: true,
    nightlight: true,
    reload: true,
    hypr: true,
    lock: true,
    scratch: true,
    timer: true,
    pop: true,
    scale: true
  })
  readonly property var quickDeck: (root.quickActions || []).filter(function(a) {
    return !root.quickDeckHidden[a.key]
  }).map(function(a) {
    return {
      key: a.key,
      glyph: a.icon,
      label: a.name,
      sub: a.comment,
      mode: a.mode || "",
      command: a.command || [],
      ipc: a.ipc || "",
      kind: a.mode ? "pane" : (a.ipc ? "ipc" : "run"),
      tint: Data.deckTint(a.key)
    }
  })

  // --- live data + exact hub/lower + side windows (ported from old featuremenu; now the only place, module removed)
  readonly property real uiFontScale: root.launcherGeom.fontScale
  readonly property real quickOverviewScale: 1.0
  readonly property int launcherScreenH: {
    const scr = launcherPanel.screen || root.launcherScreen
    if (scr && scr.height > 1) return scr.height
    if (launcherPanel.height > 1) return launcherPanel.height
    return 1080
  }
  readonly property int launcherScreenW: {
    const scr = launcherPanel.screen || root.launcherScreen
    if (scr && scr.width > 1) return scr.width
    if (launcherPanel.width > 1) return launcherPanel.width
    return 1920
  }
  readonly property bool compactLauncher: !root.quickMode && !root.sideActive
  readonly property var launcherGeom: LauncherGeom.launcherLayout({
    screenH: root.launcherScreenH,
    screenW: root.launcherScreenW,
    tileCount: (root.quickDeck || []).length,
    sideActive: root.sideActive,
    quickMode: root.quickMode,
    hubMode: root.quickPaneKey === "hub",
    compact: root.compactLauncher,
    headerVisible: !root.quickMode && root.sectionName !== "",
    cmdVisible: !root.quickMode && !root.compactLauncher,
    rowCount: root.categoryFilter === ""
      ? Math.max(root.resultCount, (root.navRows || []).length)
      : root.resultCount
  })
  function fontPx(size) {
    const boosted = size <= 9 ? size + 2 : size
    return Math.round(boosted * root.uiFontScale)
  }
  function tintColor(token) {
    switch (token) {
      case "pink": return Style.pink
      case "mauve": return Style.mauve
      case "red": return Style.red
      case "maroon": return Style.maroon
      case "peach": return Style.orange
      case "yellow": return Style.yellow
      case "green": return Style.green
      case "teal": return Style.teal
      case "sky": return Style.sky
      case "sapphire": return Style.sapphire
      case "blue": return Style.blue
      case "lavender": return Style.lavender
      default: return Style.menuInkDeep
    }
  }
  function itemTintColor(item) {
    return root.tintColor(Data.itemTint(item))
  }
  function quickPx(size) { return Math.round(size * root.uiFontScale * root.quickOverviewScale) }
  function execAndClose(cmd) {
    Quickshell.execDetached(cmd)
    root.closeLauncher()
  }
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
  property var videos: []
  property string galleryKind: "shots"
  property string copiedShot: ""
  property string shotPreviewPath: ""
  property var clips: []
  property string clipsError: ""
  property string copiedClip: ""
  Timer { id: copyClear; interval: 1200; onTriggered: copiedShot = "" }
  Timer { id: clipCopyClear; interval: 1200; onTriggered: copiedClip = "" }

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
    interval: (root.quickMode && root.quickPaneKey === "hub") ? 800 : 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!sidebarProc.running) sidebarProc.running = true
  }

  function scanClips() {
    Quickshell.execDetached(["bash", root.binDir + "/asahi-cliphist", "watch"])
    if (!clipScan.running) clipScan.running = true
  }
  Process {
    id: clipScan
    command: ["bash", root.binDir + "/asahi-cliphist", "list"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          const data = JSON.parse(text || "{}")
          root.clips = data.entries || []
          root.clipsError = data.error || ""
        } catch (e) {
          root.clips = []
          root.clipsError = "parse"
        }
      }
    }
  }
  function copyClip(id) {
    if (!id) return
    root.copiedClip = id
    clipCopyClear.restart()
    Quickshell.execDetached(["bash", root.binDir + "/asahi-cliphist", "copy", String(id)])
  }
  function deleteClip(id) {
    if (!id) return
    root.clips = (root.clips || []).filter(c => String(c.id) !== String(id))
    Quickshell.execDetached(["bash", root.binDir + "/asahi-cliphist", "delete", String(id)])
  }
  function wipeClips() {
    root.clips = []
    Quickshell.execDetached(["bash", root.binDir + "/asahi-cliphist", "wipe"])
  }

  function scanShots() {
    shotScan.command = ["sh", "-c", Gallery.scanCommand("shots", Quickshell.env("HOME"))]
    shotScan.running = true
    root.scanVideos()
  }
  function scanVideos() {
    videoScan.command = ["sh", "-c", Gallery.scanCommand("videos", Quickshell.env("HOME"))]
    videoScan.running = true
  }
  Process {
    id: shotScan
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.shots = Gallery.mapPaths(text)
    }
  }
  Process {
    id: videoScan
    running: false
    stdout: StdioCollector {
      onStreamFinished: root.videos = Gallery.mapPaths(text)
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
  function openShot(p) { if (p) Quickshell.execDetached([binDir + "/asahi-launch", "xdg-open", p]) }
  function previewShot(p) { if (p) root.shotPreviewPath = p }
  function deleteShot(p) {
    if (!p) return
    if (root.shotPreviewPath === p) root.shotPreviewPath = ""
    if (root.copiedShot === p) root.copiedShot = ""
    root.shots = (root.shots || []).filter(s => s.path !== p)
    root.videos = (root.videos || []).filter(s => s.path !== p)
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
    running: root.quickMode && root.quickPaneKey === "storage"
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
    // Live wall clock next to the uptime pill; the hub Item is only instantiated while shown.
    SystemClock { id: hubClock; precision: SystemClock.Seconds }
    property int ffDiskPct: 0
    property int ffMemPct: 0
    property real ffMemUsedBytes: 0
    property real ffMemTotalBytes: 0
    property var ffLeftRows: []
    property var ffRightRows: []
    readonly property int ffIconWidth: 18
    readonly property int ffLabelWidth: Math.max(68, Math.round(root.fontPx(8) * 5.6))
    readonly property var ffGridRows: {
      const left = quickHubRoot.ffLeftRows || []
      const right = quickHubRoot.ffRightRows || []
      const n = Math.max(left.length, right.length)
      const out = []
      for (let i = 0; i < n; i++) {
        out.push(i < left.length ? left[i] : { key: "", icon: "", value: "" })
        out.push(i < right.length ? right[i] : { key: "", icon: "", value: "" })
      }
      return out
    }

    Component {
      id: ffInfoRowDelegate
      RowLayout {
        required property var modelData
        visible: !!(modelData && (modelData.key || modelData.value))
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredWidth: 1
        spacing: 8
        readonly property string rowValue: {
          if (modelData && (modelData.key === "Mem" || modelData.key === "Memory")) {
            return quickHubRoot.prettyBytes(quickHubRoot.ffMemTotalBytes * root.sidebarMem / 100)
              + " / " + quickHubRoot.prettyBytes(quickHubRoot.ffMemTotalBytes)
              + " (" + root.sidebarMem + "%)"
          }
          return (modelData && modelData.value) || "—"
        }

        Text {
          Layout.preferredWidth: quickHubRoot.ffIconWidth
          Layout.maximumWidth: quickHubRoot.ffIconWidth
          Layout.alignment: Qt.AlignTop
          Layout.topMargin: 1
          text: modelData.icon || ""
          color: modelData.accent || Style.m3onSurfaceVariant
          font.pixelSize: root.fontPx(10)
          font.family: root.uiFont
          horizontalAlignment: Text.AlignHCenter
        }
        Text {
          Layout.preferredWidth: quickHubRoot.ffLabelWidth
          Layout.minimumWidth: quickHubRoot.ffLabelWidth
          Layout.maximumWidth: quickHubRoot.ffLabelWidth
          Layout.alignment: Qt.AlignTop
          Layout.topMargin: 1
          text: (modelData.key || "")
          color: Style.m3onSurfaceVariant
          font.pixelSize: root.fontPx(9)
          font.family: root.uiSans
          font.weight: Font.Medium
          horizontalAlignment: Text.AlignLeft
          elide: Text.ElideNone
        }
        Text {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignTop
          Layout.topMargin: 1
          text: rowValue
          color: Style.m3onSurface
          font.pixelSize: root.fontPx(9)
          font.family: root.uiSans
          // Guard on width so the first 0-wide pass does not wrap
          // one grapheme per line. Shared GridLayout rows keep wrap aligned.
          wrapMode: width > 80 ? Text.WordWrap : Text.NoWrap
          elide: Text.ElideRight
          maximumLineCount: width > 80 ? 2 : 1
        }
      }
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
        const ips = one("LocalIp") || []
        const ip = ips.find(x => x.defaultRoute && x.defaultRoute.ipv4) || ips[0] || {}
        const bats = one("Battery") || []
        const bat = bats.length > 0 ? bats[0] : {}
        const uptime = one("Uptime") || {}
        const diskBytes = disk.bytes || {}
        const memUsed = Number(mem.used) || 0
        const memTotal = Number(mem.total) || 0
        const diskUsed = Number(diskBytes.used) || 0
        const diskTotal = Number(diskBytes.total) || 0
        const out = display.output || {}
        const scaled = display.scaled || out
        const refresh = out.refreshRate ? (" @ " + Math.round(out.refreshRate) + " Hz") : ""
        const scale = (out.width && scaled.width && out.width !== scaled.width)
          ? (" @ " + (out.width / scaled.width).toFixed(2) + "x") : ""
        const batteryStatus = Array.isArray(bat.status) ? bat.status.join(", ") : (bat.status || "")
        quickHubRoot.ffTitle = (title.userName && title.hostName)
          ? (title.userName + "@" + title.hostName) : (host.name || "System")
        quickHubRoot.ffSubtitle = os.prettyName || os.name || "fastfetch"
        quickHubRoot.ffUptime = quickHubRoot.formatUptime(uptime.uptime)
        quickHubRoot.ffDiskPct = quickHubRoot.pct(diskUsed, diskTotal)
        quickHubRoot.ffMemPct = quickHubRoot.pct(memUsed, memTotal)
        quickHubRoot.ffMemUsedBytes = memUsed
        quickHubRoot.ffMemTotalBytes = memTotal
        // Header already shows user@host, OS, and uptime — keep the well
        // to short one-line facts that fit the leftover pane width.
        quickHubRoot.ffLeftRows = [
          quickHubRoot.ffRow("Host", "󰌢", Style.sky, host.name || host.family || "—"),
          quickHubRoot.ffRow("Kernel", "󰣀", Style.teal, kernel.release || "—"),
          quickHubRoot.ffRow("Pkgs", "󰏖", Style.mauve,
            (pkgs.flatpakUser || 0) + " flatpak · " + (pkgs.rpm || 0) + " rpm"),
          quickHubRoot.ffRow("CPU", "󰘚", Style.orange,
            (cpu.cpu || "—") + (cpu.cores && cpu.cores.logical ? (" (" + cpu.cores.logical + ")") : "")),
          quickHubRoot.ffRow("GPU", "󰢮", Style.menuIndigo,
            (gpu.name || "—") + (gpu.coreCount ? (" (" + gpu.coreCount + ")") : "")),
          quickHubRoot.ffRow("Mem", "󰍛", Style.lavender,
            quickHubRoot.prettyBytes(memUsed) + " / " + quickHubRoot.prettyBytes(memTotal)
              + " (" + quickHubRoot.ffMemPct + "%)")
        ]
        quickHubRoot.ffRightRows = [
          quickHubRoot.ffRow("Display", "󰍹", Style.sapphire,
            (out.width || scaled.width || "?") + "x" + (out.height || scaled.height || "?")
              + scale + refresh
              + (display.name ? (" · " + display.name) : "")),
          quickHubRoot.ffRow("WM", "󰖯", Style.green, (wm.prettyName || wm.processName || "—")
            + (wm.version ? " " + wm.version : "")
            + (wm.protocolName ? " (" + wm.protocolName + ")" : "")),
          quickHubRoot.ffRow("Shell", "󰆍", Style.yellow, shell.prettyName || shell.processName || "—"),
          quickHubRoot.ffRow("Disk", "󰋊", Style.menuIndigo,
            quickHubRoot.prettyBytes(diskUsed) + " / " + quickHubRoot.prettyBytes(diskTotal)
              + (disk.filesystem ? (" · " + disk.filesystem) : "")),
          quickHubRoot.ffRow("IP", "󰩠", Style.cyan, ip.ipv4 || "—"),
          quickHubRoot.ffRow("Bat", "󰁹", Style.green,
            (bat.capacity !== undefined ? (Math.round(bat.capacity) + "%") : "—")
              + (batteryStatus ? (" · " + batteryStatus) : ""))
        ]
      } catch (_) {
        quickHubRoot.ffLeftRows = [quickHubRoot.ffRow("fastfetch", "󰀦", Style.red, "unavailable")]
        quickHubRoot.ffRightRows = []
      }
    }
    function refreshFastfetch() {
      if (!ffProc.running) ffProc.running = true
    }

    Process {
      id: ffProc
      // Explicit structure: the user config's default module list lacks most
      // of what parseFastfetch reads (Host, Packages, GPU, Display, LocalIp,
      // Theme, Battery, PowerAdapter, Locale), leaving dashes on the card.
      command: ["fastfetch", "--format", "json", "--structure",
        "Title:OS:Host:Kernel:Uptime:Packages:Shell:Display:WM:Theme:CPU:GPU:Memory:Disk:LocalIp:Battery:PowerAdapter:Locale"]
      stdout: StdioCollector { onStreamFinished: quickHubRoot.parseFastfetch(text) }
    }
    Timer {
      interval: 60000
      running: root.quickMode && root.quickPaneKey === "hub"
      repeat: true
      triggeredOnStart: true
      onTriggered: quickHubRoot.refreshFastfetch()
    }
    Component.onCompleted: Qt.callLater(quickHubRoot.refreshFastfetch)

    ColumnLayout {
      anchors.fill: parent
      spacing: 12

      // User card: logo tile, user@host, uptime + clock chips.
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: userRow.implicitHeight + 28
        radius: Style.menuPanelRadius
        color: Style.m3container
        RowLayout {
          id: userRow
          anchors.fill: parent
          anchors.margins: 14
          spacing: 14
          Rectangle {
            width: 46; height: 46; radius: Style.menuRadiusLg
            color: Style.m3primaryContainer
            Text { anchors.centerIn: parent; text: "󰣛"; color: Style.m3primary; font.family: root.uiFont; font.pixelSize: 28 }
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { Layout.fillWidth: true; text: quickHubRoot.ffTitle; color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(17); font.weight: Font.DemiBold; elide: Text.ElideRight }
            Text { Layout.fillWidth: true; text: quickHubRoot.ffSubtitle; color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(11); elide: Text.ElideRight }
          }
          Rectangle {
            implicitWidth: upRow.implicitWidth + 22; implicitHeight: upRow.implicitHeight + 12
            radius: Style.menuRadiusFull; color: Style.m3tertiaryContainer
            Row {
              id: upRow; anchors.centerIn: parent; spacing: 6
              Text { text: "󰅐"; color: Style.m3onSurface; font.family: root.uiFont; font.pixelSize: root.fontPx(11); anchors.verticalCenter: parent.verticalCenter }
              Text { text: "up " + (quickHubRoot.ffUptime || "…"); color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
            }
          }
          Rectangle {
            implicitWidth: clockRow.implicitWidth + 22; implicitHeight: clockRow.implicitHeight + 12
            radius: Style.menuRadiusFull; color: Style.m3secondaryContainer
            Row {
              id: clockRow; anchors.centerIn: parent; spacing: 6
              Text { text: "󰥔"; color: Style.m3onSurface; font.family: root.uiFont; font.pixelSize: root.fontPx(11); anchors.verticalCenter: parent.verticalCenter }
              Text { text: Qt.formatTime(hubClock.date, "HH:mm:ss"); color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
            }
          }
        }
      }

      // Gauges: CPU / memory / storage / battery rings.
      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(root.launcherGeom.rowHTall * 2.7)
        Layout.maximumHeight: Layout.preferredHeight
        spacing: 12
        Repeater {
          model: [
            { label: "CPU", icon: "󰘚", key: "cpu", r: Style.menuRadiusLg },
            { label: "Memory", icon: "󰍛", key: "ram", r: Style.menuRadiusLg },
            { label: "Storage", icon: "󰋊", key: "disk", r: Style.menuRadiusLg },
            { label: "Battery", icon: "󰁹", key: "bat", r: Style.menuPanelRadius }
          ]
          delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: modelData.r
            color: Style.m3container
            Menu.MenuHudDial {
              anchors.fill: parent
              anchors.margins: 12
              value: ({ cpu: root.sidebarCpu, ram: root.sidebarMem, disk: quickHubRoot.ffDiskPct, bat: root.sidebarBat })[modelData.key]
              accent: ({ cpu: Style.m3primary, ram: Style.m3tertiary, disk: Style.m3secondary,
                bat: root.sidebarBat < 20 && root.sidebarBatStatus !== "Charging" ? Style.red : Style.green })[modelData.key]
              label: modelData.label
              icon: modelData.icon
              fontFamily: root.uiFont
              labelFamily: root.uiSans
            }
          }
        }
      }

      // Facts card.
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.menuPanelRadius
        color: Style.m3container
        GridLayout {
          id: ffInfoBody
          anchors.fill: parent
          anchors.margins: 16
          columns: 2
          columnSpacing: 24
          rowSpacing: 6
          Repeater {
            model: quickHubRoot.ffGridRows
            delegate: ffInfoRowDelegate
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
    // Carousel first; the filter + grid only when "All" is toggled.
    property bool showAll: false
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
      spacing: 8

      // Carousel, three tiles at a time: ←/→ or the wheel browse and preview
      // the centre tile live, ⏎ or a click on a tile applies it. Centred in the
      // leftover space while the list is collapsed.
      Item {
        id: wallHost
        Layout.fillWidth: true
        Layout.fillHeight: !quickWallpaperRoot.showAll
        Layout.preferredHeight: wallCarousel.implicitHeight
        Wallpaper.WallpaperCarousel {
          id: wallCarousel
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          height: implicitHeight
          viewW: wallHost.width
          paths: quickWallpaperRoot.filtered
          fontScale: root.uiFontScale
          fontFamily: root.uiSans
          iconFamily: root.uiFont
          anchorPath: Wallpaper.WallpaperService.currentWallpaper
          live: root.shouldShow
          onActivated: function(p) { Wallpaper.WallpaperService.setWallpaper(p); root.expandedQuickKey = "" }
          Component.onCompleted: root.wallCarousel = wallCarousel
          Component.onDestruction: { if (root.wallCarousel === wallCarousel) root.wallCarousel = null; Wallpaper.WallpaperService.stopPreview() }
        }
      }
      Text {
        id: wallPathCaption
        Layout.fillWidth: true
        text: (wallCarousel.currentPath || "").split("/").pop() || "—"
        color: Style.m3onSurface
        font.family: root.uiSans
        font.pixelSize: root.fontPx(10)
        font.weight: Font.Medium
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignHCenter
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Item { Layout.fillWidth: true }
        Rectangle {
          implicitWidth: shuffleRow.implicitWidth + 20; implicitHeight: 26; radius: Style.menuRadiusFull
          color: shuffleMa.containsMouse ? Style.m3containerHigh : Style.m3container
          Row {
            id: shuffleRow; anchors.centerIn: parent; spacing: 6
            Text { text: "󰒝"; color: Style.m3primary; font.family: root.uiFont; font.pixelSize: root.fontPx(11); anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Shuffle"; color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(9); font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
          }
          MouseArea { id: shuffleMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wallCarousel.jumpTo(Wallpaper.WallpaperService.randomWallpaper()) }
        }
        Rectangle {
          implicitWidth: applyRow.implicitWidth + 20; implicitHeight: 26; radius: Style.menuRadiusFull
          color: applyMa.containsMouse ? Qt.lighter(Style.m3primary, 1.1) : Style.m3primary
          Row {
            id: applyRow; anchors.centerIn: parent; spacing: 6
            Text { text: "󰄬"; color: Style.m3onPrimary; font.family: root.uiFont; font.pixelSize: root.fontPx(11); anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Apply"; color: Style.m3onPrimary; font.family: root.uiSans; font.pixelSize: root.fontPx(9); font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
          }
          MouseArea { id: applyMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wallCarousel.activate() }
        }
        Rectangle {
          implicitWidth: allRow.implicitWidth + 20; implicitHeight: 26; radius: Style.menuRadiusFull
          color: quickWallpaperRoot.showAll ? Style.m3secondaryContainer : (allMa.containsMouse ? Style.m3containerHigh : Style.m3container)
          Row {
            id: allRow; anchors.centerIn: parent; spacing: 6
            Text { text: quickWallpaperRoot.showAll ? "󰅃" : "󰅀"; color: Style.m3onSurface; font.family: root.uiFont; font.pixelSize: root.fontPx(11); anchors.verticalCenter: parent.verticalCenter }
            Text { text: "All " + ((quickWallpaperRoot.wps || []).length || 0); color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(9); font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
          }
          MouseArea { id: allMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { quickWallpaperRoot.showAll = !quickWallpaperRoot.showAll; if (quickWallpaperRoot.showAll) wpIn.forceActiveFocus(); else { quickWallpaperRoot.wpSearch = ""; wpIn.text = ""; root.focusLauncherInput() } } }
        }
      }

      Item {
        visible: quickWallpaperRoot.showAll
        Layout.fillWidth: true; Layout.preferredHeight: 26
        Rectangle {
          anchors.fill: parent; radius: height / 2; color: Style.m3container
          TextInput {
            id: wpIn; anchors.fill: parent; anchors.margins: 3; anchors.leftMargin: 12
            color: Style.menuInk; font.pixelSize: root.fontPx(10); font.family: root.uiFont
            text: quickWallpaperRoot.wpSearch
            onTextChanged: quickWallpaperRoot.wpSearch = text
            Keys.onEscapePressed: { quickWallpaperRoot.wpSearch = ""; wpIn.text = "" }
          }
          Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "Filter wallpapers"; color: Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(9); font.family: root.uiSans; visible: wpIn.text === "" && !wpIn.activeFocus }
        }
      }
      Text {
        visible: quickWallpaperRoot.showAll && (quickWallpaperRoot.filtered || []).length === 0
        text: quickWallpaperRoot.wpSearch ? "No matching wallpapers" : "No wallpapers (rescan in bg)"
        color: Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont
        Layout.alignment: Qt.AlignHCenter; Layout.preferredHeight: 20
      }
      GridView {
        id: wpGrid
        visible: quickWallpaperRoot.showAll
        Layout.fillWidth: true; Layout.fillHeight: quickWallpaperRoot.showAll && (quickWallpaperRoot.filtered || []).length > 0
        cellWidth: Math.max(1, Math.floor((Math.max(0, width - rightMargin - 4)) / 4)); cellHeight: cellWidth * 0.62 + 4
        clip: true; model: quickWallpaperRoot.filtered
        // Scroll perf: pool delegates instead of destroying them mid-flick,
        // pre-create extra rows beyond the viewport, and drop the synchronous
        // layout thrash of Flickable's animated wheel response in favor of
        // direct contentY steps (omarchy's pickers feel instant for the same
        // reason — no kinetic animation on wheel).
        reuseItems: true
        cacheBuffer: Math.max(800, cellHeight * 5)
        boundsBehavior: Flickable.StopAtBounds
        rightMargin: 12
        ScrollBar.vertical: Menu.MenuScrollBar {}
        WheelHandler {
          target: null
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(ev) {
            const step = WallThumbs.wheelStep(ev.pixelDelta.y, ev.angleDelta.y, wpGrid.cellHeight)
            wpGrid.contentY = WallThumbs.clampedContentY(wpGrid.contentY, step, wpGrid.contentHeight, wpGrid.height)
            ev.accepted = true
          }
        }
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
              anchors.fill: parent; anchors.margins: (Wallpaper.WallpaperService.currentWallpaper === modelData) ? 2 : 1
              source: Wallpaper.WallpaperService.previewSource(modelData)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
              // Cap decode + texture at thumb resolution even if a source
              // ever resolves to a full-size image.
              sourceSize.width: 320
              sourceSize.height: 192
              Rectangle {
                anchors.fill: parent; color: Style.menuControlBg; visible: parent.status !== Image.Ready
                Text { anchors.centerIn: parent; text: "󰋩"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(18); font.family: root.uiFont }
              }
            }
            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 14; color: Qt.rgba(0,0,0,0.55)
              Text {
                anchors.centerIn: parent
                text: (modelData || "").split("/").pop()
                color: Style.menuOverlayLight; font.pixelSize: root.fontPx(7); font.family: root.uiFont
                elide: Text.ElideMiddle; width: parent.width-4; horizontalAlignment: Text.AlignHCenter
              }
            }
            Rectangle {
              anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 3
              width: 14; height: 14; radius: 7; color: Style.green
              visible: Wallpaper.WallpaperService.currentWallpaper === modelData
              Text { anchors.centerIn: parent; text: "✓"; color: Style.menuOnAccent; font.pixelSize: 9; font.bold: true }
            }
            MouseArea {
              id: wma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: function(e) {
                if (e.button === Qt.RightButton) {
                  if (modelData) Quickshell.execDetached([binDir + "/asahi-launch", "xdg-open", modelData])  // preview action
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
        Text { text: "←/→ or ctrl+h/l browse · ⏎ or click applies · All lists every wallpaper"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiSans }
        Item { Layout.fillWidth: true }
        Text {
          text: ((Wallpaper.WallpaperService.currentWallpaper || "").split("/").pop() || "none")
          color: Style.menuSeal
          font.pixelSize: root.fontPx(8)
          font.family: root.uiFont
          elide: Text.ElideMiddle
          Layout.maximumWidth: Math.round(140 * root.launcherGeom.uiScale)
        }
        Text { text: ((quickWallpaperRoot.wps || []).length || 0) + " wallpapers"; color: Style.menuInkDeep; font.pixelSize: root.fontPx(8); font.family: root.uiFont }
      }
    }
  } }
  Component { id: quickScreenshotsComp; Panes.ScreenshotsPane { root: launcherSelf } }
  Component { id: quickMediaComp; Panes.MediaPane { root: launcherSelf } }
  Component { id: quickNetworkComp; Panes.NetworkPane { root: launcherSelf } }
  Component { id: quickMonitorsComp; Panes.MonitorsPane { root: launcherSelf } }
  Component { id: quickTempComp; Panes.TempPane { root: launcherSelf } }
  Component { id: quickBatteryComp; Panes.BatteryPane { root: launcherSelf } }
  Component { id: quickBtComp; Panes.BluetoothPane { root: launcherSelf } }
  Component { id: quickStorageComp; Panes.StoragePane { root: launcherSelf } }
  Component { id: quickClipboardComp; Panes.ClipboardPane { root: launcherSelf } }

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
      case "battery": return quickBatteryComp
      case "bluetooth": return quickBtComp
      case "storage": return quickStorageComp
      case "clipboard": return quickClipboardComp
      default: return quickDefaultComp
    }
  }

  readonly property string sectionIcon: {
    if (root.categoryFilter === "") return ""
    for (let i = 0; i < Data.categoryNav.length; i++) {
      if (Data.categoryNav[i].target === root.categoryFilter)
        return Data.categoryNav[i].icon || ""
    }
    return ""
  }

  readonly property string sectionName: {
    const q = root.query.trim()
    if (root.categoryFilter !== "") return root.categoryFilter
    if (q.startsWith("=")) return "Calculator"
    if (q.startsWith("!")) return "Web Search"
    if (q.startsWith("@")) return "Documentation"
    if (q.startsWith(":")) return "Actions"
    if (q.startsWith("?")) return "Keys"
    if (q.startsWith(";")) return "Emoji"
    if (root.fileTerm(q) !== null) return "Files"
    if (root.dictTerm(q) !== null) return "Dictionary"
    return ""
  }

  readonly property string headerHintText: {
    if (root.quickMode)
      return root.quickPaneKey !== "hub"
        ? "↑↓ command · esc cluster"
        : "↑↓ command · ↩ open · esc leave"
    if (root.argArmed) return "type argument · ↩ go · tab results"
    if (root.fileMode) return "↑↓ / tab · open file · esc back"
    return "↓ / tab · ↩ open · esc close"
  }

  readonly property string headerText: {
    const q = root.query.trim()
    if (root.categoryFilter !== "") return "› " + root.categoryFilter.toUpperCase()
    if (q.startsWith("=")) return "Calculator"
    if (q.startsWith("!")) return "Web Search"
    if (q.startsWith("@")) return "Documentation"
    if (q.startsWith(":")) return "Actions"
    if (q.startsWith("?")) return "› KEYS"
    if (q.startsWith(";")) return "› EMOJI"
    if (root.fileTerm(q) !== null) return "File Search"
    if (root.dictTerm(q) !== null) return "Dictionary"
    return "LAUNCHER"
  }

  readonly property string resultText: {
    const c = root.resultCount
    const s = c !== 1 ? "s" : ""
    const matches = c === 1 ? "match" : "matches"
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
      if (root.dictStatus === "prompt") return root.argArmed ? "Type a word to translate" : "Tab to type a word"
      if (root.dictStatus === "no-results") return "No translations"
      const lang = root.dictCopyLang === "en" ? "English" : (root.dictCopyLang === "de" ? "German" : "translation")
      return c + " result" + s + " · Return copies " + lang
    }
    if (qq.startsWith(":")) return c + " action" + s
    if (qq.startsWith("?")) return c + " shortcut" + s
    if (qq.startsWith(";")) return c + " emoji" + s
    if (qq.startsWith("=") || qq.startsWith("!") || qq.startsWith("@")) return c + " result" + s
    if (root.categoryFilter !== "") {
      if (root.quickMode) {
        const n = (root.quickDeck || []).length
        return n + " commands · cluster live"
      }
      if (root.categoryFilter === "App") {
        const n = (DesktopEntries.applications.values || []).filter(d => !d.noDisplay && !root.isHiddenApp(d)).length
        return c + " " + matches + " · " + n + " total"
      }
      if (root.categoryFilter === "Actions") {
        const n = (root.quickActions || []).length
        return c + " action" + s + " · " + n + " total"
      }
      if (root.categoryFilter === "Keys") {
        const n = (root.keyBinds || []).length
        return c + " shortcut" + s + " · " + n + " total"
      }
      if (root.categoryFilter === "Websearch") {
        const n = (root.webEngines || []).length
        return c + " engine" + s + " · " + n + " total"
      }
      if (root.categoryFilter === "Emoji") {
        return c + " emoji" + s + " · " + Emoji.EMOJI.length + " total"
      }
      const n = (root.launcherItems || []).filter(x => x.category === root.categoryFilter).length
      return c + " " + matches + " · " + n + " total"
    }
    if (qq.length === 0) {
      const total = (root.launcherItems || []).length + (DesktopEntries.applications.values || []).length
      return c + " entries · " + total + " total"
    }
    return c + " " + matches
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
    if (root.shouldShow) {
      chromeHideKick.stop()
      root.panelVisible = true
      root.chromeReveal = 0
      chromeRevealKick.restart()
      root.focusLauncherInput()
    } else {
      root.chromeReveal = 0
      root.shotPreviewPath = ""
      Wallpaper.WallpaperService.stopPreview()
      chromeHideKick.restart()
    }
  }

  onCategoryFilterChanged: {
    if (resultsList) resultsList.currentIndex = 0
    root.selectedIndex = 0
    if (root.categoryFilter === "Keys") root.scanKeyBinds()
    if (root.fileMode) root.scheduleFileLookup()
    else { root.fileItems=[]; root.fileStatus=""; root.filePreviewText=""; root.filePreviewMeta=""; root.pdfPreviewPath=""; root.pdfPreviewVersion=0 }
    if (root.categoryFilter === "Quick") {
      root.setSearchQuery("")
      if (root.expandedQuickKey === "") root.expandedQuickKey = "hub"
    } else {
      root.expandedQuickKey = ""
    }
    if (root.categoryFilter === Data.fileCategory && (root.query || "").trim() === "") {
      root.setSearchQuery(">")
    }
    if (root.categoryFilter === "Actions" && !(root.query || "").trim().startsWith(":")) {
      root.setSearchQuery(":")
    }
    if (root.categoryFilter === "Keys" && !(root.query || "").trim().startsWith("?")) {
      root.setSearchQuery("?")
    }
    if (root.categoryFilter === "Websearch" && !(root.query || "").trim().startsWith("@")) {
      root.setSearchQuery("@")
    }
    if (root.categoryFilter === "Emoji" && !(root.query || "").trim().startsWith(";")) {
      root.setSearchQuery(";")
    }
    if (root.shouldShow) root.focusLauncherInput()
  }

  function currentResultEntry() {
    if (resultsList && resultsList.currentItem && resultsList.currentItem.modelData)
      return resultsList.currentItem.modelData
    if (filteredApps && filteredApps.values && resultsList && resultsList.currentIndex < filteredApps.values.length)
      return filteredApps.values[resultsList.currentIndex]
    return null
  }

  function setSearchQuery(q) {
    root.argCommand = ""
    root.argPlaceholder = ""
    root.query = q || ""
    if (searchInput) searchInput.text = root.query
  }

  function armArgument(command, hint) {
    const cmd = command || ""
    if (!cmd) return
    const arg = ArgCommands.argFromQuery(root.query, cmd)
    root.argCommand = cmd
    root.argPlaceholder = hint || ArgCommands.placeholder(cmd)
    root.query = ArgCommands.join(cmd, arg)
    if (searchInput) {
      if (searchInput.text !== arg) searchInput.text = arg
      searchInput.forceActiveFocus()
    }
  }

  function clearArgument() {
    if (!root.argCommand) return
    const cmd = root.argCommand
    root.argCommand = ""
    root.argPlaceholder = ""
    root.query = cmd
    if (searchInput) searchInput.text = cmd
  }

  function tryArmArgument() {
    if (root.argArmed) {
      const arg = searchInput ? String(searchInput.text || "").trim() : ""
      return !arg
    }
    const armed = ArgCommands.tabArm(root.query, root.currentResultEntry(), root.webEngines)
    if (!armed) return false
    root.armArgument(armed.command, armed.placeholder)
    return true
  }

  // Wallpaper pane: ←/→ move the carousel, ⏎ applies the centre item.
  function quickWallKey(qk) {
    if (root.quickPaneKey !== "wallpaper" || !root.wallCarousel) return false
    if (qk === Qt.Key_Left) { root.wallCarousel.prev(); return true }
    if (qk === Qt.Key_Right) { root.wallCarousel.next(); return true }
    if (qk === Qt.Key_Return || qk === Qt.Key_Enter) { root.wallCarousel.activate(); return true }
    return false
  }

  function activateDeckItem(t) {
    if (!t) return
    if (t.mode) {
      root.expandQuick(t.key || t.mode)
      return
    }
    if (t.ipc) {
      Quickshell.execDetached(["qs", "-c", "remix", "ipc", "call", t.ipc, "toggle"])
      root.shouldShow = false
      return
    }
    if (t.command && t.command.length) {
      Quickshell.execDetached(root.resolveCmd(t.command))
      root.shouldShow = false
    }
  }

  function launchCurrent() {
    if (root.quickMode) {
      root.activateDeckItem((root.quickDeck || [])[root.selectedIndex])
      return
    }
    const entry = root.currentResultEntry()
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
    root.setSearchQuery("")
    if (resultsList) resultsList.currentIndex = 0
    root.focusLauncherInput()
  }

  function openFileSearch(term) {
    if (!root.shouldShow) root.openLauncher()
    root.setSearchQuery(">" + (term || ""))
    root.focusLauncherInput()
  }

  function openCategory(cat) {
    if (!root.shouldShow) root.openLauncher()
    root.categoryFilter = cat || ""
    root.setSearchQuery(root.categoryFilter === Data.fileCategory ? ">"
      : (root.categoryFilter === "Actions" ? ":"
        : (root.categoryFilter === "Keys" ? "?"
          : (root.categoryFilter === "Websearch" ? "@"
            : (root.categoryFilter === "Emoji" ? ";" : "")))))
    root.selectedIndex = 0
    root.expandedQuickKey = ""
    root.focusLauncherInput()
  }

  function openQuick(key) {
    if (!root.shouldShow) root.openLauncher()
    root.categoryFilter = "Quick"
    root.setSearchQuery("")
    const k = key === "dashboard" ? "hub" : (key === "vpn" ? "network" : (key || "hub"))
    root.expandedQuickKey = k
    const idx = (root.quickDeck || []).findIndex(function(t) { return t.mode === k || t.key === k })
    root.selectedIndex = Math.max(0, idx)
    if (k === "clipboard") root.scanClips()
    if (k === "screenshots") root.scanShots()
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
    if (!root.quickMode) { root.categoryFilter = "Quick"; root.setSearchQuery("") }
    root.expandedQuickKey = (k === "hub" || root.quickPaneKey === k) ? "hub" : k
    if (root.expandedQuickKey === "screenshots") root.scanShots()
    if (root.expandedQuickKey === "storage") root.scanStorage()
    if (root.expandedQuickKey === "clipboard") root.scanClips()
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
    // Prefer the scanned app/device index: Qt's themed cache never re-scans
    // after startup, so apps installed mid-session resolve blank without it.
    const found = root.iconIndex[icon]
    if (found) return "file://" + found
    return Quickshell.iconPath(icon, "")
  }

  function actionMatches(action, term) {
    if (!term) return true
    const values = [action.key, action.name].concat(action.aliases || [])
    return values.some(v => String(v || "").toLowerCase().includes(term))
  }

  // Live state decoration for toggle actions (currently nightlight only).
  function actionLabel(a) {
    root.nightVersion
    if (a.key === "nightlight" && root.nightLightOn) return a.name + " ✓"
    return a.name
  }

  function actionGlyph(a) {
    root.nightVersion
    if (a.key === "nightlight" && root.nightLightOn) return "󰽥"
    return a.icon
  }

  function getActionResults(q) {
    const value = (q || "").trim()
    if (!value.startsWith(":")) return null
    const term = value.substring(1).trim().toLowerCase()
    if (/^timer\s+\S/.test(term)) {
      const t = ArgCommands.parseTimer(value.substring(1))
      if (!t) return [{ id: "timer-bad", name: "Timer: 10m · 1:30 · 1h15m [label]", comment: "duration not understood", glyph: "󰔛", special: "noop" }]
      return [{
        id: "timer-add", name: "Start timer · " + ArgCommands.formatSeconds(t.seconds) + " · " + t.label,
        comment: "notifies when done · bar chip cancels", glyph: "󰔛", special: "action",
        command: [root.binDir + "/asahi-timer", "add", t.duration, t.label]
      }]
    }
    const actions = root.quickActions.filter(a => root.actionMatches(a, term))
    if (actions.length === 0) {
      return [{ id: "action-empty", name: "No action found", comment: term, glyph: "󰅙", special: "noop" }]
    }
    return actions.map(a => ({
      id: "action-" + a.key,
      name: root.actionLabel(a),
      comment: a.comment || "",
      glyph: root.actionGlyph(a),
      special: "action",
      mode: a.mode || "",
      ipc: a.ipc || "",
      query: a.query || "",
      command: a.command || []
    }))
  }

  function launchDesktopEntry(entry) {
    root.bumpAppUsage(entry)
    root.beginLaunchFeedback(entry.name)
    const command = Array.from(entry.command || [])
    const exec = command.length > 0 ? command.map(root.shQuote).join(" ") : String(entry.execString || "")
    if (exec === "") {
      entry.execute()
      return
    }

    const ws = root.launcherWorkspaceId || Hyprland.focusedWorkspace?.id || 1
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + ws + " })"])
    const launchPrefix = (command.length > 0 ? (binDir + "/asahi-launch ") : "uwsm-app -- ")
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exec_cmd(" + root.luaQuote("[workspace " + ws + "] " + launchPrefix + exec) + ")"])
  }

  function launchApp(entry) {
    if (!entry) { shouldShow = false; return }
    if (entry.isCategory || entry.target) {
      // Drill into category overview (launcher style) or quick action target
      const tgt = entry.target || entry.category || ""
      if (tgt) {
        root.categoryFilter = tgt
        root.setSearchQuery(tgt === Data.fileCategory ? ">"
          : (tgt === "Actions" ? ":"
            : (tgt === "Keys" ? "?"
              : (tgt === "Websearch" ? "@"
                : (tgt === "Emoji" ? ";" : "")))))
        root.selectedIndex = 0
        root.expandedQuickKey = ""
        if (tgt === Data.fileCategory) root.scheduleFileLookup()
        return
      }
    }
    if (entry.id === "dict-prompt") {
      root.armArgument("dict")
      return
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
      Quickshell.execDetached([binDir + "/asahi-launch", "xdg-open", entry.path])
    } else if (entry.special === "emoji") {
      const copy = entry.copy || entry.glyph || ""
      if (copy) Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", copy])
    } else if (entry.special === "action") {
      if (entry.query) {
        root.setSearchQuery(entry.query)
        root.focusLauncherInput()
        return
      }
      if (entry.mode) {
        root.categoryFilter = "Quick"
        root.setSearchQuery("")
        root.expandQuick(entry.mode)
        return
      } else if (entry.ipc) {
        Quickshell.execDetached(["qs", "-c", "remix", "ipc", "call", entry.ipc, "toggle"])
        root.shouldShow = false
        return
      } else if (entry.command && entry.command.length > 0) {
        Quickshell.execDetached(root.resolveCmd(entry.command))
        root.shouldShow = false
      }
    } else if ((entry.special === "web" || entry.special === "doc") && entry.url) {
      if (entry.prefix) {
        root.armArgument("@" + entry.prefix, ArgCommands.placeholder("@" + entry.prefix, entry))
        root.selectedIndex = 0
        return
      }
      const web = ArgCommands.parse(root.query, root.webEngines)
      if (web && web.command.charAt(0) === "@" && web.command.length > 1 && !web.arg) {
        root.armArgument(web.command, ArgCommands.placeholder(web.command, entry))
        return
      }
      let u = entry.url
      if (u.includes("%TERM%")) u = u.replace("%TERM%", "")
      u = u.replace(/\?q=$/, "").replace(/\?s=$/, "").replace(/&text=$/, "").replace(/search\?q=$/, "")
      Quickshell.execDetached([binDir + "/asahi-launch", "xdg-open", u])
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
    if (t.startsWith(">") || t.startsWith("@") || t.startsWith(":") || t.startsWith("?")
        || t.startsWith("=") || t.startsWith("!") || t.startsWith(";")) return true
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

  function buildFdArgs(tokens) {
    const args = ["--type", "f", "--max-results", "200"]
    const excludes = Data.fdExcludes
    for (let i = 0; i < excludes.length; i++) {
      args.push("--exclude")
      args.push(excludes[i])
    }
    const raw = tokens.join(" ")
    const hasSlash = raw.indexOf("/") >= 0
    const hasGlob = raw.indexOf("*") >= 0 || raw.indexOf("?") >= 0
    if (hasSlash) {
      args.push("--glob")
      args.push("--full-path")
      const prefix = (raw[0] === "*" || raw[0] === "/") ? "" : "**/"
      args.push(prefix + raw)
    } else if (hasGlob) {
      args.push("--glob")
      args.push(raw)
    } else {
      args.push(tokens.join(".*"))
    }
    args.push(Quickshell.env("HOME"))
    return args
  }

  function startFileLookup() {
    const term = root.filePendingTerm
    if (!term || fileProc.running) return
    root.fileRunningTerm = term
    root.fileStatus = "loading"
    root.fileVersion++
    const tokens = term.toLowerCase().split(/\s+/).filter(t => t.length > 0)
    fileProc.command = ["fd"].concat(root.buildFdArgs(tokens))
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
      return [{ id: "file-prompt", name: "Search files in ~", comment: "Globs: docs/*.txt  Regex: word1 word2", icon: "", glyph: "󰍉", special: "noop" }]
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
      root.abortDictXhr()
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
      root.abortDictXhr()
      root.dictStatus = "prompt"
      root.dictCopyLang = ""
      root.dictError = ""
      root.dictItems = []
      root.dictVersion++
      return
    }
    const q = DictCC.parseQuery(term, root.dictDefaults)
    const cached = q.term ? DictCC.cacheGet(q.sourceLanguage, q.targetLanguage, q.term) : undefined
    if (cached) {
      root.abortDictXhr()
      root.dictStatus = cached.items.length > 0 ? "ok" : "no-results"
      root.dictCopyLang = cached.copyLang
      root.dictError = ""
      root.dictItems = cached.items
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

  function abortDictXhr() {
    const xhr = root.dictXhr
    root.dictXhr = null
    if (xhr) xhr.abort()
  }

  function startDictLookup() {
    const term = root.dictPendingTerm
    if (!term) return
    root.abortDictXhr()
    root.dictRunningTerm = term
    root.dictStatus = "loading"
    root.dictVersion++
    const q = DictCC.parseQuery(term, root.dictDefaults)
    const xhr = new XMLHttpRequest()
    root.dictXhr = xhr
    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      if (root.dictXhr !== xhr) return
      root.dictXhr = null
      if (xhr.status !== 200) {
        root.finishDictLookup(term, {
          status: "error",
          copyLang: "",
          error: xhr.status ? "dict.cc " + xhr.status : "Network error",
          items: []
        })
        return
      }
      let result
      try {
        const copyLang = DictCC.copyLangFromUrl(xhr.responseURL || "", q.targetLanguage)
        const items = DictCC.parseHits(xhr.responseText, q.term, copyLang)
        DictCC.cachePut(q.sourceLanguage, q.targetLanguage, q.term, { items: items, copyLang: copyLang, url: "" })
        result = { status: items.length > 0 ? "ok" : "no-results", copyLang: copyLang, error: "", items: items }
      } catch (e) {
        result = { status: "error", copyLang: "", error: "" + e, items: [] }
      }
      root.finishDictLookup(term, result)
    }
    xhr.open("GET", DictCC.buildUrl(q.sourceLanguage, q.targetLanguage, q.term))
    xhr.timeout = 8000
    xhr.send()
  }

  function finishDictLookup(term, result) {
    if (term === root.dictPendingTerm && term === dictTerm(root.query)) {
      root.dictStatus = result.status || "error"
      root.dictCopyLang = result.copyLang || ""
      root.dictError = result.error || ""
      root.dictItems = result.items || []
      root.dictVersion++
    }
    if (root.dictPendingTerm && root.dictPendingTerm !== term) dictDebounce.restart()
  }

  function getDictResults(q) {
    const term = dictTerm(q)
    if (term === null) return null
    if (!term) {
      return [{
        id: "dict-prompt",
        name: "Translate with dict.cc",
        comment: "Tab to type a word · en de Term for language override",
        icon: root.dictIcon,
        special: "noop"
      }]
    }
    if (root.dictStatus === "loading") {
      return [{ id: "dict-loading", name: "Looking up " + term, comment: "dict.cc", icon: root.dictIcon, special: "noop" }]
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
      const metaLine = DictCC.metaText(it.meta)
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
    interval: 150
    onTriggered: root.startDictLookup()
  }

  // websearch: @ uses engines[] (fuzzy lists + prefix direct). ! passes the literal text to Kagi via defaultSearchUrl.
  // Seeded empty; FileView.text() fills from websearch.json (Startpage, wikis, …).
  property var webEngines: []
  property string defaultSearchUrl: "https://kagi.com/search?q=%s"

  // FileView.text() is a method, not a property — passing bare `text` into
  // JSON.parse throws and silently kept the old hardcoded list (no "sp").
  FileView {
    id: websearchConfig
    path: root.websearchJsonPath
    watchChanges: true
    blockLoading: true
    onFileChanged: reload()
    onLoaded: root.parseWebsearchConfig(websearchConfig.text())
    onTextChanged: if (root) root.parseWebsearchConfig(websearchConfig.text())
    onLoadFailed: root.parseWebsearchConfig("")
  }

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() { root.deVersion++; iconIndexDebounce.restart() }
  }

  // --- Icon fallback index: one find over the XDG icon dirs into name -> path.
  // SVGs are listed before PNGs so the first hit per name prefers scalable.
  function iconIndexScanCommand() {
    return [
      'dirs="$HOME/.icons $HOME/.local/share/icons";',
      'IFS=":"; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done; unset IFS;',
      'for ext in svg png; do',
      '  for base in $dirs; do',
      '    [ -d "$base" ] && find "$base" \\( -path "*/apps/*" -o -path "*/devices/*" \\) -name "*.$ext" 2>/dev/null;',
      '  done;',
      '  find /usr/share/pixmaps -maxdepth 1 -name "*.$ext" 2>/dev/null;',
      'done'
    ].join(' ')
  }

  function indexIconLine(path) {
    const value = String(path || "").trim()
    if (value.length === 0) return
    const slash = value.lastIndexOf("/")
    const file = slash >= 0 ? value.slice(slash + 1) : value
    const dot = file.lastIndexOf(".")
    const name = dot > 0 ? file.slice(0, dot) : file
    if (name.length > 0 && root.pendingIconIndex[name] === undefined)
      root.pendingIconIndex[name] = value
  }

  Process {
    id: iconIndexScan
    command: ["bash", "-c", root.iconIndexScanCommand()]
    stdout: SplitParser { onRead: line => root.indexIconLine(line) }
    onStarted: root.pendingIconIndex = ({})
    // Swapping the property re-evaluates every resolveIconUrl binding.
    onExited: root.iconIndex = root.pendingIconIndex
  }

  // Coalesces bursts of app-list changes (a dnf install touches many entries).
  Timer {
    id: iconIndexDebounce
    interval: 750
    onTriggered: if (!iconIndexScan.running) iconIndexScan.running = true
  }

  // --- Hidden desktop entries (launcher.hides: one id per line, # comments).
  function isHiddenApp(a) {
    return root.hiddenAppIds[String((a && a.id) || "")] === true
  }

  function parseHides(text) {
    const next = {}
    const lines = String(text || "").split("\n")
    for (let i = 0; i < lines.length; i++) {
      let id = lines[i].trim()
      if (!id || id.charAt(0) === "#") continue
      if (id.endsWith(".desktop")) id = id.slice(0, -8)
      next[id] = true
    }
    root.hiddenAppIds = next
    root.hiddenVersion++
  }

  FileView {
    id: hidesFile
    path: root.hidesPath
    watchChanges: true
    printErrors: false
    onLoaded: root.parseHides(text)
    onTextChanged: if (root) root.parseHides(text)
    onLoadFailed: root.parseHides("")
  }

  // --- Nightlight state for the Actions checkmark (written by asahi-nightlight).
  function parseNightState(text) {
    try {
      const data = JSON.parse(String(text || "").trim())
      root.nightLightOn = !!data.on
    } catch (e) {
      root.nightLightOn = false
    }
    root.nightVersion++
  }

  FileView {
    id: nightStateFile
    path: root.nightStatePath
    watchChanges: true
    printErrors: false
    onLoaded: root.parseNightState(text)
    onTextChanged: if (root) root.parseNightState(text)
    onLoadFailed: root.parseNightState("")
  }

  // --- Keyboard shortcuts: parse `hyprctl binds` into { combo, desc } rows.
  function scanKeyBinds() {
    if (!keyBindsProc.running) keyBindsProc.running = true
  }

  function bindCombo(b) {
    let key = String(b.key || "")
    // Lua binds may report "SUPER + <key>"; mods are carried in modmask.
    const plus = key.lastIndexOf(" + ")
    if (plus >= 0) key = key.slice(plus + 3)
    if (!key && b.keycode && b.keycode !== "0") key = "code:" + b.keycode
    if (!key || key.indexOf("switch:") === 0) return ""
    const mouseNames = {
      "mouse:272": "LeftClick", "mouse:273": "RightClick", "mouse:274": "MiddleClick",
      "mouse_down": "ScrollDown", "mouse_up": "ScrollUp"
    }
    if (mouseNames[key]) key = mouseNames[key]
    // Binds given as raw keycodes would otherwise read "code:12".
    // Labels follow de(mac_nodeadkeys): AD11 is "ü", AD12 is "+".
    const codeNames = {
      "code:12": "3", "code:13": "4", "code:14": "5",
      "code:34": "ü", "code:35": "+"
    }
    if (codeNames[key]) key = codeNames[key]
    const mask = Number(b.modmask) || 0
    const parts = []
    if (mask & 64) parts.push("Super")
    if (mask & 4) parts.push("Ctrl")
    if (mask & 8) parts.push("Alt")
    if (mask & 1) parts.push("Shift")
    parts.push(key)
    return parts.join("+")
  }

  function parseHyprBinds(text) {
    const rows = []
    const seen = {}
    const lines = String(text || "").split("\n")
    let cur = null
    const flush = function() {
      if (!cur) return
      const desc = (cur.description || "").trim()
      const combo = root.bindCombo(cur)
      // Repeat variants (binde) duplicate their base bind; keep the first.
      const dedup = combo + "|" + desc
      if (desc && combo && !seen[dedup]) {
        seen[dedup] = true
        rows.push({ combo: combo, desc: desc })
      }
      cur = null
    }
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      if (line.indexOf("bind") === 0) { flush(); cur = {}; continue }
      if (!cur) continue
      const m = line.match(/^\t([a-z]+): ?(.*)$/)
      if (m) cur[m[1]] = m[2]
    }
    flush()
    root.keyBinds = rows
    root.keysVersion++
  }

  Process {
    id: keyBindsProc
    command: ["hyprctl", "binds"]
    stdout: StdioCollector {
      onStreamFinished: root.parseHyprBinds(text)
    }
  }

  // --- Launch feedback: "Launching X…" toast when no window shows within 2s.
  function toplevelCount() {
    try { return ToplevelManager.toplevels.values.length } catch (e) { return 0 }
  }

  function beginLaunchFeedback(name) {
    root.launchToplevelCount = root.toplevelCount()
    root.launchActiveToplevel = ToplevelManager.activeToplevel
    root.launchFeedbackName = String(name || "application")
    launchDelay.restart()
    launchTimeout.restart()
  }

  function closeLaunchFeedback() {
    launchDelay.stop()
    launchTimeout.stop()
    if (root.launchOsdOpen) {
      if (root.osd && root.osd.dismissToast) root.osd.dismissToast()
      root.launchOsdOpen = false
    }
  }

  function maybeFinishLaunchFeedback() {
    if (!launchDelay.running && !launchTimeout.running && !root.launchOsdOpen) return
    if (root.toplevelCount() <= root.launchToplevelCount && ToplevelManager.activeToplevel === root.launchActiveToplevel) return
    root.closeLaunchFeedback()
  }

  Timer {
    id: launchDelay
    interval: 2000
    onTriggered: {
      if (root.toplevelCount() > root.launchToplevelCount || ToplevelManager.activeToplevel !== root.launchActiveToplevel) return
      if (root.osd && root.osd.toast) {
        root.launchOsdOpen = true
        root.osd.toast("󱓞", "Launching " + root.launchFeedbackName + "…", "", 0)
      }
    }
  }

  Timer {
    id: launchTimeout
    interval: 15000
    onTriggered: root.closeLaunchFeedback()
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() { root.maybeFinishLaunchFeedback() }
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { root.maybeFinishLaunchFeedback() }
  }

  Component.onCompleted: iconIndexScan.running = true

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
      const parsed = WebSearch.parseConfig(text, root.webIconBase)
      if (parsed && parsed.engines.length > 0) {
        webEngines = parsed.engines
        if (parsed.defaultSearchUrl) defaultSearchUrl = parsed.defaultSearchUrl
      }
    } catch (e) {
    }
    webVersion++
  }

  function getSpecialResults(qq) {
    const q = (qq || "").trim()
    if (!q) return null
    const actionResults = getActionResults(q)
    if (actionResults) return actionResults
    const emojiResults = getEmojiResults(q)
    if (emojiResults) return emojiResults
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
        const p = (e.prefix || "").toLowerCase()
        if (!p) continue
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
    if (root.quickMode && root.quickPaneKey !== "hub") {
      root.expandedQuickKey = "hub"
      root.focusLauncherInput()
      return
    }
    if (root.argArmed) {
      root.clearArgument()
      root.focusLauncherInput()
      return
    }
    if (root.quickMode || root.categoryFilter !== "") {
      root.categoryFilter = ""
      root.setSearchQuery("")
      root.selectedIndex = 0
      root.expandedQuickKey = ""
      root.focusLauncherInput()
      return
    }
    root.shouldShow = false
  }

  // ---------- Launcher port: scoring + category overview (following bjarneo launcher ref style) ----------
  function goUp() {
    if (root.quickMode && root.quickPaneKey !== "hub") {
      root.expandedQuickKey = "hub"
      return true
    }
    if (root.argArmed) {
      root.clearArgument()
      return true
    }
    if (root.categoryFilter !== "") {
      root.categoryFilter = ""
      root.setSearchQuery("")
      root.selectedIndex = 0
      root.expandedQuickKey = ""
      return true
    }
    return false
  }

  function actionSearchTerm() {
    let t = (root.query || "").trim()
    if (t.startsWith(":")) t = t.substring(1).trim()
    return t.toLowerCase()
  }

  function keysSearchTerm() {
    let t = (root.query || "").trim()
    if (t.startsWith("?")) t = t.substring(1).trim()
    return t.toLowerCase()
  }

  function emojiSearchTerm() {
    let t = (root.query || "").trim()
    if (t.startsWith(";")) t = t.substring(1).trim()
    return t
  }

  function mapEmojiResults(list) {
    const src = list || []
    const out = []
    for (let i = 0; i < src.length; i++) {
      const e = src[i]
      out.push({
        id: "emoji-" + e.g + "-" + i,
        title: e.n,
        name: e.n,
        comment: e.k || "Enter to copy",
        glyph: e.g,
        copy: e.g,
        category: "Emoji",
        special: "emoji",
        _t: (e.n || "").toLowerCase(),
        _k: (e.k || "").toLowerCase(),
        _c: "emoji"
      })
    }
    return out
  }

  function getEmojiResults(q) {
    const term = Emoji.term(q)
    if (term === null) return null
    const hits = Emoji.search(term, root.maxResults)
    if (hits.length === 0) {
      return [{ id: "emoji-empty", name: "No emoji found", comment: term, glyph: "󰅙", special: "noop" }]
    }
    return root.mapEmojiResults(hits)
  }

  function mapActionEntry(a) {
    return {
      id: "action-" + a.key,
      title: root.actionLabel(a),
      comment: a.comment || "",
      glyph: root.actionGlyph(a),
      category: "Actions",
      special: "action",
      mode: a.mode || "",
      ipc: a.ipc || "",
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
    const acro = item._a || ""
    let total = 0
    for (let i = 0; i < tokens.length; i++) {
      const t = tokens[i]
      let sub = 0
      if (title.indexOf(t) === 0) sub += root.scPrefix
      else if (title.indexOf(t) >= 0) sub += root.scTitle
      if (kw.indexOf(t) >= 0) sub += root.scKw
      if (cat.indexOf(t) >= 0) sub += root.scCat
      // Acronym rescue for short terms only: "ff" -> Firefox, "vsc" -> VS Code.
      if (sub === 0 && t.length <= 5 && acro.indexOf(t) >= 0) sub += root.scAcro
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
    root.hiddenVersion; root.nightVersion; root.keysVersion

    const tokens = root.queryTokens
    const filter = root.categoryFilter

    // Prefix specials still win (calc/web/@/dict/>/:/? ) for muscle memory + power
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
    if (filter === "Emoji") {
      const term = root.emojiSearchTerm()
      return root.mapEmojiResults(Emoji.search(term, root.maxResults))
    }
    if (filter === "Keys") {
      const term = root.keysSearchTerm()
      const terms = term.length ? term.split(/\s+/) : []
      const binds = root.keyBinds || []
      const out = []
      for (let i = 0; i < binds.length; i++) {
        const b = binds[i]
        const hay = (b.desc + " " + b.combo).toLowerCase()
        let ok = true
        for (let j = 0; j < terms.length; j++) {
          if (hay.indexOf(terms[j]) < 0) { ok = false; break }
        }
        if (!ok) continue
        out.push({
          id: "key-" + i, title: b.desc, accessory: b.combo,
          glyph: "󰌌", category: "Keys", special: "noop"
        })
      }
      return out.length <= root.maxResults ? out : out.slice(0, root.maxResults)
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
        if (a.noDisplay || root.isHiddenApp(a)) continue
        const t = String(a.name || "").toLowerCase()
        const kws = Data.desktopKeywords(a)
        const k = String((a.genericName || "") + " " + (a.comment || "") + " " + kws + " " + (a.id || "")).toLowerCase()
        const aid = "app-" + (a.id || a.name || i)
        pool.push({
          id: aid, title: a.name, accessory: "APP",
          _t: t, _k: k, _c: "app",
          _a: Data.acronym((a.name || "") + " " + (a.genericName || "") + " " + kws + " " + (a.id || "")),
          category: "App", icon: "󰀻", rawIcon: a.icon || "", special: "app", raw: a
        })
      }
    }

    // Empty query: for App drill use limited usage tail (no flood); for other drills use pool; root: nav only
    if (tokens.length === 0) {
      if (filter !== "" && filter !== "Quick") {
        if (filter === "App") {
          const tail = []
          let allApps = (DesktopEntries.applications.values || []).filter(d => !d.noDisplay && !root.isHiddenApp(d))
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
      if (s > 0) scored.push({ s: s, p: root.primaryScore(it, tokens), u: it.special === "app" ? root.appScore(it.raw) : 0, item: it })
    }
    scored.sort((a, b) => {
      if (b.p !== a.p) return b.p - a.p
      const aCat = a.item.isCategory ? 0 : 1
      const bCat = b.item.isCategory ? 0 : 1
      if (aCat !== bCat) return aCat - bCat
      if (b.s !== a.s) return b.s - a.s
      if (b.u !== a.u) return b.u - a.u
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
    visible: root.panelVisible
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.shouldShow ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
      reveal: root.chromeReveal
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.shouldShow
      onClicked: root.shouldShow = false
    }

    Menu.MenuCard {
      id: launcherBox
      anchors.horizontalCenter: parent.horizontalCenter
      // Raycast placement: card near the top, dropping in from the top edge
      // with the caelestia drawer spring.
      readonly property int restY: root.launcherGeom.cardY
      y: restY - Math.round((height + 24) * (1 - root.chromeReveal))
      width: root.launcherGeom.cardWidth
      Behavior on width { Menu.MenuAnim {} }
      Behavior on y { Menu.MenuAnim {} }
      Behavior on height { Menu.MenuAnim {} }
      height: root.launcherGeom.cardHeight
      cardMargin: root.launcherGeom.cardMargin
      chromeReveal: root.chromeReveal
      focus: true
      activeFocusOnTab: true
      enabled: root.shouldShow
      Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
          root.handleEscape()
          event.accepted = true
          return
        }
        if (!root.quickMode) return
        const max = Math.max(0, root.resultCount - 1)
        const cols = root.quickGridCols
        const hjkl = {}
        hjkl[Qt.Key_H] = Qt.Key_Left
        hjkl[Qt.Key_J] = Qt.Key_Down
        hjkl[Qt.Key_K] = Qt.Key_Up
        hjkl[Qt.Key_L] = Qt.Key_Right
        const qk = hjkl[event.key] !== undefined ? hjkl[event.key] : event.key
        if (root.quickWallKey(qk)) { event.accepted = true; return }
        if (qk === Qt.Key_Down) {
          root.selectedIndex = Math.min(root.selectedIndex + cols, max)
          event.accepted = true
        } else if (qk === Qt.Key_Up) {
          root.selectedIndex = Math.max(root.selectedIndex - cols, 0)
          event.accepted = true
        } else if (qk === Qt.Key_Left) {
          root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
          event.accepted = true
        } else if (qk === Qt.Key_Right) {
          root.selectedIndex = Math.min(root.selectedIndex + 1, max)
          event.accepted = true
        } else if (qk === Qt.Key_Return || qk === Qt.Key_Enter) {
          root.launchCurrent()
          event.accepted = true
        } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32
          && event.text.charCodeAt(0) !== 127
          && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
          root.categoryFilter = ""
          root.expandedQuickKey = ""
          root.setSearchQuery(event.text)
          event.accepted = true
        }
      }

      ColumnLayout {
        id: launcherCol
        anchors.fill: parent
        spacing: root.launcherGeom.colSpacing

        Menu.MenuHeader {
          Layout.fillWidth: true
          Layout.preferredHeight: (!root.quickMode && root.sectionName !== "") ? implicitHeight : 0
          visible: !root.quickMode && root.sectionName !== ""
          fontFamily: root.uiSans
          fontScale: root.uiFontScale
          title: "Launcher"
          sectionIcon: root.sectionIcon
          sectionName: root.sectionName
          countLine: root.resultText
          hintText: root.headerHintText
          subtitle: ""
        }

        Menu.MenuDivider {
          Layout.fillWidth: true
          Layout.preferredHeight: implicitHeight
          visible: !root.quickMode && root.sectionName !== ""
        }

        // Search pill under the header (caelestia pill, Raycast placement). Hidden
        // in quickMode so typing cannot pollute query/cat while the deck is shown.
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: root.quickMode ? 0 : root.launcherGeom.searchH
          visible: !root.quickMode
          clip: true

          Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Style.m3container
          }

          Text {
            id: searchPrompt
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.fileMode ? "󰉖" : "󰍉"
            color: Style.m3onSurfaceVariant
            font.family: root.uiFont
            font.pixelSize: root.fontPx(15)
          }

          Rectangle {
            id: argChip
            visible: root.argArmed
            anchors.left: searchPrompt.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: chipLabel.implicitWidth + 16
            height: Math.round(parent.height * 0.6)
            radius: height / 2
            color: Style.m3secondaryContainer
            border.width: 0
            Text {
              id: chipLabel
              anchors.centerIn: parent
              text: root.argCommand
              color: Style.m3onSurface
              font.family: root.uiSans
              font.pixelSize: root.fontPx(12)
              font.weight: Font.Medium
            }
          }

          Item {
            id: argFieldWrap
            anchors.left: root.argArmed ? argChip.right : searchPrompt.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.top: parent.top
            anchors.bottom: parent.bottom

          TextInput {
            id: searchInput
            anchors.fill: parent
            color: Style.m3onSurface
            font.family: root.uiDisplay
            font.pixelSize: root.fontPx(15)
            font.weight: Font.Medium
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            focus: true
            Accessible.role: Accessible.EditableText
            Accessible.name: root.argArmed ? (root.argPlaceholder || "Argument") : "Search applications"
            cursorDelegate: Rectangle {
              width: 2
              height: Math.round(searchInput.font.pixelSize * 1.05)
              radius: 1
              color: Style.menuAccent
              anchors.verticalCenter: parent ? parent.verticalCenter : undefined
              SequentialAnimation on opacity {
                running: searchInput.activeFocus && searchInput.cursorVisible
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.15; duration: 560; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.15; to: 1; duration: 560; easing.type: Easing.InOutSine }
              }
            }

            Text {
              anchors.fill: parent
              text: root.argArmed
                ? (root.argPlaceholder || "argument…")
                : (root.fileMode ? "Search files" : "Search  ·  ctrl+hjkl  ·  tab argument  ·  !  >  ;  @  dict")
              color: Style.m3onSurfaceVariant
              font: parent.font
              visible: !parent.text && (root.argArmed || !parent.activeFocus)
              verticalAlignment: Text.AlignVCenter
            }

            onTextChanged: {
              root.query = root.argArmed ? ArgCommands.join(root.argCommand, text) : text
              if (root.quickMode) {
                // no schedules, no auto-cat from search while quick grid is active (hidden input; internal cat sets still ok)
                if (resultsList) resultsList.currentIndex = 0
                return
              }
              const shown = root.query
              const ft = root.fileTerm(shown)
              if (ft !== null && root.categoryFilter !== Data.fileCategory) {
                root.categoryFilter = Data.fileCategory
              }
              if (shown.trim().startsWith(":") && root.categoryFilter !== "Actions") {
                root.categoryFilter = "Actions"
              }
              if (shown.trim().startsWith("?") && root.categoryFilter !== "Keys") {
                root.categoryFilter = "Keys"
              }
              if (shown.trim().startsWith("@") && root.categoryFilter !== "Websearch") {
                root.categoryFilter = "Websearch"
              }
              if (shown.trim().startsWith(";") && root.categoryFilter !== "Emoji") {
                root.categoryFilter = "Emoji"
              }
              if (shown.trim() && !root.isPrefixSpecial(shown) && root.categoryFilter === "" && !root.quickMode) {
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
              if (event.key === Qt.Key_Backspace && root.argArmed && (searchInput.text || "") === "") {
                root.clearArgument()
                event.accepted = true
                return
              }
              if (event.key === Qt.Key_Backspace && (root.query || "").trim() === "") {
                if (root.goUp()) { event.accepted = true; return; }
              }
              const max = Math.max(0, root.resultCount - 1)
              if (root.quickMode) {
                const cols = root.quickGridCols
                const hjkl = {}
                hjkl[Qt.Key_H] = Qt.Key_Left
                hjkl[Qt.Key_J] = Qt.Key_Down
                hjkl[Qt.Key_K] = Qt.Key_Up
                hjkl[Qt.Key_L] = Qt.Key_Right
                const qk = hjkl[event.key] !== undefined ? hjkl[event.key] : event.key
                if (root.quickWallKey(qk)) { event.accepted = true; return }
                if (qk === Qt.Key_Down) {
                  event.accepted = true; root.selectedIndex = Math.min(root.selectedIndex + cols, max)
                } else if (qk === Qt.Key_Up) {
                  event.accepted = true; root.selectedIndex = Math.max(root.selectedIndex - cols, 0)
                } else if (qk === Qt.Key_Left) {
                  event.accepted = true; root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                } else if (qk === Qt.Key_Right) {
                  event.accepted = true; root.selectedIndex = Math.min(root.selectedIndex + 1, max)
                } else if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) {
                  event.accepted = true; root.selectedIndex = Math.min(root.selectedIndex + 1, max)
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                  event.accepted = true; root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                }
                return
              }
              if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier) && root.tryArmArgument()) {
                event.accepted = true
                return
              }
              // Vim keys while typing: Ctrl+j/k move, Ctrl+h goes up a level, Ctrl+l opens.
              const ctrl = !!(event.modifiers & Qt.ControlModifier)
              const ctrlDown = ctrl && event.key === Qt.Key_J
              const ctrlUp = ctrl && event.key === Qt.Key_K
              if (ctrl && event.key === Qt.Key_H) {
                event.accepted = true
                root.goUp()
                return
              }
              if (ctrl && event.key === Qt.Key_L) {
                event.accepted = true
                root.launchCurrent()
                return
              }
              if (ctrlDown || event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                event.accepted = true
                resultsList.currentIndex = Math.min(resultsList.currentIndex + 1, max)
                resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
              } else if (ctrlUp || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
                || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                event.accepted = true
                resultsList.currentIndex = Math.max(resultsList.currentIndex - 1, 0)
                resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
              }
            }
          }
          }

        }


        // List area (with optional file preview split). Height is leftover
        // inside the card (ColumnLayout fill), not a fraction of the overlay.
        Item {
          id: listArea
          Layout.fillWidth: true
          Layout.fillHeight: !root.compactLauncher
          Layout.minimumHeight: root.compactLauncher
            ? root.launcherGeom.bodyHeight
            : root.launcherGeom.minList
          Layout.preferredHeight: root.launcherGeom.bodyHeight
          Layout.maximumHeight: root.compactLauncher
            ? root.launcherGeom.bodyHeight
            : 100000
          visible: true
          clip: true
          readonly property var tileGeom: LauncherGeom.tileMetrics(
            height,
            (root.quickDeck || []).length,
            true,
            root.launcherGeom.uiScale
          )

          // Normal results list (or split when preview for files)
          Item {
            anchors.fill: parent

            readonly property real listFrac: root.quickMode ? 0.22
              : (root.sideActive ? 0.46 : 1.0)
            // Icon + longest deck label ("Temperatures") + chevron. A
            // fraction of a wide card left a hollow rail; size to type.
            readonly property int quickRailW: {
              const chrome = 10 + 10 + 20 + 8
              const label = Math.round(root.fontPx(11) * 8.4)
              const want = chrome + label + 8
              const cap = Math.round(width * 0.28)
              return Math.max(root.launcherGeom.sideMin, Math.min(want, cap))
            }

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
              ScrollBar.vertical: Menu.MenuScrollBar {}
              highlight: Rectangle {
                radius: Style.menuRadiusLg
                color: Style.m3stateHover
                width: resultsList.width
                height: resultsList.currentItem ? resultsList.currentItem.height - 2 : 0
                y: resultsList.currentItem ? resultsList.currentItem.y + 1 : 0
                Behavior on y { Menu.MenuAnim {} }
                Behavior on height { Menu.MenuAnim {} }
              }

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
                height: dCat || dSub === "" ? root.launcherGeom.rowH : root.launcherGeom.rowHTall
                readonly property bool isSelected: resultsList.currentIndex === index
                readonly property string dIcon: modelData.icon || ""
                readonly property string dRawIcon: modelData.rawIcon || ""
                readonly property string dImage: root.resolveIconUrl(dRawIcon || (dIcon.startsWith("file://") || dIcon.charAt(0) === "/" ? dIcon : ""))
                readonly property string dGlyph: modelData.glyph || (dImage === "" && dIcon !== "" ? dIcon : "")
                readonly property string dAcc: modelData.accessory || (modelData.isCategory ? "›" : "")
                readonly property color dTint: root.itemTintColor(modelData)

                Accessible.role: Accessible.Button
                Accessible.name: dName

                Rectangle {
                  anchors.fill: parent
                  anchors.topMargin: 1
                  anchors.bottomMargin: 1
                  radius: Style.menuRadiusLg
                  color: rowMa.containsMouse && !delegateRoot.isSelected ? Style.m3stateHover : "transparent"
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: root.launcherGeom.rowPad
                  anchors.rightMargin: root.launcherGeom.rowPad
                  spacing: root.launcherGeom.colSpacing

                  Item {
                    id: iconSlot
                    width: root.launcherGeom.iconSlot
                    height: root.launcherGeom.iconSlot
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
                    Rectangle {
                      anchors.centerIn: parent
                      width: parent.width
                      height: parent.height
                      radius: 6
                      color: Qt.alpha(delegateRoot.dTint, 0.14)
                      visible: delegateRoot.dImage === "" || rowIcon.status !== Image.Ready
                    }
                    Text {
                      anchors.centerIn: parent
                      text: delegateRoot.dGlyph !== "" ? delegateRoot.dGlyph : delegateRoot.dName.charAt(0).toUpperCase()
                      color: delegateRoot.dTint
                      font.pixelSize: delegateRoot.dGlyph !== "" ? root.fontPx(20) : root.fontPx(15)
                      font.family: root.uiFont
                      visible: rowIcon.status !== Image.Ready
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                      Layout.fillWidth: true
                      text: delegateRoot.dName + (delegateRoot.dCat ? "  ›" : "")
                      color: Style.m3onSurface
                      font.pixelSize: root.fontPx(14)
                      font.family: root.uiSans
                      font.weight: Font.Medium
                      elide: Text.ElideRight
                    }

                    Text {
                      Layout.fillWidth: true
                      visible: delegateRoot.dSub !== "" && !delegateRoot.dCat && !root.fileMode
                      text: delegateRoot.dSub
                      color: Style.m3outline
                      font.pixelSize: root.fontPx(11)
                      font.family: root.uiSans
                      elide: Text.ElideRight
                      maximumLineCount: 1
                    }
                  }

                  Text {
                    text: root.fileMode && modelData.path
                      ? Data.tildify(Data.dirname(modelData.path), root.homeDir)
                      : delegateRoot.dAcc
                    visible: text !== ""
                    color: Style.m3outline
                    font.pixelSize: root.fontPx(11)
                    font.family: root.uiSans
                    elide: Text.ElideLeft
                    maximumLineCount: 1
                    // Key combos ("SUPER+SHIFT+ESCAPE") need more room than
                    // the short APP/category accessories.
                    Layout.maximumWidth: modelData.category === "Keys" ? root.launcherGeom.accMaxKeys : root.launcherGeom.accMax
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

              Column {
                anchors.centerIn: parent
                spacing: 8
                visible: root.resultCount === 0 && searchInput.text !== ""
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "󰍉"
                  color: Style.menuAccent
                  font.family: root.uiFont
                  font.pixelSize: root.fontPx(28)
                  opacity: 0.8
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "Nothing matches"
                  color: Style.menuInkDeep
                  font.family: root.uiSans
                  font.pixelSize: root.fontPx(13)
                  font.letterSpacing: 0.15
                  font.weight: Font.Medium
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "Try another query or prefix"
                  color: Style.menuInkMuted
                  font.family: root.uiSans
                  font.pixelSize: root.fontPx(11)
                  opacity: 0.8
                }
              }
            }

            // Quick grid (exact ref bjarneo style: compress width+cols+tileH on detail; 1 hairline sep; grid nav; sub hidden colmode)
            Flickable {
              id: quickSide
              visible: root.quickMode
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              width: root.quickDetailActive
                ? parent.quickRailW
                : parent.width * parent.listFrac
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              contentHeight: Math.max(height, listArea.tileGeom.tileColumnHeight)
              interactive: contentHeight > height + 1
              Behavior on width { NumberAnimation { duration: Style.menuAnimMs; easing.type: Easing.OutCubic } }
              ScrollBar.vertical: Menu.MenuScrollBar {}

              Grid {
                id: quickGrid
                width: quickSide.width
                height: Math.max(1, listArea.tileGeom.tileColumnHeight)
                columns: root.quickGridCols
                rowSpacing: listArea.tileGeom.tileGap
                columnSpacing: listArea.tileGeom.tileGap
                clip: true
                readonly property bool colMode: root.quickDetailActive
                readonly property int tileH: listArea.tileGeom.tileH
                Timer { interval: 0; running: root.quickMode; repeat: false; onTriggered: root.resultCount = (root.quickDeck || []).length }

              Repeater {
                model: root.quickDeck || []
                delegate: Item {
                  id: qtile
                  required property var modelData
                  required property int index
                  readonly property bool isSel: root.selectedIndex === index
                  readonly property var t: modelData || {}
                  width: (quickGrid.width - (quickGrid.columns-1)*quickGrid.columnSpacing) / quickGrid.columns
                  height: quickGrid.tileH
                  Menu.MenuHudTile {
                    anchors.fill: parent
                    selected: isSel
                    hovered: qma.containsMouse
                    compact: quickGrid.colMode
                    indexLabel: (index + 1) < 10 ? ("0" + (index + 1)) : String(index + 1)
                    glyph: t.glyph || "󰘔"
                    label: t.label || ""
                    sub: t.sub || ""
                    accessory: t.kind === "run" || t.kind === "ipc" ? "run" : "pane"
                    tint: root.tintColor(t.tint)
                    fontFamily: root.uiFont
                    glyphPx: root.fontPx(24)
                    labelPx: root.fontPx(11)
                    subPx: root.fontPx(9)
                  }
                  MouseArea {
                    id: qma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: { root.selectedIndex = index; if (resultsList) resultsList.currentIndex = index }
                    onClicked: {
                      root.selectedIndex = index
                      root.activateDeckItem(modelData)
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
              anchors.left: quickSide.right; anchors.leftMargin: 12
              width: 1; color: Style.menuSep
              opacity: root.quickDetailActive ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: Style.menuAnimMs } }
            }

            // Preview pane (file only for now, launcher style split; or quick feature detail when expanded)
            Item {
              visible: root.sideActive
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.left: root.quickMode && root.quickDetailActive ? quickSep.right : (root.quickMode ? quickSide.right : resultsList.right)
              anchors.leftMargin: root.quickDetailActive ? root.launcherGeom.sidePad : root.launcherGeom.panePad
              anchors.right: parent.right

              // Quick pane body: left rail is the selection indicator; no title/close row.
              Item {
                id: qDetailSide
                visible: root.quickDetailActive
                anchors.fill: parent
                clip: true
                opacity: root.quickDetailActive ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Style.menuAnimMs; easing.type: Easing.OutCubic } }
                Loader {
                  id: qdl
                  anchors.fill: parent
                  active: root.quickDetailActive
                  sourceComponent: root.quickDetailFor(root.quickPaneKey)
                }
              }

              // file preview (only when not quick detail)
              ColumnLayout {
                visible: root.previewActive && !root.quickDetailActive
                anchors.fill: parent
                spacing: 6

                Text {
                  id: previewName
                  Layout.fillWidth: true
                  text: {
                    const it = resultsList.currentItem ? resultsList.currentItem.modelData : null
                    return it && it.path ? Data.basename(it.path) : "File preview"
                  }
                  color: Style.menuInk
                  font.family: root.uiFont
                  font.pixelSize: root.fontPx(14)
                  elide: Text.ElideRight
                }
                Text {
                  Layout.fillWidth: true
                  text: {
                    const it = resultsList.currentItem ? resultsList.currentItem.modelData : null
                    return it && it.path ? Data.tildify(Data.dirname(it.path), root.homeDir) : ""
                  }
                  color: Style.menuInkDeep
                  font.family: root.uiFont
                  font.pixelSize: root.fontPx(12)
                  opacity: 0.7
                  elide: Text.ElideLeft
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Style.menuSep }

                Item {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
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
                    font.pixelSize: root.fontPx(10)
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
                    font.pixelSize: root.fontPx(10)
                    wrapMode: Text.Wrap
                  }
                }
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          visible: !root.quickMode && !root.compactLauncher && text !== ""
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
          color: Style.m3outline
          font.family: root.uiSans
          font.pixelSize: root.fontPx(11)
        }

      }

      // Screenshot preview overlay (copy / open / delete)
      Rectangle {
        anchors.fill: parent
        color: Style.menuDim
        visible: root.shotPreviewPath !== ""
        radius: Style.menuPanelRadius
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
            radius: Style.radiusLg
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
            radius: Style.radiusLg
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
            radius: Style.radiusLg
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
