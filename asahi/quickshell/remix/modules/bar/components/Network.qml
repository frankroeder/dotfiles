import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"

// Minimal bar widget: underlay icon (wifi / ethernet). VPN is a smaller
// badge beside it — it must not replace the link type. Full overview lives
// in the launcher's Quick > Network.
Rectangle {
    id: root

    property var barHost: null
    readonly property bool solidBar: barHost !== null && barHost !== undefined

    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    color: solidBar
      ? (ma.containsMouse ? Style.barStripHover : "transparent")
      : (ma.containsMouse ? Style.barHoverBg : Style.barBg)
    radius: solidBar ? 0 : Style.radius
    border.width: solidBar ? 0 : 1
    border.color: solidBar ? "transparent" : Style.barBorder
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    scale: solidBar ? 1.0 : (ma.containsMouse ? 1.018 : 1.0)

    implicitWidth: content.implicitWidth + (solidBar ? 8 : 14)
    implicitHeight: solidBar ? Style.barHeight : 26

    property string text: "󰤨"
    property string tooltip: ""
    property bool vpnUp: false

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 2

        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 32
            color: Style.blueAlt
        }

        Text {
            visible: root.vpnUp
            text: "󰯄"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: Style.green
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
                    root.vpnUp = !!data.vpn
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
        onClicked: Quickshell.execDetached(["qs", "-c", "remix", "ipc", "call", "launcher", "quick", "network"])
    }

    TooltipWindow {
        target: root
        text: root.tooltip
        show: ma.containsMouse
        maxWidth: 380
    }
}
