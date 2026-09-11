import QtQuick
import QtQuick.Controls
import "../../"

// Only paints when the flickable overflows (size < 1). Never reserves a
// ghost track for short lists like Monitors with 1–2 displays.
ScrollBar {
  id: root
  // When true, keep the thumb visible whenever scrolling is possible
  // (instead of Qt's hover/active-only AsNeeded fade).
  property bool alwaysShow: false
  readonly property bool overflow: size > 0 && size < 0.999

  policy: overflow
    ? (alwaysShow ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded)
    : ScrollBar.AlwaysOff
  padding: 2
  implicitWidth: overflow ? Style.scrollbarWidth + 4 : 0
  visible: overflow

  contentItem: Rectangle {
    implicitWidth: Style.scrollbarWidth
    implicitHeight: 40
    radius: Style.scrollbarWidth / 2
    visible: root.overflow
    color: root.pressed || root.hovered ? Style.scrollbarThumbHover : Style.scrollbarThumb
    opacity: root.active || root.hovered || root.alwaysShow ? 1 : 0.55
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }

  background: Rectangle {
    implicitWidth: Style.scrollbarWidth + 4
    radius: (Style.scrollbarWidth + 4) / 2
    visible: root.overflow
    color: Style.scrollbarTrack
    opacity: root.active || root.hovered || root.alwaysShow ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }
}
