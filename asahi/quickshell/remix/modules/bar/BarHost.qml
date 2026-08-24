import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import "../../"
import "BarModel.js" as BarModel
import "components" as BarComponents

// Bar content (PanelWindow wrapper lives in shell.qml so Variants injects modelData correctly).
Item {
  id: barWindow

  property var barScreen: null
  property var notificationCenter: null

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property int barSize: Style.barHeight
  readonly property bool appleSiliconHost: appleProbe.appleSiliconHost
  readonly property color barForeground: Style.barStripText
  readonly property color barBackground: Style.barStripBg

  readonly property int notchFloor: appleSiliconHost && barScreen?.name?.indexOf("eDP") === 0
    ? Math.max(barSize, BarModel.notchHeight(barScreen.name, barScreen.width, barScreen.height, barScreen.devicePixelRatio))
    : barSize

  readonly property int notchSpacerWidth: appleSiliconHost
    ? BarModel.notchSpacerWidth(barScreen.name, barScreen.width, barScreen.height, barScreen.devicePixelRatio)
    : 0

  implicitWidth: parent ? parent.width : 0
  implicitHeight: notchFloor

  // State shared with workspace block and left widgets
  property string cpuText: ""
  property string cpuTooltip: ""
  property string memText: ""
  property string memTooltip: ""
  property bool isRecording: false
  property bool updatesAvailable: false
  property real cpuPerc: 0
  property real memPerc: 0
  property string cpuTempText: ""
  property var cpuHistory: []
  readonly property int maxGraphHist: 22
  property int wsWindowVersion: 0
  property int wsIconRefreshes: 0
  property var hyprClients: []

  function fmt2(n) {
    n = Math.round(n)
    if (n > 99) n = 99
    if (n < 0) n = 0
    return n < 10 ? "0" + n : "" + n
  }

  function refreshCpu() { if (!cpuScriptProc.running) cpuScriptProc.running = true }
  function refreshMem() { if (!memScriptProc.running) memScriptProc.running = true }

  function refreshWorkspaceIcons(retries) {
    wsWindowVersion = (wsWindowVersion + 1) % 10000
    refreshHyprClients()
    if (retries > wsIconRefreshes) wsIconRefreshes = retries
    if (wsIconRefreshes > 0 && !wsIconRefreshTimer.running) wsIconRefreshTimer.restart()
  }

  function refreshHyprClients() { if (!hyprClientsProc.running) hyprClientsProc.running = true }

  function activateWorkspace(wsId) {
    const ws = Hyprland.workspaces.values.find(w => w.id === wsId)
    if (ws) ws.activate()
    else Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + wsId + " })"])
    refreshWorkspaceIcons(2)
  }

  function cycleWorkspace(next) {
    Quickshell.execDetached(["hyprctl", "dispatch", "workspace", next ? "e+1" : "e-1"])
    refreshWorkspaceIcons(2)
  }

  function appIconSource(t) {
    const candidates = appCandidates(t)
    if (candidates.length === 0) return ""
    for (let i = 0; i < candidates.length; i++) {
      const name = candidates[i]
      const entry = DesktopEntries.heuristicLookup(name)
      const source = Quickshell.iconPath(entry?.icon || name, true)
      if (source !== "") return source
    }
    return ""
  }

  function appCandidates(t) {
    const values = [
      t.class, t.initialClass, t.title, t.initialTitle, t.appId,
      t.lastIpcObject?.class, t.lastIpcObject?.initialClass,
      t.lastIpcObject?.title, t.lastIpcObject?.initialTitle
    ]
    const candidates = []
    for (let i = 0; i < values.length; i++) {
      const raw = String(values[i] || "").trim()
      if (raw === "") continue
      const lower = raw.toLowerCase()
      candidates.push(raw, lower)
      if (lower.includes(".")) candidates.push(lower.split(".").pop())
      const words = lower.split(/[^a-z0-9]+/).filter(w => w.length > 2)
      for (let j = words.length - 1; j >= 0; j--) candidates.push(words[j])
    }
    return [...new Set(candidates)]
  }

  function appFallbackText(t) {
    const candidates = appCandidates(t)
    return candidates.length > 0 ? candidates[0].charAt(0).toUpperCase() : "?"
  }

  QtObject { id: appleProbe; property bool appleSiliconHost: false }
  Process {
    running: true
    command: ["bash", "-c", "grep -qi apple /proc/device-tree/compatible 2>/dev/null && echo yes || echo no"]
    stdout: StdioCollector {
      onStreamFinished: appleProbe.appleSiliconHost = text.trim() === "yes"
    }
  }

  Process {
    id: cpuScriptProc
    command: [binDir + "/asahi-cpu"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          barWindow.cpuText = data.text || "CPU --%"
          barWindow.cpuTooltip = data.tooltip || ""
          barWindow.cpuPerc = data.percentage || 0
          const m = (data.text || "").match(/(\d+)C/)
          barWindow.cpuTempText = m ? m[1] : ""
          barWindow.cpuHistory.push(barWindow.cpuPerc)
          if (barWindow.cpuHistory.length > barWindow.maxGraphHist) barWindow.cpuHistory.shift()
          cpuInlineGraph.requestPaint()
        } catch (e) {}
      }
    }
    Component.onCompleted: barWindow.refreshCpu()
  }

  Process {
    id: memScriptProc
    command: [binDir + "/asahi-memory"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          barWindow.memText = data.text || "Mem --%"
          barWindow.memTooltip = data.tooltip || ""
          barWindow.memPerc = data.percentage || 0
        } catch (e) {}
      }
    }
    Component.onCompleted: barWindow.refreshMem()
  }

  Process {
    id: hyprClientsProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          barWindow.hyprClients = JSON.parse(text.trim())
          barWindow.wsWindowVersion = (barWindow.wsWindowVersion + 1) % 10000
        } catch (e) {}
      }
    }
    Component.onCompleted: barWindow.refreshHyprClients()
  }

  Process {
    id: recordingProc
    command: ["pgrep", "-x", "wf-recorder"]
    stdout: StdioCollector { onStreamFinished: barWindow.isRecording = text.trim().length > 0 }
    onExited: code => { if (code !== 0) barWindow.isRecording = false }
  }

  Process {
    id: updatesProc
    command: ["sh", "-c", "dnf check-update --cacheonly -q >/dev/null 2>&1; c=$?; [ \"$c\" = 100 ] && echo 1 || echo 0"]
    stdout: StdioCollector { onStreamFinished: barWindow.updatesAvailable = text.trim() === "1" }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: { barWindow.refreshCpu(); barWindow.refreshMem() }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!recordingProc.running) recordingProc.running = true
  }

  Timer {
    interval: 1800000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!updatesProc.running) updatesProc.running = true
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      const n = event.name || ""
      if (["openwindow", "closewindow", "movewindow", "workspace", "focusedmon", "activewindow"].some(x => n.includes(x)))
        barWindow.refreshWorkspaceIcons(n.includes("openwindow") ? 8 : 0)
    }
  }

  Connections {
    target: Hyprland.toplevels
    ignoreUnknownSignals: true
    function onValuesChanged() { barWindow.refreshWorkspaceIcons(4) }
  }

  Connections {
    target: Hyprland.workspaces
    ignoreUnknownSignals: true
    function onValuesChanged() { barWindow.refreshWorkspaceIcons(0) }
  }

  Timer {
    id: wsIconRefreshTimer
    interval: 180
    repeat: true
    onTriggered: {
      barWindow.wsIconRefreshes--
      barWindow.refreshWorkspaceIcons(0)
      if (barWindow.wsIconRefreshes <= 0) stop()
    }
  }

  Item {
    id: barContent
    anchors.fill: parent
    anchors.leftMargin: Style.barEdgeMargin
    anchors.rightMargin: Style.barEdgeMargin

  Row {
    id: leftSection
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    WorkspacesBlock { controller: barWindow }

    BarComponents.MediaPlayer { barHost: barWindow }

    WidgetButton {
      barHost: barWindow
      text: "󰍛 " + barWindow.fmt2(barWindow.cpuPerc) + "%"
      fontSize: Style.barFontBody
      tooltipText: barWindow.cpuTooltip
      foreground: Style.orange
    }

    WidgetButton {
      barHost: barWindow
      text: "󰘚 " + barWindow.fmt2(barWindow.memPerc) + "%"
      fontSize: Style.barFontBody
      tooltipText: barWindow.memTooltip
      foreground: Style.sky
    }
  }

  // Notch spacer — omarchy keeps center empty on notched built-in panel
  Item {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    width: barWindow.notchSpacerWidth
    height: 1
    visible: barWindow.notchSpacerWidth > 0
  }

  Row {
    id: rightSection
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    BarComponents.StatusIndicators {
      notificationCenter: barWindow.notificationCenter
      isRecording: barWindow.isRecording
      updatesAvailable: barWindow.updatesAvailable
      barHost: barWindow
    }

    BarComponents.Ccu { barHost: barWindow }

    BarComponents.Microphone { barHost: barWindow }
    BarComponents.Volume { barHost: barWindow }
    BarComponents.Network { barHost: barWindow }
    BarComponents.Bluetooth { barHost: barWindow }
    BarComponents.Battery { barHost: barWindow }
    BarComponents.Clock { barHost: barWindow }
  }
  }

  Canvas {
    id: cpuInlineGraph
    visible: false
  }
}
