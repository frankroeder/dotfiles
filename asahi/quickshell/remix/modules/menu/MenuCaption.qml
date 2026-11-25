import QtQuick
import "../../"

// Section caption: the one tracked-caps look (popups, sheet, panes, badges, legends). Popups use the Style size;
// launcher panes set `font.pixelSize: root.fontPx(8)` (their type is scaled), badges fontPx(7).
Text {
  color: Style.m3onSurfaceVariant
  font.family: Style.menuSans
  font.pixelSize: Style.typeCaption
  font.weight: Font.DemiBold
  font.letterSpacing: 1.2
  font.capitalization: Font.AllUppercase
  elide: Text.ElideRight
  textFormat: Text.PlainText
}
