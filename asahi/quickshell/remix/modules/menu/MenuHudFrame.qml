import QtQuick
import "../../"

// Kept as a no-op so older includes stay valid. The launcher card is a
// single hairline — no brackets, sheen, or scan sweep.
Item {
  id: root
  property real reveal: 1.0
  property int inset: 0
  property color accent: Style.menuAccent
  anchors.fill: parent
  visible: false
}
