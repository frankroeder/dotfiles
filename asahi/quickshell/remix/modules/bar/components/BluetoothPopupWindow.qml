import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Io
import "../../../"

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

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: Style.surface
    border.color: Style.border
    border.width: 1

    ColumnLayout {
      id: contentColumn
      anchors.fill: parent
      anchors.margins: 14
      spacing: 10

      // Header — informative only (power handled via blueman-manager)
      RowLayout {
        Layout.fillWidth: true
        Text { text: "󰂯"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: Style.magenta }
        Text { text: "Bluetooth"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true; color: Style.text }
        Text {
          text: (Bluetooth.defaultAdapter?.discovering ? "Discovering..." : (Bluetooth.defaultAdapter?.enabled ?? false ? "Ready" : "Off"))
          color: Style.textMuted; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; Layout.fillWidth: true
        }
        Item { Layout.fillWidth: true }
        // Scan toggle (useful for discovering new devices)
        MouseArea {
          width: 22; height: 22; cursorShape: Qt.PointingHandCursor
          onClicked: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering }
          Text { anchors.centerIn:parent; text: Bluetooth.defaultAdapter?.discovering ? "󰓛" : "󰂰"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Style.magenta }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: Style.border; opacity: 0.5 }

      // Devices list
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
          model: Bluetooth.devices.values
          delegate: Rectangle {
            Layout.fillWidth: true; height: 30; radius: 5
            color: mouseArea.containsMouse ? Qt.rgba(Style.surface.r, Style.surface.g, Style.surface.b, 0.2) : "transparent"
            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 6
              Text {
                text: modelData.connected ? "󰂱" : "󰂯"
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14
                color: modelData.connected ? Style.green : Style.textMuted
              }
              ColumnLayout {
                spacing: -1; Layout.fillWidth: true
                Text {
                  text: modelData.name || modelData.alias || modelData.address
                  font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: Style.text; elide: Text.ElideRight; Layout.fillWidth: true
                }
                Text {
                  text: (modelData.batteryAvailable ? modelData.battery + "%" : (modelData.paired ? "Paired" : "Nearby"))
                  font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8; color: Style.textMuted
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
                  color: actionBtn.containsMouse ? Style.magenta : "transparent"; border.color: Style.magenta; border.width: 1; opacity: actionBtn.containsMouse ? 0.18 : 0.7
                }
                Text {
                  anchors.centerIn: parent
                  text: modelData.connected ? "Disconnect" : (modelData.paired ? "Connect" : "Pair")
                  font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: Style.text
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
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: Style.textMuted; Layout.alignment: Qt.AlignHCenter
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: Style.border; opacity: 0.5 }

      // Footer
      RowLayout {
        Layout.fillWidth: true

        MouseArea {
          Layout.fillWidth: true
          height: 26
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.shouldShow = false
            Quickshell.execDetached([binDir + "/asahi-launch-bluetooth"])
          }

          Text {
            anchors.centerIn: parent
            text: "Open Bluetooth Menu →"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: Style.magenta
          }
        }
      }
    }
  }
}
