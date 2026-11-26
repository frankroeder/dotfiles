import QtQuick
import "../../"

// M3 switch: 34x18 track, primary when on; the handle is 10 off, 14 on, 16 while pressed (M3 16 / 24 / 28 dp on a
// 32 dp track). It travels on the fast spring with its edges apart (the leading one first, the trailing 1.5× slower:
// it stretches toward the new side, as MenuStretchPill). `locked` = shown dimmed, not togglable.
Rectangle {
  id: sw
  property bool checked: false
  property bool locked: false
  signal toggled()

  implicitWidth: 34
  implicitHeight: 18
  radius: height / 2
  color: sw.checked ? Style.m3primary : Style.m3containerHigh
  border.width: sw.checked ? 0 : 1
  border.color: Style.m3outline
  opacity: sw.locked ? 0.45 : 1
  Behavior on color { ColorAnimation { duration: Style.menuStateMs } }

  readonly property real side: swMa.pressed && !sw.locked ? 16 : sw.checked ? 14 : 10
  readonly property real targetLeft: sw.checked ? sw.width - (sw.height + side) / 2 : (sw.height - side) / 2
  readonly property real targetRight: targetLeft + side
  property real edgeLeft: targetLeft
  property real edgeRight: targetRight
  // Turning on (moving right) the left edge trails; turning off, the right one. Latched in a handler: a binding (on the
  // edges, or on `checked` itself) updated after the Behavior had started (stretched on the first toggle only, then
  // compressed).
  property bool movingRight: checked
  onCheckedChanged: sw.movingRight = sw.checked
  Behavior on edgeLeft { MenuAnim { fast: true; duration: Style.menuSpringFastMs * (sw.movingRight ? 1.5 : 1) } }
  Behavior on edgeRight { MenuAnim { fast: true; duration: Style.menuSpringFastMs * (sw.movingRight ? 1 : 1.5) } }

  Rectangle {   // hover / press state layer
    anchors.fill: parent
    radius: parent.radius
    color: swMa.pressed ? Style.m3statePress : Style.m3stateHover
    opacity: (swMa.containsMouse || swMa.pressed) && !sw.locked ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Style.menuStateMs } }
  }
  Rectangle {
    id: knob
    x: sw.edgeLeft
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, sw.edgeRight - sw.edgeLeft); height: sw.side; radius: height / 2
    color: sw.checked ? Style.m3onPrimary : Style.m3outline
    Behavior on height { MenuAnim { fast: true } }
  }
  MouseArea {
    id: swMa
    anchors.fill: parent
    anchors.margins: -4
    hoverEnabled: true
    cursorShape: sw.locked ? Qt.ArrowCursor : Qt.PointingHandCursor
    onClicked: if (!sw.locked) sw.toggled()
  }
}
