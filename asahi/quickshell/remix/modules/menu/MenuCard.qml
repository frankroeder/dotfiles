import QtQuick
import "../../"

Rectangle {
  id: root
  property int cardRadius: Style.menuRadius
  property int cardMargin: 18
  property real chromeReveal: 1.0
  default property alias content: inner.data

  color: Style.menuBg
  border.color: Style.menuHairline
  border.width: 1
  radius: root.cardRadius
  clip: true
  opacity: chromeReveal
  scale: 0.92 + 0.08 * chromeReveal
  transformOrigin: Item.Top

  Behavior on opacity {
    NumberAnimation {
      duration: Style.menuAnimMs + 40
      easing.type: Easing.OutCubic
    }
  }
  Behavior on scale {
    NumberAnimation {
      duration: Style.menuAnimMs + 60
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
    z: 1
  }
}
