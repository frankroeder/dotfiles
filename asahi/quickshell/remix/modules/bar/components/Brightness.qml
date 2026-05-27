import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"

// Simple Brightness pill - reuses asahi data approach
Rectangle {
  id: root

  implicitWidth: row.implicitWidth + 14
  implicitHeight: 26
  color: brightnessMouse.containsMouse ? Style.hoverBg : Style.moduleBg
  radius: Style.radius
  border.width: 1
  border.color: Style.border

  property string text: "☀ --%"

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 2

    Text {
      text: root.text
      font.family: Style.fontFamily
      font.pixelSize: 17
      color: Style.orange
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
    id: brightnessMouse
    anchors.fill: parent
    hoverEnabled: true
    onWheel: (wheel) => {
      const dir = wheel.angleDelta.y > 0 ? " -A 5" : " -U 5"
      Quickshell.execDetached(["bash", "-c", "brightnessctl" + dir])
    }
  }
}
