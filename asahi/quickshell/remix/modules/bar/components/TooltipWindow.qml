import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../../"
import "../BarModel.js" as BarModel

PopupWindow {
  id: root

  property Item target: null
  property string text: ""
  property int maxWidth: 420
  property int pad: 10
  property bool show: false
  property int barHeight: Style.barHeight

  visible: show && text.length > 0
  color: "transparent"

  anchor.item: target
  anchor.edges: Edges.Bottom
  anchor.margins.bottom: -BarModel.popupDrop(barHeight, Style.barHeight)  // negative = below

  implicitWidth: Math.min(textItem.paintedWidth + pad * 2, maxWidth)
  implicitHeight: textItem.paintedHeight + pad * 2

  Rectangle {
    anchors.fill: parent
    color: Style.m3surfaceSolid
    radius: Style.menuRadiusLg
    opacity: root.visible ? 1 : 0
    Behavior on color { ColorAnimation { duration: 140 } }
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
