import QtQuick
import "../../"

// Card-header glyph: a tinted rounded tile that scales with the launcher font, the one look of every pane's card
// headers (it replaced fixed 30 px tiles whose glyph outgrew them at large scales, and bare glyphs).
Rectangle {
  id: tile
  property string glyph: ""
  property real fontScale: Style.uiScale
  property color tint: Style.m3primary
  readonly property int side: Math.round(22 * tile.fontScale)
  implicitWidth: tile.side
  implicitHeight: tile.side
  radius: Math.round(tile.side * 0.3)
  color: Qt.alpha(tile.tint, 0.18)
  Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
  Text {
    anchors.centerIn: parent
    text: tile.glyph
    color: tile.tint
    font.family: Style.fontMono
    font.pixelSize: Math.round(13 * tile.fontScale)
  }
}
