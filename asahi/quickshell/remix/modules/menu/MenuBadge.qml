import QtQuick
import "../../"

// Count / status badge: a 16 px pill (a circle for one digit) on the primary container, tabular digits.
// `bg` / `fg` for a loud one ("NEW": m3primary / m3onPrimary).
Rectangle {
  id: badge
  property string text: ""
  property color bg: Style.m3primaryContainer
  property color fg: Style.m3onSurface
  property real fontScale: Style.uiScale
  implicitHeight: Math.round(16 * badge.fontScale)
  implicitWidth: Math.max(implicitHeight, badgeText.implicitWidth + Math.round(10 * badge.fontScale))
  radius: height / 2
  color: badge.bg
  Text {
    id: badgeText
    anchors.centerIn: parent
    text: badge.text
    textFormat: Text.PlainText
    color: badge.fg
    font.family: Style.fontUi; font.features: Style.fontTabular; font.weight: Font.DemiBold
    font.pixelSize: Math.round(10 * badge.fontScale)   // typeCaption already carries uiScale
  }
}
