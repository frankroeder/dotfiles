import QtQuick
import Quickshell.Widgets
import "../../"
import "../menu" as Menu
import "wallpaper_thumbs.js" as WallThumbs

// Three-slot wallpaper strip. A horizontal ListView sized itself to one tile
// in the Quick pane (neighbours clipped); this Row always lays out prev /
// current / next from the host viewport width.
Item {
  id: root
  property var paths: []
  property int viewW: 0
  property int currentIndex: 0
  property real fontScale: 1.0
  property string fontFamily: Style.menuSans
  property string iconFamily: Style.menuMono
  property bool live: true
  property string anchorPath: ""
  property bool placed: false
  property string pendingPath: ""
  signal activated(string path)

  readonly property int _vw: viewW > 0 ? viewW : width
  readonly property int itemW: WallThumbs.carouselItemWidth(_vw)
  readonly property int itemH: Math.round(itemW * 9 / 16)
  readonly property string currentPath: currentIndex >= 0 && currentIndex < (paths || []).length ? paths[currentIndex] : ""
  readonly property var slots: WallThumbs.carouselSlots(paths, currentIndex)

  implicitWidth: itemW * 3
  implicitHeight: itemH + 16
  height: implicitHeight
  clip: true

  function indexOfPath(path) { return (paths || []).indexOf(path) }
  function pathAt(i) { return i >= 0 && i < (paths || []).length ? paths[i] : "" }
  function go(i) {
    if (i < 0 || i >= (paths || []).length) return
    placed = true
    currentIndex = i
    const p = pathAt(i)
    if (live && p) WallpaperService.preview(p)
  }
  function next() { go(Math.min((paths || []).length - 1, currentIndex + 1)) }
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
  function activate() { const p = pathAt(currentIndex); if (p) activated(p) }
  function recenter() {}

  onLiveChanged: if (!live) WallpaperService.stopPreview()
  onAnchorPathChanged: { placed = false; settle() }
  onPathsChanged: { settle() }
  Component.onCompleted: Qt.callLater(settle)

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(ev) {
      const d = Math.abs(ev.angleDelta.x) > Math.abs(ev.angleDelta.y) ? ev.angleDelta.x : ev.angleDelta.y
      if (d < 0) root.next()
      else if (d > 0) root.prev()
    }
  }

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    height: root.implicitHeight
    Repeater {
      model: root.slots
      delegate: Item {
        id: item
        required property var modelData
        readonly property string path: (modelData && modelData.path) || ""
        readonly property bool current: !!(modelData && modelData.current)
        readonly property bool applied: item.path !== "" && WallpaperService.currentWallpaper === item.path
        readonly property real dist: item.current ? 0 : 1
        width: root.itemW
        height: root.implicitHeight
        visible: root.itemW > 0
        opacity: item.path ? 1 : 0
        enabled: item.path !== ""
        z: 1 - dist
        scale: 1 - 0.2 * dist

        ClippingRectangle {
          id: frame
          anchors.top: parent.top
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.max(0, root.itemW - 16)
          height: root.itemH
          radius: Style.menuRadiusLg
          color: Style.m3container
          visible: item.path !== ""
          Image {
            id: img
            anchors.fill: parent
            source: item.path ? WallpaperService.previewSource(item.path) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: 480
            sourceSize.height: 270
          }
          Text {
            anchors.centerIn: parent
            visible: item.path !== "" && img.status !== Image.Ready
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
          visible: item.path !== ""
          border.width: item.current ? 2 : 0
          border.color: Style.m3primary
        }
        MouseArea {
          anchors.fill: parent
          enabled: item.path !== ""
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activated(item.path)
        }
      }
    }
  }
}
