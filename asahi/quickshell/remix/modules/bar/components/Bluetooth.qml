import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 30

    property string icon: ""
    property string text: "BT"
    property string tooltip: ""

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2

        // Script already provides the symbol (󰂲 or 󰂱N)
        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 22   // matches waybar #bluetooth { font-size: 23px }
            color: "#cba6f7"
        }
    }

    Process {
        id: btProc
        command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-bluetooth"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.text = data.text || "BT"
                    root.tooltip = data.tooltip || ""
                    if (data.text && data.text.includes("on")) root.icon = "󰂯"
                    else root.icon = "󰂲"
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: btProc.running = true
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property var btPopup: null

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Quickshell.execDetached(["blueman-manager"])
            } else {
                // Left click: toggle the rich floating popup
                if (!btPopup) {
                    btPopup = Qt.createComponent("BluetoothPopupWindow.qml").createObject(root)
                }
                btPopup.shouldShow = !btPopup.shouldShow
            }
        }
    }

    TooltipWindow {
        target: root
        text: root.tooltip
        show: ma.containsMouse
        maxWidth: 380
    }
}
