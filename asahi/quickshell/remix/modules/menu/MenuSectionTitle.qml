import QtQuick
import "../../"

Text {
  id: root
  property string uiFont: Style.menuSans
  color: Style.menuInkMuted
  font.family: uiFont
  font.pixelSize: 11
  font.letterSpacing: 0.2
  font.weight: Font.Medium
}
