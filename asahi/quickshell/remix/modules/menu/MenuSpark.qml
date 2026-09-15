import QtQuick
import QtQuick.Shapes
import "../../"

// Sparkline: `samples` (0..max) drawn oldest→newest, filled under the line.
Item {
  id: root
  property var samples: []
  property real max: 100
  property color accent: Style.menuNeon
  property int capacity: 60

  readonly property var pts: {
    const s = root.samples || []
    const n = Math.max(2, root.capacity)
    const out = []
    for (let i = 0; i < s.length; i++) {
      const x = (n - s.length + i) / (n - 1) * root.width
      const y = root.height - Math.max(0, Math.min(1, s[i] / root.max)) * (root.height - 2) - 1
      out.push(Qt.point(x, y))
    }
    return out
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillGradient: LinearGradient {
        x1: 0; y1: 0; x2: 0; y2: root.height
        GradientStop { position: 0.0; color: Qt.alpha(root.accent, 0.35) }
        GradientStop { position: 1.0; color: "transparent" }
      }
      startX: root.pts.length ? root.pts[0].x : 0
      startY: root.height
      PathPolyline { path: root.pts.length ? [Qt.point(root.pts[0].x, root.height)].concat(root.pts, [Qt.point(root.pts[root.pts.length - 1].x, root.height)]) : [] }
    }
    ShapePath {
      strokeWidth: 1.5
      strokeColor: root.accent
      fillColor: "transparent"
      joinStyle: ShapePath.RoundJoin
      PathPolyline { path: root.pts }
    }
  }

  // Head dot on the newest sample.
  Rectangle {
    visible: root.pts.length > 0
    x: (root.pts.length ? root.pts[root.pts.length - 1].x : 0) - 2
    y: (root.pts.length ? root.pts[root.pts.length - 1].y : 0) - 2
    width: 4; height: 4; radius: 2
    color: Qt.lighter(root.accent, 1.3)
  }
}
