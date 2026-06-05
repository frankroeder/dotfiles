import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"

Rectangle {
    id: root

    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    color: batMa.containsMouse ? Style.barHoverBg : Style.barBg
    radius: Style.radius
    border.width: 1
    border.color: batMa.containsMouse ? Style.barHoverBorder : Style.barBorder
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    scale: batMa.containsMouse ? 1.018 : 1.0
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

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
        onClicked: Quickshell.execDetached(["qs", "-c", "remix", "ipc", "call", "launcher", "openCategory", "Quick"])
    }

    TooltipWindow {
        target: root
        text: root.tooltip
        show: batMa.containsMouse
        maxWidth: 380
    }
}
