import QtQuick
import "../../"

// Quiet deck tile: selected = left lumen rail, no ticks or boxed fill.
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
  property color tint: Style.menuInkDeep
  property int glyphPx: 24
  property int labelPx: 11
  property int subPx: 9

  Rectangle {
    anchors.fill: parent
    anchors.margins: root.compact ? 2 : 4
    color: root.selected
      ? Style.menuRowSel
      : (root.hovered ? Style.menuRowHi : "transparent")
    border.width: 0
    radius: Style.radiusSm
    Behavior on color { ColorAnimation { duration: 80 } }
  }

  Rectangle {
    visible: root.selected
    width: Style.menuRail
    height: parent.height - (root.compact ? 10 : 16)
    radius: 1
    color: root.tint
    anchors.left: parent.left
    anchors.leftMargin: root.compact ? 4 : 6
    anchors.verticalCenter: parent.verticalCenter
  }

  Text {
    visible: !root.compact && root.indexLabel !== ""
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.leftMargin: 14
    anchors.topMargin: 10
    text: root.indexLabel
    color: Style.menuInkMuted
    font.family: root.labelFamily
    font.pixelSize: Math.max(9, Math.round(root.labelPx * 0.8))
    font.letterSpacing: 0.4
    opacity: 0.7
  }

  Row {
    visible: root.compact
    anchors.fill: parent
    anchors.leftMargin: 14
    anchors.rightMargin: 10
    anchors.topMargin: 4
    anchors.bottomMargin: 4
    spacing: 10
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      color: root.tint
      font.pixelSize: Math.round(root.glyphPx * 0.64)
      font.family: root.fontFamily
      width: 20
      horizontalAlignment: Text.AlignHCenter
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 30
      text: root.label
      color: root.selected ? Style.menuInk : Style.menuInkDeep
      font.pixelSize: root.labelPx
      font.family: root.labelFamily
      font.letterSpacing: 0.15
      font.weight: root.selected ? Font.Medium : Font.Normal
      elide: Text.ElideRight
    }
  }

  Column {
    visible: !root.compact
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: 2
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    spacing: 4
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.glyph
      color: root.tint
      font.pixelSize: root.glyphPx
      font.family: root.fontFamily
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      text: root.label
      color: root.selected ? Style.menuInk : Style.menuInk
      font.pixelSize: root.labelPx
      font.family: root.labelFamily
      font.letterSpacing: 0.2
      font.weight: Font.Medium
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      text: root.sub
      color: Style.menuInkMuted
      font.pixelSize: root.subPx
      font.family: root.labelFamily
      font.letterSpacing: 0.1
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
      opacity: 0.8
    }
  }
}
