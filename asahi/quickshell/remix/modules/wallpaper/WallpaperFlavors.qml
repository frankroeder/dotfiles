import QtQuick
import QtQuick.Layouts
import "../../"
import "wallpaper_colors.js" as WallColors

// Theme flavour: how strong and how colorful the palette built from the
// wallpaper comes out (`asahi-autotheme --variant`, matugen scheme-* analogue).
// Picking one re-themes in place — the wallpaper does not change.
ColumnLayout {
  id: root
  property string fontFamily: Style.menuSans
  property string iconFamily: Style.menuMono
  property string hoverKey: ""

  spacing: 5

  RowLayout {
    Layout.fillWidth: true
    spacing: 8
    Text {
      text: "Flavour"
      color: Style.m3onSurface
      font.family: root.fontFamily
      font.pixelSize: 11
      font.weight: Font.DemiBold
    }
    Text {
      Layout.fillWidth: true
      text: WallColors.flavorHint(root.hoverKey || WallpaperService.flavor)
      color: Style.m3onSurfaceVariant
      font.family: root.fontFamily
      font.pixelSize: 10
      elide: Text.ElideRight
    }
  }

  Flow {
    Layout.fillWidth: true
    spacing: 6
    Repeater {
      model: WallColors.FLAVORS
      delegate: WallpaperChip {
        required property var modelData
        label: modelData.label
        on: WallpaperService.flavor === modelData.key
        fontFamily: root.fontFamily
        iconFamily: root.iconFamily
        onClicked: WallpaperService.setFlavor(modelData.key)
        onHoveredChanged: root.hoverKey = hovered ? modelData.key : ""
      }
    }
  }
}
