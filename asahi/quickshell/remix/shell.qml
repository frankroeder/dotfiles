import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "modules/bar/components" as BarComponents
import "modules/wallpaper"

ShellRoot {
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData
        id: root

        // Theme
        property color colBg: "#1a1b26"
  property color colFg: "#a9b1d6"
  property color colMuted: "#444b6a"
  property color colCyan: "#0db9d7"
  property color colBlue: "#7aa2f7"
  property color colYellow: "#e0af68"
  property string fontFamily: "JetBrainsMono Nerd Font"
  property int fontSize: 16   // bigger symbols / text overall


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

  function fmt2(n) {
    n = Math.round(n)
    if (n > 99) n = 99
    if (n < 0) n = 0
    return n < 10 ? "0" + n : "" + n
  }

  // Windows on the currently focused workspace — used to show app icons
  // next to the active workspace (only when it contains apps)
  property int wsWindowVersion: 0

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
    command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-cpu"]
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

          if (cpuBarGraph) cpuBarGraph.requestPaint()
        } catch (e) {}
      }
    }
    Component.onCompleted: running = true
  }

  // Memory script (usage + history bars like CPU)
  Process {
    id: memScriptProc
    command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-memory"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          root.memText = data.text || "Mem --%"
          root.memTooltip = data.tooltip || ""
          root.memPerc = data.percentage || 0

          root.memHistory.push(root.memPerc)
          if (root.memHistory.length > root.maxGraphHist) root.memHistory.shift()

          if (memBarGraph) memBarGraph.requestPaint()
        } catch (e) {}
      }
    }
    Component.onCompleted: running = true
  }

  // Update your timer to run both processes
  Timer {
    interval: 800
    running: true
    repeat: true
    onTriggered: {
      cpuScriptProc.running = true
      memScriptProc.running = true
    }
  }

  // Keep window icons fresh (Hyprland events + periodic refresh)
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      const n = event.name || ""
      if (["openwindow", "closewindow", "movewindow", "workspace", "focusedmon", "activewindow"].some(x => n.includes(x))) {
        root.wsWindowVersion = (root.wsWindowVersion + 1) % 10000
      }
    }
  }

  Timer {
    interval: 800
    running: true
    repeat: true
    onTriggered: root.wsWindowVersion = (root.wsWindowVersion + 1) % 10000
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: 4
    spacing: 10

    // Power and Control Center on the left
    BarComponents.PowerButton {}

    // Workspaces: only those that contain running apps.
    // Each occupied workspace shows its number + its app icons.
    Rectangle {
      color: "#313244"
      radius: 6
      implicitHeight: 38
      implicitWidth: wsContent.implicitWidth + 14

      Row {
        id: wsContent
        anchors.centerIn: parent
        spacing: 8

        Repeater {
          model: root.occupiedWorkspaces
          // Per-workspace pill: highlighted rectangle containing the number + all its app icons (the bar's workspace overview)
          Rectangle {
            radius: 6
            color: isFocused ? "#3a3f4a" : "#2a2a3a"
            border.color: isFocused ? root.colCyan : "#3a3a4a"
            border.width: 1
            implicitHeight: 32
            implicitWidth: wsInner.implicitWidth + 8

            property bool isFocused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData

            Row {
              id: wsInner
              anchors.centerIn: parent
              spacing: 4

              // Workspace number label (plain, no own MouseArea).
              Rectangle {
                width: 22
                height: 26
                radius: 5
                color: "#25252f"
                border.width: 0

                Text {
                  anchors.centerIn: parent
                  text: modelData
                  color: isFocused ? root.colCyan : root.colBlue
                  font { family: root.fontFamily; pixelSize: 13; bold: true }
                }
              }

              // App icons (the apps "inside" this workspace's overview rect)
              Row {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
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
                    width: 24
                    height: 24
                    radius: 4
                    color: "#313244"
                    border.color: "#585b70"
                    border.width: 1

                    IconImage {
                      id: winIcon
                      anchors.centerIn: parent
                      width: 20
                      height: 20
                      source: {
                        const raw = modelData.appId || modelData.lastIpcObject?.class || ""
                        const entry = DesktopEntries.heuristicLookup(raw)
                        return Quickshell.iconPath(entry?.icon || raw, true)
                      }
                      visible: source !== ""
                    }
                    Text {
                      anchors.centerIn: parent
                      visible: !winIcon.visible
                      text: (modelData.appId || modelData.lastIpcObject?.class || "?").charAt(0).toUpperCase()
                      font.pixelSize: 12
                      font.bold: true
                      color: "#cdd6f4"
                    }

                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: modelData.activate()
                    }
                  }
                }
              }
            }

            // Whole pill is clickable to switch workspace.
            // Uses the proper Quickshell Hyprland API (.activate()) instead of string dispatch
            // to avoid the broken Lua dispatch handler in the user's Hyprland config.
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton
              onClicked: {
                const ws = Hyprland.workspaces.values.find(w => w.id === modelData)
                if (ws) ws.activate()
              }
            }
          }
        }
      }
    }

    // Spacer to push Media to center
    Item { Layout.fillWidth: true }
    Item { Layout.fillWidth: true }
    Item { Layout.fillWidth: true }

    // Media in the middle
    BarComponents.MediaPlayer {}

    // Spacer to push right group to the right

    BarComponents.StatusIndicators {}
    // Right side (as specified): mic, vol, CPU widget (graph left/middle + % + temp right), RAM widget (graph left/middle + % right), net, bt, battery, clock
    BarComponents.Microphone {}
    BarComponents.Volume {}

    // CPU widget: graph occupies left + middle of the widget, percentage (2 digits, leading zero) and temp on the very right of the widget.
    // Temp combined with CPU as requested.
    Rectangle {
      color: "#313244"
      radius: 4
      implicitWidth: 170
      implicitHeight: 24

      RowLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 4

        Canvas {
          id: cpuBarGraph
          Layout.fillWidth: true
          Layout.preferredWidth: 120
          Layout.preferredHeight: 12
          Layout.alignment: Qt.AlignVCenter
          onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            const h = height; const w = width
            const hist = root.cpuHistory
            if (!hist || hist.length < 2) return
            const n = hist.length
            const step = w / (n - 1)
            const color = "#fab387"
            ctx.lineJoin = "round"; ctx.lineCap = "round"

            const grad = ctx.createLinearGradient(0, 0, 0, h)
            grad.addColorStop(0, Qt.alpha(color, 0.35))
            grad.addColorStop(1, "transparent")
            ctx.fillStyle = grad
            ctx.beginPath()
            ctx.moveTo(0, h)
            for (let i = 0; i < n; i++) {
              const x = i * step
              const y = h - (hist[i] / 100) * h
              ctx.lineTo(x, y)
            }
            ctx.lineTo(w, h)
            ctx.closePath()
            ctx.fill()

            ctx.beginPath()
            for (let j = 0; j < n; j++) {
              const x = j * step
              const y = h - (hist[j] / 100) * h
              if (j === 0) ctx.moveTo(x, y)
              else ctx.lineTo(x, y)
            }
            ctx.strokeStyle = color
            ctx.lineWidth = 1.4
            ctx.stroke()

            const lx = (n - 1) * step
            const ly = h - (hist[n - 1] / 100) * h
            ctx.fillStyle = color
            ctx.beginPath()
            ctx.arc(lx, ly, 1.2, 0, 6.28)
            ctx.fill()
          }
        }

        // Right of CPU widget: percentage with % symbol, temperature right next to it (combined as requested)
        Row {
          Layout.preferredWidth: 94
          spacing: 4
          Text {
            text: "CPU " + fmt2(root.cpuPerc) + "%"
            color: root.colYellow
            font { family: root.fontFamily; pixelSize: 14 }
            horizontalAlignment: Text.AlignRight
          }
          Text {
            text: fmt2(root.cpuTempText) + "°C"
            color: "#a9b1d6"
            font { family: root.fontFamily; pixelSize: 14 }
            horizontalAlignment: Text.AlignRight
          }
        }
      }

      MouseArea {
        id: cpuMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["bash", "-c", "/home/froeder/.dotfiles/asahi/bin/asahi-launch-or-focus-tui htop"])
      }
    }

    // RAM widget: graph occupies left + middle of the widget, percentage (2 digits) on the very right of the widget.
    Rectangle {
      color: "#313244"
      radius: 4
      implicitWidth: 130
      implicitHeight: 24

      RowLayout {
        anchors.fill: parent
        anchors.margins: 3
        spacing: 4

        Canvas {
          id: memBarGraph
          Layout.fillWidth: true
          Layout.preferredWidth: 100
          Layout.preferredHeight: 12
          Layout.alignment: Qt.AlignVCenter
          onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            const h = height; const w = width
            const hist = root.memHistory
            if (!hist || hist.length < 2) return
            const n = hist.length
            const step = w / (n - 1)
            const color = "#b4befe"
            ctx.lineJoin = "round"; ctx.lineCap = "round"

            const grad = ctx.createLinearGradient(0, 0, 0, h)
            grad.addColorStop(0, Qt.alpha(color, 0.35))
            grad.addColorStop(1, "transparent")
            ctx.fillStyle = grad
            ctx.beginPath()
            ctx.moveTo(0, h)
            for (let i = 0; i < n; i++) {
              const x = i * step
              const y = h - (hist[i] / 100) * h
              ctx.lineTo(x, y)
            }
            ctx.lineTo(w, h)
            ctx.closePath()
            ctx.fill()

            ctx.beginPath()
            for (let j = 0; j < n; j++) {
              const x = j * step
              const y = h - (hist[j] / 100) * h
              if (j === 0) ctx.moveTo(x, y)
              else ctx.lineTo(x, y)
            }
            ctx.strokeStyle = color
            ctx.lineWidth = 1.4
            ctx.stroke()

            const lx = (n - 1) * step
            const ly = h - (hist[n - 1] / 100) * h
            ctx.fillStyle = color
            ctx.beginPath()
            ctx.arc(lx, ly, 1.2, 0, 6.28)
            ctx.fill()
          }
        }

        // Right of RAM widget: percentage with % symbol
        Text {
          text: "RAM " + fmt2(root.memPerc) + "%"
          color: root.colCyan
          font { family: root.fontFamily; pixelSize: 13 }
          Layout.preferredWidth: 60
          horizontalAlignment: Text.AlignRight
          Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        }
      }

      MouseArea {
        id: memMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
      }
    }

    BarComponents.Network {}
    BarComponents.Bluetooth {}

    BarComponents.Battery {}

    // Clock last on the right - click to open launcher
    BarComponents.Clock {
      launcher: launcherLoader.item
    }
  }

  // Custom tooltips attached to each widget's MouseArea
  BarComponents.TooltipWindow {
    id: cpuTip
    target: cpuMa
    text: root.cpuTooltip
    show: cpuMa.containsMouse
    maxWidth: 380
  }

  BarComponents.TooltipWindow {
    id: memTip
    target: memMa
    text: root.memTooltip
    show: memMa.containsMouse
    maxWidth: 380
  }
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

    WallpaperManager {}

}  // close ShellRoot
