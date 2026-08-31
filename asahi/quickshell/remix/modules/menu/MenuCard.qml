import QtQuick
import "../../"

Rectangle {
  id: root
  property int cardRadius: Style.menuRadius
  property int cardMargin: 18
  property real chromeReveal: 1.0
  default property alias content: inner.data

  color: Style.menuBg
  border.color: Style.menuSep
  border.width: 1
  radius: cardRadius
  clip: true
  opacity: chromeReveal
  scale: 0.96 + 0.04 * chromeReveal
  transformOrigin: Item.Center

  Behavior on opacity {
    NumberAnimation {
      duration: Style.menuAnimMs
      easing.type: Easing.OutCubic
    }
  }
  Behavior on scale {
    NumberAnimation {
      duration: Style.menuAnimMs + 40
      easing.type: Easing.OutCubic
    }
  }

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
