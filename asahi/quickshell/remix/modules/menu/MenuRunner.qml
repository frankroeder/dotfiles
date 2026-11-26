import QtQuick
import "../../"

// Indeterminate progress under a pane / card header: a 2 px accent runner sweeps its track while `busy`
// (a helper Process is out). The sweep runs only while shown and busy (XAnimator: on the render thread);
// a still bar under reduced motion. Takes no layout space of its own: anchor it to the header's foot.
Rectangle {
  id: track
  property bool busy: false
  implicitHeight: 2
  radius: 1
  color: Qt.alpha(Style.m3primary, 0.14)
  opacity: track.busy ? 1 : 0
  clip: true
  Behavior on opacity { NumberAnimation { duration: Style.menuStateMs } }
  Rectangle {
    id: runner
    width: Math.round(track.width * 0.3); height: track.height; radius: 1
    x: Math.round((track.width - width) / 2)
    color: Style.m3primary
    XAnimator {
      target: runner
      from: -runner.width; to: track.width
      duration: 1100; easing.type: Easing.InOutQuad
      loops: Animation.Infinite
      running: track.busy && track.visible && !!track.Window.window && track.Window.window.visible && !Style.reduceMotion
    }
  }
}
