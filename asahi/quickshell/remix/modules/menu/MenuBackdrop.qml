import QtQuick
import "../../"

// Light scrim behind a panel; the panel itself carries the shadow.
Item {
  id: root
  property real reveal: 1.0
  anchors.fill: parent
  opacity: reveal

  Behavior on opacity { id: fade; MenuAnim { effects: true; exit: fade.targetValue < 1 } }   // target, not `reveal`: read stale

  Rectangle {
    anchors.fill: parent
    color: Qt.alpha(Style.crust, 0.12)
  }
}
