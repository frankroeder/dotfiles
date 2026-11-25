import QtQuick
import "../../"

// One key as a keycap (fontData). Modifiers (Super / Ctrl / Alt / Shift) two-tone: primary container + 1 px primary
// border; every other key neutral (the launcher's prefix keys, DisplayPrompt's digits).
Rectangle {
  id: cap
  property string key: ""
  property real fontScale: Style.uiScale
  readonly property bool modifier: /^(super|ctrl|alt|shift)$/i.test(cap.key)
  implicitWidth: Math.max(implicitHeight, label.implicitWidth + Math.round(10 * fontScale))
  implicitHeight: Math.round(20 * fontScale)
  radius: Style.radiusSm
  color: cap.modifier ? Style.m3primaryContainer : Style.m3containerHigh
  border.width: 1
  border.color: cap.modifier ? Style.m3primary : Style.menuHairline
  Text {
    id: label
    anchors.centerIn: parent
    text: cap.key
    textFormat: Text.PlainText
    color: cap.modifier ? Style.m3primary : Style.m3onSurfaceVariant
    font.family: Style.fontData; font.pixelSize: Math.round(11 * cap.fontScale); font.weight: Font.DemiBold
  }
}
