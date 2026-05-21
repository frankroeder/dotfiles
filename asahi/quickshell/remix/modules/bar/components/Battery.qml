import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 30

    property string text: "Bat --%"

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: "󰁹"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: "#a6e3a1"
        }

        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: "#cdd6f4"
        }
    }

    Process {
        id: batProc
        command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-battery"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.text = data.text || "Bat --%"
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: batProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-battery-menu"])
    }
}
