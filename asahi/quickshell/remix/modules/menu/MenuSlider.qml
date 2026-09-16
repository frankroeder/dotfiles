import QtQuick
import "../../"

// M3 slider: container track, accent fill, round handle. Emits moved(v) with
// v in 0..1 on press and drag; the owner applies and writes `value` back.
Item {
  id: root
  property real value: 0
  property color accent: Style.m3primary
  property bool dimmed: false
  signal moved(real v)
  implicitHeight: 18

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width; height: 6; radius: 3
    color: Style.m3containerHigh
  }
  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, Math.min(1, root.value)) * parent.width
    height: 6; radius: 3
    color: root.dimmed ? Style.m3outline : root.accent
    Behavior on width { NumberAnimation { duration: 80 } }
  }
  Rectangle {
    x: Math.max(0, Math.min(parent.width - width, Math.min(1, root.value) * parent.width - width / 2))
    anchors.verticalCenter: parent.verticalCenter
    width: 16; height: 16; radius: 8
    color: root.dimmed ? Style.m3outline : root.accent
    scale: ma.pressed ? 1.15 : 1
    Behavior on scale { NumberAnimation { duration: 100 } }
  }
  MouseArea {
    id: ma
    anchors.fill: parent
    anchors.topMargin: -6; anchors.bottomMargin: -6
    cursorShape: Qt.PointingHandCursor
    preventStealing: true
    function apply(mx) { root.moved(Math.max(0, Math.min(1, mx / root.width))) }
    onPressed: function(m) { apply(m.x) }
    onPositionChanged: function(m) { if (pressed) apply(m.x) }
  }
}
