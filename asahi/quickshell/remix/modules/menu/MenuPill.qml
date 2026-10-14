import QtQuick
import "../../"

// Full-round action pill: optional glyph + label on a tonal fill. `selected` = primary container
// + accent hairline; hover is the onSurface state layer (shows on light and dark fills alike).
Rectangle {
  id: pill
  property string icon: ""
  property string label: ""
  property color bg: Style.m3containerHigh
  property color fg: Style.m3onSurface
  property bool selected: false
  property real fontScale: 1
  property string iconFamily: Style.menuMono
  property string fontFamily: Style.menuSans
  signal clicked()

  implicitWidth: pillRow.implicitWidth + 24
  implicitHeight: 32
  radius: Style.menuRadiusFull
  color: pill.selected ? Style.m3primaryContainer : pill.bg
  border.width: pill.selected ? 1 : 0
  border.color: Style.menuSelBorder
  Behavior on color { ColorAnimation { duration: 120 } }

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: Style.m3stateHover
    opacity: pillMa.containsMouse ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }
  Row {
    id: pillRow
    anchors.centerIn: parent
    spacing: 6
    Text {
      visible: pill.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: pill.icon
      color: pill.selected ? Style.m3primary : pill.fg
      font.family: pill.iconFamily
      font.pixelSize: Math.round(12 * pill.fontScale)
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: pill.label
      color: pill.selected ? Style.m3primary : pill.fg
      font.family: pill.fontFamily
      font.pixelSize: Math.round(10 * pill.fontScale)
      font.weight: pill.selected ? Font.DemiBold : Font.Medium
    }
  }
  MouseArea { id: pillMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
}
