import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../"

// Dominant colors of the preselected wallpaper — the material the flavour is
// built from. Blank until the color index has caught up with the thumbs.
RowLayout {
  id: root
  property string path: ""
  property string fontFamily: Style.menuSans
  property string iconFamily: Style.menuMono
  property string hovered: ""

  readonly property var entry: {
    const _ = WallpaperService.colorIndex
    return WallpaperService.colorEntry(root.path)
  }
  readonly property var swatches: (root.entry && root.entry.swatches) || []

  spacing: 8
  onPathChanged: root.hovered = ""

  Text {
    visible: !!root.entry
    text: root.entry && root.entry.tone === "light" ? "󰖙" : "󰽥"
    color: Style.m3onSurfaceVariant
    font.family: root.iconFamily
    font.pixelSize: 13
  }
  Text {
    visible: !!root.entry
    text: root.entry ? (root.entry.tone === "light" ? "Light" : "Dark") : ""
    color: Style.m3onSurfaceVariant
    font.family: root.fontFamily
    font.pixelSize: 11
    font.weight: Font.Medium
  }

  ClippingRectangle {
    id: strip
    Layout.fillWidth: true
    Layout.preferredHeight: 18
    radius: Style.menuRadiusFull
    color: Style.m3container

    Row {
      anchors.fill: parent
      Repeater {
        model: root.swatches
        delegate: Rectangle {
          required property string modelData
          required property int index
          readonly property int n: Math.max(1, root.swatches.length)
          // Exact split: each slice ends where the next begins, so no seams.
          width: Math.round(strip.width * (index + 1) / n) - Math.round(strip.width * index / n)
          height: strip.height
          color: modelData
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.hovered = parent.modelData
            onExited: if (root.hovered === parent.modelData) root.hovered = ""
          }
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: root.swatches.length === 0
      text: "indexing colors…"
      color: Style.m3outline
      font.family: root.fontFamily
      font.pixelSize: 10
    }
  }

  Text {
    visible: !!root.entry
    text: root.hovered || (root.entry ? root.entry.accent : "")
    color: Style.m3onSurfaceVariant
    font.family: root.iconFamily
    font.pixelSize: 10
    Layout.preferredWidth: 60
  }
}
