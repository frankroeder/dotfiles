import QtQuick
import "../../"

// One progress meter: 4 px, round ends, the shared `Style.menuMeterTrack` track, a `fill` for `value` (0..1).
// `animate`: value changes ease (layout width changes snap). Children are laid over the track (stacked segments).
Rectangle {
  id: meter
  property real value: 0
  property color fill: Style.m3primary
  property bool animate: true
  property real shown: Math.max(0, Math.min(1, meter.value))
  // The first value after creation snaps (data landing after the meter was built grew it from 0 on every open).
  property bool primed: false
  onValueChanged: if (!meter.primed) Qt.callLater(() => meter.primed = true)
  // Only while its window shows: SysPanel's tiles follow the bar's 3 s stats on every bar, open or not.
  Behavior on shown {
    enabled: meter.animate && meter.primed && !!meter.Window.window && meter.Window.window.visible
    MenuAnim { effects: true }
  }
  implicitHeight: 4
  radius: height / 2
  color: Style.menuMeterTrack
  Rectangle {
    width: meter.width * meter.shown
    height: meter.height; radius: meter.radius
    color: meter.fill
  }
}
