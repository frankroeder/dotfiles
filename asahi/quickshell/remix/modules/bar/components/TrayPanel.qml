import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../BarModel.js" as BarModel
import "../../../"
import "../../menu" as Menu

// The tray's overflow surface: every item as a readable row instead of a 20px glyph,
// with the app's own menu on a real target rather than a precise right-click.
// Needs `screen` and `exclusionMode` like Osd.qml, or the layer lands off-screen.
PanelWindow {
  id: root

  property var barHost: null
  // BarHost's one-popup-at-a-time slot.
  readonly property bool shouldShow: !!root.barHost && root.barHost.openPanel === "tray"
  function close() { if (root.shouldShow) root.barHost.openPanel = "" }
  property var trayItems: []
  property var panelScreen: null
  property int barHeight: Style.barHeight

  // The bar this panel opens from (focus-grab whitelist).
  property var barWindow: null
  // App menus open in the bar's TrayMenu below the row's menu button; its grab whitelists this panel, ours pauses
  // until it closes.
  property var trayMenu: null
  property bool menuShown: false
  Connections {
    target: root.trayMenu
    function onMenuClosed() { root.menuShown = false }
  }
  function openMenu(item, button) {
    if (!item.menu || !root.trayMenu) return
    const p = button.mapToItem(null, button.width / 2, button.height)   // window coords; the window hangs at the right
    root.menuShown = true
    root.trayMenu.openFor(item, (root.screen ? root.screen.width : 1920) - Style.barEdgeMargin - root.width + p.x,
      root.barHeight + 6 + p.y + 4, root)
  }

  visible: shouldShow || popOut.running
  onShouldShowChanged: if (shouldShow) { popOut.stop(); popIn.restart() } else popOut.restart()
  color: "transparent"
  // Focusable for the grab below (HyprlandFocusGrab dies on focusable: false).
  focusable: true
  screen: root.panelScreen
  exclusionMode: ExclusionMode.Ignore

  anchors { top: true; right: true }
  margins { top: root.barHeight + 6; right: Style.barEdgeMargin }
  Menu.MenuPopIn { id: popIn; target: card }
  Menu.MenuPopOut { id: popOut; target: card }

  implicitWidth: 320
  implicitHeight: card.implicitHeight

  // Whitelist the bar window too, else the click that opened this counts as outside and closes it.
  // Esc is an app-wide shortcut: the grab may leave keyboard focus on the bar.
  HyprlandFocusGrab {
    windows: [root, root.barWindow]
    active: root.shouldShow && !root.menuShown
    onCleared: root.close()
  }
  Shortcut {
    enabled: root.shouldShow
    sequences: ["Escape"]
    context: Qt.ApplicationShortcut
    onActivated: root.close()
  }

  WlrLayershell.namespace: "quickshell-tray"
  WlrLayershell.layer: WlrLayer.Overlay

  Rectangle {
    id: card
    width: parent.width
    implicitHeight: column.implicitHeight + 12
    radius: Style.menuRadiusLg
    color: Style.m3surfaceSolid
    border.color: Style.popupBorder
    border.width: Style.popupBorderWidth
    transformOrigin: Item.TopRight

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
          color: rowMouse.containsMouse ? Style.m3stateHover : "transparent"
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
              textFormat: Text.PlainText
              text: String(row.modelData.title || row.modelData.id || "")
              elide: Text.ElideRight
              font.family: Style.fontUi; font.features: Style.fontTabular
              font.pixelSize: Style.barFontBody
              color: row.modelData.status === Status.NeedsAttention ? Style.orange : Style.barStripText
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: row.detail
              visible: text !== ""
              elide: Text.ElideRight
              font.family: Style.fontUi; font.features: Style.fontTabular
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
            color: menuMouse.containsMouse ? Style.m3stateHover : "transparent"

            Text {
              anchors.centerIn: parent
              text: "󰇙"
              font.family: Style.fontUi; font.features: Style.fontTabular
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
              else { row.modelData.activate(); root.close() }
            }
          }
        }
      }
    }
  }
}
