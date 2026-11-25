import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../"
import "../../menu" as Menu
import "../BarModel.js" as BarModel
import "../../../services" as Services

// Recorder chip popup (caelestia utilities Record card): start modes when
// idle, stop with the running clock and file size while recording, and the
// most recent recordings underneath. (No pause: wf-recorder has none here.)
PopupWindow {
  id: root

  property var barHost: null
  property bool panelOpen: false
  property string confirmDelete: ""
  readonly property bool rec: Services.Recorder.running

  visible: root.panelOpen || popOut.running
  onPanelOpenChanged: if (root.panelOpen) { popOut.stop(); popIn.restart() } else popOut.restart()
  color: "transparent"
  anchor.edges: Edges.Bottom
  anchor.margins.bottom: -BarModel.popupDrop(root.barHost ? root.barHost.height : Style.barHeight, Style.barHeight)  // negative = below
  implicitWidth: 380
  implicitHeight: col.implicitHeight + 2 * Style.popupPad

  onVisibleChanged: {
    if (visible) { Services.Recorder.refresh(); Services.Recorder.scanRecent() }
    else root.confirmDelete = ""
  }

  function close() {
    if (root.barHost && root.barHost.openPanel === "rec") root.barHost.openPanel = ""
  }
  // A take starts once the card has left (MenuPopOut): started at once, the screen take's first frames caught the
  // fading card, and a second click on the leaving tile stopped the take it had just started (the card takes no
  // input while it leaves: `enabled` below).
  property var pendingTake: null
  function startAfterClose(mode, cam) {
    root.pendingTake = { mode: mode, cam: cam }
    root.close()
    takeDelay.restart()
  }
  Timer {
    id: takeDelay
    interval: Style.menuExitMs + 150
    onTriggered: {
      const t = root.pendingTake
      root.pendingTake = null
      if (t) Services.Recorder.start(t.mode, t.cam)
    }
  }

  // Whitelist the bar window too, else the click that opened this counts as outside and closes it.
  // Esc is an app-wide shortcut: the grab may leave keyboard focus on the bar.
  // Armed once the popup is mapped: armed at show time its surface was not whitelisted yet, and every
  // click inside closed it (no button in a bar popup worked).
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

  // Mode tile: glyph tile + label on the container tone, like the launcher pane cards; the shared press layer,
  // give and ripple (MenuPill).
  component ModeTile: Rectangle {
    id: tile
    property string icon
    property string label
    property color tint: Style.m3primary
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: 54
    radius: Style.menuRadiusLg
    color: ma.containsMouse ? Style.m3containerHigh : Style.m3container
    Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
    scale: ma.pressed && !Style.reduceMotion ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Style.menuStateMs; easing.type: Easing.OutCubic } }
    Rectangle { anchors.fill: parent; radius: parent.radius; color: Style.m3statePress; visible: ma.pressed }
    Menu.MenuRipple { id: tileRipple; radius: tile.radius }
    Row {
      anchors.left: parent.left
      anchors.leftMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10
      Rectangle {
        width: 38; height: 38; radius: Style.menuRadiusMd
        color: Qt.alpha(tint, 0.16)
        Text { anchors.centerIn: parent; text: icon; color: tint; font.family: Style.menuMono; font.pixelSize: 22 }
      }
      Text { text: label; color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: Style.typeTitle; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea {
      id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
      onPressed: mouse => tileRipple.start(mouse.x, mouse.y)
      onReleased: tileRipple.release()
      onCanceled: tileRipple.release()
      onClicked: tile.clicked()
    }
  }

  component Caption: Menu.MenuCaption {}

  component RoundBtn: Menu.MenuIconBtn { implicitWidth: 44; implicitHeight: 44; iconPx: 20; bg: Style.m3secondaryContainer }
  component IconBtn: Menu.MenuIconBtn { iconPx: 18; hot: Style.m3onSurface }

  Menu.MenuPopIn { id: popIn; target: card }
  Menu.MenuPopOut { id: popOut; target: card }

  Rectangle {
    id: card
    anchors.fill: parent
    enabled: root.panelOpen   // no clicks while it leaves
    transformOrigin: Item.Top
    color: Style.m3surfaceSolid
    radius: Style.menuRadiusLg
    border.color: Style.popupBorder
    border.width: Style.popupBorderWidth

    ColumnLayout {
      id: col
      anchors.fill: parent
      anchors.margins: Style.popupPad
      spacing: Style.popupGap

      // Header: glyph tile, title, state.
      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        // Recording: the tile turns solid red (the signal the old 44 px tile gave).
        Menu.MenuGlyphTile { glyph: "󰑊"; tint: root.rec ? Style.m3onPrimary : Style.red; color: root.rec ? Style.red : Qt.alpha(Style.red, 0.18) }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Text { Layout.fillWidth: true; text: "Screen recorder"; color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: Style.typeTitle; font.weight: Font.DemiBold }
          Text {
            text: root.rec ? "Recording…" : "Ready · saves to ~/Videos"
            color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: Style.typeBody
          }
        }
        Text {
          visible: root.rec
          text: Services.Recorder.fmtElapsed(Services.Recorder.elapsed)
          color: Style.red
          font.family: Style.menuSans; font.features: Style.fontTabular; font.pixelSize: Style.typeDisplay; font.weight: Font.DemiBold
          font.variableAxes: Style.opsz(Style.typeDisplay)
        }
        // Always-present close affordance: the bar chip that opens this panel can
        // disappear out from under it (e.g. recording stops), so closing must not
        // depend on clicking back on the chip.
        IconBtn { icon: "󰅖"; iconPx: 22; implicitWidth: 34; implicitHeight: 34; onClicked: root.close() }
      }

      // Running: file + size, pause / stop.
      Rectangle {
        visible: root.rec
        Layout.fillWidth: true
        implicitHeight: runRow.implicitHeight + 24
        radius: Style.menuRadiusLg
        color: Style.m3container
        RowLayout {
          id: runRow
          anchors.fill: parent
          anchors.margins: 12
          spacing: 12
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
              Layout.fillWidth: true
              textFormat: Text.PlainText
              text: (Services.Recorder.file || "").split("/").pop() || "…"
              color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: Style.typeLead; font.weight: Font.Medium; elide: Text.ElideMiddle
            }
            Text {
              text: Services.Recorder.fmtBytes(Services.Recorder.bytes) + ((Services.Recorder.file || "").endsWith("-camera.mp4") ? "  ·  camera" : "  ·  wf-recorder")
              color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: Style.typeBody
            }
          }
          RoundBtn { icon: "󰓛"; bg: Style.red; tone: Style.m3onPrimary; onClicked: Services.Recorder.stop() }
        }
      }

      // Idle: start modes.
      GridLayout {
        visible: !root.rec
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        ModeTile { icon: "󰍹"; label: "Display"; onClicked: root.startAfterClose("fullscreen", false) }
        ModeTile { icon: "󰩬"; label: "Region"; onClicked: root.startAfterClose("region", false) }
        ModeTile { icon: "󰄀"; label: "Display + cam"; tint: Style.m3tertiary; onClicked: root.startAfterClose("fullscreen", true) }
        ModeTile { icon: "󰄀"; label: "Region + cam"; tint: Style.m3tertiary; onClicked: root.startAfterClose("region", true) }
        ModeTile { Layout.columnSpan: 2; icon: "󰄀"; label: "Camera only"; tint: Style.m3secondary; onClicked: root.startAfterClose("camera", false) }
      }

      // Idle: screen takes' audio (one device: wf-recorder). Webcam and camera-only takes always record the mic.
      RowLayout {
        visible: !root.rec
        Layout.fillWidth: true
        Caption { text: "Screen audio" }
        Item { Layout.fillWidth: true }
        Menu.MenuSegmented {
          readonly property var keys: ["system", "mic", "none"]
          model: [{ icon: "󰕾", label: "System" }, { icon: "󰍬", label: "Mic" }, { icon: "󰖁", label: "Silent" }]
          current: keys.indexOf(Services.Recorder.audio)
          onActivated: index => Services.Recorder.setAudio(keys[index])
        }
      }

      // Recent recordings, in one container card like the launcher lists.
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        Caption { text: "Recent" }
        Item { Layout.fillWidth: true }
        IconBtn { icon: "󰉋"; onClicked: { root.close(); Services.Recorder.revealFolder() } }
      }
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: recentCol.implicitHeight + 12
        radius: Style.menuRadiusLg
        color: Style.m3container
        ColumnLayout {
          id: recentCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 6
          spacing: 2
          Menu.MenuEmptyState {
            visible: (Services.Recorder.recent || []).length === 0
            Layout.margins: 6
            quiet: true
            glyph: "󰕧"
            title: "No recordings yet"
          }
          Repeater {
            model: Services.Recorder.recent
            delegate: Rectangle {
              required property var modelData
              readonly property bool armed: root.confirmDelete === modelData.path
              Layout.fillWidth: true
              implicitHeight: 44
              radius: Style.menuRadiusMd
              color: rowMa.containsMouse ? Style.m3stateHover : "transparent"
              MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.close(); Services.Recorder.open(modelData.path) } }
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6; anchors.rightMargin: 6
                spacing: 10
                Rectangle {
                  width: 32; height: 32; radius: Style.menuRadiusMd
                  color: Style.m3primaryContainer
                  Text { anchors.centerIn: parent; text: "󰕧"; color: Style.m3primary; font.family: Style.menuMono; font.pixelSize: 18 }
                }
                Text {
                  Layout.fillWidth: true; textFormat: Text.PlainText; text: modelData.label
                  color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: Style.typeLead; elide: Text.ElideMiddle
                }
                Text { text: Services.Recorder.fmtBytes(modelData.bytes); color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: Style.typeBody }
                IconBtn {
                  icon: armed ? "󰆴" : "󰩹"
                  tone: armed ? Style.red : Style.m3onSurfaceVariant
                  onClicked: {
                    if (armed) { Services.Recorder.remove(modelData.path); root.confirmDelete = "" }
                    else root.confirmDelete = modelData.path
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
