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

  // Windows on the currently focused workspace — used to show app icons
  // next to the active workspace (only when it contains apps)
  property int wsWindowVersion: 0
  property int wsIconRefreshes: 0

  function refreshWorkspaceIcons(retries) {
    root.wsWindowVersion = (root.wsWindowVersion + 1) % 10000
    if (retries > root.wsIconRefreshes) root.wsIconRefreshes = retries
    if (root.wsIconRefreshes > 0 && !wsIconRefreshTimer.running) wsIconRefreshTimer.restart()
  }

  function appIconSource(t) {
    const raw = String(t.appId || t.lastIpcObject?.class || t.lastIpcObject?.initialClass || "").trim()
    if (raw === "") return ""
    const entry = DesktopEntries.heuristicLookup(raw)
    return Quickshell.iconPath(entry?.icon || raw, true)
  }

  // Workspaces that contain windows (or the focused one), in stable numeric order.
  // Active workspace is highlighted with color/border on its pill; order never changes to avoid jumping.
  readonly property var occupiedWorkspaces: {
    wsWindowVersion
    const ids = new Set()
    for (const t of Hyprland.toplevels.values) {
      const id = t.workspace?.id ?? t.lastIpcObject?.workspace?.id
      if (id != null) ids.add(id)
    }
    const focused = Hyprland.focusedWorkspace?.id
    if (focused != null) ids.add(focused)
    return Array.from(ids).sort((a, b) => a - b)
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
    }

    // Exactly centered workspaces (true geometric center, independent of left/right widths)
    Rectangle {
      id: workspacesBlock
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      color: Style.moduleBg
      radius: 6
      implicitHeight: 38
      implicitWidth: wsContent.implicitWidth + 14

      Row {
        id: wsContent
        anchors.centerIn: parent
        spacing: 8

        Repeater {
          model: root.occupiedWorkspaces
          Rectangle {
            radius: 6
            border.width: 1
            implicitHeight: 32
            implicitWidth: wsInner.implicitWidth + 8

            property bool isFocused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData

            color: isFocused ? Qt.alpha(Style.primary, 0.15) : Style.controlBg
            border.color: isFocused ? Style.primary : Style.border

            Row {
              id: wsInner
              anchors.centerIn: parent
              spacing: 4

              Rectangle {
                width: 22; height: 26; radius: 5; color: Style.wsNumBg; border.width: 0
                Text {
                  anchors.centerIn: parent; text: modelData
                  color: isFocused ? Style.primary : Style.blue
                  font { family: Style.fontFamily; pixelSize: 13; bold: true }
                }
              }

              Row {
                spacing: 3; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                  model: {
                    root.wsWindowVersion
                    const wsId = modelData
                    return Hyprland.toplevels.values.filter(function(t) {
                      const w = t.workspace || t.lastIpcObject?.workspace
                      return (w && w.id === wsId) || (t.lastIpcObject?.workspace?.id === wsId)
                    })
                  }
                  Rectangle {
                    width: 24; height: 24; radius: 4; color: Style.moduleBg; border { color: Style.border; width: 1 }
                    IconImage {
                      id: winIcon; anchors.centerIn: parent; width: 20; height: 20
                      source: { root.wsWindowVersion; return root.appIconSource(modelData) }
                      visible: source !== ""
                    }
                    Text {
                      anchors.centerIn: parent; visible: !winIcon.visible
                      text: (modelData.appId || modelData.lastIpcObject?.class || "?").charAt(0).toUpperCase()
                      font.pixelSize: 12; font.bold: true; color: Style.text
                    }
                    MouseArea {
                      anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                      onClicked: modelData.activate()
                    }
                  }
                }
              }
            }

            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton
              onClicked: {
                const ws = Hyprland.workspaces.values.find(w => w.id === modelData)
                if (ws) ws.activate()
              }
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

      // Compact CPU (icon + % + temp, click for graph popup) - match Vol/Mic sizes
      Rectangle {
        color: Style.moduleBg
        radius: 6
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
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.showCpuPopup = !root.showCpuPopup
        }
      }

      // Compact RAM (% only, click for graph popup) - match Vol/Mic sizes
      Rectangle {
        color: Style.moduleBg
        radius: 6
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
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.showRamPopup = !root.showRamPopup
        }
      }

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
    anchors { top: true; right: true }
    margins { top: 48; right: 8 }
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
    anchors { top: true; right: true }
    margins { top: 48; right: 8 }
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
