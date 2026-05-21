import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 30

    property string icon: "󰤨"
    property string text: "WiFi"

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: "#89b4fa"
        }

        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: "#cdd6f4"
            elide: Text.ElideRight
            Layout.maximumWidth: 90
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
                    // Simple icon logic based on text if needed
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
        anchors.fill: parent
        onClicked: Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-launch-wifi"])
    }
}
