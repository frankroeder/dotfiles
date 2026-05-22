import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Io

// Inline Bluetooth Panel (FocusScope version for popupHost inside Bar)
// Same content as BluetoothPopupWindow but hosted inside the bar window

FocusScope {
  id: root

  property bool shouldShow: false
  signal closeRequested()

  implicitWidth: 320
  implicitHeight: contentColumn.implicitHeight + 24

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

      RowLayout {
        Layout.fillWidth: true

        Text {
          text: "󰂯"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 18
          color: cPrimary
        }

        Text { text: "Bluetooth"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true; color: cText }
        Text {
          text: (Bluetooth.defaultAdapter?.discovering ? "Scan..." : (Bluetooth.defaultAdapter?.enabled ?? false ? "Ready" : "Off"))
          color: cSub; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"; Layout.fillWidth: true
        }
        Item { Layout.fillWidth: true }

        // Scan toggle (useful for discovering new devices)
        MouseArea {
          width: 20; height: 20; cursorShape: Qt.PointingHandCursor
          onClicked: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering }
          Text { anchors.centerIn:parent; text: Bluetooth.defaultAdapter?.discovering ? "󰓛" : "󰂰"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: cPrimary }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.5 }

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
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                color: modelData.connected ? "#a6e3a1" : cSub
              }
              ColumnLayout {
                spacing: -1; Layout.fillWidth: true
                Text { text: modelData.name || modelData.alias || modelData.address; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: cText; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: (modelData.batteryAvailable ? modelData.battery+"%" : (modelData.paired?"Paired":"")); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8; color: cSub }
              }
              MouseArea {
                id: actionBtn; width: 64; height: 18; cursorShape: Qt.PointingHandCursor
                onClicked: { if (modelData.connected) modelData.disconnect(); else if (modelData.paired) modelData.connect(); else modelData.pair() }
                Rectangle {
                  anchors.fill: parent; radius: 3
                  color: actionBtn.containsMouse ? cPrimary : "transparent"; border.color: cPrimary; border.width: 1; opacity: actionBtn.containsMouse ? 0.18 : 0.7
                }
                Text {
                  anchors.centerIn: parent
                  text: modelData.connected ? "Disconnect" : (modelData.paired ? "Connect" : "Pair")
                  font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8; color: cText
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

        Text {
          visible: Bluetooth.devices.values.length === 0
          text: (Bluetooth.defaultAdapter?.discovering ? "Scanning..." : (Bluetooth.defaultAdapter?.enabled ?? false ? "No paired devices" : "Bluetooth is off"))
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: cSub; Layout.alignment: Qt.AlignHCenter
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.5 }

      RowLayout {
        Layout.fillWidth: true

        MouseArea {
          Layout.fillWidth: true
          height: 26
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.closeRequested()
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
