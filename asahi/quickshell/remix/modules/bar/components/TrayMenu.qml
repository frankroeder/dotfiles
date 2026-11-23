import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../../"
import "../../menu" as Menu

// An app's tray menu in the shell's own look (idea: caelestia's TrayMenu) instead of the GTK-styled QMenu that
// item.display() / QsMenuAnchor showed: rows on the popup surface, hairline separators, a check mark column, the app's
// icons, submenus opened in place with a Back row (Esc goes back, then closes; three levels deep). One per bar (SystemTray): the inline
// icons and TrayPanel's menu button open it. Its own focus grab whitelists the bar and the panel beneath.
PanelWindow {
  id: root

  property var screenRef: null
  property var barWindow: null
  property var extraWindow: null   // TrayPanel while it stays open beneath
  property real menuX: 0           // screen x the menu centres on
  property real menuY: 0           // screen y of its top edge
  property bool shown: false
  // The item's menu, then each submenu opened in place (Back pops one). One opener per level keeps every parent
  // referenced: re-pointing a single opener released the parent menu, and with it the submenu entry (empty list).
  property var levels: []
  signal menuClosed()

  function openFor(item, x, y, extra) {
    if (!item || !item.menu) return
    root.extraWindow = extra || null
    root.levels = [item.menu]
    root.menuX = x
    root.menuY = y
    root.shown = true
    popIn.restart()
  }
  function close() {
    if (!root.shown) return
    root.shown = false
    root.levels = []
    root.menuClosed()
  }
  function back() { root.levels = root.levels.slice(0, -1) }
  function activate(entry) {
    if (!entry || entry.isSeparator || !entry.enabled) return
    if (entry.hasChildren) { if (root.levels.length < 3) root.levels = root.levels.concat([entry]); return }
    entry.triggered()
    root.close()
  }
  // DBusMenu mnemonics: "_Quit" → "Quit", "__" → "_".
  function label(t) { return String(t || "").replace(/__/g, "\u0001").replace(/_/g, "").replace(/\u0001/g, "_") }

  QsMenuOpener { id: o0; menu: root.levels[0] || null }
  QsMenuOpener { id: o1; menu: root.levels[1] || null }
  QsMenuOpener { id: o2; menu: root.levels[2] || null }
  readonly property var current: root.levels.length > 0 ? [o0, o1, o2][root.levels.length - 1] : null

  visible: root.shown
  screen: root.screenRef
  color: "transparent"
  focusable: true
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; left: true }
  margins {
    top: Math.round(root.menuY)
    left: Math.round(Math.max(8, Math.min((root.screenRef ? root.screenRef.width : 1920) - root.implicitWidth - 8,
      root.menuX - root.implicitWidth / 2)))
  }
  implicitWidth: 260
  implicitHeight: card.implicitHeight
  WlrLayershell.namespace: "quickshell-tray-menu"
  WlrLayershell.layer: WlrLayer.Overlay

  HyprlandFocusGrab {
    windows: root.extraWindow ? [root, root.barWindow, root.extraWindow] : [root, root.barWindow]
    active: root.shown
    onCleared: root.close()
  }
  Shortcut {
    enabled: root.shown
    sequences: ["Escape"]
    context: Qt.ApplicationShortcut
    onActivated: root.levels.length > 1 ? root.back() : root.close()
  }
  Menu.MenuPopIn { id: popIn; target: card }

  Rectangle {
    id: card
    width: parent.width
    implicitHeight: col.implicitHeight + 12
    radius: Style.menuRadiusLg
    color: Style.m3surfaceSolid
    border.color: Style.popupBorder
    border.width: Style.popupBorderWidth
    transformOrigin: Item.Top

    Column {
      id: col
      x: 6; y: 6
      width: parent.width - 12

      component EntryRow: Item {
        id: row
        property string mark: ""
        property string icon: ""
        property string text: ""
        property bool active: true
        property bool sub: false
        signal clicked()
        width: col.width
        height: 30
        Rectangle {
          anchors.fill: parent
          radius: Style.radiusSm
          color: ma.containsMouse && row.active ? Style.m3stateHover : "transparent"
        }
        Text {
          id: markText
          x: 8; width: 16
          anchors.verticalCenter: parent.verticalCenter
          text: row.mark
          color: Style.m3primary
          font.family: Style.fontMono; font.pixelSize: Style.typeBody
        }
        Image {
          id: iconImg
          x: 28; width: 16; height: 16
          anchors.verticalCenter: parent.verticalCenter
          visible: row.icon !== "" && status === Image.Ready
          source: row.icon
          sourceSize: Qt.size(32, 32)
          fillMode: Image.PreserveAspectFit
        }
        Text {
          anchors.left: iconImg.visible ? iconImg.right : markText.right
          anchors.leftMargin: iconImg.visible ? 8 : 4
          anchors.right: chevron.left
          anchors.verticalCenter: parent.verticalCenter
          text: row.text
          textFormat: Text.PlainText   // app strings
          elide: Text.ElideRight
          color: row.active ? Style.m3onSurface : Style.m3onSurfaceVariant
          opacity: row.active ? 1 : 0.6
          font.family: Style.fontUi; font.pixelSize: Style.typeLead
        }
        Text {
          id: chevron
          anchors.right: parent.right; anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: row.sub ? "󰅂" : ""
          color: Style.m3onSurfaceVariant
          font.family: Style.fontMono; font.pixelSize: Style.typeBody
        }
        MouseArea {
          id: ma
          anchors.fill: parent
          hoverEnabled: true
          enabled: row.active
          cursorShape: Qt.PointingHandCursor
          onClicked: row.clicked()
        }
      }

      EntryRow { visible: root.levels.length > 1; mark: "󰁍"; text: "Back"; onClicked: root.back() }

      Repeater {
        model: root.current ? root.current.children : []
        delegate: Item {
          id: entry
          required property var modelData
          width: col.width
          height: entry.modelData.isSeparator ? 9 : entryRow.height
          Rectangle {
            visible: entry.modelData.isSeparator
            anchors.verticalCenter: parent.verticalCenter
            x: 8; width: parent.width - 16; height: 1
            color: Style.menuHairline
          }
          EntryRow {
            id: entryRow
            visible: !entry.modelData.isSeparator
            mark: entry.modelData.checkState === Qt.Checked ? "󰄬" : ""
            icon: entry.modelData.icon || ""
            text: root.label(entry.modelData.text)
            active: entry.modelData.enabled
            sub: entry.modelData.hasChildren
            onClicked: root.activate(entry.modelData)
          }
        }
      }
    }
  }
}
