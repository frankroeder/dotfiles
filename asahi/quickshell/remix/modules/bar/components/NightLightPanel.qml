import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../"
import "../../menu" as Menu
import "../BarModel.js" as BarModel

// Night-light chip popup: warmth slider (1000–6000 K, warmer to the right, 250 K steps), three presets and Off.
// The slider sends one `asahi-nightlight set` 300 ms after the last move (a run per step raced, like the wheel did).
PopupWindow {
  id: root

  property var barHost: null
  property bool panelOpen: false
  property int temperature: 3000          // nightlight.json's, from the chip
  property int shown: root.temperature    // the slider's, ahead of the file while dragging
  onTemperatureChanged: if (!send.running) root.shown = root.temperature
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  function close() { if (root.barHost && root.barHost.openPanel === "night") root.barHost.openPanel = "" }
  function warmth(t) { return (6000 - t) / 5000 }
  function kelvin(v) { return Math.round((6000 - v * 5000) / 250) * 250 }
  function setTemp(t) { root.shown = t; send.restart() }
  Timer {
    id: send
    interval: 300
    onTriggered: Quickshell.execDetached([root.binDir + "/asahi-nightlight", "set", String(root.shown)])
  }

  visible: root.panelOpen || popOut.running
  onPanelOpenChanged: if (root.panelOpen) { popOut.stop(); popIn.restart() } else popOut.restart()
  color: "transparent"
  anchor.edges: Edges.Bottom
  anchor.margins.bottom: -BarModel.popupDrop(root.barHost ? root.barHost.height : Style.barHeight, Style.barHeight)
  implicitWidth: 300
  implicitHeight: card.implicitHeight

  Timer { id: grabArm; interval: 150; running: root.panelOpen }
  HyprlandFocusGrab {
    windows: [root, root.anchor.window]
    active: root.panelOpen && !grabArm.running
    onCleared: root.close()
  }
  Shortcut {
    enabled: root.panelOpen
    sequences: ["Escape"]
    context: Qt.ApplicationShortcut
    onActivated: root.close()
  }
  Menu.MenuPopIn { id: popIn; target: card }
  Menu.MenuPopOut { id: popOut; target: card }

  Rectangle {
    id: card
    width: parent.width
    implicitHeight: col.implicitHeight + 2 * Style.popupPad
    radius: Style.menuRadiusLg
    color: Style.m3surfaceSolid
    border.color: Style.popupBorder
    border.width: Style.popupBorderWidth
    transformOrigin: Item.Top
    enabled: root.panelOpen

    ColumnLayout {
      id: col
      anchors.fill: parent
      anchors.margins: Style.popupPad
      spacing: Style.popupGap

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Menu.MenuGlyphTile { glyph: "󰽥"; tint: Style.orange }
        Text {
          Layout.fillWidth: true
          text: "Night light"
          color: Style.m3onSurface
          font.family: Style.menuSans; font.pixelSize: Style.typeTitle; font.weight: Font.DemiBold
        }
        Text {
          text: root.shown + " K"
          color: Style.orange
          font.family: Style.menuSans; font.pixelSize: Style.typeLead; font.weight: Font.DemiBold
          font.features: Style.fontTabular
        }
      }

      Menu.MenuSlider {
        Layout.fillWidth: true
        accent: Style.orange
        value: root.warmth(root.shown)
        onMoved: v => root.setTemp(root.kelvin(v))
      }
      RowLayout {
        Layout.fillWidth: true
        Text { text: "Neutral"; color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: Style.typeCaption }
        Item { Layout.fillWidth: true }
        Text { text: "Warm"; color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: Style.typeCaption }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
          model: [["Candle", 1500], ["Warm", 2500], ["Soft", 4000]]
          Menu.MenuPill {
            required property var modelData
            label: modelData[0]
            selected: root.shown === modelData[1]
            onClicked: root.setTemp(modelData[1])
          }
        }
        Item { Layout.fillWidth: true }
        Menu.MenuPill {
          icon: "󰐥"; label: "Off"; fg: Style.orange
          onClicked: { Quickshell.execDetached([root.binDir + "/asahi-nightlight", "toggle"]); root.close() }
        }
      }
    }
  }
}
