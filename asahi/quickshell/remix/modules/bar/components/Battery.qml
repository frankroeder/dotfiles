import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"

Rectangle {
    id: root

    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    color: batMa.containsMouse ? Style.hoverBg : Style.moduleBg
    radius: Style.radius
    border.width: 1
    border.color: Style.border

    implicitWidth: row.implicitWidth + 14
    implicitHeight: 26

    property string text: "Bat --%"
    property string tooltip: ""

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            color: Style.green
        }
    }

    Process {
        id: batProc
        command: ["bash", binDir + "/asahi-battery"]
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
        // Hover + pointer cursor for tooltip (click action removed)
    }

    TooltipWindow {
        target: root
        text: root.tooltip
        show: batMa.containsMouse
        maxWidth: 380
    }
}
