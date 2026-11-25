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
  property real fontScale: Style.uiScale
  property string iconFamily: Style.menuMono
  signal clicked()

  implicitWidth: 30
  implicitHeight: 30
  radius: btnMa.pressed && !Style.reduceMotion ? Style.menuRadiusMd : width / 2   // held: squares off (shape morph)
  Behavior on radius { NumberAnimation { duration: Style.menuStateMs; easing.type: Easing.OutCubic } }
  color: btn.bg
  Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
  scale: btnMa.pressed && !Style.reduceMotion ? 0.92 : 1
  Behavior on scale { NumberAnimation { duration: Style.menuStateMs; easing.type: Easing.OutCubic } }

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: btnMa.pressed ? Style.m3statePress : Style.m3stateHover
    opacity: btnMa.containsMouse || btnMa.pressed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Style.menuStateMs } }
  }
  // Under the label: the disc must not veil the text.
  MenuRipple { id: ripple; radius: btn.radius }
  Text {
    anchors.centerIn: parent
    text: btn.icon
    color: btnMa.containsMouse ? btn.hot : btn.tone
    font.family: btn.iconFamily
    font.pixelSize: Math.round(btn.iconPx * btn.fontScale)
  }
  MouseArea {
    id: btnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    onPressed: mouse => ripple.start(mouse.x, mouse.y)
    onReleased: ripple.release()
    onCanceled: ripple.release()
    onClicked: btn.clicked()
  }
}
