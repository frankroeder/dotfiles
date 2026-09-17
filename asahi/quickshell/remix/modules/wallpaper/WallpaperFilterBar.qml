import QtQuick
import QtQuick.Layouts
import "../../"
import "wallpaper_colors.js" as WallColors

// Dark/light tone, dominant-color dots and the sort cycle. State lives on
// WallpaperService, so the compact card and the launcher pane filter alike.
RowLayout {
  id: root
  property string fontFamily: Style.menuSans
  property string iconFamily: Style.menuMono
  property string query: ""

  readonly property var counts: WallpaperService.filterCounts(root.query)
  readonly property bool filtered: WallpaperService.filterTone !== ""
    || WallpaperService.filterBucket !== "" || WallpaperService.sortKey !== "name"

  function toggleTone(t) { WallpaperService.filterTone = WallpaperService.filterTone === t ? "" : t }
  function cycleSort() {
    const keys = WallColors.SORTS
    for (let i = 0; i < keys.length; i++) {
      if (keys[i].key === WallpaperService.sortKey) {
        WallpaperService.sortKey = keys[(i + 1) % keys.length].key
        return
      }
    }
    WallpaperService.sortKey = keys[0].key
  }
  function sortLabel() {
    const keys = WallColors.SORTS
    for (let i = 0; i < keys.length; i++) if (keys[i].key === WallpaperService.sortKey) return keys[i]
    return keys[0]
  }

  spacing: 6

  WallpaperChip {
    glyph: "󰽥"; label: "Dark"; badge: root.counts.tones.dark
    on: WallpaperService.filterTone === "dark"
    fontFamily: root.fontFamily; iconFamily: root.iconFamily
    onClicked: root.toggleTone("dark")
  }
  WallpaperChip {
    glyph: "󰖙"; label: "Light"; badge: root.counts.tones.light
    on: WallpaperService.filterTone === "light"
    fontFamily: root.fontFamily; iconFamily: root.iconFamily
    onClicked: root.toggleTone("light")
  }

  // Main-color row: click a dot to keep only that hue family. A bucket with no
  // matches under the current tone/search fades out instead of disappearing, so
  // the row never reflows while you browse.
  Row {
    Layout.leftMargin: 4
    spacing: 4
    Repeater {
      model: WallColors.BUCKETS
      delegate: Rectangle {
        id: dot
        required property var modelData
        readonly property int n: root.counts.buckets[modelData.key] || 0
        readonly property bool on: WallpaperService.filterBucket === modelData.key
        width: 20; height: 20; radius: 10
        color: modelData.swatch
        border.width: dot.on ? 2 : 0
        border.color: Style.m3onSurface
        opacity: dot.n === 0 ? 0.18 : (dot.on ? 1 : (dotMa.containsMouse ? 0.95 : 0.72))
        scale: dot.on ? 1.12 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        MouseArea {
          id: dotMa
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: WallpaperService.filterBucket = dot.on ? "" : dot.modelData.key
        }
      }
    }
  }

  Item { Layout.fillWidth: true }

  WallpaperChip {
    glyph: root.sortLabel().icon
    label: root.sortLabel().label
    on: WallpaperService.sortKey !== "name"
    fontFamily: root.fontFamily; iconFamily: root.iconFamily
    onClicked: root.cycleSort()
  }
  WallpaperChip {
    visible: root.filtered
    glyph: "󰅖"
    fontFamily: root.fontFamily; iconFamily: root.iconFamily
    onClicked: WallpaperService.clearFilters()
  }
}
