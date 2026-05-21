import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
  id: root

  // Theme
  property color colBg: "#1a1b26"
  property color colFg: "#a9b1d6"
  property color colMuted: "#444b6a"
  property color colCyan: "#0db9d7"
  property color colBlue: "#7aa2f7"
  property color colYellow: "#e0af68"
  property string fontFamily: "JetBrainsMono Nerd Font"
  property int fontSize: 14

  // System data
  property int cpuUsage: 0
  property int memUsage: 0
  property var lastCpuIdle: 0
  property var lastCpuTotal: 0

  // Processes and timers here...

  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: 30
  color: root.colBg

  Process {
    id: cpuProc
    command: ["sh", "-c", "head -1 /proc/stat"]
    stdout: SplitParser {
      onRead: data => {
        if (!data) return
        var p = data.trim().split(/\s+/)
        var idle = parseInt(p[4]) + parseInt(p[5])
        var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0)
        if (lastCpuTotal > 0) {
          cpuUsage = Math.round(100 * (1 - (idle - lastCpuIdle) / (total - lastCpuTotal)))
        }
        lastCpuTotal = total
        lastCpuIdle = idle
      }
    }
    Component.onCompleted: running = true
  }

  // Memory process
  Process {
    id: memProc
    command: ["sh", "-c", "free | grep Mem"]
    stdout: SplitParser {
      onRead: data => {
        if (!data) return
        var parts = data.trim().split(/\s+/)
        var total = parseInt(parts[1]) || 1
        var used = parseInt(parts[2]) || 0
        memUsage = Math.round(100 * used / total)
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
      cpuProc.running = true
      memProc.running = true
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: 8
    spacing: 8

    // Workspaces
    Repeater {
      model: 9
      Text {
        property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
        property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
        text: index + 1
        color: isActive ? root.colCyan : (ws ? root.colBlue : root.colMuted)
        font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
        MouseArea {
          anchors.fill: parent
          onClicked: Hyprland.dispatch("workspace " + (index + 1))
        }
      }
    }

    Item { Layout.fillWidth: true }

    // CPU
    Text {
      text: "CPU: " + cpuUsage + "%"
      color: root.colYellow
      font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
    }

    Rectangle { width: 1; height: 16; color: root.colMuted }

    // Memory
    Text {
      text: "Mem: " + memUsage + "%"
      color: root.colCyan
      font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
    }

    Rectangle { width: 1; height: 16; color: root.colMuted }

    // Clock
    Text {
      id: clock
      color: root.colBlue
      font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
      text: Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
      Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
      }
    }
  }
}
