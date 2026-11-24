import QtQuick
import "../../"

// M3 switch: 34x18 track, primary when on; the handle is 10 off, 14 on, 16 while pressed (M3 16 / 24 / 28 dp on a
// 32 dp track), sized on the shared spring. `locked` = shown dimmed, not togglable.
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
  Behavior on color { ColorAnimation { duration: 160 } }

  Rectangle {
    readonly property real side: swMa.pressed && !sw.locked ? 16 : sw.checked ? 14 : 10
    x: sw.checked ? sw.width - (sw.height + side) / 2 : (sw.height - side) / 2
    anchors.verticalCenter: parent.verticalCenter
    width: side; height: side; radius: side / 2
    color: sw.checked ? Style.m3onPrimary : Style.m3outline
    Behavior on x { MenuAnim {} }
    Behavior on width { MenuAnim {} }
  }
  MouseArea {
    id: swMa
    anchors.fill: parent
    anchors.margins: -4
    cursorShape: sw.locked ? Qt.ArrowCursor : Qt.PointingHandCursor
    onClicked: if (!sw.locked) sw.toggled()
  }
}
