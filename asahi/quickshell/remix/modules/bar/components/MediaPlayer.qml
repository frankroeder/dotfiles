import QtQuick
import "../../../"
import "../../../services" as Services
import "../cava_bars.js" as CavaBars

Item {
  id: root

  property var barHost: null
  property real maxChipWidth: 280
  property bool fullMode: false
  // Notch budget from BarHost; 280 caps the chip on notchless externals.
  readonly property int chipCap: Math.min(root.maxChipWidth, 280)
  readonly property int chipPad: 10

  implicitWidth: Math.min(root.chipCap, contentCol.implicitWidth + root.chipPad)
  implicitHeight: Style.barHeight

  property bool hasMedia: Services.Players.hasPlayer
  property string mediaText: {
    if (!hasMedia) return ""
    const title = Services.Players.title || "Media"
    const artist = Services.Players.artist || ""
    return (Services.Players.isPlaying ? " " : " ") + (artist ? artist + " - " + title : title)
  }

  visible: hasMedia
  onHasMediaChanged: if (!root.hasMedia) root.fullMode = false

  // The shared cava (Services.Cava) runs only while this visualizer shows and music plays.
  readonly property bool cavaWanted: root.fullMode && root.visible && Services.Players.isPlaying
  onCavaWantedChanged: Services.Cava.hold(root, root.cavaWanted)
  Component.onDestruction: Services.Cava.hold(root, false)

  HoverTint { lit: chipMouse.containsMouse }

  Column {
    id: contentCol
    anchors.centerIn: parent
    spacing: 1

    Text {
      id: titleText
      text: root.mediaText
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontBody
      color: barHost ? barHost.barForeground : Style.text
      elide: Text.ElideRight
      width: Math.min(implicitWidth, root.chipCap - root.chipPad)
    }

    Row {
      visible: root.fullMode
      width: titleText.width
      height: 10
      spacing: 1
      Repeater {
        // Bars exist only in full mode: invisible items bound to Cava.values (held e.g. by the media
        // pane) would still repaint the bar window at cava's 30 fps.
        model: root.fullMode ? 24 : 0
        Rectangle {
          required property int index
          width: Math.max(2, (parent.width - 23) / 24)
          anchors.bottom: parent.bottom
          height: CavaBars.barHeight((Services.Cava.values[index] || 0), 10)
          radius: 1
          color: Style.teal
        }
      }
    }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: 6
    anchors.rightMargin: 6
    anchors.bottomMargin: 3
    height: 2
    radius: 1
    color: Qt.alpha(Style.text, 0.12)
    visible: !root.fullMode && Services.Players.progress > 0

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, Services.Players.progress))
      height: parent.height
      radius: parent.radius
      color: Style.teal
      Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }
  }

  Timer {
    id: clickWait
    interval: 220
    onTriggered: Services.Players.playPause()
  }

  MouseArea {
    id: chipMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) Services.Players.next()
      else if (mouse.button === Qt.MiddleButton) Services.Players.previous()
      else clickWait.restart()
    }
    onDoubleClicked: (mouse) => {
      if (mouse.button !== Qt.LeftButton) return
      clickWait.stop()
      root.fullMode = !root.fullMode
    }
  }
}
