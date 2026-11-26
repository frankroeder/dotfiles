import QtQuick
import QtQuick.Controls
import "../../"

// Only paints when the flickable overflows (size < 1). Never reserves a
// ghost track for short lists like Monitors with 1–2 displays.
ScrollBar {
  id: root
  // Synced once `size` settles, not bound: the reserve it sets (implicitWidth → a list's row width) relaid the launcher
  // results out inside the binding (leaving Windows / Files mode: "Binding loop detected for property overflow"), and the
  // aborted pass kept a 9 px reserve with nothing to scroll.
  property bool overflow: false
  function syncOverflow() { root.overflow = root.size > 0 && root.size < 0.999 }
  onSizeChanged: Qt.callLater(root.syncOverflow)
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
    Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
    // Pause from the Behavior's target (bound to active / hovered it read stale: shown 0.6 s late, hidden at once).
    Behavior on opacity {
      id: thumbFade
      SequentialAnimation {
        PauseAnimation { duration: thumbFade.targetValue >= 1 ? 0 : 600 }
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
    Behavior on opacity { NumberAnimation { duration: Style.menuStateMs } }
  }
}
