import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Compact System Usage - CPU / Mem / Disk percentages
// Inspired by reference SystemUsage.qml but script-light for the remix
Item {
  id: root

  implicitWidth: usageRow.implicitWidth
  implicitHeight: 26

  property real cpuPerc: 0
  property real memPerc: 0
  property real diskPerc: 0

  Process {
    id: usageProc
    command: ["bash", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1; free | awk '/Mem/ {printf \"%.0f\", $3/$2*100}'; df / | awk 'NR==2 {print $5}' | tr -d '%' "]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n")
        if (lines.length >= 3) {
          root.cpuPerc = parseFloat(lines[0]) || 0
          root.memPerc = parseFloat(lines[1]) || 0
          root.diskPerc = parseFloat(lines[2]) || 0
        }
      }
    }
  }

  Timer {
    interval: 4000
    running: true
    repeat: true
    onTriggered: usageProc.running = true
  }

  Component.onCompleted: usageProc.running = true

  RowLayout {
    id: usageRow
    anchors.centerIn: parent
    spacing: 8

    // CPU
    Row {
      spacing: 3
      Text { text: "󰘚"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: "#fab387" }
      Text { text: Math.round(cpuPerc) + "%"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: "#cdd6f4" }
    }

    Rectangle { width: 1; height: 12; color: "#45475a" }

    // Memory
    Row {
      spacing: 3
      Text { text: "󰍛"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: "#b4befe" }
      Text { text: Math.round(memPerc) + "%"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: "#cdd6f4" }
    }

    Rectangle { width: 1; height: 12; color: "#45475a" }

    // Disk
    Row {
      spacing: 3
      Text { text: "󰋊"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: "#94e2d5" }
      Text { text: Math.round(diskPerc) + "%"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: "#cdd6f4" }
    }
  }
}