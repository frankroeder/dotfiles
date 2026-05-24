import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"

// Power button - inspired by reference, styled for remix
// Click opens user's power menu (asahi-battery-menu or similar)
Rectangle {
  id: root

  color: Style.moduleBg
  radius: 6
  implicitWidth: 28
  implicitHeight: 28

  property string powerMenuCommand: Quickshell.env("HOME") + "/.dotfiles/asahi/bin/asahi-control-menu"

  Text {
    anchors.centerIn: parent
    text: "󰐥"
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 16
    font.bold: true
    color: mouseArea.containsMouse ? Style.red : Style.text

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