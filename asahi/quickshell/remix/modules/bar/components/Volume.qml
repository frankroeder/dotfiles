import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 30

    property string icon: "󰕾"
    property string text: "--%"
    property bool muted: false

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.muted ? "󰖁" : root.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: root.muted ? "#f38ba8" : "#a6e3a1"
        }

        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: "#cdd6f4"
        }
    }

    Process {
        id: audioProc
        command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-audio", "output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.text = data.text || "--%"
                    root.muted = data.text && data.text.includes("muted")
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: audioProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Quickshell.execDetached(["bash", "-c", "$HOME/.dotfiles/asahi/bin/asahi-media-control output mute-toggle"])
        onWheel: (wheel) => {
            const direction = wheel.angleDelta.y > 0 ? "raise" : "lower"
            Quickshell.execDetached(["bash", "-c", "$HOME/.dotfiles/asahi/bin/asahi-media-control output-volume " + direction])
        }
    }
}
