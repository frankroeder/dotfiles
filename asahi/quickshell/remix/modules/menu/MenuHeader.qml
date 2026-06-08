import QtQuick
import "../../"

Item {
  id: root
  property string title: ""
  property string subtitle: ""
  property string sectionIcon: ""
  property string sectionName: ""
  property string countLine: ""
  property string hintText: ""
  property real fontScale: 1.0
  property string fontFamily: Style.menuMono

  readonly property bool breadcrumb: root.sectionName !== ""

  width: parent ? parent.width : 0
  height: breadcrumb
    ? Math.max(40, titleRow.height + 4 + countText.implicitHeight)
    : Math.max(28, titleText.implicitHeight + 4)

  // Classic single-row header (wallpaper picker, root launcher)
  Text {
    id: titleText
    visible: !root.breadcrumb
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
    visible: !root.breadcrumb && root.subtitle !== ""
    anchors.left: titleText.right
    anchors.leftMargin: 18
    anchors.baseline: titleText.baseline
    text: root.subtitle
    color: Style.menuInkDeep
    font.family: root.fontFamily
    font.pixelSize: 11 * root.fontScale
    font.letterSpacing: Style.menuLabelSpacing
  }

  // Breadcrumb header: LAUNCHER › icon SECTION + hints right, count below
  Item {
    id: titleRow
    visible: root.breadcrumb
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: breadcrumbRow.height

    Row {
      id: breadcrumbRow
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10

      Text {
        text: root.title
        color: Style.menuInk
        font.family: root.fontFamily
        font.pixelSize: 19 * root.fontScale
        font.letterSpacing: Style.menuTitleSpacing
        font.weight: Font.Medium
      }

      Text {
        text: "›"
        color: Style.menuInkDeep
        font.family: root.fontFamily
        font.pixelSize: 15 * root.fontScale
        opacity: 0.7
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        visible: root.sectionIcon !== ""
        text: root.sectionIcon
        color: Style.menuSeal
        font.family: root.fontFamily
        font.pixelSize: 17 * root.fontScale
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: root.sectionName.toUpperCase()
        color: Style.menuInk
        font.family: root.fontFamily
        font.pixelSize: 19 * root.fontScale
        font.letterSpacing: Style.menuTitleSpacing
        font.weight: Font.Medium
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Text {
      visible: root.hintText !== ""
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.hintText
      color: Style.menuInkDeep
      font.family: root.fontFamily
      font.pixelSize: 10 * root.fontScale
      font.letterSpacing: 1.2
      opacity: 0.75
      horizontalAlignment: Text.AlignRight
    }
  }

  Text {
    id: countText
    visible: root.breadcrumb && root.countLine !== ""
    anchors.left: parent.left
    anchors.top: titleRow.bottom
    anchors.topMargin: 4
    text: root.countLine
    color: Style.menuInkDeep
    font.family: root.fontFamily
    font.pixelSize: 11 * root.fontScale
    font.letterSpacing: Style.menuLabelSpacing
  }
}