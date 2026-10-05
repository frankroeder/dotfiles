import QtQuick
import "../../../"

// Chip background tint; `lit` is the caller's choice (hover, or its popup open).
Rectangle {
  property bool lit: false
  z: -1
  anchors.fill: parent
  anchors.topMargin: Style.barChipInset
  anchors.bottomMargin: Style.barChipInset
  radius: Style.radiusSm
  color: lit ? Style.barStripHover : "transparent"
  Behavior on color { ColorAnimation { duration: 120 } }
}
