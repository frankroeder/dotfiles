import QtQuick
import "../../"

// Mini Ghostty mock so wallpaper preview shows the live palette. Real Ghostty
// sits behind the picker overlay; this is the visible terminal change.
Rectangle {
  id: root
  property real fontPx: 11
  property string fontFamily: Style.menuMono
  readonly property int _gen: Style.themeGeneration

  implicitHeight: Math.round(fontPx * 5.4) + 18
  radius: Style.menuRadiusMd
  color: Style.bg
  border.width: 1
  border.color: Style.border
  clip: true

  Column {
    anchors.fill: parent
    anchors.margins: 10
    spacing: Math.max(2, Math.round(root.fontPx * 0.12))

    Text {
      text: "ghostty"
      color: Style.textMuted
      font.family: root.fontFamily
      font.pixelSize: Math.max(9, Math.round(root.fontPx * 0.85))
    }
    Text {
      text: "$  ls src"
      color: Style.text
      font.family: root.fontFamily
      font.pixelSize: root.fontPx
    }
    Row {
      spacing: Math.round(root.fontPx * 1.1)
      Text { text: "main.c"; color: Style.blue; font.family: root.fontFamily; font.pixelSize: root.fontPx }
      Text { text: "Makefile"; color: Style.yellow; font.family: root.fontFamily; font.pixelSize: root.fontPx }
      Text { text: "README"; color: Style.green; font.family: root.fontFamily; font.pixelSize: root.fontPx }
    }
    Text {
      text: "$  "
      color: Style.green
      font.family: root.fontFamily
      font.pixelSize: root.fontPx
    }
  }
}
