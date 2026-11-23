import QtQuick
import "../../"

// Scroll hint (idea: end-4 ScrollEdgeFade): the surface colour fades in over a list's bottom (or top) edge while more
// content lies past it, so a cut row reads as "scroll on" instead of clipped. A plain gradient: no layer, no mask, no
// cost while still. Declare it inside the flickable with `parent:` set to it (else it lands in the scrolling content);
// it takes no input. `gutter` keeps the scrollbar clear.
Rectangle {
  id: root
  property Flickable flick: root.parent
  property bool atTop: false
  property color surface: Style.m3container
  property real gutter: 0
  readonly property bool more: !!root.flick && root.flick.contentHeight > root.flick.height + 1
    && (root.atTop ? !root.flick.atYBeginning : !root.flick.atYEnd)

  anchors.left: parent ? parent.left : undefined
  anchors.right: parent ? parent.right : undefined
  anchors.rightMargin: root.gutter
  anchors.top: parent && root.atTop ? parent.top : undefined
  anchors.bottom: parent && !root.atTop ? parent.bottom : undefined
  implicitHeight: 28
  opacity: root.more ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: Style.menuStateMs } }
  gradient: Gradient {
    GradientStop { position: 0; color: root.atTop ? root.surface : Qt.alpha(root.surface, 0) }
    GradientStop { position: 1; color: root.atTop ? Qt.alpha(root.surface, 0) : root.surface }
  }
}
