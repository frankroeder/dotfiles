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
    property string device: ""
    property real rxSpeed: 0
    property real txSpeed: 0
    property real previousRxBytes: -1
    property real previousTxBytes: -1
    property real previousSampleMs: 0

    function formatSpeed(bytes) {
        let unit = "K"
        let value = bytes / 1024
        if (value >= 1024) {
            unit = "M"
            value /= 1024
        }
        if (value >= 1024) {
            unit = "G"
            value /= 1024
        }
        return Math.min(999, Math.round(value)).toString().padStart(3, "0") + " " + unit
    }

    function refreshSpeed() {
        if (root.device === "" || speedProc.running) return
        speedProc.command = [
            "cat",
            "/sys/class/net/" + root.device + "/statistics/rx_bytes",
            "/sys/class/net/" + root.device + "/statistics/tx_bytes"
        ]
        speedProc.running = true
    }

    function updateSpeed(text) {
        const values = text.trim().split(/\s+/)
        if (values.length < 2) return

        const now = Date.now()
        const rxBytes = Number(values[0])
        const txBytes = Number(values[1])
        const seconds = (now - root.previousSampleMs) / 1000

        if (root.previousSampleMs > 0 && seconds > 0) {
            root.rxSpeed = Math.max(0, (rxBytes - root.previousRxBytes) / seconds)
            root.txSpeed = Math.max(0, (txBytes - root.previousTxBytes) / seconds)
        }

        root.previousRxBytes = rxBytes
        root.previousTxBytes = txBytes
        root.previousSampleMs = now
    }

    onDeviceChanged: {
        root.rxSpeed = 0
        root.txSpeed = 0
        root.previousSampleMs = 0
        root.refreshSpeed()
    }

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

        Column {
            spacing: -4

            Text {
                text: "↑ " + root.formatSpeed(root.txSpeed)
                font.family: Style.fontFamily
                font.pixelSize: 11
                color: root.txSpeed >= 1024 ? Style.green : Style.textMuted
            }

            Text {
                text: "↓ " + root.formatSpeed(root.rxSpeed)
                font.family: Style.fontFamily
                font.pixelSize: 11
                color: root.rxSpeed >= 1024 ? Style.blueAlt : Style.textMuted
            }
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
                    root.device = data.device || ""
                } catch (e) {}
            }
        }
    }

    Process {
        id: speedProc
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: root.updateSpeed(text)
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.refreshSpeed()
    }

    Component.onCompleted: {
        netProc.running = true
        root.refreshSpeed()
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -12   // much larger hit area so hover and click are reliable
        hoverEnabled: true
    }

    TooltipWindow {
        target: root
        text: root.tooltip + "\nUpload: " + root.formatSpeed(root.txSpeed) + "/s\nDownload: " + root.formatSpeed(root.rxSpeed) + "/s"
        show: ma.containsMouse
        maxWidth: 380
    }
}
