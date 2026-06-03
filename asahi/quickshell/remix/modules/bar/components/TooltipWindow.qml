import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../../"

PopupWindow {
  id: root

  property Item target: null
  property string text: ""
  property int maxWidth: 420
  property int pad: 10
  property bool show: false

  visible: show && text.length > 0
  color: "transparent"

  anchor.item: target
  anchor.edges: Edges.Bottom

  implicitWidth: Math.min(textItem.paintedWidth + pad * 2, maxWidth)
  implicitHeight: textItem.paintedHeight + pad * 2

  Rectangle {
    anchors.fill: parent
    color: Style.surface
    border.color: Style.barBorder
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    radius: Style.radius
  }

  Text {
    id: textItem
    x: root.pad
    y: root.pad
    text: root.text
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSizeTiny
    color: Style.text
    wrapMode: Text.Wrap
    width: root.maxWidth - root.pad * 2
  }
}
