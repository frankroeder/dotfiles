import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../"
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

  // The keybind/IPC toggle is one flag shared by every screen's panel (there's
  // no per-screen state to target); restrict it to the currently focused
  // monitor, same trick as Clock.qml's calendar dropdown.
  readonly property bool sameScreen: {
    const mon = Hyprland.focusedMonitor
    const scr = root.barHost ? root.barHost.barScreen : null
    if (!mon || !scr) return true
    return mon.name === scr.name
  }

  visible: root.panelOpen || (Services.Recorder.panelOpen && root.sameScreen)
  color: "transparent"
  anchor.edges: Edges.Bottom
  anchor.margins.bottom: -BarModel.popupDrop(root.barHost ? root.barHost.height : Style.barHeight, Style.barHeight)  // negative = below
  implicitWidth: 380
  implicitHeight: col.implicitHeight + 32

  onVisibleChanged: {
    if (visible) { Services.Recorder.refresh(); Services.Recorder.scanRecent() }
    else root.confirmDelete = ""
  }

  function close() {
    if (root.barHost) root.barHost.recPanelOpen = false
    Services.Recorder.panelOpen = false
  }

  // Keybind / quick-menu opens have no click to swallow, so grab the keyboard
  // there: Esc closes the panel instead of reaching the app underneath.
  HyprlandFocusGrab {
    windows: [root]
    active: root.visible && !root.panelOpen
    onCleared: root.close()
  }

  Shortcut {
    enabled: root.visible
    sequences: ["Escape"]
    onActivated: root.close()
  }

  // Mode tile: glyph tile + label on the container tone, like the launcher pane cards.
  component ModeTile: Rectangle {
    property string icon
    property string label
    property color tint: Style.m3primary
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: 54
    radius: Style.menuRadiusLg
    color: ma.containsMouse ? Style.m3containerHigh : Style.m3container
    Behavior on color { ColorAnimation { duration: 120 } }
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
      Text { text: label; color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: 13; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }

  // Same small tracked caps as SysPanel's section titles.
  component Caption: Text {
    color: Style.menuInkDeep
    font.family: Style.menuSans
    font.pixelSize: 10
    font.weight: Font.DemiBold
    font.letterSpacing: 1.2
    font.capitalization: Font.AllUppercase
  }

  component RoundBtn: Rectangle {
    property string icon
    property color bg: Style.m3secondaryContainer
    property color fg: Style.m3onSurface
    signal clicked()
    width: 44; height: 44; radius: 22
    color: rma.containsMouse ? Qt.lighter(bg, 1.15) : bg
    Behavior on color { ColorAnimation { duration: 120 } }
    Text { anchors.centerIn: parent; text: icon; color: fg; font.family: Style.fontFamily; font.pixelSize: 20 }
    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }

  component IconBtn: Text {
    property color tone: Style.m3onSurfaceVariant
    signal clicked()
    color: ima.containsMouse ? Style.m3onSurface : tone
    font.family: Style.menuMono
    font.pixelSize: 18
    leftPadding: 4; rightPadding: 4
    MouseArea { id: ima; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }

  Rectangle {
    anchors.fill: parent
    color: Style.m3surfaceSolid
    radius: Style.menuRadiusLg

    ColumnLayout {
      id: col
      anchors.fill: parent
      anchors.margins: 16
      spacing: 12

      // Header: icon pill, title, state.
      RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Rectangle {
          width: 44; height: 44; radius: Style.menuRadiusMd
          color: root.rec ? Style.red : Qt.alpha(Style.red, 0.16)
          Behavior on color { ColorAnimation { duration: 160 } }
          Text { anchors.centerIn: parent; text: "󰑊"; color: root.rec ? Style.m3onPrimary : Style.red; font.family: Style.menuMono; font.pixelSize: 26 }
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1
          Text { Layout.fillWidth: true; text: "Screen recorder"; color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: 14; font.weight: Font.DemiBold }
          Text {
            text: root.rec ? "Recording…" : "Ready · saves to ~/Videos"
            color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: 11
          }
        }
        Text {
          visible: root.rec
          text: Services.Recorder.fmtElapsed(Services.Recorder.elapsed)
          color: Style.red
          font.family: Style.menuSans; font.pixelSize: 22; font.weight: Font.DemiBold
        }
        // Always-present close affordance: the bar chip that opens this panel can
        // disappear out from under it (e.g. recording stops), so closing must not
        // depend on clicking back on the chip.
        IconBtn { text: "󰅖"; font.pixelSize: 22; onClicked: root.close() }
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
              text: (Services.Recorder.file || "").split("/").pop() || "…"
              color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: 12; font.weight: Font.Medium; elide: Text.ElideMiddle
            }
            Text {
              text: Services.Recorder.fmtBytes(Services.Recorder.bytes) + "  ·  wf-recorder"
              color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: 11
            }
          }
          RoundBtn { icon: "󰓛"; bg: Style.red; fg: Style.m3onPrimary; onClicked: Services.Recorder.stop() }
        }
      }

      // Idle: start modes.
      GridLayout {
        visible: !root.rec
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        ModeTile { icon: "󰍹"; label: "Display"; onClicked: { root.close(); Services.Recorder.start("fullscreen", false) } }
        ModeTile { icon: "󰩬"; label: "Region"; onClicked: { root.close(); Services.Recorder.start("region", false) } }
        ModeTile { icon: "󰄀"; label: "Display + cam"; tint: Style.m3tertiary; onClicked: { root.close(); Services.Recorder.start("fullscreen", true) } }
        ModeTile { icon: "󰄀"; label: "Region + cam"; tint: Style.m3tertiary; onClicked: { root.close(); Services.Recorder.start("region", true) } }
      }

      // Recent recordings, in one container card like the launcher lists.
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        Caption { text: "Recent" }
        Item { Layout.fillWidth: true }
        IconBtn { text: "󰉋"; onClicked: { root.close(); Services.Recorder.revealFolder() } }
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
          Text {
            visible: (Services.Recorder.recent || []).length === 0
            Layout.fillWidth: true
            Layout.margins: 8
            text: "No recordings yet"
            color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: 11
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
                Text { Layout.fillWidth: true; text: modelData.label; color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: 12; elide: Text.ElideMiddle }
                Text { text: Services.Recorder.fmtBytes(modelData.bytes); color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: 11 }
                IconBtn {
                  text: armed ? "󰆴" : "󰩹"
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
