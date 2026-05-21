import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 30

    property string text: "--%"
    property bool muted: false

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2

        // Script provides icon + level (e.g. "󰍬 60%")
        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 17
            color: root.muted ? "#f38ba8" : "#89b4fa"
        }
    }

    Process {
        id: micProc
        command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-audio", "input"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.text = data.text || "--%"
                    root.muted = (data.class || []).includes("muted") || (data.text || "").includes("muted")
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: micProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Quickshell.execDetached(["bash", "-c", "$HOME/.dotfiles/asahi/bin/asahi-media-control input mute-toggle"])
        onWheel: (wheel) => {
            const direction = wheel.angleDelta.y > 0 ? "raise" : "lower"
            Quickshell.execDetached(["bash", "-c", "$HOME/.dotfiles/asahi/bin/asahi-media-control input-volume " + direction])
        }
    }
}
