import QtQuick
import "../../"

// M3 slider: container track, accent fill, round handle. Emits moved(v) with v in 0..1 on press, drag, the wheel
// (`stepSize` a notch) and Left / Right while hovered; the owner applies and writes `value` back.
// `detents`: a drag snaps to each 5 % within 1.5 %.
// Sizes are in launcher type units: 4 / 3 = the bar popups' fixed look (handle 16, track 6); panes pass uiFontScale.
Item {
  id: root
  property real value: 0
  property color accent: Style.m3primary
  property bool dimmed: false
  property bool detents: false
  // Off for sliders inside a scrolling list (Media streams, HID++ settings): there the wheel scrolls the list.
  property bool wheelSteps: true
  // One wheel notch / arrow key; a slider over a few choices passes 1 / (n − 1) (a 5 % step rounded back to the same one).
  property real stepSize: 0.05
  property real fontScale: 4 / 3
  readonly property int handle: Math.round(12 * root.fontScale)
  readonly property int track: Math.round(4.5 * root.fontScale)
  signal moved(real v)
  // Fill and handle share one eased position: a click and steps (wheel, keys, another client) glide; a drag is 1:1
  // (with the Behavior left on, the fill trailed the pointer by its 80 ms).
  property real pos: Math.max(0, Math.min(1, root.value))
  // The first value snaps (a stream's volume reads 0 until its node binds: the slider eased up from 0 on every visit).
  property bool primed: false
  onValueChanged: if (!root.primed) Qt.callLater(() => root.primed = true)
  // Only while its window shows (closed night-light popups in every bar, a Quick pane kept after the launcher closed).
  Behavior on pos {
    enabled: root.primed && !ma.pressed && !Style.reduceMotion && !!root.Window.window && root.Window.window.visible
    NumberAnimation { duration: 80 }
  }
  implicitHeight: root.handle + 2

  // With `detents` a step lands on the 5 % grid (0.47 → 0.50, not 0.52).
  function step(n) {
    const v = Math.max(0, Math.min(1, root.value)) + n * root.stepSize
    root.moved(Math.max(0, Math.min(1, root.detents ? Math.round(v * 20) / 20 : v)))
  }
  // Left / Right only once the pointer really moved over the slider (window coords: a pane's slide-in moves the item):
  // a pane built under a resting pointer (Quick rail Up / Down) got the hover, and the rail's Left stepped a volume.
  property bool keysLive: false
  Shortcut { enabled: ma.containsMouse && root.keysLive; sequences: ["Left"]; onActivated: root.step(-1) }
  Shortcut { enabled: ma.containsMouse && root.keysLive; sequences: ["Right"]; onActivated: root.step(1) }

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
    property point enterAt: Qt.point(0, 0)
    onEntered: { enterAt = mapToItem(null, mouseX, mouseY); root.keysLive = false }
    onPressed: function(m) { root.keysLive = true; apply(m.x) }
    onPositionChanged: function(m) {
      if (pressed) apply(m.x)
      const g = mapToItem(null, m.x, m.y)
      if (Math.abs(g.x - enterAt.x) > 1 || Math.abs(g.y - enterAt.y) > 1) root.keysLive = true
    }
    onWheel: function(w) {
      if (!root.wheelSteps) { w.accepted = false; return }
      wheelAcc += w.angleDelta.y
      const n = Math.trunc(wheelAcc / 120)
      if (n) { wheelAcc -= n * 120; root.step(n) }
    }
  }
}
