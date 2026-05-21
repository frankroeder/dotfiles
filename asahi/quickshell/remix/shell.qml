import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "modules/bar/components" as BarComponents

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

  // Windows on the currently focused workspace — used to show app icons
  // next to the active workspace (only when it contains apps)
  property int wsWindowVersion: 0

  // Only workspaces that contain at least one window (+ always the focused one)
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
        } catch (e) {}
      }
    }
    Component.onCompleted: running = true
  }

  // Update your timer to run both processes
  Timer {
    interval: 2000
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
          Row {
            spacing: 6
            // Workspace number (only occupied + focused)
            Rectangle {
              width: 22
              height: 22
              radius: 4
              color: (Hyprland.focusedWorkspace?.id === modelData) ? "#45475a" : "#2a2a3a"
              border.color: (Hyprland.focusedWorkspace?.id === modelData) ? root.colCyan : "transparent"
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: modelData
                color: (Hyprland.focusedWorkspace?.id === modelData) ? root.colCyan : root.colBlue
                font { family: root.fontFamily; pixelSize: 14; bold: true }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: Hyprland.dispatch("workspace " + modelData)
              }
            }

            // App icons for every workspace that has running apps
            Row {
              spacing: 4
              anchors.verticalCenter: parent.verticalCenter
              Repeater {
                model: {
                  root.wsWindowVersion  // force refresh on window events
                  const wsId = modelData
                  return Hyprland.toplevels.values.filter(function(t) {
                    const w = t.workspace || t.lastIpcObject?.workspace
                    return (w && w.id === wsId) || (t.lastIpcObject?.workspace?.id === wsId)
                  })
                }
                Rectangle {
                  width: 30
                  height: 30
                  radius: 6
                  color: "#313244"
                  border.color: "#585b70"
                  border.width: 1

                  Image {
                    id: winIcon
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    fillMode: Image.PreserveAspectFit
                    source: {
                      const appId = (modelData.appId || modelData.lastIpcObject?.class || "").toLowerCase().trim()
                      if (!appId) return ""

                      const candidates = []

                      // 1. Full cleaned name (best for modern Papirus)
                      candidates.push(appId.replace(/\./g, "-"))

                      // 2. Last meaningful segment
                      const last = appId.split(/[\.-]/).pop()
                      if (last && !["com", "org", "net"].includes(last)) {
                          candidates.push(last)
                      }

                      // 3. Known renames
                      const map = {
                          "google-chrome": "google-chrome",
                          "chrome": "google-chrome",
                          "code": "visual-studio-code",
                          "vscodium": "vscodium",
                          "ghostty": "com.mitchellh.ghostty",
                          "com": "application",
                          "org": "application",
                          "net": "application",
                      }

                      for (const c of candidates) {
                          const name = map[c] || c
                          return `/usr/share/icons/Papirus/24x24/apps/${name}.svg`
                      }

                      return "/usr/share/icons/Papirus/24x24/apps/application.svg"
                    }
                    visible: status === Image.Ready
                  }
                  Text {
                    anchors.centerIn: parent
                    visible: !winIcon.visible
                    text: (modelData.appId || modelData.lastIpcObject?.class || "?").charAt(0).toUpperCase()
                    font.pixelSize: 16
                    font.bold: true
                    color: "#cdd6f4"
                  }
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      const addr = modelData.address || modelData.lastIpcObject?.address
                      if (addr) Hyprland.dispatch("focuswindow address:" + addr)
                    }
                  }
                }
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
    // Right side (as specified): mic, vol, CPU, RAM, Wifi, bluetooth, battery, clock
    BarComponents.Microphone {}
    BarComponents.Volume {}

    // CPU — fixed width
    Rectangle {
      color: "#313244"
      radius: 4
      implicitWidth: 178
      implicitHeight: 24

      Text {
        id: cpuDisplay
        anchors.centerIn: parent
        text: root.cpuText || "CPU --%"
        color: root.colYellow
        font { family: root.fontFamily; pixelSize: 12 }
      }

      MouseArea {
        id: cpuMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["bash", "-c", "/home/froeder/.dotfiles/asahi/bin/asahi-launch-or-focus-tui htop"])
      }
    }

    // Memory (RAM) — fixed width
    Rectangle {
      color: "#313244"
      radius: 4
      implicitWidth: 160
      implicitHeight: 24

      Text {
        id: memDisplay
        anchors.centerIn: parent
        text: root.memText || "Mem --%"
        color: root.colCyan
        font { family: root.fontFamily; pixelSize: 12 }
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

    // Clock last on the right
    BarComponents.Clock {}
  }

  // Custom tooltips sized to full multi-line content (PopupWindow + paintedHeight)
  BarComponents.TooltipWindow {
    id: cpuTip
    target: cpuDisplay
    text: root.cpuTooltip
    show: cpuMa.containsMouse
    maxWidth: 380
  }

  BarComponents.TooltipWindow {
    id: memTip
    target: memDisplay
    text: root.memTooltip
    show: memMa.containsMouse
    maxWidth: 380
  }
}
}  // close Variants
}  // close ShellRoot
