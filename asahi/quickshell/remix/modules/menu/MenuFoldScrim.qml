import QtQuick
import "../../"

// Omarchy fold-peek: fade strength tracks how much content is hidden
// past each edge, so a jump to the top/bottom lands already faded.
Item {
  id: root
  property var flick: null
  property color wash: Style.menuBg
  anchors.fill: parent
  z: 20
  clip: true

  readonly property real hiddenTop: {
    if (!flick || flick.contentHeight <= flick.height) return 0
    return Math.max(0, flick.contentY - (flick.originY || 0))
  }
  readonly property real hiddenBottom: {
    if (!flick || flick.contentHeight <= flick.height) return 0
    return Math.max(0, (flick.originY || 0) + flick.contentHeight - flick.height - flick.contentY)
  }

  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Math.min(28, parent.height / 2)
    opacity: Math.max(0, Math.min(1, root.hiddenTop / height))
    visible: opacity > 0
    gradient: Gradient {
      GradientStop { position: 0.0; color: root.wash }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }
  Rectangle {
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: Math.min(28, parent.height / 2)
    opacity: Math.max(0, Math.min(1, root.hiddenBottom / height))
    visible: opacity > 0
    gradient: Gradient {
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 1.0; color: root.wash }
    }
  }
}
