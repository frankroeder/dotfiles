import QtQuick
import QtQuick.Shapes
import "../../"

// Ring gauge (caelestia CircularProgress): 270° track in the container tone,
// value arc in the accent with round caps and a small gap, icon + percent
// inside and the label underneath.
Item {
  id: dial
  property real value: 0
  property string label: ""
  property string icon: ""
  property string suffix: "%"
  property color accent: Style.m3primary
  property string fontFamily: Style.menuMono
  property string labelFamily: Style.menuSans

  readonly property real diameter: Math.max(8, Math.min(width, height - labelText.height - 6))
  readonly property real stroke: Math.max(4, Math.round(diameter * 0.075))
  readonly property real arcR: diameter / 2 - stroke / 2
  readonly property real start: -225
  readonly property real sweep: 270
  readonly property real gapDeg: (stroke * 1.6 / Math.max(1, arcR)) * 180 / Math.PI
  property real shown: 0
  readonly property real frac: Math.max(0.003, Math.min(1, shown / 100))

  Behavior on shown { MenuAnim {} }
  onValueChanged: shown = value
  Component.onCompleted: shown = value

  Item {
    id: ring
    width: dial.diameter
    height: dial.diameter
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      // remaining track
      ShapePath {
        strokeWidth: dial.stroke
        strokeColor: Qt.alpha(dial.accent, 0.20)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: dial.diameter / 2; centerY: dial.diameter / 2
          radiusX: dial.arcR; radiusY: dial.arcR
          startAngle: dial.start + dial.sweep * dial.frac + dial.gapDeg
          sweepAngle: Math.max(0.5, dial.sweep * (1 - dial.frac) - dial.gapDeg)
        }
      }
      // value arc
      ShapePath {
        strokeWidth: dial.stroke
        strokeColor: dial.accent
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: dial.diameter / 2; centerY: dial.diameter / 2
          radiusX: dial.arcR; radiusY: dial.arcR
          startAngle: dial.start
          sweepAngle: dial.sweep * dial.frac
        }
      }
    }

    Column {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: Math.round(dial.diameter * 0.03)
      spacing: 0
      Text {
        visible: dial.icon !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        text: dial.icon
        color: dial.accent
        font.family: dial.fontFamily
        font.pixelSize: Math.max(14, Math.round(dial.diameter * 0.28))
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Math.round(dial.shown) + dial.suffix
        color: dial.accent
        font.family: dial.labelFamily
        font.pixelSize: Math.max(10, Math.round(dial.diameter * 0.2))
        font.weight: Font.DemiBold
      }
    }
  }

  Text {
    id: labelText
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: ring.bottom
    anchors.topMargin: 6
    text: dial.label
    color: Style.m3onSurfaceVariant
    font.family: dial.labelFamily
    // Sized from the item height, not the diameter, so the ring can size from the label.
    font.pixelSize: Math.max(10, Math.round(dial.height * 0.09))
    font.weight: Font.Medium
  }
}
