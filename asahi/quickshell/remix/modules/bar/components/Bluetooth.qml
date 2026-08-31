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

    color: solidBar ? "transparent" : (ma.containsMouse ? Style.barHoverBg : Style.barBg)
    radius: solidBar ? 0 : Style.radius
    border.width: solidBar ? 0 : 1
    border.color: solidBar ? "transparent" : Style.barBorder
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    scale: solidBar ? 1.0 : (ma.containsMouse ? 1.018 : 1.0)

    implicitWidth: row.implicitWidth + (solidBar ? 8 : 14)
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

    property string text: "BT"
    property string tooltip: ""

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Text {
            text: root.text
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontGlyph
            color: Style.magenta
        }
    }

    Process {
        id: btProc
        command: [binDir + "/asahi-bluetooth"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.text = data.text || "BT"
                    root.tooltip = data.tooltip || ""
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: btProc.running = true
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "-c", "remix", "ipc", "call", "launcher", "quick", "bluetooth"])
    }

    TooltipWindow {
        target: root
        text: root.tooltip
        show: ma.containsMouse
        maxWidth: 380
    }
}
