import QtQuick

// Control Center toggle button (gear/settings icon)
// Inspired by reference - rotates when "active"
Item {
  id: root

  property var controlCenter: null

  implicitWidth: 26
  implicitHeight: 26

  readonly property bool isActive: controlCenter ? controlCenter.shouldShow : false

  Text {
    id: icon
    anchors.centerIn: parent
    text: "󰒓"
    font.family: "JetBrainsMono Nerd Font"
    font.pixelSize: 18
    color: isActive || mouseArea.containsMouse ? "#cba6f7" : "#cdd6f4"

    rotation: isActive ? 90 : 0
    scale: mouseArea.pressed ? 0.85 : (mouseArea.containsMouse || isActive ? 1.1 : 1.0)

    Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 150 } }
    Behavior on color { ColorAnimation { duration: 150 } }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: {
      if (controlCenter) {
        controlCenter.shouldShow = !controlCenter.shouldShow
      } else {
        console.log("No ControlCenterWindow connected to toggle")
      }
    }
  }
}