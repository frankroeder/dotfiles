import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../"

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

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  // Current data
  property string outText: ""
  property bool outMuted: false
  property string inText: ""
  property bool inMuted: false

  Process {
    id: outProc
    command: ["bash", binDir + "/asahi-audio", "output"]
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
    command: ["bash", binDir + "/asahi-audio", "input"]
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
    color: Style.surface
    border.color: Style.barBorder
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
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
        color: Style.text
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: Style.barBorder; opacity: 0.5 }

      // Output
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "󰕾"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 18
          color: outMuted ? Style.red : Style.green
        }

        Text {
          text: outText || "Output"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 13
          color: Style.text
          Layout.fillWidth: true
        }

        MouseArea {
          width: 50
          height: 22
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached([binDir + "/asahi-media-control", "output-volume", "mute-toggle"])
            refresh()
          }
          Text {
            anchors.centerIn: parent
            text: outMuted ? "Unmute" : "Mute"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            color: Style.textMuted
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
          color: inMuted ? Style.red : Style.blueAlt
        }

        Text {
          text: inText || "Input"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 13
          color: Style.text
          Layout.fillWidth: true
        }

        MouseArea {
          width: 50
          height: 22
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached([binDir + "/asahi-media-control", "input-volume", "mute-toggle"])
            refresh()
          }
          Text {
            anchors.centerIn: parent
            text: inMuted ? "Unmute" : "Mute"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            color: Style.textMuted
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: Style.barBorder; opacity: 0.5 }

      // Quick actions
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        MouseArea {
          Layout.fillWidth: true
          height: 26
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached([binDir + "/asahi-media-control", "output-volume", "raise"])
            refresh()
          }
          Text {
            anchors.centerIn: parent
            text: "Raise"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: Style.green
          }
        }

        MouseArea {
          Layout.fillWidth: true
          height: 26
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached([binDir + "/asahi-media-control", "output-volume", "lower"])
            refresh()
          }
          Text {
            anchors.centerIn: parent
            text: "Lower"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: Style.green
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
            color: Style.green
          }
        }
      }
    }
  }
}
