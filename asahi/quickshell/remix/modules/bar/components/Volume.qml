import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"

Rectangle {
  id: root

  property var barHost: null
  readonly property bool solidBar: barHost !== null && barHost !== undefined

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  color: solidBar ? "transparent" : (volumeMouse.containsMouse ? Style.barHoverBg : Style.barBg)
  radius: solidBar ? 0 : Style.radius
  border.width: solidBar ? 0 : 1
  border.color: solidBar ? "transparent" : (volumeMouse.containsMouse ? Style.barHoverBorder : Style.barBorder)
  Behavior on color { ColorAnimation { duration: 140 } }
  Behavior on border.color { ColorAnimation { duration: 140 } }
  scale: solidBar ? 1.0 : (volumeMouse.containsMouse ? 1.018 : 1.0)

  implicitWidth: content.implicitWidth + (solidBar ? 10 : 14)
  implicitHeight: solidBar ? Style.barHeight : 30

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: Style.barChipInset
    anchors.bottomMargin: Style.barChipInset
    radius: Style.radiusSm
    visible: solidBar
    color: volumeMouse.containsMouse ? Style.barStripHover : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  property bool muted: false
  property int percentage: -1

  function outputIcon(pct, isMuted) {
    if (isMuted) return "󰖁"
    if (pct <= 30) return "󰕿"
    if (pct <= 60) return "󰖀"
    return "󰕾"
  }

  readonly property string iconGlyph: outputIcon(percentage, muted)
  readonly property string levelText: percentage >= 0 ? percentage + "%" : "--%"

  RowLayout {
    id: content
    anchors.centerIn: parent
    spacing: 4

    Text {
      text: root.iconGlyph
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontMicVolIcon
      color: root.muted ? Style.red : Style.green
    }

    Text {
      text: root.levelText
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontBody
      color: barHost ? barHost.barForeground : Style.text
    }
  }

  Process {
    id: audioProc
    command: ["bash", binDir + "/asahi-audio", "output"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          root.muted = (data.class || []).includes("muted")
          if (typeof data.percentage === "number") root.percentage = data.percentage
        } catch (e) {
          root.percentage = -1
        }
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: audioProc.running = true
  }

  Component.onCompleted: audioProc.running = true

  Timer {
    id: refreshDelay
    interval: 250
    onTriggered: audioProc.running = true
  }

  MouseArea {
    id: volumeMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      Quickshell.execDetached(["bash", "-c", binDir + "/asahi-media-control output-volume mute-toggle"])
      refreshDelay.restart()
    }
    onWheel: wheel => {
      const direction = wheel.angleDelta.y > 0 ? "raise" : "lower"
      Quickshell.execDetached(["bash", "-c", binDir + "/asahi-media-control output-volume " + direction])
      refreshDelay.restart()
    }
  }
}
