import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

// Basic SystemTray following Quickshell + waybar style
Item {
  id: root

  implicitWidth: trayRow.implicitWidth
  implicitHeight: 30

  RowLayout {
    id: trayRow
    anchors.centerIn: parent
    spacing: 4

    Repeater {
      model: SystemTray.items
      delegate: MouseArea {
        width: 20
        height: 20
        cursorShape: Qt.PointingHandCursor

        Image {
          anchors.fill: parent
          source: modelData.icon
          fillMode: Image.PreserveAspectFit
        }

        onClicked: modelData.activate()
      }
    }
  }
}
