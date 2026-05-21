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

    property string icon: "󰤨"
    property string text: "WiFi"
    property string tooltip: ""

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 2

        // Use only the script-provided text (already contains nice icon)
        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 22   // matches waybar #network { font-size: 23px }
            color: "#89b4fa"
        }
    }

    Process {
        id: netProc
        command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-network"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.text = data.text || "󰤮"
                    root.tooltip = data.tooltip || ""
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

    Component.onCompleted: netProc.running = true

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -12   // much larger hit area so hover and click are reliable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            // Click on Wifi symbol → open nmtui (in terminal)
            Quickshell.execDetached(["foot", "-e", "nmtui"])
        }
    }

    TooltipWindow {
        target: root
        text: root.tooltip
        show: ma.containsMouse
        maxWidth: 380
    }
}
