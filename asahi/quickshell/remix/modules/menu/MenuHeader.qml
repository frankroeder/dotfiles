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
  property string fontFamily: Style.menuSans
  property string iconFamily: Style.menuMono

  readonly property bool breadcrumb: root.sectionName !== ""

  implicitWidth: parent ? parent.width : 0
  implicitHeight: breadcrumb
    ? Math.max(36, titleRow.height + (countText.visible ? 2 + countText.implicitHeight : 0))
    : Math.max(26, titleText.implicitHeight)
  width: parent ? parent.width : implicitWidth
  height: implicitHeight

  Text {
    id: titleText
    visible: !root.breadcrumb
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root.title
    color: Style.m3onSurfaceVariant
    font.family: root.fontFamily
    font.pixelSize: 13 * root.fontScale
    font.weight: Font.Medium
  }

  Text {
    visible: !root.breadcrumb && root.subtitle !== ""
    anchors.left: titleText.right
    anchors.leftMargin: 12
    anchors.baseline: titleText.baseline
    text: root.subtitle
    color: Style.m3outline
    font.family: root.fontFamily
    font.pixelSize: 12 * root.fontScale
  }

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
      spacing: 8

      Text {
        text: root.title
        color: Style.m3onSurfaceVariant
        font.family: root.fontFamily
        font.pixelSize: 13 * root.fontScale
        font.weight: Font.Medium
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        visible: root.sectionName !== ""
        text: "/"
        color: Style.m3outline
        font.family: root.fontFamily
        font.pixelSize: 13 * root.fontScale
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        visible: root.sectionIcon !== ""
        text: root.sectionIcon
        color: Style.m3primary
        font.family: root.iconFamily
        font.pixelSize: 15 * root.fontScale
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: root.sectionName
        color: Style.m3onSurface
        font.family: root.fontFamily
        font.pixelSize: 15 * root.fontScale
        font.weight: Font.DemiBold
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Text {
      visible: root.hintText !== ""
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.hintText
      color: Style.m3outline
      font.family: root.fontFamily
      font.pixelSize: 11 * root.fontScale
      horizontalAlignment: Text.AlignRight
    }
  }

  Text {
    id: countText
    visible: root.breadcrumb && root.countLine !== ""
    anchors.left: parent.left
    anchors.top: titleRow.bottom
    anchors.topMargin: 2
    text: root.countLine
    color: Style.m3outline
    font.family: root.fontFamily
    font.pixelSize: 11 * root.fontScale
  }
}
