import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../BarModel.js" as BarModel
import "../../../"

// System tray with a capped width. Any app can add a tray icon, and on the notched
// panel a growing tray reflows the strip into the camera — so the bar shows at most
// `maxInline` icons and puts the rest behind a "+N" pill that opens TrayPanel
// downward (space beside the cutout is scarce, space under the bar is free).
// With 1-3 items there is no extra chrome at all.
Item {
  id: root

  property int maxInline: 3
  property int barHeight: Style.barHeight
  property var trayScreen: null

  readonly property var items: SystemTray.items.values
  readonly property int overflowCount: Math.max(0, root.items.length - root.maxInline)
  readonly property bool attention: root.items.some(i => i.status === SystemTrayItem.NeedsAttention)

  implicitWidth: strip.implicitWidth
  implicitHeight: Style.barHeight
  visible: root.items.length > 0

  Row {
    id: strip
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Repeater {
      model: root.items.slice(0, root.maxInline)

      delegate: Item {
        id: slot
        required property var modelData
        width: Style.barIconSlot - 4
        height: Style.barHeight

        readonly property bool needsAttention: slot.modelData.status === SystemTrayItem.NeedsAttention

        // Pops in place; omarchy's drawer slides the whole strip sideways instead.
        ParallelAnimation {
          running: true
          NumberAnimation { target: slot; property: "opacity"; from: 0; to: 1; duration: 180 }
          NumberAnimation { target: slot; property: "scale"; from: 0.5; to: 1; duration: 180; easing.type: Easing.OutBack }
        }

        HoverTint { lit: iconMouse.containsMouse }

        Image {
          id: iconImage
          anchors.centerIn: parent
          width: 20
          height: 20
          source: BarModel.trayIcon(slot.modelData.icon)
          visible: status === Image.Ready
          fillMode: Image.PreserveAspectFit
          smooth: true
        }

        // Here the icon is the only identifier, so a broken one falls back to an initial.
        Text {
          anchors.centerIn: parent
          visible: iconImage.status !== Image.Ready
          text: String(slot.modelData.title || slot.modelData.id || "?").charAt(0).toUpperCase()
          font.family: Style.fontFamily
          font.pixelSize: Style.barFontBody
          color: Style.textMuted
        }

        // SNI's NeedsAttention, which the bar used to discard. A dot, not a colour wash
        // over the app's own icon. Static: a pulse redraws the bar every frame.
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.barChipInset
          width: 4
          height: 4
          radius: 2
          color: Style.orange
          visible: slot.needsAttention
        }

        MouseArea {
          id: iconMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          hoverEnabled: true

          onClicked: (mouse) => {
            // display() wants window coordinates; slot.x is relative to the strip.
            if (mouse.button === Qt.RightButton || slot.modelData.onlyMenu)
              slot.modelData.display(root.QsWindow.window, slot.mapToItem(null, slot.width / 2, 0).x, root.barHeight)
            else if (mouse.button === Qt.MiddleButton)
              slot.modelData.secondaryActivate()
            else
              slot.modelData.activate()
          }
        }

        // The tray's only text: which app an icon belongs to.
        TooltipWindow {
          target: slot
          text: String(slot.modelData.tooltipTitle || slot.modelData.title || "")
          show: iconMouse.containsMouse
        }
      }
    }

    // A count, not a chevron: it says how many are hidden, and it only exists when
    // there is something to hide.
    Rectangle {
      width: overflowText.implicitWidth + 10
      height: Style.barHeight - 2 * Style.barChipInset
      anchors.verticalCenter: parent.verticalCenter
      radius: height / 2
      // Stay visible while the panel is open: overflow can drop to 0 meanwhile, and this chip closes it.
      visible: root.overflowCount > 0 || trayPanel.shouldShow
      color: (overflowMouse.containsMouse || trayPanel.shouldShow) ? Style.barStripHover : "transparent"
      border.width: 1
      border.color: root.attention ? Style.orange : Style.barBorder
      Behavior on color { ColorAnimation { duration: 120 } }

      Text {
        id: overflowText
        anchors.centerIn: parent
        text: "+" + root.overflowCount
        font.family: Style.fontFamily
        font.pixelSize: Style.barFontCaption
        color: root.attention ? Style.orange : Style.textMuted
      }

      MouseArea {
        id: overflowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: trayPanel.shouldShow = !trayPanel.shouldShow
      }
    }
  }

  TrayPanel {
    id: trayPanel
    trayItems: root.items
    panelScreen: root.trayScreen
    barWindow: root.QsWindow.window
    barHeight: root.barHeight
  }
}
