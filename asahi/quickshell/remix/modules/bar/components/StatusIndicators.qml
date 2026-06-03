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
    height: 26
    radius: Style.radius
    border.width: 1
    border.color: Style.barBorder
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    scale: notifMouse.containsMouse ? 1.018 : 1.0
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    color: notifMouse.containsMouse ? Style.barHoverBg : Style.barBg
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
