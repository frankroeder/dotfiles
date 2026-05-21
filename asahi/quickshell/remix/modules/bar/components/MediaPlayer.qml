import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Media Player pill for the bar
// Uses asahi-waybar-player script for data (consistent with waybar)
Rectangle {
  id: root

  color: "#313244"
  radius: 6

  implicitWidth: Math.max(180, contentRow.implicitWidth + 14)
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
      text: "󰎇"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 15
      color: hasMedia ? "#94e2d5" : "#6c7086"
    }

    Text {
      text: hasMedia ? root.text : "No media"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 13
      color: hasMedia ? "#cdd6f4" : "#6c7086"
      elide: Text.ElideRight
      Layout.maximumWidth: 140
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: {
      if (!root.playerPopup) {
        const comp = Qt.createComponent("MediaPlayerPopupWindow.qml", Component.PreferSynchronous)
        if (comp.status === Component.Ready) {
          root.playerPopup = comp.createObject(root)
        } else if (comp.status === Component.Error) {
          console.warn("Failed to load MediaPlayerPopupWindow.qml:", comp.errorString())
        }
      }
      if (root.playerPopup) {
        root.playerPopup.shouldShow = !root.playerPopup.shouldShow
      }
    }
  }

  property var playerPopup: null
}