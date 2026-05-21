import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Simple Brightness pill - reuses waybar-like data approach
Item {
  id: root

  implicitWidth: row.implicitWidth
  implicitHeight: 30

  property string text: "☀ --%"

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 2

    Text {
      text: root.text
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 17
      color: "#fab387"
    }
  }

  Process {
    id: brightProc
    command: ["bash", "-c", "brightnessctl -m | awk -F, '{print $4}'"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.text = "☀ " + (text.trim() || "--%")
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: brightProc.running = true
  }

  MouseArea {
    anchors.fill: parent
    onWheel: (wheel) => {
      const dir = wheel.angleDelta.y > 0 ? " -A 5" : " -U 5"
      Quickshell.execDetached(["bash", "-c", "brightnessctl" + dir])
    }
  }
}
