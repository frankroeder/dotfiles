import QtQuick
import Quickshell.Widgets
import "../../"
import "../menu" as Menu
import "wallpaper_thumbs.js" as WallThumbs

// Wallpaper carousel (caelestia WallpaperList): the centred item is the live
// preview, neighbours shrink with their distance from the centre. Wheel and
// keys browse; clicking any tile (or activate()) applies it. Built on a
// horizontal ListView: unlike PathView it keeps currentIndex stable while the
// pane is still animating open. Uses the thumbnail cache, never originals.
ListView {
  id: root
  property var paths: []
  // Host viewport width — never bind itemW to this ListView's own width
  // (implicit/content width collapses to one tile and hides neighbours).
  property int viewW: 0
  property int itemW: WallThumbs.carouselItemWidth(viewW)
  property real fontScale: 1.0
  property string fontFamily: Style.menuSans
  property string iconFamily: Style.menuMono
  // Owner sets this to its window visibility: previews only fire while shown,
  // and hiding always restores the desktop and palette.
  property bool live: true
  // The applied wallpaper; the view centres on it once list and path exist.
  property string anchorPath: ""
  property bool placed: false
  property string pendingPath: ""
  signal activated(string path)

  readonly property int itemH: Math.round(itemW * 9 / 16)
  readonly property string currentPath: currentIndex >= 0 && currentIndex < count ? paths[currentIndex] : ""

  implicitHeight: itemH + 16
  model: paths
  orientation: ListView.Horizontal
  interactive: false
  clip: true
  spacing: 0
  cacheBuffer: itemW * 4
  highlightRangeMode: ListView.StrictlyEnforceRange
  preferredHighlightBegin: Math.max(0, Math.round((width - itemW) / 2))
  preferredHighlightEnd: preferredHighlightBegin + itemW
  highlightMoveDuration: Style.menuSpringMs
  highlightMoveVelocity: -1

  function indexOfPath(path) { return (paths || []).indexOf(path) }
  // Only explicit moves preview (keys, wheel, shuffle): index churn from
  // layout or model resets never reaches the desktop.
  function go(i) {
    if (i < 0 || i >= count) return
    placed = true
    currentIndex = i
    const p = pathAt(i)
    if (live && p) WallpaperService.preview(p)
  }
  function next() { go(Math.min(count - 1, currentIndex + 1)) }
  function prev() { go(Math.max(0, currentIndex - 1)) }
  function jumpTo(path) {
    const i = indexOfPath(path)
    if (i >= 0) { go(i); pendingPath = "" }
    else pendingPath = path || ""
  }
  function place() {
    const i = indexOfPath(anchorPath)
    if (i >= 0) { currentIndex = i; placed = true }
  }
  function settle() {
    if (pendingPath) jumpTo(pendingPath)
    else if (!placed) place()
  }
  function pathAt(i) { return i >= 0 && i < (paths || []).length ? paths[i] : "" }
  function activate() { const p = pathAt(currentIndex); if (p) activated(p) }
  // StrictlyEnforceRange only re-centres on index changes, not when the
  // highlight range itself moves with the width, so do it by hand.
  function recenter() { if (currentIndex >= 0 && currentIndex < count) positionViewAtIndex(currentIndex, ListView.Center) }

  onLiveChanged: if (!live) WallpaperService.stopPreview()
  onAnchorPathChanged: { placed = false; settle() }
  onCountChanged: { settle(); Qt.callLater(recenter) }
  onModelChanged: { placed = false; Qt.callLater(settle) }
  onWidthChanged: Qt.callLater(recenter)
  Component.onCompleted: Qt.callLater(recenter)

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(ev) {
      const d = Math.abs(ev.angleDelta.x) > Math.abs(ev.angleDelta.y) ? ev.angleDelta.x : ev.angleDelta.y
      if (d < 0) root.next()
      else if (d > 0) root.prev()
    }
  }

  delegate: Item {
    id: item
    required property string modelData
    required property int index
    readonly property bool current: ListView.isCurrentItem
    readonly property bool applied: WallpaperService.currentWallpaper === modelData
    // 0 at the centre, 1 one slot away; drives the shrink and stacking.
    readonly property real dist: Math.min(1, Math.abs(x + width / 2 - root.contentX - root.width / 2) / root.itemW)
    width: root.itemW
    height: root.implicitHeight
    z: 1 - dist
    scale: 1 - 0.2 * dist

    ClippingRectangle {
      id: frame
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      width: root.itemW - 16
      height: root.itemH
      radius: Style.menuRadiusLg
      color: Style.m3container
      Image {
        id: img
        anchors.fill: parent
        source: WallpaperService.previewSource(item.modelData)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: 480
        sourceSize.height: 270
      }
      Text {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: "󰋩"
        color: Style.m3outline
        font.family: root.iconFamily
        font.pixelSize: 26
      }
      Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: 22; height: 22; radius: 11
        color: Style.m3primary
        visible: item.applied
        Text { anchors.centerIn: parent; text: "✓"; color: Style.m3onPrimary; font.pixelSize: 12; font.bold: true }
      }
    }
    Rectangle {
      anchors.fill: frame
      radius: frame.radius
      color: "transparent"
      border.width: item.current ? 2 : 0
      border.color: Style.m3primary
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.activated(item.modelData)
    }
  }
}
