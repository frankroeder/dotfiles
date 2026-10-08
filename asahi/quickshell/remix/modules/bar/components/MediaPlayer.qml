import QtQuick
import Quickshell.Widgets
import "../../../"
import "../../../services" as Services

// Now-playing chip (serpantinum MediaFace): art thumb + title / artist. Click = MediaPanel,
// middle = play/pause, right = next. Accent thumb ring while playing; title scrolls on hover only
// (a free-running marquee would repaint the bar every frame).
Item {
  id: root

  property var barHost: null
  property real maxChipWidth: 260
  property bool panelOpen: false
  signal toggled()
  // Notch budget from BarHost; 260 caps the chip on notchless externals.
  readonly property int chipCap: Math.min(root.maxChipWidth, 260)
  readonly property int thumb: Style.barHeight - 2 * Style.barChipInset - 6
  readonly property real textMax: root.chipCap - root.thumb - 22

  // Uncapped wish (BarHost's temperature-fits check must not depend on the cap it feeds).
  readonly property real naturalWidth: root.thumb + 22 + Math.max(titleText.implicitWidth, artistText.implicitWidth)
  implicitWidth: Math.min(root.chipCap, root.naturalWidth)
  implicitHeight: Style.barHeight

  readonly property bool hasMedia: Services.Players.hasPlayer
  readonly property bool playing: Services.Players.isPlaying
  visible: hasMedia

  HoverTint { lit: chipMouse.containsMouse || root.panelOpen }

  Rectangle {
    id: thumbBox
    x: 6
    anchors.verticalCenter: parent.verticalCenter
    width: root.thumb; height: root.thumb; radius: 7
    color: Style.m3primaryContainer
    border.width: 1.5
    border.color: root.playing ? Style.accent : Style.surface1
    Behavior on border.color { ColorAnimation { duration: 200 } }
    Text {
      anchors.centerIn: parent
      visible: Services.Players.artUrl === ""
      text: "󰎈"
      color: Style.accent
      font.family: Style.fontFamily
      font.pixelSize: 14
    }
    ClippingRectangle {
      anchors.fill: parent
      anchors.margins: 1.5
      radius: 6
      color: "transparent"
      visible: Services.Players.artUrl !== ""
      Image {
        anchors.fill: parent
        source: Services.Players.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(64, 64)
      }
    }
  }

  Item {
    id: textBox
    anchors.left: thumbBox.right
    anchors.leftMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(root.textMax, Math.max(titleText.implicitWidth, artistText.implicitWidth))
    height: titleText.height + artistText.height - 2
    clip: true

    Text {
      id: titleText
      // Overflowing titles slide to their end while hovered, then back.
      readonly property real overflow: Math.max(0, implicitWidth - textBox.width)
      readonly property bool sliding: chipMouse.containsMouse && overflow > 0
      x: sliding ? -overflow : 0
      width: sliding ? implicitWidth : textBox.width
      elide: sliding ? Text.ElideNone : Text.ElideRight
      Behavior on x { NumberAnimation { duration: Math.max(400, titleText.overflow * 18); easing.type: Easing.InOutSine } }
      text: Services.Players.title || "Media"
      font.family: Style.menuSans
      font.pixelSize: Style.barFontCaption + 1
      font.weight: Font.DemiBold
      color: root.barHost ? root.barHost.barForeground : Style.text
    }
    Text {
      id: artistText
      y: titleText.height - 2
      width: textBox.width
      text: Services.Players.artist || Services.Players.active?.identity || ""
      font.family: Style.menuSans
      font.pixelSize: Style.barFontCaption - 1
      color: Style.barStripMuted
      elide: Text.ElideRight
    }
  }

  MouseArea {
    id: chipMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) Services.Players.next()
      else if (mouse.button === Qt.MiddleButton) Services.Players.playPause()
      else root.toggled()
    }
  }
}
