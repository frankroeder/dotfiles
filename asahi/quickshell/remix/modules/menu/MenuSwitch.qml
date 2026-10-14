import QtQuick
import "../../"

// M3 switch: 34x18 track, 14 knob, primary when on. `locked` = shown dimmed, not togglable.
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
    x: sw.checked ? sw.width - width - 2 : 2
    anchors.verticalCenter: parent.verticalCenter
    width: 14; height: 14; radius: 7
    color: sw.checked ? Style.m3onPrimary : Style.m3outline
    Behavior on x { MenuAnim {} }
  }
  MouseArea {
    anchors.fill: parent
    anchors.margins: -4
    cursorShape: sw.locked ? Qt.ArrowCursor : Qt.PointingHandCursor
    onClicked: if (!sw.locked) sw.toggled()
  }
}
