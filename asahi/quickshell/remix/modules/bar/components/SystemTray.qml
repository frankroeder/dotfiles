import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

// Improved SystemTray - based on reference, better icon handling
RowLayout {
  id: root
  spacing: 4

  Repeater {
    model: SystemTray.items

    delegate: Rectangle {
      Layout.preferredWidth: 22
      Layout.preferredHeight: 22
      radius: 4
      color: trayMouse.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent"

      Image {
        anchors.centerIn: parent
        width: 16
        height: 16
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
