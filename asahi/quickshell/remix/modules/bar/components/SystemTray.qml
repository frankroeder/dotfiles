import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "../../../"

// Improved SystemTray - based on reference, better icon handling
Rectangle {
  id: root
  implicitWidth: trayRow.implicitWidth + 10
  implicitHeight: 26
  radius: Style.radius
  color: Style.barBg
  border.width: 1
  border.color: Style.barBorder
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
  visible: trayRow.implicitWidth > 0

  RowLayout {
    id: trayRow
    anchors.centerIn: parent
    spacing: 4

    Repeater {
      model: SystemTray.items

      delegate: Rectangle {
        Layout.preferredWidth: 22
        Layout.preferredHeight: 22
        radius: 4
        color: trayMouse.containsMouse ? Style.barHoverBg : "transparent"

        Image {
          anchors.centerIn: parent
          width: 20
          height: 20
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
