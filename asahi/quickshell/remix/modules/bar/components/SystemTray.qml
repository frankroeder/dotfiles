import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "../../../"

// Flat system tray for the solid strip — no capsule chrome.
Item {
  id: root
  implicitWidth: trayRow.implicitWidth
  implicitHeight: Style.barHeight
  visible: trayRow.implicitWidth > 0

  RowLayout {
    id: trayRow
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Repeater {
      model: SystemTray.items

      delegate: Item {
        Layout.preferredWidth: Style.barIconSlot - 4
        Layout.preferredHeight: Style.barHeight

        Rectangle {
          anchors.fill: parent
          anchors.topMargin: Style.barChipInset
          anchors.bottomMargin: Style.barChipInset
          radius: Style.radiusSm
          color: trayMouse.containsMouse ? Style.barStripHover : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }
        }

        Image {
          anchors.centerIn: parent
          width: 18
          height: 18
          source: {
            const icon = modelData.icon ?? ""
            if (typeof icon === "string" && icon.includes("?path=")) {
              const parts = icon.split("?path=")
              const name = parts[0]
              const base = parts[1] ?? ""
              const fileName = name.slice(name.lastIndexOf("/") + 1)
              return Qt.resolvedUrl(`${base}/${fileName}`)
            }
            return icon
          }
          visible: status === Image.Ready
          fillMode: Image.PreserveAspectFit
          smooth: true
        }

        MouseArea {
          id: trayMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          hoverEnabled: true

          onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
              modelData.activate()
            } else if (mouse.button === Qt.RightButton) {
              if (modelData.menu) modelData.menu.open()
            }
          }
        }
      }
    }
  }
}
