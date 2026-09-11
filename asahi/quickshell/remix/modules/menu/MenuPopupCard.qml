import QtQuick
import "../../"

Rectangle {
  id: root
  default property alias content: inner.data

  anchors.fill: parent
  radius: Style.menuRadius
  color: Style.menuBg
  border.color: Style.menuHairline
  border.width: 1
  clip: true

  Item {
    id: inner
    anchors.fill: parent
    anchors.margins: 14
  }
}
