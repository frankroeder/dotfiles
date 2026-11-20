import QtQuick
import "../../"
import "../bar/BarModel.js" as BarModel
import "../menu" as Menu

// Auth "dynamic island" (idea: shell-ninja/hyprconf): a notch-black pill the size of the camera cutout, flush with
// the top edge, that springs down into a card while the surface fades in over the black; the content (kept below
// the cutout) fades in last. Closing runs it backwards on the exit curve. Without a notch it grows out of the bar.
// Owner: a full-screen-wide top-anchored layer, `exclusionMode: Ignore`, `visible: shown || card.busy`.
Item {
  id: root

  property bool shown: false
  property var screen: null
  property int fullWidth: 440
  property int contentHeight: 0
  property int padding: 22
  property color tone: "transparent"           // an extra rim colour (Touch ID state); transparent = hairline
  default property alias content: inner.data
  readonly property bool busy: growIn.running || growOut.running
  readonly property bool notched: !!root.screen && String(root.screen.name || "").indexOf("eDP") === 0
  // The cutout (BarModel geometry), else a bar-high pill.
  readonly property int pillWidth: root.notched ? Math.ceil(root.screen.width * 370 / 3024) : 180
  readonly property int pillHeight: root.notched
    ? Math.max(Style.barHeight, BarModel.notchHeight(root.screen.name, root.screen.width, root.screen.height)) : Style.barHeight
  readonly property int fullHeight: root.pillHeight + root.contentHeight + root.padding
  property real grow: 0

  function lerp(a, b) { return a + (b - a) * root.grow }

  onShownChanged: if (root.shown) { growOut.stop(); growIn.restart() } else { growIn.stop(); growOut.restart() }
  Menu.MenuAnim { id: growIn; target: root; property: "grow"; to: 1 }
  Menu.MenuAnim { id: growOut; target: root; property: "grow"; to: 0; exit: true }

  width: root.lerp(root.pillWidth, root.fullWidth)
  height: root.lerp(root.pillHeight, root.fullHeight)

  readonly property real surfaceOpacity: Math.min(1, root.grow * 1.6)
  readonly property real cornerRadius: root.lerp(root.notched ? 12 : root.pillHeight / 2, Style.menuPanelRadius)

  // The island: notch-black (bar-coloured without a notch) fading out under the surface fading in.
  Rectangle {
    anchors.fill: parent
    topLeftRadius: 0; topRightRadius: 0
    bottomLeftRadius: root.cornerRadius; bottomRightRadius: root.cornerRadius
    color: root.notched ? "black" : Style.barStripBg
    opacity: 1 - root.surfaceOpacity
  }
  Rectangle {
    anchors.fill: parent
    topLeftRadius: 0; topRightRadius: 0
    bottomLeftRadius: root.cornerRadius; bottomRightRadius: root.cornerRadius
    color: Style.m3surfaceSolid
    opacity: root.surfaceOpacity
    border.width: root.tone.a > 0 ? Style.popupBorderWidth : 1
    border.color: root.tone.a > 0 ? Qt.alpha(root.tone, 0.55) : Style.menuHairline
    Behavior on border.color { ColorAnimation { duration: Style.menuStateMs } }
  }

  // Content: fixed width (no reflow while the island grows), centred, below the cutout, last to appear;
  // clipped to the island until it is full size.
  Item {
    anchors.fill: parent
    clip: root.grow < 1
    Item {
      id: inner
      width: root.fullWidth - 2 * root.padding
      height: root.contentHeight
      x: (parent.width - width) / 2
      y: root.pillHeight + Math.round(root.padding / 3)
      opacity: Math.max(0, (root.grow - 0.55) / 0.45)
    }
  }
}
