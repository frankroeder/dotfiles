import QtQuick
import "../../"

Rectangle {
  id: root
  property real reveal: 1.0
  anchors.fill: parent
  color: Qt.rgba(0, 0, 0, Style.menuDim.a * reveal)
}