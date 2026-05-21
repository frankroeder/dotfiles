import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    color: "#313244"   // dark background like waybar @surface0 modules
    radius: 6

    implicitWidth: row.implicitWidth + 14
    implicitHeight: 26

    property string text: "Bat --%"
    property string tooltip: ""

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 20

        // Script already includes the battery symbol (e.g. "󰂋 87%")
        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 17   // consistent with other widgets after waybar alignment
            color: "#a6e3a1"
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
                    root.tooltip = data.tooltip || ""
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
        id: batMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["$HOME/.dotfiles/asahi/bin/asahi-battery-menu"])
    }

    // Full rich tooltip on hover (same pattern as CPU/Memory)
    TooltipWindow {
        target: root
        text: root.tooltip
        show: batMa.containsMouse
        maxWidth: 380
    }
}
