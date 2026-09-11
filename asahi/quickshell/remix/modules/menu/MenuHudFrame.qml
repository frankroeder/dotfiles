import QtQuick
import "../../"

// Kept as a no-op so older includes stay valid. The launcher card is
// a single hairline now — no ticks, sheen, or scan sweep.
Item {
  id: root
  property real reveal: 1.0
  property int tick: 0
  property int thick: 0
  property color accent: Style.menuAccent
  anchors.fill: parent
  visible: false
}
