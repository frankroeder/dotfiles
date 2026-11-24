import QtQuick
import QtQuick.Controls
import "../../"

// Only paints when the flickable overflows (size < 1). Never reserves a
// ghost track for short lists like Monitors with 1–2 displays.
ScrollBar {
  id: root
  readonly property bool overflow: size > 0 && size < 0.999
  // Lists without MenuEdgeFade keep a resting thumb (nothing else says they scroll).
  property bool autoHide: true

  policy: overflow ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
  padding: 2
  implicitWidth: overflow ? Style.scrollbarWidth + 4 : 0
  visible: overflow

  contentItem: Rectangle {
    implicitWidth: Style.scrollbarWidth
    implicitHeight: 40
    radius: Style.scrollbarWidth / 2
    visible: root.overflow
    color: root.pressed || root.hovered ? Style.scrollbarThumbHover : Style.scrollbarThumb
    // Shown while scrolling or under the pointer, gone 0.6 s after (caelestia StyledScrollBar): at rest the
    // list's edge fades say there is more.
    opacity: root.active || root.hovered ? 1 : root.autoHide ? 0 : 0.55
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on opacity {
      SequentialAnimation {
        PauseAnimation { duration: root.active || root.hovered ? 0 : 600 }
        NumberAnimation { duration: 200 }
      }
    }
  }

  background: Rectangle {
    implicitWidth: Style.scrollbarWidth + 4
    radius: (Style.scrollbarWidth + 4) / 2
    visible: root.overflow
    color: Style.scrollbarTrack
    opacity: root.active || root.hovered ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }
}
