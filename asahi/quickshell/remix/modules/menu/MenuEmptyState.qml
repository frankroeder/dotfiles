import QtQuick
import "../../"

// Centred empty / off / error state for a pane card: tinted glyph disc, title,
// optional detail line and optional action pill. One look for every pane.
Column {
  id: root
  property string glyph: ""
  property string title: ""
  property string detail: ""
  property string actionIcon: ""
  property string actionLabel: ""
  property color tint: Style.m3onSurfaceVariant
  property real fontScale: 1
  property string iconFamily: Style.menuMono
  property string fontFamily: Style.menuSans
  property real maxWidth: 420 * fontScale
  signal action()

  spacing: Math.round(6 * fontScale)

  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.round(56 * root.fontScale); height: width; radius: width / 2
    color: Qt.alpha(root.tint, 0.12)
    Text {
      anchors.centerIn: parent
      text: root.glyph; color: root.tint
      font.family: root.iconFamily; font.pixelSize: Math.round(26 * root.fontScale)
    }
  }
  Item { width: 1; height: Math.round(2 * root.fontScale) }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    visible: root.title !== ""
    text: root.title
    color: Style.m3onSurface
    font.family: root.fontFamily; font.pixelSize: Math.round(13 * root.fontScale); font.weight: Font.DemiBold
  }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    visible: root.detail !== ""
    width: Math.min(implicitWidth, root.maxWidth)
    text: root.detail
    color: Style.m3onSurfaceVariant
    font.family: root.fontFamily; font.pixelSize: Math.round(11 * root.fontScale)
    wrapMode: Text.Wrap
    horizontalAlignment: Text.AlignHCenter
  }
  Item { width: 1; height: Math.round(4 * root.fontScale); visible: root.actionLabel !== "" }
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    visible: root.actionLabel !== ""
    implicitWidth: actRow.implicitWidth + Math.round(28 * root.fontScale)
    implicitHeight: Math.round(32 * root.fontScale)
    radius: height / 2
    color: actMa.containsMouse ? Qt.lighter(Style.m3primary, 1.1) : Style.m3primary
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
      id: actRow
      anchors.centerIn: parent
      spacing: Math.round(6 * root.fontScale)
      Text {
        visible: root.actionIcon !== ""
        text: root.actionIcon; color: Style.m3onPrimary
        font.family: root.iconFamily; font.pixelSize: Math.round(13 * root.fontScale)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: root.actionLabel; color: Style.m3onPrimary
        font.family: root.fontFamily; font.pixelSize: Math.round(11 * root.fontScale); font.weight: Font.DemiBold
        anchors.verticalCenter: parent.verticalCenter
      }
    }
    MouseArea { id: actMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.action() }
  }
}
