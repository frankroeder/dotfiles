import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"
import "../BarModel.js" as BarModel

// Underlay icon (wifi / ethernet) plus a same-size VPN glyph and uptime.
// Full overview lives in the launcher's Quick > Network.
Rectangle {
    id: root

    property var barHost: null
    readonly property bool solidBar: barHost !== null && barHost !== undefined

    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    color: solidBar ? "transparent" : (ma.containsMouse ? Style.barHoverBg : Style.barBg)
    radius: solidBar ? 0 : Style.radius
    border.width: solidBar ? 0 : 1
    border.color: solidBar ? "transparent" : Style.barBorder
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    scale: solidBar ? 1.0 : (ma.containsMouse ? 1.018 : 1.0)

    implicitWidth: content.implicitWidth + (solidBar ? 8 : 14)
    implicitHeight: solidBar ? Style.barHeight : 26

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Style.barChipInset
        anchors.bottomMargin: Style.barChipInset
        radius: Style.radiusSm
        visible: solidBar
        color: ma.containsMouse ? Style.barStripHover : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    property string text: "󰤨"
    property string tooltip: ""
    property bool vpnUp: false
    property int vpnSince: 0
    property int nowTick: 0

    readonly property string vpnAge: {
        nowTick
        return BarModel.formatAge(root.vpnSince, Date.now() / 1000)
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.text
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontGlyph
            color: Style.blueAlt
        }

        Text {
            visible: root.vpnUp
            text: "󰯄"
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontGlyph
            color: Style.green
        }

        Text {
            visible: root.vpnUp && root.vpnAge !== ""
            text: root.vpnAge
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontCaption
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
                    root.vpnSince = Number(data.vpnSince) || 0
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

    Timer {
        interval: 15000
        running: root.vpnUp
        repeat: true
        triggeredOnStart: true
        onTriggered: root.nowTick++
    }

    Component.onCompleted: netProc.running = true

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -2
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
