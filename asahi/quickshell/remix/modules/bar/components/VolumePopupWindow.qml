import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Floating Volume popup (output + input)
// Matches our remix dark theme + the split pattern (PopupWindow + Panel)
PanelWindow {
  id: root

  property bool shouldShow: false
  visible: shouldShow
  color: "transparent"

  anchors {
    top: true
    right: true
  }
  margins {
    top: 38
    right: 12
  }

  implicitWidth: 320
  implicitHeight: contentColumn.implicitHeight + 24

  readonly property color cSurface: "#1e1e2e"
  readonly property color cBorder: "#45475a"
  readonly property color cText: "#cdd6f4"
  readonly property color cSub: "#a6adc8"
  readonly property color cPrimary: "#a6e3a1"

  // Current data
  property string outText: ""
  property bool outMuted: false
  property string inText: ""
  property bool inMuted: false

  Process {
    id: outProc
    command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-audio", "output"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(text.trim())
          root.outText = d.text || ""
          root.outMuted = (d.class || []).includes("muted")
        } catch (e) {}
      }
    }
  }

  Process {
    id: inProc
    command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-audio", "input"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(text.trim())
          root.inText = d.text || ""
          root.inMuted = (d.class || []).includes("muted")
        } catch (e) {}
      }
    }
  }

  function refresh() {
    outProc.running = true
    inProc.running = true
  }

  Component.onCompleted: refresh()

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: cSurface
    border.color: cBorder
    border.width: 1

    ColumnLayout {
      id: contentColumn
      anchors.fill: parent
      anchors.margins: 14
      spacing: 12

      // Header
      Text {
        text: "Volume"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        font.bold: true
        color: cText
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.5 }

      // Output
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "󰕾"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 18
          color: outMuted ? "#f38ba8" : cPrimary
        }

        Text {
          text: outText || "Output"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 13
          color: cText
          Layout.fillWidth: true
        }

        MouseArea {
          width: 50
          height: 22
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-media-control", "output", "mute-toggle"])
            refresh()
          }
          Text {
            anchors.centerIn: parent
            text: outMuted ? "Unmute" : "Mute"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            color: cSub
          }
        }
      }

      // Input (mic)
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "󰍬"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 18
          color: inMuted ? "#f38ba8" : "#89b4fa"
        }

        Text {
          text: inText || "Input"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 13
          color: cText
          Layout.fillWidth: true
        }

        MouseArea {
          width: 50
          height: 22
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-media-control", "input", "mute-toggle"])
            refresh()
          }
          Text {
            anchors.centerIn: parent
            text: inMuted ? "Unmute" : "Mute"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            color: cSub
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.5 }

      // Quick actions
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        MouseArea {
          Layout.fillWidth: true
          height: 26
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-media-control", "output-volume", "raise"])
            refresh()
          }
          Text {
            anchors.centerIn: parent
            text: "Raise"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: cPrimary
          }
        }

        MouseArea {
          Layout.fillWidth: true
          height: 26
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-media-control", "output-volume", "lower"])
            refresh()
          }
          Text {
            anchors.centerIn: parent
            text: "Lower"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: cPrimary
          }
        }

        MouseArea {
          Layout.fillWidth: true
          height: 26
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.shouldShow = false
            Quickshell.execDetached(["pavucontrol"])
          }
          Text {
            anchors.centerIn: parent
            text: "Mixer →"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: cPrimary
          }
        }
      }
    }
  }
}
