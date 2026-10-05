import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"
import "../BarModel.js" as BarModel

// Underlay icon (wifi / ethernet) plus a same-size VPN glyph and uptime.
// Full overview lives in the launcher's Quick > Network (click).
Item {
    id: root

    property var barHost: null
    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    implicitWidth: content.implicitWidth + 6
    implicitHeight: Style.barHeight

    property string text: "󰤨"
    property bool vpnUp: false
    property int vpnSince: 0
    property int nowTick: 0

    readonly property string vpnAge: {
        nowTick
        return BarModel.formatAge(root.vpnSince, Date.now() / 1000)
    }

    HoverTint { lit: chipMouse.containsMouse }

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

    function refresh() { if (!netProc.running) netProc.running = true }

    Process {
        id: netProc
        command: [binDir + "/asahi-network", "--bar"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.text = data.text || "󰤮"
                    root.vpnUp = !!data.vpn
                    root.vpnSince = Number(data.vpnSince) || 0
                } catch (e) {}
            }
        }
    }

    // nmcli monitor pushes state changes; the slow poll only tracks Wi-Fi signal.
    Process {
        running: true
        // pdeathsig: nmcli dies with qs (a SIGTERMed qs would orphan it).
        command: ["setpriv", "--pdeathsig", "TERM", "nmcli", "monitor"]
        stdout: SplitParser { onRead: changeDebounce.restart() }
    }

    Timer {
        id: changeDebounce
        interval: 500
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 15000
        running: root.vpnUp
        repeat: true
        triggeredOnStart: true
        onTriggered: root.nowTick++
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        anchors.margins: -2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.barHost) root.barHost.quickRequested("network")
    }
}
