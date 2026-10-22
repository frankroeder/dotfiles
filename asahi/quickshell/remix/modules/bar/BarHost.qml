import QtQuick
import QtQml.Models
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../"
import "BarModel.js" as BarModel
import "components" as BarComponents
import "../../services" as Services

// Bar content (PanelWindow wrapper lives in shell.qml so Variants injects modelData correctly).
Item {
  id: barWindow

  property var barScreen: null
  property var notificationCenter: null
  property bool isRecording: false
  property bool calendarOpen: false
  property bool launcherOpen: false
  // One bar popup at a time: "", "sys", "rec", "media", "ccu" or "tray". The calendar
  // (shell.qml) and the notification sheet close it, and opening it closes them.
  property string openPanel: ""
  onLauncherOpenChanged: if (launcherOpen) barWindow.openPanel = ""
  onCalendarOpenChanged: { if (calendarOpen) barWindow.openPanel = ""; barWindow.reportPopupSide() }
  onOpenPanelChanged: barWindow.reportPopupSide()
  // Bar popups cover toasts (NotificationCenter.setPopupSide): tell it which half the open one hangs
  // in, from its chip. The tray panel is a layer surface under the toasts: not reported.
  function reportPopupSide() {
    const chip = barWindow.calendarOpen ? clockBlock
      : ({ sys: sysBlock, media: mediaBlock, rec: statusBlock, ccu: ccuBlock })[barWindow.openPanel]
    const side = !chip ? "" : chip.mapToItem(barWindow, chip.width / 2, 0).x < barWindow.width / 2 ? "left" : "right"
    if (barWindow.notificationCenter && barWindow.barScreen) barWindow.notificationCenter.setPopupSide(barWindow.barScreen.name, side)
  }
  signal calendarToggle()
  // Chip clicks open their Quick pane (updates chip: PkgManager's Updates tab) through shell.qml in-process,
  // no `qs ipc` client fork per click.
  signal quickRequested(string key)
  function closeHistory() { if (barWindow.notificationCenter) barWindow.notificationCenter.historyVisible = false }
  Connections {
    target: barWindow.notificationCenter
    function onHistoryVisibleChanged() { if (barWindow.notificationCenter.historyVisible) barWindow.openPanel = "" }
  }
  function togglePanel(name) {
    if (barWindow.calendarOpen) barWindow.calendarToggle()
    barWindow.closeHistory()
    barWindow.openPanel = barWindow.openPanel === name ? "" : name
  }
  // IPC `media panel` / Super+Alt+R (shell.qml signals): only the bar on the focused monitor answers; media
  // only with a player.
  function requestPanel(name) {
    const mon = Hyprland.focusedMonitor
    if (mon && barWindow.barScreen && mon.name !== barWindow.barScreen.name) return
    if (name === "media" && !mediaBlock.hasMedia) return
    barWindow.togglePanel(name)
  }

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property int barSize: Style.barHeight
  readonly property bool appleSiliconHost: Services.BarData.appleSiliconHost
  readonly property color barForeground: Style.barStripText
  readonly property color barBackground: Style.barStripBg

  readonly property int notchFloor: appleSiliconHost && barScreen?.name?.indexOf("eDP") === 0
    ? Math.max(barSize, BarModel.notchHeight(barScreen.name, barScreen.width, barScreen.height))
    : barSize

  readonly property int notchSpacerWidth: appleSiliconHost
    ? BarModel.notchSpacerWidth(barScreen?.name, barScreen?.width)
    : 0

  // Distance from either bar edge to the cutout — the wall each cluster stops at.
  readonly property int notchInset: BarModel.notchRegionInset(barContent.width, notchSpacerWidth)

  // ccu is the widest member and the only one with short forms, so it is what gives
  // when the cutout leaves the right cluster too little room: first the plan drops, then the
  // countdown. The sum deliberately excludes ccu's own width and uses its fixed `fullWidth` /
  // `planlessWidth`, so the answer cannot change the question.
  readonly property real rightOthers: trayBlock.implicitWidth + statusBlock.implicitWidth
    + micBlock.implicitWidth + volBlock.implicitWidth + netBlock.implicitWidth
    + btBlock.implicitWidth + battBlock.implicitWidth + clockBlock.implicitWidth + notifBlock.implicitWidth
    + 10 * rightSection.spacing
  // Temperature in the CPU / RAM chip only when it fits: with media playing the chip must keep
  // 200 px (its natural width, not the capped one — that would make the answer change the question).
  readonly property real leftSpare: leftRegion.width - wsBlock.implicitWidth - sysBlock.baseWidth
    - (backupBlock.visible ? backupBlock.implicitWidth + leftSection.spacing : 0) - 2 * leftSection.spacing
  readonly property bool showTemp: tempAvg > 0
    && leftSpare - (mediaBlock.hasMedia ? Math.min(mediaBlock.naturalWidth, 200) : 0) >= sysBlock.tempWidth
  readonly property bool ccuShowPlan: notchInset <= 0
    || rightOthers + ccuBlock.fullWidth <= rightRegion.width
  readonly property bool ccuCompact: notchInset > 0
    && rightOthers + ccuBlock.planlessWidth > rightRegion.width

  implicitWidth: parent ? parent.width : 0
  implicitHeight: notchFloor

  // Shared with every bar (services/BarData.qml): read here so the chips and panels keep their names.
  readonly property string cpuTooltip: Services.BarData.cpuTooltip
  readonly property string memTooltip: Services.BarData.memTooltip
  readonly property bool updatesAvailable: Services.BarData.updatesAvailable
  readonly property real cpuPerc: Services.BarData.cpuPerc
  readonly property real memPerc: Services.BarData.memPerc
  readonly property real heatpipeW: Services.BarData.heatpipeW
  readonly property real tempAvg: Services.BarData.tempAvg
  readonly property var cpuCores: Services.BarData.cpuCores
  readonly property var cpuHistory: Services.BarData.cpuHistory
  readonly property var memHistory: Services.BarData.memHistory
  readonly property int wsWindowVersion: Services.BarData.wsWindowVersion
  readonly property var hyprClients: Services.BarData.hyprClients

  function fmt2(n) {
    n = Math.round(n)
    if (n > 99) n = 99
    if (n < 0) n = 0
    return n < 10 ? "0" + n : "" + n
  }

  // SysPanel's per-core list and tooltips fork scripts: only while this bar's panel is open.
  Timer {
    interval: 3000; repeat: true; triggeredOnStart: true
    running: barWindow.openPanel === "sys"
    onTriggered: Services.BarData.refreshDetail()
  }

  function refreshWorkspaceIcons(retries) { Services.BarData.refreshWorkspaceIcons(retries) }

  function activateWorkspace(wsId) {
    // Hyprland 0.56 lua treats `dispatch workspace N` as `hl.dispatch(workspace N)` (syntax error).
    // Quickshell's ws.activate() uses that classic dispatcher, so bar clicks never switch.
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + wsId + " })"])
    refreshWorkspaceIcons(2)
  }

  function cycleWorkspace(next) {
    const step = next ? "e+1" : "e-1"
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + step + "\" })"])
    refreshWorkspaceIcons(2)
  }

  function appIconSource(t) {
    const candidates = appCandidates(t)
    if (candidates.length === 0) return ""
    for (let i = 0; i < candidates.length; i++) {
      const name = candidates[i]
      // Papirus-Dark has no grok-bot; RPM ships hicolor pngs.
      if (String(name).toLowerCase() === "grok-bot")
        return "file:///usr/share/icons/hicolor/48x48/apps/grok-bot.png"
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

  // Chips that appear / vanish in the left cluster (media, backup…) slide their neighbours instead of
  // jumping; the right cluster only fades new chips in (see rightSection) (upstream BarModule: 300 ms OutCubic, fade 180 ms). Off for the first second so the
  // bar does not cascade in on start or reload.
  property bool chipAnim: false
  Timer { interval: 1000; running: true; onTriggered: barWindow.chipAnim = true }
  Transition {
    id: chipMove
    enabled: barWindow.chipAnim
    NumberAnimation { properties: "x"; duration: 300; easing.type: Easing.OutCubic }
  }
  Transition {
    id: chipAdd
    enabled: barWindow.chipAnim
    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
  }

  Item {
    id: barContent
    anchors.fill: parent
    anchors.leftMargin: Style.barEdgeMargin
    anchors.rightMargin: Style.barEdgeMargin

  // The cutout is a hole in the layout, not a spacer between two free-floating rows:
  // each cluster is confined to its own side of it (sketchybar's `bar notch_width`).
  // Nothing can render under the camera — overflow is cut at the wall instead.
  Item {
    id: leftRegion
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: barWindow.notchInset > 0 ? barContent.width - barWindow.notchInset : barContent.width
    clip: true

  Row {
    id: leftSection
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8
    move: chipMove
    add: chipAdd

    WorkspacesBlock { id: wsBlock; controller: barWindow; anchors.verticalCenter: parent.verticalCenter }

    // One CPU + RAM chip: click opens SysPanel, right-click btop.
    BarComponents.SysChip {
      id: sysBlock
      barHost: barWindow
      onPressed: function(button) {
        if (button === Qt.RightButton) Quickshell.execDetached([barWindow.binDir + "/asahi-sysmon"])
        else barWindow.togglePanel("sys")
      }
    }

    // Backup progress / failure; hidden (and out of the Row) otherwise.
    BarComponents.BackupChip { id: backupBlock; barHost: barWindow }

    BarComponents.MediaPlayer {
      id: mediaBlock
      barHost: barWindow
      panelOpen: barWindow.openPanel === "media"
      onToggled: barWindow.togglePanel("media")
      maxChipWidth: Math.max(64,
        leftRegion.width - wsBlock.implicitWidth - sysBlock.implicitWidth
          - (backupBlock.visible ? backupBlock.implicitWidth + leftSection.spacing : 0)
          - 2 * leftSection.spacing)
    }
  }
  }

  Item {
    id: rightRegion
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: barWindow.notchInset > 0 ? barContent.width - barWindow.notchInset : barContent.width
    clip: true

  // Bell right of the notch: pinned to the cutout's wall on the notched panel; elsewhere it leads
  // the right cluster. The clock stays rightmost; the left belongs to the media chip.
  BarComponents.Notifications {
    id: notifNotch
    visible: barWindow.notchInset > 0 && barWindow.notificationCenter !== null
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    notificationCenter: barWindow.notificationCenter
  }

  Row {
    id: rightSection
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2
    // No `move` here: the Row is anchored right, so it shifts at once while `move` animated the
    // children from their old in-row x — everything right of a new chip (REC) jumped and slid back.
    add: chipAdd

    BarComponents.Notifications {
      id: notifBlock
      visible: barWindow.notchInset === 0 && barWindow.notificationCenter !== null
      notificationCenter: barWindow.notificationCenter
    }

    BarComponents.SystemTray {
      id: trayBlock
      barHeight: barWindow.notchFloor
      trayScreen: barWindow.barScreen
      barHost: barWindow
    }

    BarComponents.StatusIndicators {
      id: statusBlock
      isRecording: barWindow.isRecording
      updatesAvailable: barWindow.updatesAvailable
      barHost: barWindow
    }

    BarComponents.Ccu {
      id: ccuBlock
      barHost: barWindow
      showPlan: barWindow.ccuShowPlan
      compact: barWindow.ccuCompact
    }

    BarComponents.AudioChip { id: micBlock; input: true; barHost: barWindow }
    BarComponents.AudioChip { id: volBlock; barHost: barWindow }
    BarComponents.Network { id: netBlock; barHost: barWindow }
    BarComponents.Bluetooth { id: btBlock; barHost: barWindow }
    BarComponents.Battery { id: battBlock; barHost: barWindow }
    BarComponents.Clock {
      id: clockBlock
      barHost: barWindow
      calendarOpen: barWindow.calendarOpen
      onCalendarToggle: barWindow.calendarToggle()
    }
  }
  }
  }

  BarComponents.SysPanel {
    barHost: barWindow
    panelOpen: barWindow.openPanel === "sys"
    anchor.item: sysBlock
  }

  BarComponents.MediaPanel {
    barHost: barWindow
    panelOpen: barWindow.openPanel === "media"
    anchor.item: mediaBlock
  }

  BarComponents.RecordPanel {
    barHost: barWindow
    panelOpen: barWindow.openPanel === "rec"
    anchor.item: statusBlock
  }
}
