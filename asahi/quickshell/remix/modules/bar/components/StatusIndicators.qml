import QtQuick
import QtQuick.Layouts
import "../../../"

RowLayout {
  id: root

  property var notificationCenter: null
  property bool isRecording: false
  property bool updatesAvailable: false

  spacing: 6

  SystemTray {}

  Rectangle {
    id: recChip
    width: recRow.implicitWidth + 12
    height: 26
    radius: Style.radius
    color: recMouse.containsMouse ? Style.panelDangerBg : Style.barBg
    border.width: 1
    border.color: recMouse.containsMouse ? Style.red : Style.barBorder
    visible: root.isRecording
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    RowLayout {
      id: recRow
      anchors.centerIn: parent
      spacing: 5
      Text { text: "󰑋"; font.family: Style.fontFamily; font.pixelSize: 12; color: Style.red }
      Text { text: "REC"; font.family: Style.fontFamily; font.pixelSize: 10; font.bold: true; color: Style.red }
    }

    MouseArea { id: recMouse; anchors.fill: parent; hoverEnabled: true }
    TooltipWindow { target: recChip; text: "Screen recording active"; show: recMouse.containsMouse }
  }

  Rectangle {
    id: updateChip
    width: 26
    height: 26
    radius: Style.radius
    color: updateMouse.containsMouse ? Style.panelWarningBg : Style.barBg
    border.width: 1
    border.color: updateMouse.containsMouse ? Style.orange : Style.barBorder
    visible: root.updatesAvailable
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    Text {
      anchors.centerIn: parent
      text: "󰚰"
      font.family: Style.fontFamily
      font.pixelSize: 13
      color: Style.orange
    }

    MouseArea { id: updateMouse; anchors.fill: parent; hoverEnabled: true }
    TooltipWindow { target: updateChip; text: "Package updates available"; show: updateMouse.containsMouse }
  }

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
