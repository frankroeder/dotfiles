import QtQuick
import QtQuick.Layouts

// Improved Clock component inspired by the reference Clock.qml
// Bigger, nicer formatting, subtle animation, click to open launcher (via parent IPC if wired)
Rectangle {
  id: root

  color: "#313244"
  radius: 6

  property var launcher: null   // can be wired later for click-to-launcher

  implicitWidth: clockRow.implicitWidth + 14
  implicitHeight: 26

  RowLayout {
    id: clockRow
    anchors.centerIn: parent
    spacing: 4

    Text {
      text: Qt.formatDateTime(new Date(), "ddd MMM dd")
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 16
      color: "#89b4fa"
    }
    Text {
      id: timeText
      text: Qt.formatDateTime(new Date(), "HH:mm")
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 17
      color: "#89b4fa"
      Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: timeText.text = Qt.formatDateTime(new Date(), "HH:mm")
      }
    }

  }
}
