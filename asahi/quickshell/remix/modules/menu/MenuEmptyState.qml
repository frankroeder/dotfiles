import QtQuick
import "../../"

// Centred empty / off / error state for a pane card: tinted glyph disc, title,
// optional detail line and optional action pill. One look for every pane.
// `quiet`: one line (faint glyph + `title` as body text) for an empty list inside a card, where the disc would shout.
Column {
  id: root
  property string glyph: ""
  property string title: ""
  property bool quiet: false
  property string detail: ""
  property string actionIcon: ""
  property string actionLabel: ""
  property color tint: Style.m3onSurfaceVariant
  property real fontScale: Style.uiScale
  property string iconFamily: Style.menuMono
  property string fontFamily: Style.menuSans
  property real maxWidth: 420 * fontScale
  signal action()

  spacing: Math.round(6 * fontScale)

  Row {
    visible: root.quiet
    spacing: Math.round(6 * root.fontScale)
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.round(20 * root.fontScale); horizontalAlignment: Text.AlignHCenter
      visible: root.glyph !== ""
      text: root.glyph; color: Qt.alpha(root.tint, 0.7)
      font.family: root.iconFamily; font.pixelSize: Math.round(14 * root.fontScale)
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, root.maxWidth)
      text: root.title
      textFormat: Text.PlainText
      color: Style.m3onSurfaceVariant
      font.family: root.fontFamily; font.pixelSize: Math.round(11 * root.fontScale)
      elide: Text.ElideRight
    }
  }
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    visible: !root.quiet
    width: Math.round(56 * root.fontScale); height: width; radius: width / 2
    color: Qt.alpha(root.tint, 0.12)
    MenuGlyph { anchors.centerIn: parent; text: root.glyph; color: root.tint; font.family: root.iconFamily; size: parent.width * Style.glyphRatio }
  }
  Item { width: 1; height: Math.round(2 * root.fontScale); visible: !root.quiet }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    visible: !root.quiet && root.title !== ""
    text: root.title
    textFormat: Text.PlainText
    width: Math.min(implicitWidth, root.maxWidth); elide: Text.ElideRight   // a long title stays inside a narrow card
    color: Style.m3onSurface
    font.family: root.fontFamily; font.pixelSize: Math.round(13 * root.fontScale); font.weight: Font.DemiBold
  }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    visible: !root.quiet && root.detail !== ""
    width: Math.min(implicitWidth, root.maxWidth)
    text: root.detail
    textFormat: Text.PlainText
    color: Style.m3onSurfaceVariant
    font.family: root.fontFamily; font.pixelSize: Math.round(11 * root.fontScale)
    wrapMode: Text.Wrap
    horizontalAlignment: Text.AlignHCenter
  }
  Item { width: 1; height: Math.round(4 * root.fontScale); visible: !root.quiet && root.actionLabel !== "" }
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    visible: !root.quiet && root.actionLabel !== ""
    implicitWidth: actRow.implicitWidth + Math.round(28 * root.fontScale)
    implicitHeight: Math.round(32 * root.fontScale)
    radius: height / 2
    color: actMa.containsMouse ? Qt.tint(Style.m3primary, Style.m3stateHover) : Style.m3primary
    Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
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
