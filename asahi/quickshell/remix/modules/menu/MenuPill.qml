import QtQuick
import "../../"

// Full-round action pill: optional glyph + label on a tonal fill. `selected` = primary container
// + accent hairline; hover is the onSurface state layer (shows on light and dark fills alike).
Rectangle {
  id: pill
  property string icon: ""
  property string label: ""
  property color bg: Style.m3containerHigh
  property color fg: Style.m3onSurface
  property bool selected: false
  property bool numeric: false   // a number that ticks: tabular digits (tnum also widens - : . in names)
  property real fontScale: Style.uiScale
  property string iconFamily: Style.menuMono
  property string fontFamily: Style.menuSans
  signal clicked()

  implicitWidth: pillRow.implicitWidth + 24
  implicitHeight: 32
  // Held: the full round squares off a little (M3 expressive shape morph), back on release.
  radius: pillMa.pressed && !Style.reduceMotion ? Style.menuRadiusSm : height / 2
  Behavior on radius { MenuAnim { fast: true } }
  color: pill.selected ? Style.m3primaryContainer : pill.bg
  border.width: pill.selected ? 1 : 0
  border.color: Style.menuSelBorder
  Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
  // Press: the pressed state layer + a small give (none under reduced motion).
  scale: pillMa.pressed && !Style.reduceMotion ? 0.97 : 1
  Behavior on scale { MenuAnim { fast: true } }

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: pillMa.pressed ? Style.m3statePress : Style.m3stateHover
    opacity: pillMa.containsMouse || pillMa.pressed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Style.menuStateMs } }
  }
  // Under the label: the disc must not veil the text.
  MenuRipple { id: ripple; radius: pill.radius }
  Row {
    id: pillRow
    anchors.centerIn: parent
    spacing: 6
    Text {
      visible: pill.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: pill.icon
      color: pill.selected ? Style.m3primary : pill.fg
      font.family: pill.iconFamily
      font.pixelSize: Math.round(12 * pill.fontScale)
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: pill.label
      textFormat: Text.PlainText  // notification action labels come from the sender
      color: pill.selected ? Style.m3primary : pill.fg
      font.family: pill.fontFamily; font.features: pill.numeric ? Style.fontTabular : ({})
      font.pixelSize: Math.round(10 * pill.fontScale)
      font.weight: pill.selected ? Font.DemiBold : Font.Medium
    }
  }
  MouseArea {
    id: pillMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    onPressed: mouse => ripple.start(mouse.x, mouse.y)
    onReleased: ripple.release()
    onCanceled: ripple.release()
    onClicked: pill.clicked()
  }
}
