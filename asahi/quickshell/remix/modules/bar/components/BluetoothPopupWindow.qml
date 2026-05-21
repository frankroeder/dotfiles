import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Io

// Floating Bluetooth popup (standalone PanelWindow version)
// Styled to match the current remix dark theme + TooltipWindow
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

  // Colors matching shell.qml + TooltipWindow
  readonly property color cSurface: "#1e1e2e"
  readonly property color cBorder: "#45475a"
  readonly property color cText: "#cdd6f4"
  readonly property color cSub: "#a6adc8"
  readonly property color cPrimary: "#cba6f7"

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
          text: "󰂯"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 18
          color: cPrimary
        }

        Text {
          text: "Bluetooth"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14
          font.bold: true
          color: cText
          Layout.fillWidth: true
        }

        // Power toggle
        MouseArea {
          width: 24
          height: 24
          onClicked: {
            if (Bluetooth.defaultAdapter) {
              Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
            }
          }
          cursorShape: Qt.PointingHandCursor

          Text {
            anchors.centerIn: parent
            text: (Bluetooth.defaultAdapter?.enabled ?? false) ? "󰂯" : "󰂲"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: (Bluetooth.defaultAdapter?.enabled ?? false) ? cPrimary : cSub
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.5 }

      // Devices list
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
          model: Bluetooth.devices.values
          delegate: Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 6
            color: mouseArea.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 8

              Text {
                text: modelData.connected ? "󰂱" : "󰂯"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                color: modelData.connected ? "#a6e3a1" : cSub
              }

              Text {
                text: modelData.name || modelData.alias || modelData.address
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: cText
                Layout.fillWidth: true
                elide: Text.ElideRight
              }

              MouseArea {
                id: actionBtn
                width: 60
                height: 22
                anchors.verticalCenter: parent.verticalCenter
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (modelData.connected) {
                    modelData.disconnect()
                  } else if (modelData.paired) {
                    modelData.connect()
                  } else {
                    // Try to pair + connect
                    modelData.pair()
                  }
                }

                Rectangle {
                  anchors.fill: parent
                  radius: 4
                  color: actionBtn.containsMouse ? cPrimary : "transparent"
                  border.color: cPrimary
                  border.width: 1
                  opacity: actionBtn.containsMouse ? 0.2 : 0.8
                }

                Text {
                  anchors.centerIn: parent
                  text: modelData.connected ? "Disconnect" : (modelData.paired ? "Connect" : "Pair")
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 10
                  color: cText
                }
              }
            }

            MouseArea {
              id: mouseArea
              anchors.fill: parent
              hoverEnabled: true
              z: -1
            }
          }
        }

        // Empty state
        Text {
          visible: Bluetooth.devices.values.length === 0
          text: (Bluetooth.defaultAdapter?.enabled ?? false) ? "No paired devices" : "Bluetooth is off"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 11
          color: cSub
          Layout.alignment: Qt.AlignHCenter
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.5 }

      // Footer
      RowLayout {
        Layout.fillWidth: true

        MouseArea {
          Layout.fillWidth: true
          height: 26
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.shouldShow = false
            Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-bluetooth-menu"])
          }

          Text {
            anchors.centerIn: parent
            text: "Open Bluetooth Menu →"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: cPrimary
          }
        }
      }
    }
  }
}
