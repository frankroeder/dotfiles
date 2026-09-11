import QtQuick
import "../../"

Item {
  id: root
  property real reveal: 1.0
  anchors.fill: parent
  opacity: reveal

  Behavior on opacity {
    NumberAnimation {
      duration: Style.menuAnimMs
      easing.type: Easing.OutCubic
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Style.menuDim
  }
}
