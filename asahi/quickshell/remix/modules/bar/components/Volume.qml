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
        spacing: 2

        // Script already provides icon + percentage (e.g. "󰕿 15%")
        // Show only one symbol, bigger
        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 17
            color: root.muted ? "#f38ba8" : "#a6e3a1"
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
                    root.muted = (data.class || []).includes("muted") || (data.text || "").includes("muted")
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
        id: volMa
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property var volPopup: null

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                // Right click: quick mute
                Quickshell.execDetached(["bash", "-c", "$HOME/.dotfiles/asahi/bin/asahi-media-control output mute-toggle"])
            } else {
                // Left click: rich popup
                if (!volPopup) {
                    volPopup = Qt.createComponent("VolumePopupWindow.qml").createObject(root)
                }
                volPopup.shouldShow = !volPopup.shouldShow
            }
        }

        onWheel: (wheel) => {
            const direction = wheel.angleDelta.y > 0 ? "raise" : "lower"
            Quickshell.execDetached(["bash", "-c", "$HOME/.dotfiles/asahi/bin/asahi-media-control output-volume " + direction])
        }
    }
}
