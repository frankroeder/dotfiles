import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../"

// Launchpad-style app grid (Super+Alt+Space; omarchy's shell/plugins/dock/AppGrid.qml): every app on one grid, A–Z.
// Typing filters (name start, then word start, then anywhere), arrows + Enter or a click launch, Esc clears the filter,
// then closes; a click on the scrim closes. Apps, hidden ids (launcher.hides), icons and launching (workspace,
// uwsm-app, usage count) are the launcher's.
Scope {
  id: root

  property var launcher: null
  property bool shown: false
  property var screen: null
  property string query: ""

  function toggle() {
    if (root.shown) { root.shown = false; return }
    const l = root.launcher
    if (l && l.shouldShow) l.closeLauncher()
    if (l) l.launcherWorkspaceId = Hyprland.focusedWorkspace?.id ?? 1
    const mon = Hyprland.focusedMonitor
    root.screen = (mon && Quickshell.screens.find(s => s.name === mon.name)) || Quickshell.screens[0]
    root.query = ""
    root.shown = true
  }
  function launch(entry) {
    if (!entry || !root.launcher) return
    root.shown = false
    root.launcher.launchDesktopEntry(entry)
  }

  readonly property var apps: {
    const l = root.launcher
    if (!root.shown || !l) return []
    const _ = l.hiddenVersion
    const q = root.query.trim().toLowerCase()
    const rank = d => {
      const n = String(d.name || "").toLowerCase()
      if (!q) return 1
      if (n.startsWith(q)) return 1
      if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 2
      if (n.includes(q) || String(d.genericName || "").toLowerCase().includes(q)) return 3
      return 0
    }
    return (DesktopEntries.applications.values || [])
      .filter(d => !d.noDisplay && !l.isHiddenApp(d))
      .map(d => ({ d: d, r: rank(d) }))
      .filter(x => x.r > 0)
      .sort((a, b) => a.r - b.r || String(a.d.name).localeCompare(String(b.d.name)))
      .map(x => x.d)
  }

  PanelWindow {
    id: win
    visible: root.shown
    screen: root.screen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-appgrid"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { left: true; right: true; top: true; bottom: true }
    onVisibleChanged: if (visible) { search.text = ""; grid.currentIndex = 0; search.forceActiveFocus() }

    Rectangle {
      anchors.fill: parent
      color: Style.menuDim
      MouseArea { anchors.fill: parent; onClicked: root.shown = false }
    }

    Rectangle {
      id: card
      readonly property int cols: Math.max(3, Math.min(7, Math.floor((win.width - 160) / grid.cellWidth)))
      width: cols * grid.cellWidth + 40
      height: Math.min(win.height - 160, 92 + 4 * grid.cellHeight)
      anchors.centerIn: parent
      radius: 18
      color: Style.m3surface
      border.color: Style.popupBorder
      border.width: Style.popupBorderWidth
      MouseArea { anchors.fill: parent }   // a click on the card is no click on the scrim

      Text {
        id: glyph
        x: 24; y: 22
        text: "󰍉"
        font.family: Style.menuMono
        font.pixelSize: 20
        color: Style.m3onSurfaceVariant
      }
      TextInput {
        id: search
        anchors { left: glyph.right; leftMargin: 10; right: parent.right; rightMargin: 24; verticalCenter: glyph.verticalCenter }
        font.family: Style.menuSans
        font.pixelSize: 18
        color: Style.m3onSurface
        selectionColor: Style.m3primaryContainer
        clip: true
        onTextChanged: { root.query = text; grid.currentIndex = 0 }
        Keys.onPressed: (event) => {
          if (event.key === Qt.Key_Escape) {
            if (search.text) search.text = ""
            else root.shown = false
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.launch(root.apps[grid.currentIndex])
          } else if (event.key === Qt.Key_Left) grid.moveCurrentIndexLeft()
          else if (event.key === Qt.Key_Right) grid.moveCurrentIndexRight()
          else if (event.key === Qt.Key_Up) grid.moveCurrentIndexUp()
          else if (event.key === Qt.Key_Down) grid.moveCurrentIndexDown()
          else return
          event.accepted = true
        }
        Text {
          visible: !search.text
          text: "Search " + root.apps.length + " apps"
          font: search.font
          color: Style.m3onSurfaceVariant
        }
      }

      GridView {
        id: grid
        anchors { fill: parent; topMargin: 64; leftMargin: 20; rightMargin: 20; bottomMargin: 16 }
        cellWidth: 132
        cellHeight: 124
        clip: true
        model: root.apps
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        highlight: Rectangle { radius: 14; color: Style.m3primaryContainer }

        delegate: Item {
          id: cell
          required property var modelData
          required property int index
          width: grid.cellWidth
          height: grid.cellHeight

          Image {
            id: icon
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 12 }
            width: 56; height: 56
            sourceSize: Qt.size(112, 112)
            source: root.launcher ? root.launcher.resolveIconUrl(cell.modelData.icon) : ""
            asynchronous: true
            fillMode: Image.PreserveAspectFit
          }
          Rectangle {   // no icon: the name's first letter
            visible: icon.status !== Image.Ready
            anchors.fill: icon
            radius: 14
            color: Style.m3container
            Text {
              anchors.centerIn: parent
              text: String(cell.modelData.name || "?").charAt(0).toUpperCase()
              font.family: Style.menuSans
              font.pixelSize: 26
              color: Style.m3onSurface
            }
          }
          Text {
            anchors { top: icon.bottom; topMargin: 8; horizontalCenter: parent.horizontalCenter }
            width: grid.cellWidth - 16
            text: cell.modelData.name || ""
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.family: Style.menuSans
            font.pixelSize: 13
            color: Style.m3onSurface
          }
          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: grid.currentIndex = cell.index
            onClicked: root.launch(cell.modelData)
          }
        }
      }
    }
  }
}
