import Quickshell
import QtQuick
import "../../../"
import "../BarModel.js" as BarModel
import "../tooltip_warm.js" as Warm

// Bar tooltip: shows after a 470 ms hover, at once while another is open or hid < 600 ms ago (moving along the tray);
// enters with a 140 ms fade + 0.96 → 1 scale from the bar, leaves on a 100 ms fade. Popup text tokens.
PopupWindow {
  id: root

  property Item target: null
  property string text: ""
  property int maxWidth: 420
  property int pad: 10
  property bool show: false
  property int barHeight: Style.barHeight

  property bool shown: false
  onShowChanged: {
    if (root.show) {
      if (Warm.warm()) root.shown = true
      else delay.restart()
    } else {
      delay.stop()
      root.shown = false
    }
  }
  onShownChanged: root.shown ? Warm.opened() : Warm.hid()
  Component.onDestruction: if (root.shown) Warm.hid()
  Timer { id: delay; interval: 470; onTriggered: root.shown = true }

  // Mapped (still transparent) from the hover on: a surface maps in 50–80 ms, which ate the first third of the fade.
  visible: (root.show || root.shown || fade.running) && text.length > 0
  color: "transparent"

  anchor.item: target
  anchor.edges: Edges.Bottom
  anchor.margins.bottom: -BarModel.popupDrop(barHeight, Style.barHeight)  // negative = below

  implicitWidth: Math.min(textItem.paintedWidth + pad * 2, maxWidth)
  implicitHeight: textItem.paintedHeight + pad * 2

  Item {
    anchors.fill: parent
    transformOrigin: Item.Top
    opacity: root.shown ? 1 : 0
    scale: root.shown || Style.reduceMotion ? 1 : 0.96
    Behavior on opacity { NumberAnimation { id: fade; duration: root.shown && !Style.reduceMotion ? 140 : 100; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Rectangle {
      anchors.fill: parent
      color: Style.m3surfaceSolid
      radius: Style.menuRadiusMd   // ~36 px tall: Lg read as a pill
      border.color: Style.popupBorder
      border.width: Style.popupBorderWidth
    }

    Text {
      id: textItem
      x: root.pad
      y: root.pad
      textFormat: Text.PlainText
      text: root.text
      font.family: Style.fontUi
      font.pixelSize: Style.typeBody
      color: Style.menuInk
      wrapMode: Text.Wrap
      width: root.maxWidth - root.pad * 2
    }
  }
}
