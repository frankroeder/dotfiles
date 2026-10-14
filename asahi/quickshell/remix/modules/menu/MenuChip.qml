import QtQuick
import "../../"

// Full-round fact chip: glyph + label on a tonal fill. `fixedWidth` keeps a live label from
// reflowing the row; `clickable` adds the hover state layer and `clicked`.
Rectangle {
  id: chip
  property string icon: ""
  property string label: ""
  property color bg: Style.m3secondaryContainer
  property color fg: Style.m3onSurface
  property int fixedWidth: 0
  property bool clickable: false
  property real fontScale: 1
  property string iconFamily: Style.menuMono
  property string fontFamily: Style.menuSans
  signal clicked()

  implicitWidth: chip.fixedWidth > 0 ? chip.fixedWidth : chipRow.implicitWidth + 20
  implicitHeight: 28
  radius: Style.menuRadiusFull
  color: chip.bg

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: Style.m3stateHover
    visible: chipMa.containsMouse
  }
  Row {
    id: chipRow
    anchors.centerIn: parent
    spacing: 6
    Text {
      visible: chip.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: chip.icon
      color: chip.fg
      font.family: chip.iconFamily
      font.pixelSize: Math.round(11 * chip.fontScale)
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: chip.label
      color: chip.fg
      font.family: chip.fontFamily
      font.pixelSize: Math.round(10 * chip.fontScale)
      font.weight: Font.Medium
    }
  }
  MouseArea {
    id: chipMa
    anchors.fill: parent
    enabled: chip.clickable
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: chip.clicked()
  }
}
