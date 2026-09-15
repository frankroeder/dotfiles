import QtQuick
import "../../"

// Flat glass card: one hairline, one accent line along the top edge.
Rectangle {
  id: root
  property int cardRadius: Style.menuRadius
  property int cardMargin: 18
  property real chromeReveal: 1.0
  default property alias content: inner.data

  color: Style.menuGlass
  border.color: Style.menuHairline
  border.width: 1
  radius: root.cardRadius
  clip: true
  opacity: chromeReveal
  scale: 0.96 + 0.04 * chromeReveal
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

  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: root.cardRadius
    anchors.rightMargin: root.cardRadius
    height: 1
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 0.5; color: Style.menuNeon }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  Item {
    id: inner
    anchors.fill: parent
    anchors.margins: root.cardMargin
    z: 1
  }
}
