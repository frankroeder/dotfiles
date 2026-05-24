import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"

Rectangle {
    id: root

    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    color: Style.moduleBg
    radius: 6

    implicitWidth: content.implicitWidth + 14
    implicitHeight: 26

    property string icon: "󰕾"
    property string text: "--%"
    property bool muted: false

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 2

        // Script already provides icon + percentage (e.g. "󰕿 15%")
        // Show only one symbol, bigger
        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 17
            color: root.muted ? Style.red : Style.green
        }
    }

    Process {
        id: audioProc
        command: ["bash", binDir + "/asahi-audio", "output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    // Prefer the script's text (it already includes the correct icon for muted state, like waybar)
                    root.text = data.text || (root.muted ? "󰖁 --%" : "󰕾 --%")
                    root.muted = (data.class || []).includes("muted") || (data.text || "").includes("muted")
                } catch (e) {
                    root.text = root.muted ? "󰖁 --%" : "󰕾 --%"
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: audioProc.running = true
    }

    Component.onCompleted: audioProc.running = true

    MouseArea {
        id: volMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        // Left click: toggle mute
        onClicked: {
            Quickshell.execDetached(["bash", "-c", binDir + "/asahi-media-control output-volume mute-toggle"])
        }

        // Scroll wheel: adjust volume
        onWheel: (wheel) => {
            const direction = wheel.angleDelta.y > 0 ? "raise" : "lower"
            Quickshell.execDetached(["bash", "-c", binDir + "/asahi-media-control output-volume " + direction])
        }
    }
}
