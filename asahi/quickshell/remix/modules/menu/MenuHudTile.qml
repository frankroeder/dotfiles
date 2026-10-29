import QtQuick
import "../../"

// Navigation-drawer item: the active entry sits in a full-round
// secondary-container pill, hover is the onSurface state layer.
Item {
  id: root
  property bool selected: false
  property bool hovered: false
  property string glyph: ""
  property string label: ""
  property string fontFamily: Style.menuMono
  property string labelFamily: Style.menuSans
  property color tint: Style.m3onSurfaceVariant
  property int glyphPx: 24
  property int labelPx: 11

  Rectangle {
    anchors.fill: parent
    anchors.margins: 2
    radius: Style.menuRadiusFull
    color: root.selected ? Style.menuSelFill : (root.hovered ? Style.m3stateHover : "transparent")
    border.width: root.selected ? 1 : 0
    border.color: Style.menuSelBorder
    Behavior on color { ColorAnimation { duration: Style.menuAnimMs } }
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 12
    anchors.topMargin: 4
    anchors.bottomMargin: 4
    spacing: 10
    // Icon disc (Ryoku QsTile): own tint when idle, solid accent when selected.
    Rectangle {
      id: disc
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(parent.height - 4, Math.round(root.glyphPx * 1.35)); height: width; radius: width / 2
      color: root.selected ? Style.m3primary : Qt.alpha(root.tint, root.hovered ? 0.22 : 0.14)
      Behavior on color { ColorAnimation { duration: Style.menuAnimMs } }
      Text {
        anchors.centerIn: parent
        text: root.glyph
        color: root.selected ? Style.m3onPrimary : root.tint
        font.pixelSize: Math.max(1, Math.round(disc.width * 0.62))
        font.family: root.fontFamily
        Behavior on color { ColorAnimation { duration: Style.menuAnimMs } }
      }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - disc.width - 10
      text: root.label
      color: root.selected ? Style.m3onSurface : Style.m3onSurfaceVariant
      font.pixelSize: root.labelPx + 1
      font.family: root.labelFamily
      font.weight: root.selected ? Font.DemiBold : Font.Medium
      elide: Text.ElideRight
    }
  }
}
