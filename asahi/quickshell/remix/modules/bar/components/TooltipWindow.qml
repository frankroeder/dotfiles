import Quickshell
import Quickshell.Wayland
import QtQuick

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
    color: "#1e1e2e"
    border.color: "#45475a"
    radius: 6
  }

  Text {
    id: textItem
    x: root.pad
    y: root.pad
    text: root.text
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 12
    color: "#cdd6f4"
    wrapMode: Text.Wrap
    width: root.maxWidth - root.pad * 2
  }
}
