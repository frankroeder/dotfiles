import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: row.implicitWidth
    // implicitHeight: 30

    property string icon: "󰤨"
    property string text: "WiFi"
    property string tooltip: ""

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2

        // Use only the script-provided text (already contains nice icon)
        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 22   // matches waybar #network { font-size: 23px }
            color: "#89b4fa"
        }
    }

    Process {
        id: netProc
        command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-network"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.text = data.text || "WiFi"
                    root.tooltip = data.tooltip || ""
                    if (data.text && data.text.includes("down")) root.icon = "󰤭"
                    else root.icon = "󰤨"
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property var netPopup: null

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Quickshell.execDetached(["nmtui"])
            } else {
                // Left click: rich floating popup
                if (!netPopup) {
                    netPopup = Qt.createComponent("NetworkPopupWindow.qml").createObject(root)
                }
                netPopup.shouldShow = !netPopup.shouldShow
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
