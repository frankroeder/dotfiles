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

      // Header — informative only (power handled via blueman-manager)
      RowLayout {
        Layout.fillWidth: true
        Text { text: "󰂯"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: cPrimary }
        Text { text: "Bluetooth"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true; color: cText }
        Text {
          text: (Bluetooth.defaultAdapter?.discovering ? "Discovering..." : (Bluetooth.defaultAdapter?.enabled ?? false ? "Ready" : "Off"))
          color: cSub; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; Layout.fillWidth: true
        }
        Item { Layout.fillWidth: true }
        // Scan toggle (useful for discovering new devices)
        MouseArea {
          width: 22; height: 22; cursorShape: Qt.PointingHandCursor
          onClicked: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering }
          Text { anchors.centerIn:parent; text: Bluetooth.defaultAdapter?.discovering ? "󰓛" : "󰂰"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: cPrimary }
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
            Layout.fillWidth: true; height: 30; radius: 5
            color: mouseArea.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent"
            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 6
              Text {
                text: modelData.connected ? "󰂱" : "󰂯"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                color: modelData.connected ? "#a6e3a1" : cSub
              }
              ColumnLayout {
                spacing: -1; Layout.fillWidth: true
                Text {
                  text: modelData.name || modelData.alias || modelData.address
                  font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: cText; elide: Text.ElideRight; Layout.fillWidth: true
                }
                Text {
                  text: (modelData.batteryAvailable ? modelData.battery + "%" : (modelData.paired ? "Paired" : "Nearby"))
                  font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8; color: cSub
                }
              }
              MouseArea {
                id: actionBtn; width: 72; height: 20; Layout.alignment: Qt.AlignVCenter; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (modelData.connected) modelData.disconnect()
                  else if (modelData.paired) modelData.connect()
                  else modelData.pair()
                }
                Rectangle {
                  anchors.fill: parent; radius: 4
                  color: actionBtn.containsMouse ? cPrimary : "transparent"; border.color: cPrimary; border.width: 1; opacity: actionBtn.containsMouse ? 0.18 : 0.7
                }
                Text {
                  anchors.centerIn: parent
                  text: modelData.connected ? "Disconnect" : (modelData.paired ? "Connect" : "Pair")
                  font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: cText
                }
              }
            }
            MouseArea { id: mouseArea; anchors.fill: parent; hoverEnabled: true; z: -1 }
          }
        }

        // Empty state
        Text {
          visible: Bluetooth.devices.values.length === 0
          text: (Bluetooth.defaultAdapter?.discovering ? "Scanning for devices..." : (Bluetooth.defaultAdapter?.enabled ?? false ? "No paired devices" : "Bluetooth is off"))
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: cSub; Layout.alignment: Qt.AlignHCenter
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
            Quickshell.execDetached(["/home/froeder/.dotfiles/asahi/bin/asahi-launch-bluetooth"])
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
