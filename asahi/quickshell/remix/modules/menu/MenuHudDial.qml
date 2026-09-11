import QtQuick
import QtQuick.Shapes
import "../../"

// Omarchy speed-cluster dial, scaled for the launcher overview.
Item {
  id: dial
  property real value: 0
  property string label: ""
  property color accent: Style.menuAccent
  property string fontFamily: Style.menuMono

  readonly property real diameter: Math.max(8, Math.min(width, height))
  readonly property real start: 135
  readonly property real sweep: 270
  readonly property real arcW: Math.max(2, Math.round(diameter * 0.055))
  readonly property real arcR: diameter / 2 - arcW
  readonly property real fraction: Math.max(0, Math.min(1, shown / 100))
  readonly property bool arcOn: fraction > 0.004
  property real shown: 0

  Behavior on shown {
    NumberAnimation { duration: 480; easing.type: Easing.OutCubic }
  }
  onValueChanged: shown = value
  Component.onCompleted: shown = value

  Item {
    width: dial.diameter
    height: dial.diameter
    anchors.centerIn: parent

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeWidth: dial.arcW
        strokeColor: Qt.rgba(1, 1, 1, 0.12)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: dial.diameter / 2
          centerY: dial.diameter / 2
          radiusX: dial.arcR
          radiusY: dial.arcR
          startAngle: dial.start
          sweepAngle: dial.sweep
        }
      }
      ShapePath {
        strokeWidth: dial.arcW * 2.6
        strokeColor: dial.arcOn ? Qt.rgba(dial.accent.r, dial.accent.g, dial.accent.b, 0.16) : "transparent"
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: dial.diameter / 2
          centerY: dial.diameter / 2
          radiusX: dial.arcR
          radiusY: dial.arcR
          startAngle: dial.start
          sweepAngle: dial.sweep * dial.fraction
        }
      }
      ShapePath {
        strokeWidth: dial.arcW
        strokeColor: dial.arcOn ? dial.accent : "transparent"
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: dial.diameter / 2
          centerY: dial.diameter / 2
          radiusX: dial.arcR
          radiusY: dial.arcR
          startAngle: dial.start
          sweepAngle: dial.sweep * dial.fraction
        }
      }
    }

    Repeater {
      model: 19
      delegate: Item {
        required property int index
        readonly property bool major: index % 3 === 0
        anchors.fill: parent
        rotation: dial.start + (index / 18) * dial.sweep - 270
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          y: dial.arcW * 1.6
          width: major ? 2 : 1
          height: major ? Math.max(4, dial.diameter * 0.07) : Math.max(3, dial.diameter * 0.045)
          radius: 1
          color: major ? Qt.rgba(1, 1, 1, 0.32) : Qt.rgba(1, 1, 1, 0.12)
        }
      }
    }

    Item {
      anchors.fill: parent
      rotation: dial.start + dial.fraction * dial.sweep - 270
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: dial.arcW * 2 + 4
        width: Math.max(2, Math.round(dial.diameter * 0.03))
        height: dial.diameter * 0.28
        radius: width / 2
        gradient: Gradient {
          GradientStop { position: 0.0; color: dial.accent }
          GradientStop { position: 0.55; color: dial.accent }
          GradientStop { position: 1.0; color: "transparent" }
        }
      }
    }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: Math.round(dial.diameter * 0.06)
      spacing: 0
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Math.round(dial.shown) + "%"
        color: Style.menuInk
        font.family: dial.fontFamily
        font.pixelSize: Math.max(9, Math.round(dial.diameter * 0.18))
        font.weight: Font.DemiBold
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: dial.label
        color: Style.menuInkMuted
        font.family: dial.fontFamily
        font.pixelSize: Math.max(7, Math.round(dial.diameter * 0.09))
        font.letterSpacing: 0.3
        font.weight: Font.Medium
      }
    }
  }
}
