import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"

Rectangle {
    id: root

    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    color: volumeMouse.containsMouse ? Style.barHoverBg : Style.barBg
    radius: Style.radius
    border.width: 1
    border.color: volumeMouse.containsMouse ? Style.barHoverBorder : Style.barBorder
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    scale: volumeMouse.containsMouse ? 1.018 : 1.0
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    implicitWidth: content.implicitWidth + 14
    implicitHeight: 26

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

    Timer {
        id: refreshDelay
        interval: 250
        onTriggered: audioProc.running = true
    }

    MouseArea {
        id: volumeMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            Quickshell.execDetached(["bash", "-c", binDir + "/asahi-media-control output-volume mute-toggle"])
            refreshDelay.restart()
        }

        onWheel: (wheel) => {
            const direction = wheel.angleDelta.y > 0 ? "raise" : "lower"
            Quickshell.execDetached(["bash", "-c", binDir + "/asahi-media-control output-volume " + direction])
            refreshDelay.restart()
        }
    }
}
