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

  color: solidBar ? "transparent" : (micMouse.containsMouse ? Style.barHoverBg : Style.barBg)
  radius: solidBar ? 0 : Style.radius
  border.width: solidBar ? 0 : 1
  border.color: solidBar ? "transparent" : (micMouse.containsMouse ? Style.barHoverBorder : Style.barBorder)
  Behavior on color { ColorAnimation { duration: 140 } }
  Behavior on border.color { ColorAnimation { duration: 140 } }
  scale: solidBar ? 1.0 : (micMouse.containsMouse ? 1.018 : 1.0)

  implicitWidth: content.implicitWidth + (solidBar ? 10 : 14)
  implicitHeight: solidBar ? Style.barHeight : 30

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: Style.barChipInset
    anchors.bottomMargin: Style.barChipInset
    radius: Style.radiusSm
    visible: solidBar
    color: micMouse.containsMouse ? Style.barStripHover : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  property bool muted: false
  property int level: -1
  readonly property string iconGlyph: muted ? "󰍭" : "󰍬"
  readonly property string levelText: level >= 0 ? level + "%" : "--%"

  RowLayout {
    id: content
    anchors.centerIn: parent
    spacing: 4

    Text {
      text: root.iconGlyph
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontMicVolIcon
      color: root.muted ? Style.red : Style.blueAlt
    }

    Text {
      text: root.levelText
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontBody
      color: barHost ? barHost.barForeground : Style.text
    }
  }

  Process {
    id: micProc
    command: ["bash", binDir + "/asahi-audio", "input"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          root.muted = (data.class || []).includes("muted")
          if (typeof data.percentage === "number") root.level = data.percentage
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: micProc.running = true
  }

  Component.onCompleted: micProc.running = true

  MouseArea {
    id: micMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["bash", "-c", binDir + "/asahi-media-control input-volume mute-toggle"])
    onWheel: wheel => {
      const direction = wheel.angleDelta.y > 0 ? "raise" : "lower"
      Quickshell.execDetached(["bash", "-c", binDir + "/asahi-media-control input-volume " + direction])
    }
  }

  TooltipWindow {
    target: root
    text: "Microphone\nClick: mute\nScroll: adjust"
    show: micMouse.containsMouse
  }
}
