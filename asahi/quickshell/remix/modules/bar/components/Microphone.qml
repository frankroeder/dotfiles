import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    color: "#313244"   // dark background like waybar @surface0 modules
    radius: 6

    implicitWidth: content.implicitWidth + 14
    implicitHeight: 26

    property string text: "󰍬 --%"
    property bool muted: false
    property string level: "--"   // current volume percentage as string

    onMutedChanged: {
        const icon = muted ? "󰍭" : "󰍬"
        text = icon + " " + level + "%"
    }

    RowLayout {
        id: content
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
                    root.muted = (data.class || []).includes("muted") || (data.text || "").includes("muted")
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            micProc.running = true
            micLevelProc.running = true
        }
    }

    // Separate process to always get real mic volume percentage
    Process {
        id: micLevelProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk '{gsub(/[^0-9.]/, \"\", $2); printf \"%.0f\", $2*100}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const perc = text.trim()
                root.level = perc.length > 0 ? perc : "--"
                const icon = root.muted ? "󰍭" : "󰍬"
                root.text = icon + " " + root.level + "%"
            }
        }
    }

    Component.onCompleted: {
        micProc.running = true
        micLevelProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Left click: toggle mute
        onClicked: {
            Quickshell.execDetached(["bash", "-c", "$HOME/.dotfiles/asahi/bin/asahi-media-control input mute-toggle"])
        }

        // Scroll wheel: adjust microphone volume
        onWheel: (wheel) => {
            const direction = wheel.angleDelta.y > 0 ? "raise" : "lower"
            Quickshell.execDetached(["bash", "-c", "$HOME/.dotfiles/asahi/bin/asahi-media-control input-volume " + direction])
        }
    }
}
