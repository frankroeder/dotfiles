import QtQuick
import "../../"

// One pill for the wallpaper picker's filter / flavour rows: optional color dot,
// optional glyph, label, optional count badge.
Rectangle {
  id: chip
  property string label: ""
  property string glyph: ""
  property bool on: false
  property int badge: -1          // < 0 hides it; 0 dims the whole chip
  property string fontFamily: Style.menuSans
  property string iconFamily: Style.menuMono
  readonly property bool hovered: ma.containsMouse
  signal clicked()

  implicitWidth: row.implicitWidth + 18
  implicitHeight: 24
  radius: Style.menuRadiusFull
  color: chip.on ? Style.m3primaryContainer : (ma.containsMouse ? Style.m3containerHigh : Style.m3container)
  // 2px: a monochrome wallpaper makes m3primaryContainer nearly the same grey as
  // m3container, so the ring is what actually marks the selection.
  border.width: chip.on ? 2 : 0
  border.color: Style.m3primary
  opacity: chip.badge === 0 ? 0.35 : 1
  Behavior on color { ColorAnimation { duration: 120 } }
  Behavior on opacity { NumberAnimation { duration: 120 } }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 5
    Text {
      visible: chip.glyph !== ""
      text: chip.glyph
      color: chip.on ? Style.m3primary : Style.m3onSurfaceVariant
      font.family: chip.iconFamily
      font.pixelSize: 12
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      visible: chip.label !== ""
      text: chip.label
      color: Style.m3onSurface
      font.family: chip.fontFamily
      font.pixelSize: 11
      font.weight: chip.on ? Font.DemiBold : Font.Medium
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      visible: chip.badge >= 0
      text: chip.badge
      color: Style.m3onSurfaceVariant
      font.family: chip.fontFamily
      font.pixelSize: 9
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: chip.clicked()
  }
}
