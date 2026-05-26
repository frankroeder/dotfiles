import QtQuick
import QtQuick.Layouts
import "../../../"

RowLayout {
  id: root

  property var notificationCenter: null

  spacing: 6

  SystemTray {}

  Rectangle {
    width: notifRow.implicitWidth + 12
    height: 24
    radius: Style.radiusSm
    color: notifMouse.containsMouse ? Style.hoverBg : Style.moduleBg
    visible: root.notificationCenter !== null

    RowLayout {
      id: notifRow
      anchors.centerIn: parent
      spacing: 5

      Text {
        text: root.notificationCenter && root.notificationCenter.dndEnabled ? "󰂛" : "󰂚"
        font.family: Style.fontFamily
        font.pixelSize: 13
        color: root.notificationCenter && root.notificationCenter.dndEnabled ? Style.yellow : Style.blueAlt
      }

      Text {
        text: root.notificationCenter ? root.notificationCenter.historyCount : 0
        font.family: Style.fontFamily
        font.pixelSize: 11
        color: Style.textMuted
        visible: root.notificationCenter && root.notificationCenter.historyCount > 0
      }
    }

    MouseArea {
      id: notifMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onClicked: (mouse) => {
        if (!root.notificationCenter) return
        if (mouse.button === Qt.RightButton) root.notificationCenter.toggleDnd()
        else root.notificationCenter.toggleHistory()
      }
    }
  }
}
