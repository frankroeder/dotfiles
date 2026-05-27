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

  // For the new graphical short history graphs (replaces old unicode blocks)
  property real cpuPerc: 0
  property real memPerc: 0
  property string cpuTempText: ""
  property var cpuHistory: []
  property var memHistory: []
  readonly property int maxGraphHist: 22

  // For ref-like popups (icons in bar, detail on click)
  property bool showCpuPopup: false
  property bool showRamPopup: false

  onShowCpuPopupChanged: {
    if (!showCpuPopup) return
    cpuHistory = []
    root.refreshCpu()
    cpuPopupTimer.restart()
  }
  onShowRamPopupChanged: {
    if (!showRamPopup) return
    memHistory = []
    root.refreshMem()
    memPopupTimer.restart()
  }

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

  function toggleCpuPopup() {
    showRamPopup = false
    showCpuPopup = !showCpuPopup
  }

  function toggleRamPopup() {
    showCpuPopup = false
    showRamPopup = !showRamPopup
  }

  // Bump bindings that derive workspace occupancy/icons from Hyprland toplevel state.
  property int wsWindowVersion: 0
  property int wsIconRefreshes: 0

  function refreshWorkspaceIcons(retries) {
    root.wsWindowVersion = (root.wsWindowVersion + 1) % 10000
    if (retries > root.wsIconRefreshes) root.wsIconRefreshes = retries
    if (root.wsIconRefreshes > 0 && !wsIconRefreshTimer.running) wsIconRefreshTimer.restart()
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

  readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace?.id ?? 1
  readonly property var occupiedWorkspaces: {
    wsWindowVersion
    const ids = new Set()
    for (const t of Hyprland.toplevels.values) {
      const id = t.workspace?.id ?? t.lastIpcObject?.workspace?.id
      if (id != null) ids.add(id)
    }
    return Array.from(ids).sort((a, b) => a - b)
  }

  function workspaceWindows(wsId) {
    root.wsWindowVersion
    return Hyprland.toplevels.values.filter(function(t) {
      const w = t.workspace || t.lastIpcObject?.workspace
      return (w && w.id === wsId) || (t.lastIpcObject?.workspace?.id === wsId)
    })
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

          if (root.showCpuPopup) {
            root.cpuHistory.push(root.cpuPerc)
            if (root.cpuHistory.length > root.maxGraphHist) root.cpuHistory.shift()

            cpuPopupGraph.requestPaint()
          }
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

          if (root.showRamPopup) {
            root.memHistory.push(root.memPerc)
            if (root.memHistory.length > root.maxGraphHist) root.memHistory.shift()

            memPopupGraph.requestPaint()
          }
        } catch (e) {}
      }
    }
    Component.onCompleted: root.refreshMem()
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
    id: cpuPopupTimer
    interval: 800
    running: root.showCpuPopup
    repeat: true
    onTriggered: root.refreshCpu()
  }

  Timer {
    id: memPopupTimer
    interval: 800
    running: root.showRamPopup
    repeat: true
    onTriggered: root.refreshMem()
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
      BarComponents.StatusIndicators { notificationCenter: notificationCenter }

      // Compact CPU (icon + % + temp, click for graph popup)
      Rectangle {
        id: cpuWidget
        color: cpuMouse.containsMouse ? Style.hoverBg : Style.moduleBg
        radius: Style.radius
        border.width: 1
        border.color: Style.border
        implicitWidth: 96
        implicitHeight: 26
        RowLayout {
          anchors.centerIn: parent
          spacing: 4
          Text {
            text: "󰍛"
            font { family: Style.fontFamily; pixelSize: 22 }
            color: Style.orange
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
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
        }
        MouseArea {
          id: cpuMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggleCpuPopup()
        }
      }

      // Compact RAM (% only, click for graph popup)
      Rectangle {
        id: ramWidget
        color: ramMouse.containsMouse ? Style.hoverBg : Style.moduleBg
        radius: Style.radius
        border.width: 1
        border.color: Style.border
        implicitWidth: 68
        implicitHeight: 26
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
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggleRamPopup()
        }
      }
    }

    // Exactly centered workspaces (true geometric center, independent of left/right widths)
    Rectangle {
      id: workspacesBlock
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      color: Style.moduleBg
      radius: Style.radius
      border.width: 1
      border.color: Style.border
      implicitHeight: 38
      implicitWidth: wsContent.implicitWidth + 12

      Row {
        id: wsContent
        anchors.centerIn: parent
        spacing: 4

        Repeater {
          model: root.occupiedWorkspaces
          Rectangle {
            id: wsButton
            required property int modelData
            readonly property int wsId: modelData
            readonly property bool isFocused: root.focusedWorkspaceId === wsId
            readonly property var windows: root.workspaceWindows(wsId)

            implicitWidth: wsInner.implicitWidth + 10
            implicitHeight: 30
            radius: 15
            color: isFocused ? Qt.alpha(Style.primary, 0.18) : Style.controlBg
            border.width: 1
            border.color: isFocused ? Style.primary : Style.border

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
                color: isFocused ? Style.primary : Style.wsNumBg

                Text {
                  anchors.fill: parent
                  text: wsButton.wsId
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  color: isFocused ? Style.onPrimary : Style.text
                  font { family: Style.fontFamily; pixelSize: wsButton.wsId >= 10 ? 10 : 11; bold: true }
                }
              }

              Repeater {
                model: wsButton.windows

                Item {
                  width: 22
                  height: 22

                  IconImage {
                    id: appIcon
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: root.appIconSource(modelData)
                    visible: status === Image.Ready
                  }

                  Text {
                    anchors.fill: parent
                    visible: !appIcon.visible
                    text: root.appFallbackText(modelData)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: Style.text
                    font { family: Style.fontFamily; pixelSize: 10; bold: true }
                  }
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton
              onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsButton.wsId + " })")
            }
          }
        }
      }
    }

    // Far right (minimal strip)
    Row {
      id: rightSection
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6
      BarComponents.Microphone {}
      BarComponents.Volume {}

      BarComponents.Network {}
      BarComponents.Bluetooth {}

      BarComponents.Battery {}

      // Clock / date (display only)
      BarComponents.Clock {}
    }
  }

  // Graph popups (ref-style minimal: icons in bar, click for full canvas detail)
  PanelWindow {
    visible: root.showCpuPopup; color: "transparent"
    anchors { top: true; left: true }
    margins { top: 48; left: barContent.x + leftSection.x + cpuWidget.x }
    implicitWidth: 420; implicitHeight: 110
    Rectangle { anchors.fill: parent; color: Style.moduleBg; radius: 8; border { color: Style.primary; width: 1 }
      Column { anchors { fill: parent; margins: 8 }
        Text {
          text: root.cpuText
          color: Style.orange; font { family: Style.fontFamily; pixelSize: 12; bold: true }
        }
        Canvas { id: cpuPopupGraph; width: parent.width - 16; height: 60; onPaint: {
          const ctx = getContext("2d"); ctx.reset(); const h = height; const w = width; const hist = root.cpuHistory
          if (!hist || hist.length < 2) return; const n = hist.length; const step = w / (n - 1); const c = Style.orange
          ctx.strokeStyle = c; ctx.lineWidth = 1.5; ctx.beginPath()
          for (let j = 0; j < n; j++) { const x = j * step; const y = h - (hist[j] / 100) * h; j ? ctx.lineTo(x, y) : ctx.moveTo(x, y) }
          ctx.stroke()
        } }
        Text { text: "click icon to close"; color: Style.textMuted; font.pixelSize: 10 }
      }
      MouseArea { anchors.fill: parent; onClicked: root.showCpuPopup = false }
    }
  }
  PanelWindow {
    visible: root.showRamPopup; color: "transparent"
    anchors { top: true; left: true }
    margins { top: 48; left: barContent.x + leftSection.x + ramWidget.x }
    implicitWidth: 420; implicitHeight: 110
    Rectangle { anchors.fill: parent; color: Style.moduleBg; radius: 8; border { color: Style.primary; width: 1 }
      Column { anchors { fill: parent; margins: 8 }
        Text { text: "RAM " + root.memText; color: Style.lavender; font { family: Style.fontFamily; pixelSize: 12; bold: true } }
        Canvas { id: memPopupGraph; width: parent.width - 16; height: 60; onPaint: {
          const ctx = getContext("2d"); ctx.reset(); const h = height; const w = width; const hist = root.memHistory
          if (!hist || hist.length < 2) return; const n = hist.length; const step = w / (n - 1); const c = Style.lavender
          ctx.strokeStyle = c; ctx.lineWidth = 1.5; ctx.beginPath()
          for (let j = 0; j < n; j++) { const x = j * step; const y = h - (hist[j] / 100) * h; j ? ctx.lineTo(x, y) : ctx.moveTo(x, y) }
          ctx.stroke()
        } }
        Text { text: "click icon to close"; color: Style.textMuted; font.pixelSize: 10 }
      }
      MouseArea { anchors.fill: parent; onClicked: root.showRamPopup = false }
    }
  }
  // (old cpu/mem tooltips removed - ids gone after compacting)


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
    }

    Loader {
      id: featureLoader
      source: "modules/featuremenu/FeatureMenuWindow.qml"
      active: true
    }

    IpcHandler {
      target: "feature"
      function toggle() {
        const f = featureLoader.item
        if (!f) return
        if (f.shouldShow) {
          if (f.closeFeature) f.closeFeature()
          else f.shouldShow = false
        } else {
          if (f.openFeature) f.openFeature()
          else f.shouldShow = true
        }
      }
    }

    WallpaperManager {}

}  // close ShellRoot
