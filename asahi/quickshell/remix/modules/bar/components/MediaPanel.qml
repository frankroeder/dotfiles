import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../../"
import "../BarModel.js" as BarModel
import "../../../services" as Services

// Media chip popup: the shared MediaCard (stacked, with a cava strip; the launcher's Media pane
// shows the same card wide). Hangs under the chip, left-aligned to it. Esc / click outside closes.
PopupWindow {
  id: root

  property var barHost: null
  property bool panelOpen: false
  readonly property var p: Services.Players.active

  visible: root.panelOpen && root.p !== null
  color: "transparent"
  anchor.edges: Edges.Bottom | Edges.Left
  anchor.gravity: Edges.Bottom | Edges.Right
  anchor.margins.bottom: -BarModel.popupDrop(root.barHost ? root.barHost.height : Style.barHeight, Style.barHeight)  // negative = below
  implicitWidth: 460
  implicitHeight: card.implicitHeight

  function close() { if (root.barHost && root.barHost.openPanel === "media") root.barHost.openPanel = "" }

  onVisibleChanged: if (visible) openAnim.restart()
  // Nothing left to show (player closed): drop the flag so the next track does not pop it open.
  onPChanged: if (!root.p) root.close()

  // Shared cava only while the strip is on screen and something plays.
  readonly property bool cavaWanted: root.visible && Services.Players.isPlaying
  onCavaWantedChanged: Services.Cava.hold(root, root.cavaWanted)
  Component.onDestruction: Services.Cava.hold(root, false)

  // Armed once the popup is mapped: armed at show time its surface was not whitelisted yet, and every
  // click inside closed it (no button in a bar popup worked).
  Timer { id: grabArm; interval: 150; running: root.visible }
  HyprlandFocusGrab {
    windows: [root, root.anchor.window]
    active: root.visible && !grabArm.running
    onCleared: root.close()
  }
  Shortcut {
    enabled: root.visible
    sequences: ["Escape"]
    context: Qt.ApplicationShortcut
    onActivated: root.close()
  }

  MediaCard {
    id: card
    anchors.fill: parent
    live: root.visible
    cavaOn: root.cavaWanted
    border.color: Style.popupBorder
    border.width: Style.popupBorderWidth
    transformOrigin: Item.TopLeft

    ParallelAnimation {
      id: openAnim
      NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
      NumberAnimation { target: card; property: "scale"; from: 0.96; to: 1; duration: 260; easing.type: Easing.OutCubic }
    }
  }
}
