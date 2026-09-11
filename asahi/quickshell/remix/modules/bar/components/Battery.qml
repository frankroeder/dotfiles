import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"

Rectangle {
    id: root

    property var barHost: null
    readonly property bool solidBar: barHost !== null && barHost !== undefined

    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    color: solidBar ? "transparent" : (batMa.containsMouse ? Style.barHoverBg : Style.barBg)
    radius: solidBar ? 0 : Style.radius
    border.width: solidBar ? 0 : 1
    border.color: solidBar ? "transparent" : (batMa.containsMouse ? Style.barHoverBorder : Style.barBorder)
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    scale: solidBar ? 1.0 : (batMa.containsMouse ? 1.018 : 1.0)

    implicitWidth: row.implicitWidth + (solidBar ? 8 : 14)
    implicitHeight: solidBar ? Style.barHeight : 26

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Style.barChipInset
        anchors.bottomMargin: Style.barChipInset
        radius: Style.radiusSm
        visible: solidBar
        color: batMa.containsMouse ? Style.barStripHover : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    property string tooltip: ""
    property int percentage: 0
    property string iconGlyph: "󰁹"
    property string levelText: "--%"

    function parseBatteryPayload(raw) {
        try {
            const data = JSON.parse(raw.trim())
            root.tooltip = data.tooltip || ""
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

    Process {
        id: batProc
        command: ["bash", binDir + "/asahi-battery"]
        stdout: StdioCollector {
            onStreamFinished: root.parseBatteryPayload(text)
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
        onClicked: Quickshell.execDetached(["qs", "-c", "remix", "ipc", "call", "launcher", "quick", "battery"])
    }

    TooltipWindow {
        target: root
        text: root.tooltip
        show: batMa.containsMouse
        maxWidth: 380
    }
}
