import QtQuick
import "../../"

// Round glyph button: `bg` disc (transparent by default), onSurface state layer on hover;
// `hot` tints the glyph while hovered.
Rectangle {
  id: btn
  property string icon: ""
  property color tone: Style.m3onSurfaceVariant
  property color hot: btn.tone
  property color bg: "transparent"
  property int iconPx: 13
  property real fontScale: 1
  property string iconFamily: Style.menuMono
  signal clicked()

  implicitWidth: 30
  implicitHeight: 30
  radius: width / 2
  color: btn.bg
  Behavior on color { ColorAnimation { duration: 120 } }

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: Style.m3stateHover
    opacity: btnMa.containsMouse ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }
  Text {
    anchors.centerIn: parent
    text: btn.icon
    color: btnMa.containsMouse ? btn.hot : btn.tone
    font.family: btn.iconFamily
    font.pixelSize: Math.round(btn.iconPx * btn.fontScale)
  }
  MouseArea { id: btnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
}
