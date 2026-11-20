import QtQuick
import "../../../"

// Chip background tint; `lit` is the caller's choice (hover, or its popup open), `down` its mouse press: a click
// answers at once, before its popup opens.
Rectangle {
  property bool lit: false
  property bool down: false
  z: -1
  anchors.fill: parent
  anchors.topMargin: Style.barChipInset
  anchors.bottomMargin: Style.barChipInset
  radius: Style.radiusSm
  color: down ? Style.barStripPress : lit ? Style.barStripHover : "transparent"
  Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
}
