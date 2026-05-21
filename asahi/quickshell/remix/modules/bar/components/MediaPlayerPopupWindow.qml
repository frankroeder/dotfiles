import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Floating Media Player popup
PanelWindow {
  id: root

  property bool shouldShow: false
  visible: shouldShow
  color: "transparent"

  anchors {
    top: true
  }
  margins {
    top: 40
  }

  readonly property int popupWidth: 340

  anchors {
    top: true
    left: true
  }
  margins {
    top: 40
    left: (Quickshell.screens[0] ? (Quickshell.screens[0].width - popupWidth) / 2 : 200)
  }

  implicitWidth: popupWidth
  implicitHeight: contentColumn.implicitHeight + 20

  readonly property color cSurface: "#1e1e2e"
  readonly property color cBorder: "#45475a"
  readonly property color cText: "#cdd6f4"
  readonly property color cPrimary: "#94e2d5"

  property string currentInfo: "No media playing"

  Process {
    id: infoProc
    command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-player"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(text.trim())
          root.currentInfo = d.text || "No media playing"
        } catch (e) {
          root.currentInfo = "No media playing"
        }
      }
    }
  }

  function refresh() { infoProc.running = true }

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
      anchors.margins: 16
      spacing: 12

      Text {
        text: "Now Playing"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        font.bold: true
        color: cPrimary
      }

      Text {
        text: root.currentInfo
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        color: cText
        wrapMode: Text.Wrap
        Layout.fillWidth: true
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.5 }

      RowLayout {
        Layout.fillWidth: true
        spacing: 16

        MouseArea {
          Layout.fillWidth: true
          height: 28
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-media-control", "previous"])
            refresh()
          }
          Text { anchors.centerIn: parent; text: "󰒮"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: cText }
        }

        MouseArea {
          Layout.fillWidth: true
          height: 28
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-media-control", "play-pause"])
            refresh()
          }
          Text { anchors.centerIn: parent; text: "󰐊"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 20; color: cPrimary }
        }

        MouseArea {
          Layout.fillWidth: true
          height: 28
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-media-control", "stop"])
            refresh()
          }
          Text { anchors.centerIn: parent; text: "󰓛"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: cText }
        }

        MouseArea {
          Layout.fillWidth: true
          height: 28
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-media-control", "next"])
            refresh()
          }
          Text { anchors.centerIn: parent; text: "󰒭"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: cText }
        }
      }
    }
  }
}