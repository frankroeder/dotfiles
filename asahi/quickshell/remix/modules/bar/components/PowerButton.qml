import QtQuick
import QtQuick.Layouts
import Quickshell

// Power button - inspired by reference, styled for remix
// Click opens user's power menu (asahi-battery-menu or similar)
Rectangle {
  id: root

  color: "#313244"
  radius: 6
  implicitWidth: 28
  implicitHeight: 28

  property string powerMenuCommand: "/home/froeder/.dotfiles/asahi/bin/asahi-control-menu"

  Text {
    anchors.centerIn: parent
    text: "󰐥"
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 16
    font.bold: true
    color: mouseArea.containsMouse ? "#f38ba8" : "#cdd6f4"

    Behavior on color { ColorAnimation { duration: 120 } }
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