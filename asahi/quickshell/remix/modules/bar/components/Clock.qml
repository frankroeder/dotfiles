import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
  id: root

  color: "#313244"
  radius: 6

  property var launcher: null

  implicitWidth: clockRow.implicitWidth + 14
  implicitHeight: 26

  RowLayout {
    id: clockRow
    anchors.centerIn: parent
    spacing: 6

    Text {
      text: Qt.formatDateTime(new Date(), "ddd dd MMM")
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 18
      color: "#74c7ec"
    }
    Text {
      id: timeText
      text: Qt.formatDateTime(new Date(), "HH:mm")
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 18
      color: "#74c7ec"
      Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: timeText.text = Qt.formatDateTime(new Date(), "HH:mm")
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (root.launcher && root.launcher.openLauncher) {
        root.launcher.openLauncher()
      }
    }
  }
}
