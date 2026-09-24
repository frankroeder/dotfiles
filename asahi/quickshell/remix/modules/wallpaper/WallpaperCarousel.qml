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
  readonly property var frame: WallThumbs.carouselFrame(_vw)
  readonly property string currentPath: currentIndex >= 0 && currentIndex < (paths || []).length ? paths[currentIndex] : ""

  implicitWidth: _vw
  implicitHeight: (paths || []).length ? frame.height : 0
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

  Repeater {
    model: root.paths
    delegate: Item {
      id: slice
      required property int index
      required property var modelData
      readonly property string path: modelData ? ("" + modelData) : ""
      readonly property var win: WallThumbs.carouselWindow(root.frame, (root.paths || []).length, root.currentIndex, index)
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

            Rectangle {
              visible: slice.applied
              x: slice.skew + 10
              y: 10
              width: 10
              height: 10
              radius: 5
              color: Style.m3primary
              border.width: 2
              border.color: Style.m3surface
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
