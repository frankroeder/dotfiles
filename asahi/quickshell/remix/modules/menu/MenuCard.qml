import QtQuick
import "../../"

Rectangle {
  id: root
  property int cardRadius: Style.menuRadius
  property int cardMargin: 17
  default property alias content: inner.data

  color: Style.menuBg
  border.color: Style.menuSep
  border.width: 1
  radius: cardRadius
  clip: true

  MouseArea {
    anchors.fill: parent
    onClicked: mouse => mouse.accepted = true
  }

  Item {
    id: inner
    anchors.fill: parent
    anchors.margins: root.cardMargin
  }
}