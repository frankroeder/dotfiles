import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../"
import "../menu" as Menu
import "../../services" as Services

// Short now-playing card on a track change (idea: mel-edo Island showMediaPopup): cover, title and artist for 4 s, where
// the OSD sits, on the focused screen. Once per track, only while playing; not in the first 5 s after start, not while
// the launcher is open (its Media pane shows it), not over a fullscreen window. Click hides it.
// Off / on: Launcher › Actions › "Now-playing card" (~/.local/state/asahi/now-playing-card, "off" = off).
Scope {
  id: root

  property bool suppressed: false   // shell: the launcher is open
  property bool enabled: true
  property bool shown: false
  property var cardScreen: null
  property string lastKey: ""
  property bool settled: false
  Timer { interval: 5000; running: true; onTriggered: { root.settled = true; root.lastKey = Services.Players.trackKey } }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/asahi/now-playing-card"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.enabled = text().trim() !== "off"
    onLoadFailed: root.enabled = true
  }

  // Metadata lands in pieces (title, then artist and art): wait for it to settle.
  Connections {
    target: Services.Players
    function onTrackKeyChanged() { settle.restart() }
  }
  Timer { id: settle; interval: 700; onTriggered: root.maybeShow() }

  function fullscreenFocused() {
    const c = (Services.BarData.hyprClients || []).find(w => w.focusHistoryID === 0)
    return !!c && (c.fullscreen || 0) > 0
  }
  function maybeShow() {
    const k = Services.Players.trackKey
    if (!root.settled || !k || k === root.lastKey) return
    root.lastKey = k
    if (!root.enabled || root.suppressed || !Services.Players.isPlaying || !Services.Players.title || root.fullscreenFocused()) return
    const mon = Hyprland.focusedMonitor
    root.cardScreen = (mon && Quickshell.screens.find(s => s.name === mon.name)) || Quickshell.screens[0]
    root.shown = true
    hide.restart()
  }
  Timer { id: hide; interval: 4000; onTriggered: root.shown = false }
  onSuppressedChanged: if (root.suppressed) root.shown = false
  // Entry / exit follow `shown` (like the bar popups): restarted from the window's own onVisibleChanged, the pop-in
  // re-entered its visible binding and the card stayed up for good.
  onShownChanged: if (root.shown) { popOut.stop(); popIn.restart() } else popOut.restart()

  PanelWindow {
    visible: root.shown || popOut.running
    screen: root.cardScreen
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-nowplaying"
    anchors { bottom: true }
    margins { bottom: 90 }
    implicitWidth: 360
    implicitHeight: 84
    Menu.MenuPopIn { id: popIn; target: card }
    Menu.MenuPopOut { id: popOut; target: card }

    Rectangle {
      id: card
      anchors.fill: parent
      transformOrigin: Item.Bottom
      radius: Style.menuRadiusLg
      color: Style.m3surfaceSolid
      border.color: Style.popupBorder
      border.width: Style.popupBorderWidth
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.shown = false }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        ClippingRectangle {
          Layout.preferredWidth: 58; Layout.preferredHeight: 58
          radius: Style.menuRadiusMd
          color: Style.m3containerHigh
          Image {
            anchors.fill: parent
            source: Services.Players.artUrl
            visible: status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(128, 128)
            asynchronous: true
          }
          Text {
            anchors.centerIn: parent
            visible: Services.Players.artUrl === ""
            text: "󰝚"; color: Style.m3primary; font.family: Style.fontMono; font.pixelSize: 26
          }
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: "Now playing · " + Services.Players.name(Services.Players.active)
            color: Style.m3primary
            font.family: Style.menuSans; font.pixelSize: Style.typeCaption; font.weight: Font.DemiBold
            elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: Services.Players.title
            color: Style.m3onSurface
            font.family: Style.menuSans; font.pixelSize: Style.typeTitle; font.weight: Font.DemiBold
            elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            visible: text !== ""
            textFormat: Text.PlainText
            text: Services.Players.artist
            color: Style.m3onSurfaceVariant
            font.family: Style.menuSans; font.pixelSize: Style.typeBody
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}
