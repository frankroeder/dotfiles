import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

import "modules/bar/components" as BarComponents
import "modules/system" as System
import "modules/wallpaper"
import "."

ShellRoot {
  id: shell

  System.Osd { id: osd }
  System.NotificationCenter { id: notificationCenter }

Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData
        id: root

        // Theme centralized in Style.qml (Catppuccin Mocha)
        // Reliable bin path (short names don't resolve reliably in QS Process env on this setup)
        readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  property string cpuText: ""
  property string cpuTooltip: ""

  property string memText: ""
  property string memTooltip: ""
  property bool isRecording: false
  property bool updatesAvailable: false

  // For the new graphical short history graphs (replaces old unicode blocks)
  property real cpuPerc: 0
  property real memPerc: 0
  property string cpuTempText: ""
  property var cpuHistory: []
  readonly property int maxGraphHist: 22

  function fmt2(n) {
    n = Math.round(n)
    if (n > 99) n = 99
    if (n < 0) n = 0
    return n < 10 ? "0" + n : "" + n
  }

  function refreshCpu() {
    if (!cpuScriptProc.running) cpuScriptProc.running = true
  }

  function refreshMem() {
    if (!memScriptProc.running) memScriptProc.running = true
  }

  // Bump bindings that derive workspace occupancy/icons from Hyprland toplevel state.
  property int wsWindowVersion: 0
  property int wsIconRefreshes: 0
  property var hyprClients: []

  function refreshWorkspaceIcons(retries) {
    root.wsWindowVersion = (root.wsWindowVersion + 1) % 10000
    root.refreshHyprClients()
    if (retries > root.wsIconRefreshes) root.wsIconRefreshes = retries
    if (root.wsIconRefreshes > 0 && !wsIconRefreshTimer.running) wsIconRefreshTimer.restart()
  }

  function refreshHyprClients() {
    if (!hyprClientsProc.running) hyprClientsProc.running = true
  }

  function appIconSource(t) {
    const candidates = root.appCandidates(t)
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
      t.class,
      t.initialClass,
      t.title,
      t.initialTitle,
      t.appId,
      t.lastIpcObject?.class,
      t.lastIpcObject?.initialClass,
      t.title,
      t.lastIpcObject?.title,
      t.lastIpcObject?.initialTitle
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
    const candidates = root.appCandidates(t)
    return candidates.length > 0 ? candidates[0].charAt(0).toUpperCase() : "?"
  }

  function activateWorkspace(wsId) {
    const ws = Hyprland.workspaces.values.find(w => w.id === wsId)
    if (ws) ws.activate()
    else Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + wsId + " })"])
    root.refreshWorkspaceIcons(2)
  }

  function cycleWorkspace(next) {
    Quickshell.execDetached(["hyprctl", "dispatch", "workspace", next ? "e+1" : "e-1"])
    root.refreshWorkspaceIcons(2)
  }

  readonly property int focusedWorkspaceId: (root.wsWindowVersion, Hyprland.focusedWorkspace?.id ?? 1)
  readonly property var visibleWorkspaces: {
    root.wsWindowVersion
    const ids = new Set()
    const focused = Hyprland.focusedWorkspace?.id
    if (focused != null) ids.add(focused)
    for (const t of root.hyprClients) {
      const id = t.workspace?.id
      if (id != null && id > 0) ids.add(id)
    }
    return Array.from(ids).sort((a, b) => a - b)
  }

  function workspaceWindows(wsId) {
    root.wsWindowVersion
    return root.hyprClients.filter(t => t.workspace?.id === wsId)
  }

  function workspaceVisibleElsewhere(wsId) {
    const monitors = Hyprland.monitors?.values || []
    return monitors.some(m => (m.activeWorkspace?.id === wsId) && wsId !== root.focusedWorkspaceId)
  }

  readonly property bool hasSpecialWorkspace: {
    root.wsWindowVersion
    return root.hyprClients.some(t => String(t.workspace?.name || "").startsWith("special:"))
  }

  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: 44   // room for large focused-workspace app icons
  exclusiveZone: 44    // reserve space so windows don't go under the bar (like waybar)
  color: "transparent"   // overall bar transparent, widgets provide their own dark background like waybar

  // CPU script (usage + temperature)
  Process {
    id: cpuScriptProc
    command: [binDir + "/asahi-cpu"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          root.cpuText = data.text || "CPU --%"
          root.cpuTooltip = data.tooltip || ""
          root.cpuPerc = data.percentage || 0

          const txt = data.text || ""
          const m = txt.match(/(\d+)C/)
          root.cpuTempText = m ? m[1] : ""

          root.cpuHistory.push(root.cpuPerc)
          if (root.cpuHistory.length > root.maxGraphHist) root.cpuHistory.shift()
          cpuInlineGraph.requestPaint()
        } catch (e) {}
      }
    }
    Component.onCompleted: root.refreshCpu()
  }

  // Memory script (usage + history bars like CPU)
  Process {
    id: memScriptProc
    command: [binDir + "/asahi-memory"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          root.memText = data.text || "Mem --%"
          root.memTooltip = data.tooltip || ""
          root.memPerc = data.percentage || 0

        } catch (e) {}
      }
    }
    Component.onCompleted: root.refreshMem()
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
    Component.onCompleted: root.refreshHyprClients()
  }

  Process {
    id: recordingProc
    command: ["pgrep", "-x", "wf-recorder"]
    stdout: StdioCollector { onStreamFinished: root.isRecording = text.trim().length > 0 }
    onExited: code => { if (code !== 0) root.isRecording = false }
  }

  Process {
    id: updatesProc
    command: ["sh", "-c", "dnf check-update --cacheonly -q >/dev/null 2>&1; c=$?; [ \"$c\" = 100 ] && echo 1 || echo 0"]
    stdout: StdioCollector { onStreamFinished: root.updatesAvailable = text.trim() === "1" }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: {
      root.refreshCpu()
      root.refreshMem()
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!recordingProc.running) recordingProc.running = true
    }
  }

  Timer {
    interval: 1800000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!updatesProc.running) updatesProc.running = true
  }

  // Keep window icons fresh (Hyprland events + periodic refresh)
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      const n = event.name || ""
      if (["openwindow", "closewindow", "movewindow", "workspace", "focusedmon", "activewindow"].some(x => n.includes(x)))
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

  Timer {
    interval: 800
    running: true
    repeat: true
    onTriggered: root.refreshWorkspaceIcons(0)
  }

  Item {
    id: barContent
    anchors.fill: parent
    anchors.margins: 4

    // Far left (minimal)
    Row {
      id: leftSection
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8
      BarComponents.MediaPlayer {}

      // Compact CPU (icon + % + temp + inline graph)
      Rectangle {
        id: cpuWidget
        color: cpuMouse.containsMouse ? Style.barHoverBg : Style.barBg
        radius: Style.radius
        border.width: 1
        border.color: cpuMouse.containsMouse ? Style.barHoverBorder : Style.barBorder
        scale: cpuMouse.containsMouse ? 1.018 : 1.0
        implicitWidth: 152
        implicitHeight: 26
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        RowLayout {
          anchors.centerIn: parent
          spacing: 4
          Text {
            text: "󰍛"
            font { family: Style.fontFamily; pixelSize: 22 }
            color: Style.orange
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 4
          }
          Text {
            text: root.fmt2(root.cpuPerc) + "%"
            font { family: Style.fontFamily; pixelSize: 17 }
            color: Style.yellow
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
          }
          Text {
            text: root.cpuTempText + "°"
            font { family: Style.fontFamily; pixelSize: 14 }
            color: Style.textAlt
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
          }
          Canvas {
            id: cpuInlineGraph
            Layout.preferredWidth: 62
            Layout.preferredHeight: 14
            onPaint: {
              const ctx = getContext("2d")
              ctx.reset()
              const hist = root.cpuHistory
              if (!hist || hist.length < 2) return
              const w = width
              const h = height
              const step = w / (hist.length - 1)
              ctx.strokeStyle = Style.orange
              ctx.lineWidth = 1.4
              ctx.beginPath()
              for (let i = 0; i < hist.length; i++) {
                const x = i * step
                const y = h - (hist[i] / 100) * h
                i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)
              }
              ctx.stroke()
            }
          }
        }
        MouseArea {
          id: cpuMouse
          anchors.fill: parent
          hoverEnabled: true
        }
      }

      // Compact RAM (% only)
      Rectangle {
        id: ramWidget
        color: ramMouse.containsMouse ? Style.barHoverBg : Style.barBg
        radius: Style.radius
        border.width: 1
        border.color: ramMouse.containsMouse ? Style.barHoverBorder : Style.barBorder
        scale: ramMouse.containsMouse ? 1.018 : 1.0
        implicitWidth: 68
        implicitHeight: 26
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        RowLayout {
          anchors.centerIn: parent
          spacing: 4
          Text {
            text: "󰘚"
            font { family: Style.fontFamily; pixelSize: 22 }
            color: Style.lavender
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
          }
          Text {
            text: root.fmt2(root.memPerc) + "%"
            font { family: Style.fontFamily; pixelSize: 17 }
            color: Style.cyan
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
          }
        }
        MouseArea {
          id: ramMouse
          anchors.fill: parent
          hoverEnabled: true
        }
      }
    }

    // Exactly centered workspaces (true geometric center, independent of left/right widths)
    Rectangle {
      id: workspacesBlock
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      color: Style.wsBg
      radius: Style.radius
      border.width: 1
      border.color: Style.wsBorder
      implicitHeight: 38
      implicitWidth: wsContent.implicitWidth + 12 + (specialBadge.visible ? 30 : 0)

      Rectangle {
        id: activeWsHighlight
        readonly property int activeIndex: root.visibleWorkspaces.indexOf(root.focusedWorkspaceId)
        readonly property var activeItem: (wsRepeater.count, activeIndex >= 0 ? wsRepeater.itemAt(activeIndex) : null)
        readonly property real targetLeft: activeItem ? wsContent.x + activeItem.x : wsContent.x
        readonly property real targetRight: targetLeft + (activeItem ? activeItem.width : 0)
        property real actualLeft: targetLeft
        property real actualRight: targetRight
        property int prevIndex: activeIndex
        property int leftDuration: 180
        property int rightDuration: 180

        function tuneEdgeMotion() {
          if (activeIndex > prevIndex) {
            leftDuration = 260
            rightDuration = 135
          } else if (activeIndex < prevIndex) {
            leftDuration = 135
            rightDuration = 260
          } else {
            leftDuration = 180
            rightDuration = 180
          }
          prevIndex = activeIndex
        }

        onTargetLeftChanged: {
          tuneEdgeMotion()
          actualLeft = targetLeft
        }
        onTargetRightChanged: actualRight = targetRight

        x: actualLeft
        y: (workspacesBlock.height - height) / 2
        width: Math.max(0, actualRight - actualLeft)
        height: 30
        radius: 15
        color: Style.wsActive
        border.width: 1
        border.color: Style.wsActiveBorder
        visible: activeItem !== null
        z: 0

        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: Style.wsActive }
          GradientStop { position: 1.0; color: Style.wsActiveAlt }
        }

        Behavior on actualLeft { NumberAnimation { duration: activeWsHighlight.leftDuration; easing.type: Easing.OutCubic } }
        Behavior on actualRight { NumberAnimation { duration: activeWsHighlight.rightDuration; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
      }

      Row {
        id: wsContent
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        z: 1

        Repeater {
          id: wsRepeater
          model: root.visibleWorkspaces
          Rectangle {
            id: wsButton
            required property int modelData
            readonly property int wsId: modelData
            readonly property bool isFocused: root.focusedWorkspaceId === wsId
            readonly property var windows: root.workspaceWindows(wsId)
            readonly property bool isOccupied: windows.length > 0
            readonly property bool isHovered: wsMouse.containsMouse
            readonly property bool isVisibleElsewhere: root.workspaceVisibleElsewhere(wsId)
            readonly property int iconLimit: isFocused ? 4 : 3
            readonly property var shownWindows: windows.slice(0, iconLimit)
            readonly property int overflowCount: Math.max(0, windows.length - shownWindows.length)

            implicitWidth: wsInner.implicitWidth + 10
            implicitHeight: 30
            radius: 15
            color: isFocused ? "transparent" : (isHovered ? Style.wsHoverBg : (isVisibleElsewhere ? Style.wsVisibleBg : (isOccupied ? Style.wsOccupiedBg : Style.wsEmptyBg)))
            border.width: 1.5
            border.color: isFocused ? "transparent" : (isVisibleElsewhere ? Style.wsVisibleBorder : Style.wsInactiveBorder)

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Row {
              id: wsInner
              anchors.centerIn: parent
              spacing: 4

              Rectangle {
                width: 22
                height: 22
                radius: 11
                color: isFocused
                  ? Style.wsBadgeActiveBg
                  : (wsButton.isHovered ? Style.wsBadgeHoverBg : (wsButton.isVisibleElsewhere ? Style.wsBadgeVisibleBg : (wsButton.isOccupied ? Style.wsBadgeOccupiedBg : Style.wsBadgeEmptyBg)))
                border.width: 1
                border.color: isFocused ? Style.wsBadgeActiveBorder : Style.wsBadgeBorder

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                  anchors.fill: parent
                  text: wsButton.wsId
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  color: isFocused ? Style.wsBadgeActiveText : (wsButton.isVisibleElsewhere ? Style.sky : (wsButton.isOccupied ? Style.wsOccupiedText : Style.wsEmptyText))
                  font { family: Style.fontFamily; pixelSize: wsButton.wsId >= 10 ? 10 : 11; bold: true }
                }
              }

              Repeater {
                model: wsButton.shownWindows

                Item {
                  width: 22
                  height: 22

                  IconImage {
                    id: appIcon
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: { root.wsWindowVersion; return root.appIconSource(modelData) }
                    visible: status === Image.Ready
                  }

                  Text {
                    anchors.fill: parent
                    visible: !appIcon.visible
                    text: { root.wsWindowVersion; return root.appFallbackText(modelData) }
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: wsButton.isFocused ? Style.crust : Style.textAlt
                    font { family: Style.fontFamily; pixelSize: 10; bold: true }
                  }
                }
              }

              Rectangle {
                visible: wsButton.overflowCount > 0
                width: visible ? 22 : 0
                height: 22
                radius: 11
                color: Qt.alpha(Style.text, 0.10)
                border.width: 1
                border.color: Qt.alpha(Style.text, 0.18)
                Text {
                  anchors.centerIn: parent
                  text: "+" + wsButton.overflowCount
                  color: wsButton.isFocused ? Style.crust : Style.textMuted
                  font { family: Style.fontFamily; pixelSize: 9; bold: true }
                }
              }
            }

            MouseArea {
              id: wsMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton
              onClicked: root.activateWorkspace(wsButton.wsId)
              onWheel: wheel => root.cycleWorkspace(wheel.angleDelta.y < 0)
            }
          }
        }
      }

      Rectangle {
        id: specialBadge
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: 12
        visible: root.hasSpecialWorkspace
        color: Style.panelAccentBg
        border.width: 1
        border.color: Style.panelAccentBorder
        z: 2

        Text {
          anchors.centerIn: parent
          text: "S"
          color: Style.sky
          font { family: Style.fontFamily; pixelSize: 10; bold: true }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "togglespecialworkspace", "scratch"])
          onWheel: wheel => root.cycleWorkspace(wheel.angleDelta.y < 0)
        }
      }
    }

    // Far right (minimal strip)
    Row {
      id: rightSection
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6
      BarComponents.StatusIndicators {
        notificationCenter: notificationCenter
        isRecording: root.isRecording
        updatesAvailable: root.updatesAvailable
      }
      BarComponents.Microphone {}
      BarComponents.Volume {}

      BarComponents.Network {}
      BarComponents.Bluetooth {}

      BarComponents.Battery {}

      // Clock / date (display only)
      BarComponents.Clock {}
    }
  }

  // (old cpu/mem popups removed - ids gone after compacting)


}
}  // close Variants

    Loader {
        id: launcherLoader
        source: "modules/launcher/LauncherWindow.qml"
        active: true
    }

    IpcHandler {
      target: "launcher"
      function toggle() {
        const l = launcherLoader.item
        if (!l) return
        if (l.shouldShow) {
          if (l.closeLauncher) l.closeLauncher()
          else l.shouldShow = false
        } else {
          if (l.openLauncher) l.openLauncher()
          else l.shouldShow = true
        }
      }
      function files(query: string) {
        const l = launcherLoader.item
        if (l && l.openFileSearch) l.openFileSearch(query || "")
      }
      function openCategory(cat: string) {
        const l = launcherLoader.item
        if (!l) return
        if (l.openCategory) l.openCategory(cat || "")
        else if (l.openLauncher) l.openLauncher()
      }
      function quick(key: string) {
        const l = launcherLoader.item
        if (!l) return
        if (l.openQuick) l.openQuick(key || "hub")
      }
    }

    // featuremodule fully integrated into launcher Quick side popups (exact windows, ref style, symbols, autofill); removed per task
    WallpaperManager {}

}  // close ShellRoot
