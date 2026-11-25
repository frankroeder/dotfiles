import QtQuick
import "../../"

// One Nerd Font glyph for a tile: `size` = the tile's side × Style.glyphRatio. The glyphs do not share a height:
// wide ones (CPU, folder, monitor) are fitted to the cell width (ink ≤ 0.60 em tall), narrow ones (battery, mic,
// Bluetooth, lock, thermometer) to its height (0.70 em). `tall` draws those at Style.glyphTallScale (the bar's
// 20 / 24), so a column of mixed glyphs reads one ink height. Measured unless the owner sets it: the icons sit
// centred 0.35 em above the baseline, so an ink top above 0.66 em means an ink box taller than 0.63 em.
// Centre it like any Text (the line box is centred on the icon cell: ink within half a device px).
Text {
  id: root
  property real size: 16
  property bool tall: -ink.tightBoundingRect.y > 66
  font.family: Style.fontMono
  font.pixelSize: Math.max(1, Math.round(root.size * (root.tall ? Style.glyphTallScale : 1)))
  TextMetrics { id: ink; text: root.text; font.family: Style.fontMono; font.pixelSize: 100 }
}
