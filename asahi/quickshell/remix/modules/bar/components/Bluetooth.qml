import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: 30

    property string icon: ""
    property string text: "BT"

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: "#cba6f7"
        }

        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: "#cdd6f4"
            elide: Text.ElideRight
            Layout.maximumWidth: 80
        }
    }

    Process {
        id: btProc
        command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-bluetooth"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.text = data.text || "BT"
                    if (data.text && data.text.includes("on")) root.icon = "󰂯"
                    else root.icon = "󰂲"
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: btProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-bluetooth-menu"])
            } else {
                Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-launch-bluetooth"])
            }
        }
    }
}
