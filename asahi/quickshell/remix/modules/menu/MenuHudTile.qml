import QtQuick
import "../../"

// Navigation-drawer item: the active entry sits in a full-round
// secondary-container pill, hover is the onSurface state layer.
Item {
  id: root
  property bool selected: false
  property bool hovered: false
  property bool compact: false
  property string indexLabel: ""
  property string glyph: ""
  property string label: ""
  property string sub: ""
  property string accessory: "›"
  property string fontFamily: Style.menuMono
  property string labelFamily: Style.menuSans
  property color tint: Style.m3onSurfaceVariant
  property int glyphPx: 24
  property int labelPx: 11
  property int subPx: 9

  Rectangle {
    anchors.fill: parent
    anchors.margins: root.compact ? 2 : 4
    radius: Style.menuRadiusFull
    color: root.selected ? Style.m3secondaryContainer : (root.hovered ? Style.m3stateHover : "transparent")
    Behavior on color { ColorAnimation { duration: Style.menuAnimMs } }
  }

  Row {
    visible: root.compact
    anchors.fill: parent
    anchors.leftMargin: 16
    anchors.rightMargin: 12
    anchors.topMargin: 4
    anchors.bottomMargin: 4
    spacing: 12
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      color: root.selected ? Style.m3onSurface : root.tint
      font.pixelSize: Math.round(root.glyphPx * 0.7)
      font.family: root.fontFamily
      width: 22
      horizontalAlignment: Text.AlignHCenter
      Behavior on color { ColorAnimation { duration: Style.menuAnimMs } }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 34
      text: root.label
      color: root.selected ? Style.m3onSurface : Style.m3onSurfaceVariant
      font.pixelSize: root.labelPx + 1
      font.family: root.labelFamily
      font.weight: root.selected ? Font.DemiBold : Font.Medium
      elide: Text.ElideRight
    }
  }

  Column {
    visible: !root.compact
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    spacing: 4
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.glyph
      color: root.selected ? Style.m3onSurface : root.tint
      font.pixelSize: root.glyphPx
      font.family: root.fontFamily
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      text: root.label
      color: root.selected ? Style.m3onSurface : Style.m3onSurfaceVariant
      font.pixelSize: root.labelPx
      font.family: root.labelFamily
      font.weight: Font.Medium
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      text: root.sub
      color: Style.m3outline
      font.pixelSize: root.subPx
      font.family: root.labelFamily
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
