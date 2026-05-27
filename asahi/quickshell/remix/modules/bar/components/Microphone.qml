import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"

Rectangle {
    id: root

    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    color: micMouse.containsMouse ? Style.hoverBg : Style.moduleBg
    radius: Style.radius
    border.width: 1
    border.color: Style.border

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
            color: root.muted ? Style.red : Style.blueAlt
        }
    }

    Process {
        id: micProc
        command: ["bash", binDir + "/asahi-audio", "input"]
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
        id: micMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Left click: toggle mute
        onClicked: {
            Quickshell.execDetached(["bash", "-c", binDir + "/asahi-media-control input-volume mute-toggle"])
        }

        // Scroll wheel: adjust microphone volume
        onWheel: (wheel) => {
            const direction = wheel.angleDelta.y > 0 ? "raise" : "lower"
            Quickshell.execDetached(["bash", "-c", binDir + "/asahi-media-control input-volume " + direction])
        }
    }
}
