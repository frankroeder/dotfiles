import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: root

  property bool shouldShow: false
  visible: shouldShow

  anchors {
    top: true
    right: true
  }
  margins {
    top: 12
    right: 12
  }

  implicitWidth: 380
  implicitHeight: Math.min(700, screen.height - 60)
  color: "transparent"

  WlrLayershell.keyboardFocus: shouldShow ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  readonly property color cSurface: "#1e1e2e"
  readonly property color cBorder: "#45475a"
  readonly property color cText: "#cdd6f4"
  readonly property color cPrimary: "#cba6f7"

  Rectangle {
    anchors.fill: parent
    radius: 16
    color: cSurface
    border.color: cBorder
    border.width: 1

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 16

      // Header
      RowLayout {
        Layout.fillWidth: true

        Text {
          text: "Control Center"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 16
          font.bold: true
          color: cText
          Layout.fillWidth: true
        }

        MouseArea {
          width: 28
          height: 28
          cursorShape: Qt.PointingHandCursor
          onClicked: root.shouldShow = false

          Text {
            anchors.centerIn: parent
            text: "󰅖"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            color: cText
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.6 }

      // Quick Actions
      GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 8
        columnSpacing: 8

        Repeater {
          model: [
            { icon: "󰖩", label: "WiFi", cmd: "nmtui" },
            { icon: "󰂯", label: "Bluetooth", cmd: "blueman-manager" },
            { icon: "󰍹", label: "Audio", cmd: "pavucontrol" },
            { icon: "󰂳", label: "Settings", cmd: "gnome-control-center" },
            { icon: "󰒓", label: "Power", cmd: "/home/froeder/.dotfiles/asahi/bin/asahi-battery-menu" },
            { icon: "󰍛", label: "System", cmd: "gnome-system-monitor" }
          ]

          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            radius: 10
            color: Qt.rgba(1,1,1,0.03)
            border.color: cBorder
            border.width: 1

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                Quickshell.execDetached(["bash", "-c", modelData.cmd])
                root.shouldShow = false
              }
            }

            Column {
              anchors.centerIn: parent
              spacing: 2

              Text {
                text: modelData.icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 20
                color: cPrimary
                anchors.horizontalCenter: parent.horizontalCenter
              }

              Text {
                text: modelData.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: cText
                anchors.horizontalCenter: parent.horizontalCenter
              }
            }
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.6 }

      // Media Section (simple)
      Text {
        text: "Now Playing"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        font.bold: true
        color: cPrimary
      }

      Text {
        text: "Use the media controls in the bar or your player"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: cText
        Layout.fillWidth: true
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.6 }

      // System Stats
      Text {
        text: "System"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        font.bold: true
        color: cPrimary
      }

      // We can embed a simple version of SystemUsage here later
      Text {
        text: "CPU / Memory / Disk stats available in bar"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        color: cText
      }

      Item { Layout.fillHeight: true }
    }
  }
}
