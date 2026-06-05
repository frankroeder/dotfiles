import QtQuick
import "../../"

Item {
  id: root
  property string title: ""
  property string subtitle: ""
  property real fontScale: 1.0
  property string fontFamily: Style.menuMono

  width: parent ? parent.width : 0
  height: Math.max(28, titleText.implicitHeight + 4)

  Text {
    id: titleText
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root.title
    color: Style.menuInk
    font.family: root.fontFamily
    font.pixelSize: 19 * root.fontScale
    font.letterSpacing: Style.menuTitleSpacing
    font.weight: Font.Medium
  }

  Text {
    anchors.left: titleText.right
    anchors.leftMargin: 18
    anchors.baseline: titleText.baseline
    visible: root.subtitle !== ""
    text: root.subtitle
    color: Style.menuInkDeep
    font.family: root.fontFamily
    font.pixelSize: 11 * root.fontScale
    font.letterSpacing: Style.menuLabelSpacing
  }
}