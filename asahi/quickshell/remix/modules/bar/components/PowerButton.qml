import QtQuick
import QtQuick.Layouts
import Quickshell

// Power button - inspired by reference, styled for remix
// Click opens user's power menu (asahi-battery-menu or similar)
Item {
  id: root

  implicitWidth: 28
  implicitHeight: 28

  property string powerMenuCommand: "~/.dotfiles/asahi/bin/asahi-control-menu"

  Rectangle {
    id: bg
    anchors.centerIn: parent
    width: 24
    height: 24
    radius: 12

    color: mouseArea.pressed ? Qt.rgba(0.9, 0.4, 0.5, 0.35) :
           mouseArea.containsMouse ? Qt.rgba(0.9, 0.4, 0.5, 0.22) :
           Qt.rgba(0.9, 0.4, 0.5, 0.12)

    border.width: 0

    scale: mouseArea.pressed ? 0.9 : (mouseArea.containsMouse ? 1.08 : 1.0)

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
  }

  Text {
    anchors.centerIn: parent
    text: "󰐥"
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 16
    font.bold: true
    color: "#f38ba8"
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: {
      Quickshell.execDetached(["bash", "-c", root.powerMenuCommand])
    }
  }
}