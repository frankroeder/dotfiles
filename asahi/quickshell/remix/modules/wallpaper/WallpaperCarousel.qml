import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../"
import "wallpaper_thumbs.js" as WallThumbs

// Skewed window fan. The pick is a 16:9 window; neighbours are leaning slices
// that overlap it. Click a slice to select it, click the centre window to apply.
// Positions come from carouselWindow(), not a ListView (that collapsed to one tile).
Item {
  id: root
  property var paths: []
  property int viewW: 0
  property real fontScale: 1.0
  property string fontFamily: Style.menuSans
  property string iconFamily: Style.menuMono
  property bool live: true
  property string anchorPath: ""
  // Path the user browsed to. Empty means "the applied wallpaper" so a filter
  // that has not indexed it yet still centres it once the row appears.
  property string selectedPath: ""
  property bool placed: false
  property string pendingPath: ""
  signal activated(string path)

  readonly property int _vw: viewW > 0 ? viewW : width
  property int maxExpandedW: 768
  readonly property var frame: WallThumbs.carouselFrame(_vw, maxExpandedW)
  // Resolved from the path, not a stored index: Dark/Light replaces `paths`
  // with a shorter array and the old index used to fall off the end.
  readonly property int shownIndex: WallThumbs.resolveCarouselIndex(paths, selectedPath, anchorPath)
  readonly property string currentPath: {
    const list = paths || []
    const i = shownIndex
    return i >= 0 && i < list.length ? list[i] : ""
  }

  implicitWidth: _vw
  implicitHeight: (paths || []).length ? frame.height : 0
  height: implicitHeight
  clip: true

  function indexOfPath(path) { return (paths || []).indexOf(path) }
  function pathAt(i) { return i >= 0 && i < (paths || []).length ? paths[i] : "" }
  function go(i) {
    if (i < 0 || i >= (paths || []).length) return
    placed = true
    selectedPath = pathAt(i)
    if (live && selectedPath) WallpaperService.preview(selectedPath)
  }
  function next() { go(Math.min((paths || []).length - 1, shownIndex + 1)) }
  function prev() { go(Math.max(0, shownIndex - 1)) }
  function jumpTo(path) {
    const i = indexOfPath(path)
    if (i >= 0) { go(i); pendingPath = "" }
    else pendingPath = path || ""
  }
  function place() {
    if ((paths || []).length === 0) return
    // Pin the applied wallpaper when it is already in this list. Leaving the
    // path empty when it is not (tone filter ahead of the color index) lets
    // shownIndex pick it up the moment the row appears, instead of sticking
    // to whichever window the fan clamped onto.
    selectedPath = indexOfPath(anchorPath) >= 0 ? anchorPath : ""
    placed = true
  }
  function settle() {
    if (pendingPath && indexOfPath(pendingPath) >= 0) { jumpTo(pendingPath); return }
    if (!placed) place()
    // Read the resolver directly. The currentPath binding may not have flushed
    // yet inside onPathsChanged, and a Light click still has to arm preview
    // on the window that just became the centre.
    const p = pathAt(WallThumbs.resolveCarouselIndex(paths, selectedPath, anchorPath))
    if (live && p && p !== WallpaperService.browsePath) WallpaperService.preview(p)
  }
  function activate() { const p = currentPath; if (p) activated(p) }
  function recenter() {}

  onLiveChanged: if (!live) WallpaperService.stopPreview()
  onAnchorPathChanged: { selectedPath = ""; placed = false; settle() }
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

  Repeater {
    model: root.paths
    delegate: Item {
      id: slice
      required property int index
      required property var modelData
      readonly property string path: modelData ? ("" + modelData) : ""
      readonly property var win: WallThumbs.carouselWindow(root.frame, (root.paths || []).length, root.shownIndex, index)
      readonly property bool selected: win.selected
      readonly property bool applied: path !== "" && WallpaperService.currentWallpaper === path
      readonly property real skew: root.frame.skew
      property bool motion: false
      function pick() { selected ? root.activate() : root.go(index) }

      visible: win.nearby && win.w > 0 && win.h > 0
      x: win.x
      y: win.y
      width: Math.max(0, win.w)
      height: Math.max(0, win.h)
      z: win.z
      Component.onCompleted: motion = true
      Behavior on x { enabled: slice.motion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on y { enabled: slice.motion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on width { enabled: slice.motion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on height { enabled: slice.motion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      Loader {
        anchors.fill: parent
        active: root.live && slice.visible
        sourceComponent: Component {
          Item {
            id: face

            Item {
              id: maskShape
              anchors.fill: parent
              visible: false
              layer.enabled: true
              layer.smooth: true
              Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  fillColor: "white"
                  strokeColor: "transparent"
                  startX: slice.skew
                  startY: 0
                  PathLine { x: face.width; y: 0 }
                  PathLine { x: face.width - slice.skew; y: face.height }
                  PathLine { x: 0; y: face.height }
                  PathLine { x: slice.skew; y: 0 }
                }
              }
            }

            Item {
              anchors.fill: parent
              layer.enabled: true
              layer.smooth: true
              layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskShape
                maskThresholdMin: 0.3
                maskSpreadAtMin: 0.3
              }
              Image {
                id: img
                anchors.fill: parent
                source: slice.path ? WallpaperService.previewSource(slice.path) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                retainWhileLoading: true
              }
              // Centre window: the 1920×1080 cache tier (the 640×360 thumb is blurry that
              // large). The thumb shows until it loads.
              Image {
                anchors.fill: parent
                visible: slice.selected && status === Image.Ready
                source: slice.selected && slice.path ? WallpaperService.hqSource(slice.path) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
              }
              Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: slice.selected ? 0 : 0.42
                Behavior on opacity { NumberAnimation { duration: 180 } }
              }
              Text {
                anchors.centerIn: parent
                visible: slice.path !== "" && img.status !== Image.Ready
                text: "󰋩"
                color: Style.m3outline
                font.family: root.iconFamily || root.fontFamily
                font.pixelSize: slice.selected ? 28 : 16
              }
            }

            Shape {
              anchors.fill: parent
              antialiasing: true
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                fillColor: "transparent"
                strokeColor: slice.selected ? Style.m3primary : Style.m3outline
                strokeWidth: slice.selected ? 3 : 1
                Behavior on strokeColor { ColorAnimation { duration: 150 } }
                startX: slice.skew
                startY: 0
                PathLine { x: face.width; y: 0 }
                PathLine { x: face.width - slice.skew; y: face.height }
                PathLine { x: 0; y: face.height }
                PathLine { x: slice.skew; y: 0 }
              }
            }

            // Applied wallpaper: a labelled chip (a bare dot read as a speck of dust).
            Rectangle {
              visible: slice.applied
              x: slice.skew + 12
              y: 12
              width: curRow.implicitWidth + 18
              height: 26
              radius: height / 2
              color: Style.m3surface
              Row {
                id: curRow
                anchors.centerIn: parent
                spacing: 5
                Text { text: "󰄬"; color: Style.m3primary; font.family: root.iconFamily; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Current"; color: Style.m3onSurface; font.family: root.fontFamily; font.pixelSize: 12; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              containmentMask: Item {
                function contains(point) {
                  return WallThumbs.carouselContains(slice.skew, face.width, face.height, point.x, point.y)
                }
              }
              onClicked: slice.pick()
            }
          }
        }
      }
    }
  }
}
