import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Media Player pill for the bar
// Uses asahi-waybar-player script for data (consistent with waybar)
Rectangle {
  id: root

  color: "#313244"
  radius: 6

  implicitWidth: Math.max(280, contentRow.implicitWidth + 14)
  implicitHeight: 26

  property string text: ""
  property bool hasMedia: text.length > 0

  Process {
    id: playerProc
    command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-player"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          root.text = data.text || ""
        } catch (e) {
          root.text = ""
        }
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: playerProc.running = true
  }

  Component.onCompleted: playerProc.running = true

  RowLayout {
    id: contentRow
    anchors.centerIn: parent
    spacing: 6
    Text {
      text: hasMedia ? root.text : "No media"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 18
      color: hasMedia ? "#cdd6f4" : "#6c7086"
      elide: Text.ElideRight
      Layout.maximumWidth: 140
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        Quickshell.execDetached(["bash", "-c", "~/.dotfiles/asahi/bin/asahi-media-control playerctl next"])
      } else if (mouse.button === Qt.MiddleButton) {
        Quickshell.execDetached(["bash", "-c", "~/.dotfiles/asahi/bin/asahi-media-control playerctl previous"])
      } else {
        Quickshell.execDetached(["bash", "-c", "~/.dotfiles/asahi/bin/asahi-media-control playerctl play-pause"])
      }
    }
  }

}