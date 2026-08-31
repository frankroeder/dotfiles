import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"

Item {
  id: root

  property var barHost: null
  readonly property bool solidBar: barHost !== null && barHost !== undefined

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  readonly property string timeLine: Qt.formatDateTime(clock.date, "HH:mm")
  readonly property string dateLine: Qt.formatDateTime(clock.date, "ddd dd MMM")

  implicitWidth: solidBar ? flatRow.implicitWidth + 16 : clockRow.implicitWidth + 14
  implicitHeight: solidBar ? Style.barHeight : 26

  Row {
    id: flatRow
    visible: root.solidBar
    anchors.centerIn: parent
    spacing: 8

    Text {
      text: root.dateLine
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontBody
      color: Style.barStripMuted
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: root.timeLine
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontBody
      color: barHost ? barHost.barForeground : Style.barStripText
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Rectangle {
    visible: !root.solidBar
    anchors.fill: parent
    color: Style.barBg
    radius: Style.radius
    border.width: 1
    border.color: Style.barBorder

    RowLayout {
      id: clockRow
      anchors.centerIn: parent
      spacing: 6

      Text {
        text: root.dateLine
        font.family: Style.fontFamily
        font.pixelSize: Style.barFontBody
        color: Style.cyan
      }
      Text {
        text: root.timeLine
        font.family: Style.fontFamily
        font.pixelSize: Style.barFontBody
        color: Style.cyan
      }
    }
  }
}
