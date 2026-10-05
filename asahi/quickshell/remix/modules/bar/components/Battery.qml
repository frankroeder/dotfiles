import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../../../"

// UPower changes run asahi-battery (60 s fallback poll). Click: Quick > Battery.
Item {
    id: root

    property var barHost: null
    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    implicitWidth: row.implicitWidth + 6
    implicitHeight: Style.barHeight

    property int percentage: 0
    property string iconGlyph: "󰁹"
    property string levelText: ""

    function parseBatteryPayload(raw) {
        try {
            const data = JSON.parse(raw.trim())
            root.percentage = typeof data.percentage === "number" ? data.percentage : 0
            const text = data.text || ""
            const iconMatch = text.match(/^(.+?)\s+(\d+)%/)
            if (iconMatch) {
                root.iconGlyph = iconMatch[1].trim()
                root.levelText = iconMatch[2] + "%"
            } else if (typeof data.percentage === "number") {
                root.levelText = data.percentage + "%"
            }
        } catch (e) {}
    }

    HoverTint { lit: chipMouse.containsMouse }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.iconGlyph
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontMicVolIcon
            color: root.percentage <= 10 ? Style.red : (root.percentage <= 20 ? Style.orange : Style.green)
        }

        Text {
            text: root.levelText
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontBody
            color: barHost ? barHost.barForeground : Style.text
        }
    }

    function refresh() { if (!batProc.running) batProc.running = true }

    Process {
        id: batProc
        command: [binDir + "/asahi-battery"]
        stdout: StdioCollector {
            onStreamFinished: root.parseBatteryPayload(text)
        }
    }

    Connections {
        target: UPower.displayDevice
        ignoreUnknownSignals: true
        function onPercentageChanged() { root.refresh() }
        function onStateChanged() { root.refresh() }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.barHost) root.barHost.quickRequested("battery")
    }
}
