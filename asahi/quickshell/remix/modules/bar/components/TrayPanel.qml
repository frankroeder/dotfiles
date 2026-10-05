import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../BarModel.js" as BarModel
import "../../../"

// The tray's overflow surface: every item as a readable row instead of a 20px glyph,
// with the app's own menu on a real target rather than a precise right-click.
// Needs `screen` and `exclusionMode` like Osd.qml, or the layer lands off-screen.
PanelWindow {
  id: root

  property bool shouldShow: false
  property var trayItems: []
  property var panelScreen: null
  property int barHeight: Style.barHeight

  // The bar this panel opens from (focus-grab whitelist).
  property var barWindow: null
  // App menus take their own grab: drop ours while one is open (QsMenuAnchor reports the close;
  // item.display() does not).
  property bool menuShown: false
  QsMenuAnchor {
    id: menuAnchor
    anchor.window: root
    onClosed: root.menuShown = false
  }
  // Below the row's menu button, in window coordinates (the rows sit inside card and list).
  function openMenu(item, button) {
    if (!item.menu) return
    const p = button.mapToItem(null, 0, button.height)
    root.menuShown = true
    menuAnchor.menu = item.menu
    menuAnchor.anchor.rect.x = p.x
    menuAnchor.anchor.rect.y = p.y
    menuAnchor.open()
  }

  visible: shouldShow
  color: "transparent"
  // Focusable for the grab below (HyprlandFocusGrab dies on focusable: false).
  focusable: true
  screen: root.panelScreen
  exclusionMode: ExclusionMode.Ignore

  anchors { top: true; right: true }
  margins { top: root.barHeight + 6; right: 12 }

  implicitWidth: 320
  implicitHeight: card.implicitHeight

  // Whitelist the bar window too, else the click that opened this counts as outside and closes it.
  // Esc is an app-wide shortcut: the grab may leave keyboard focus on the bar.
  HyprlandFocusGrab {
    windows: [root, root.barWindow]
    active: root.visible && !root.menuShown
    onCleared: root.shouldShow = false
  }
  Shortcut {
    enabled: root.visible
    sequences: ["Escape"]
    context: Qt.ApplicationShortcut
    onActivated: root.shouldShow = false
  }

  WlrLayershell.namespace: "quickshell-tray"
  WlrLayershell.layer: WlrLayer.Overlay

  Rectangle {
    id: card
    width: parent.width
    implicitHeight: column.implicitHeight + 12
    radius: Style.menuRadiusLg
    color: Style.menuBg
    border.width: 1
    border.color: Style.menuSep
    opacity: root.shouldShow ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }

    Column {
      id: column
      width: parent.width
      padding: 6
      spacing: 2

      Repeater {
        model: root.trayItems

        delegate: Rectangle {
          id: row
          required property var modelData
          width: column.width - 12
          height: 42
          radius: Style.radiusSm
          color: rowMouse.containsMouse ? Style.barStripHover : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }

          readonly property string detail: BarModel.trayDetail(row.modelData.title, row.modelData.tooltipTitle)

          Image {
            id: rowIcon
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            source: BarModel.trayIcon(row.modelData.icon)
            fillMode: Image.PreserveAspectFit
            smooth: true
          }

          Column {
            anchors.left: rowIcon.right
            anchors.leftMargin: 10
            anchors.right: menuButton.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
              width: parent.width
              text: String(row.modelData.title || row.modelData.id || "")
              elide: Text.ElideRight
              font.family: Style.fontFamily
              font.pixelSize: Style.barFontBody
              color: row.modelData.status === SystemTrayItem.NeedsAttention ? Style.orange : Style.barStripText
            }

            Text {
              width: parent.width
              text: row.detail
              visible: text !== ""
              elide: Text.ElideRight
              font.family: Style.fontFamily
              font.pixelSize: Style.barFontCaption
              color: Style.textMuted
            }
          }

          Rectangle {
            id: menuButton
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: Style.radiusSm
            visible: row.modelData.hasMenu
            color: menuMouse.containsMouse ? Style.barHoverBg : "transparent"

            Text {
              anchors.centerIn: parent
              text: "󰇙"
              font.family: Style.fontFamily
              font.pixelSize: Style.barFontBody
              color: Style.textMuted
            }

            MouseArea {
              id: menuMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openMenu(row.modelData, menuButton)
            }
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            anchors.rightMargin: 34
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              // A menu is a child of this panel: hiding it here would close the menu with it.
              if (row.modelData.onlyMenu) root.openMenu(row.modelData, menuButton)
              else { row.modelData.activate(); root.shouldShow = false }
            }
          }
        }
      }
    }
  }
}
