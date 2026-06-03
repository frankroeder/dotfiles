import QtQuick
import QtQuick.Layouts
import "../../../"

Rectangle {
  id: root

  color: Style.barBg
  radius: Style.radius
  border.width: 1
  border.color: Style.barBorder
  Behavior on color { ColorAnimation { duration: 140 } }
  Behavior on border.color { ColorAnimation { duration: 140 } }

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
      color: Style.cyan
    }
    Text {
      id: timeText
      text: Qt.formatDateTime(new Date(), "HH:mm")
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 18
      color: Style.cyan
      Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: timeText.text = Qt.formatDateTime(new Date(), "HH:mm")
      }
    }
  }

}
