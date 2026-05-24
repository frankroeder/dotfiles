import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"

// Media Player pill for the bar
// Uses asahi-player script for data (Asahi tuned json)
Rectangle {
  id: root

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  color: Style.moduleBg
  radius: 6

  implicitWidth: Math.min(300, contentRow.implicitWidth + 14)
  implicitHeight: 26

  property string text: ""
  property bool hasMedia: text.length > 0
  visible: hasMedia

  Process {
    id: playerProc
    command: ["bash", binDir + "/asahi-player"]
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
      color: hasMedia ? Style.text : Style.textMuted
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
        Quickshell.execDetached([binDir + "/asahi-media-control", "playerctl", "next"])
      } else if (mouse.button === Qt.MiddleButton) {
        Quickshell.execDetached([binDir + "/asahi-media-control", "playerctl", "previous"])
      } else {
        Quickshell.execDetached([binDir + "/asahi-media-control", "playerctl", "play-pause"])
      }
    }
  }

}