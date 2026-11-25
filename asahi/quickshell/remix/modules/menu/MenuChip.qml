import QtQuick
import "../../"

// Full-round fact chip: glyph + label on a tonal fill. `fixedWidth` keeps a live label from
// reflowing the row; `clickable` adds the hover state layer and `clicked`.
Rectangle {
  id: chip
  property string icon: ""
  property string label: ""
  property color bg: Style.m3secondaryContainer
  property color fg: Style.m3onSurface
  property int fixedWidth: 0
  property bool clickable: false
  property bool numeric: false   // a number that ticks: tabular digits (tnum also widens - : . in names)
  property real fontScale: Style.uiScale
  property string iconFamily: Style.menuMono
  property string fontFamily: Style.menuSans
  signal clicked()

  implicitWidth: chip.fixedWidth > 0 ? chip.fixedWidth : chipRow.implicitWidth + 20
  implicitHeight: 28
  // Held: the full round squares off a little (M3 expressive shape morph), back on release.
  radius: chipMa.pressed && !Style.reduceMotion ? Style.menuRadiusSm : height / 2
  Behavior on radius { NumberAnimation { duration: Style.menuStateMs; easing.type: Easing.OutCubic } }
  color: chip.bg

  scale: chipMa.pressed && !Style.reduceMotion ? 0.97 : 1
  Behavior on scale { NumberAnimation { duration: Style.menuStateMs; easing.type: Easing.OutCubic } }
  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: chipMa.pressed ? Style.m3statePress : Style.m3stateHover
    visible: chipMa.containsMouse || chipMa.pressed
  }
  // Under the label: the disc must not veil the text.
  MenuRipple { id: ripple; radius: chip.radius }
  Row {
    id: chipRow
    anchors.centerIn: parent
    spacing: 6
    Text {
      visible: chip.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: chip.icon
      color: chip.fg
      font.family: chip.iconFamily
      font.pixelSize: Math.round(11 * chip.fontScale)
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: chip.label
      textFormat: Text.PlainText   // labels carry outside strings (an inhibitor's app name, a window class)
      color: chip.fg
      font.family: chip.fontFamily; font.features: chip.numeric ? Style.fontTabular : ({})
      font.pixelSize: Math.round(10 * chip.fontScale)
      font.weight: Font.Medium
    }
  }
  MouseArea {
    id: chipMa
    anchors.fill: parent
    enabled: chip.clickable
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => ripple.start(mouse.x, mouse.y)
    onReleased: ripple.release()
    onCanceled: ripple.release()
    onClicked: chip.clicked()
  }
}
