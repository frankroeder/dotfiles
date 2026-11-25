import QtQuick
import "../../"

// M3 slider: container track, accent fill, round handle. Emits moved(v) with v in 0..1 on press, drag, the wheel
// (1/20 a notch) and Left / Right while hovered; the owner applies and writes `value` back.
// `detents`: a drag snaps to each 5 % within 1.5 %.
// Sizes are in launcher type units: 4 / 3 = the bar popups' fixed look (handle 16, track 6); panes pass uiFontScale.
Item {
  id: root
  property real value: 0
  property color accent: Style.m3primary
  property bool dimmed: false
  property bool detents: false
  property real fontScale: 4 / 3
  readonly property int handle: Math.round(12 * root.fontScale)
  readonly property int track: Math.round(4.5 * root.fontScale)
  signal moved(real v)
  // Fill and handle share one eased position: a click and steps (wheel, keys, another client) glide; a drag is 1:1
  // (with the Behavior left on, the fill trailed the pointer by its 80 ms).
  property real pos: Math.max(0, Math.min(1, root.value))
  Behavior on pos { enabled: !ma.pressed && !Style.reduceMotion; NumberAnimation { duration: 80 } }
  implicitHeight: root.handle + 2

  function step(n) { root.moved(Math.max(0, Math.min(1, Math.max(0, Math.min(1, root.value)) + n / 20))) }
  Shortcut { enabled: ma.containsMouse; sequences: ["Left"]; onActivated: root.step(-1) }
  Shortcut { enabled: ma.containsMouse; sequences: ["Right"]; onActivated: root.step(1) }

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width; height: root.track; radius: height / 2
    color: Style.m3containerHigh
  }
  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: root.pos * parent.width
    height: root.track; radius: height / 2
    color: root.dimmed ? Style.m3outline : root.accent
  }
  Rectangle {
    x: Math.max(0, Math.min(parent.width - width, root.pos * parent.width - width / 2))
    anchors.verticalCenter: parent.verticalCenter
    width: root.handle; height: width; radius: width / 2
    color: root.dimmed ? Style.m3outline : root.accent
    scale: ma.pressed ? 1.15 : 1
    Behavior on scale { NumberAnimation { duration: 100 } }
  }
  MouseArea {
    id: ma
    property real wheelAcc: 0
    anchors.fill: parent
    anchors.topMargin: -10; anchors.bottomMargin: -10
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    preventStealing: true
    function apply(mx) {
      const v = Math.max(0, Math.min(1, mx / root.width)), d = Math.round(v * 20) / 20
      root.moved(root.detents && Math.abs(v - d) < 0.015 ? d : v)
    }
    onPressed: function(m) { apply(m.x) }
    onPositionChanged: function(m) { if (pressed) apply(m.x) }
    onWheel: function(w) {
      wheelAcc += w.angleDelta.y
      const n = Math.trunc(wheelAcc / 120)
      if (n) { wheelAcc -= n * 120; root.step(n) }
    }
  }
}
