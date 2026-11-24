import QtQuick
import Quickshell.Widgets
import "../../"

// Press ripple (caelestia StateLayer): a disc grows from the press point past the farthest corner, held while the
// button is, then fades; clipped to the host's (morphing) shape. Built only while it runs: nothing at rest.
Item {
  id: r
  anchors.fill: parent
  property real radius: 0
  property color tint: Style.m3onSurface
  property bool held: false
  property real cx: 0
  property real cy: 0
  property real t: 0
  property real fade: 1
  function start(x, y) {
    if (Style.reduceMotion) return
    r.cx = x; r.cy = y; r.t = 0; r.fade = 1; r.held = true
    out.stop(); grow.restart()
  }
  function release() { r.held = false; if (!grow.running) out.restart() }
  NumberAnimation {
    id: grow; target: r; property: "t"; from: 0; to: 1; duration: 450
    easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]   // M3 standard
    onFinished: if (!r.held) out.restart()
  }
  NumberAnimation { id: out; target: r; property: "fade"; to: 0; duration: 300; easing.type: Easing.OutCubic }
  Loader {
    anchors.fill: parent
    active: r.held || grow.running || out.running
    sourceComponent: ClippingRectangle {
      radius: r.radius
      color: "transparent"
      Rectangle {
        readonly property real reach: Math.hypot(Math.max(r.cx, r.width - r.cx), Math.max(r.cy, r.height - r.cy)) * 1.15
        width: 2 * reach * r.t; height: width; radius: width / 2
        x: r.cx - width / 2; y: r.cy - height / 2
        color: Qt.alpha(r.tint, 0.16)
        opacity: r.fade
      }
    }
  }
}
