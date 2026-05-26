import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"
import "../../../services" as Services

Rectangle {
  id: root

  color: Style.moduleBg
  radius: 6

  implicitWidth: Math.min(320, contentRow.implicitWidth + 16)
  implicitHeight: 26

  property bool hasMedia: Services.Players.hasPlayer
  property string mediaText: {
    if (!hasMedia) return ""
    const title = Services.Players.title || "Media"
    const artist = Services.Players.artist || ""
    return (Services.Players.isPlaying ? " " : " ") + (artist ? artist + " - " + title : title)
  }

  visible: hasMedia

  RowLayout {
    id: contentRow
    anchors.centerIn: parent
    spacing: 6

    Text {
      text: root.mediaText
      font.family: Style.fontFamily
      font.pixelSize: 14
      color: Style.text
      elide: Text.ElideRight
      Layout.maximumWidth: 230
    }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 3
    height: 2
    radius: 1
    color: Qt.rgba(0, 0, 0, 0.22)
    visible: Services.Players.progress > 0

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, Services.Players.progress))
      height: parent.height
      radius: parent.radius
      color: Style.green
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) Services.Players.next()
      else if (mouse.button === Qt.MiddleButton) Services.Players.previous()
      else Services.Players.playPause()
    }
  }
}
