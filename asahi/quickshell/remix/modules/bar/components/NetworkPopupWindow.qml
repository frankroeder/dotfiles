import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Floating Network (WiFi) popup - standalone version
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

  implicitWidth: 340
  implicitHeight: contentColumn.implicitHeight + 24

  readonly property color cSurface: "#1e1e2e"
  readonly property color cBorder: "#45475a"
  readonly property color cText: "#cdd6f4"
  readonly property color cSub: "#a6adc8"
  readonly property color cPrimary: "#89b4fa"

  // Current status (from our script or direct)
  property string currentText: ""
  property string currentTooltip: ""

  // Scanned networks model (simple array of objects)
  property var networks: []

  Process {
    id: scanProc
    command: ["bash", "-c", "nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list --rescan auto 2>/dev/null | head -12"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n").filter(l => l.length > 0)
        const list = []
        for (const line of lines) {
          const parts = line.split(":")
          if (parts.length >= 2) {
            list.push({
              ssid: parts[0] || "(hidden)",
              signal: parseInt(parts[1]) || 0,
              security: parts[2] || ""
            })
          }
        }
        root.networks = list
      }
    }
  }

  // Refresh current status using our existing script
  Process {
    id: statusProc
    command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-network"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(text.trim())
          root.currentText = d.text || ""
          root.currentTooltip = d.tooltip || ""
        } catch (e) {}
      }
    }
  }

  function refresh() {
    statusProc.running = true
    scanProc.running = true
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
      spacing: 10

      // Header
      RowLayout {
        Layout.fillWidth: true

        Text {
          text: "󰖩"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 18
          color: cPrimary
        }

        Text {
          text: "Network"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14
          font.bold: true
          color: cText
          Layout.fillWidth: true
        }

        MouseArea {
          width: 24
          height: 24
          cursorShape: Qt.PointingHandCursor
          onClicked: root.refresh()

          Text {
            anchors.centerIn: parent
            text: "󰑐"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: cSub
          }
        }
      }

      // Current connection summary (multi-line from tooltip)
      Rectangle {
        Layout.fillWidth: true
        radius: 6
        color: Qt.rgba(0,0,0,0.2)
        border.color: cBorder
        border.width: 1
        implicitHeight: currentText.height + 16

        Text {
          id: currentText
          anchors.centerIn: parent
          anchors.margins: 8
          text: root.currentTooltip || "No connection info"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 11
          color: cText
          wrapMode: Text.Wrap
          width: parent.width - 20
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.5 }

      // Available networks
      Text {
        text: "Available networks"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        font.bold: true
        color: cSub
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Repeater {
          model: root.networks
          delegate: Rectangle {
            Layout.fillWidth: true
            height: 28
            radius: 4
            color: netMouse.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 6
              anchors.rightMargin: 6

              Text {
                text: modelData.ssid
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: cText
                Layout.fillWidth: true
                elide: Text.ElideRight
              }

              Text {
                text: modelData.signal + "%"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                color: cSub
              }

              MouseArea {
                width: 50
                height: 20
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  // Basic connect attempt (no password handling here)
                  Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", modelData.ssid])
                  root.shouldShow = false
                }

                Text {
                  anchors.centerIn: parent
                  text: "Connect"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 10
                  color: cPrimary
                }
              }
            }

            MouseArea {
              id: netMouse
              anchors.fill: parent
              hoverEnabled: true
              z: -1
            }
          }
        }

        Text {
          visible: root.networks.length === 0
          text: "No networks found (click refresh)"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 10
          color: cSub
          Layout.alignment: Qt.AlignHCenter
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.5 }

      MouseArea {
        Layout.fillWidth: true
        height: 26
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.shouldShow = false
          Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-network-menu"])
        }

        Text {
          anchors.centerIn: parent
          text: "Open Network Menu →"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 11
          color: cPrimary
        }
      }
    }
  }
}
