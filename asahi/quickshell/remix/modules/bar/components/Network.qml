import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"

Rectangle {
    id: root

    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    color: ma.containsMouse ? Style.hoverBg : Style.moduleBg
    radius: Style.radius
    border.width: 1
    border.color: Style.border

    implicitWidth: content.implicitWidth + 14
    implicitHeight: 26

    property string icon: "󰤨"
    property string text: "WiFi"
    property string tooltip: ""

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 2

        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 30
            color: Style.blueAlt
        }
    }

    Process {
        id: netProc
        command: ["bash", binDir + "/asahi-network"]
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
    }

    TooltipWindow {
        target: root
        text: root.tooltip
        show: ma.containsMouse
        maxWidth: 380
    }
}
