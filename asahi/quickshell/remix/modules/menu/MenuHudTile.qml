import QtQuick
import "../../"

// Navigation-drawer item: hover is the onSurface state layer; the selection pill is the rail's own (one pill that
// slides between entries), the selected tile only fills its disc.
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
  // Status dot on the disc ("transparent" = none), set off from the panel by a ring in the surface colour.
  property color badge: "transparent"

  Rectangle {
    anchors.fill: parent
    anchors.margins: 2
    radius: Style.menuRadiusFull
    color: root.hovered && !root.selected ? Style.m3stateHover : "transparent"
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
        font.family: root.fontFamily; font.features: Style.fontTabular
        Behavior on color { ColorAnimation { duration: Style.menuAnimMs } }
      }
      Rectangle {
        visible: root.badge.a > 0
        width: Math.max(10, Math.round(disc.width * 0.4)); height: width; radius: width / 2
        x: disc.width - width * 0.8; y: -width * 0.2
        color: root.badge
        border.width: 2; border.color: Style.m3surfaceSolid
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
