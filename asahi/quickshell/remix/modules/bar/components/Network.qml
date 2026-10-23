import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"
import "../../../services" as Services

// Underlay icon (wifi / ethernet, drawn larger: its glyph reads small) plus the VPN glyph while one is up, from the shared BarData
// (one nmcli monitor for every bar). Full overview lives in the launcher's Quick > Network (click).
Item {
    id: root

    property var barHost: null

    implicitWidth: content.implicitWidth + 6
    implicitHeight: Style.barHeight

    readonly property string text: Services.BarData.netText
    readonly property bool vpnUp: Services.BarData.vpnUp

    HoverTint { lit: chipMouse.containsMouse }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: root.text
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontGlyph + 3
            color: Style.blueAlt
        }

        Text {
            visible: root.vpnUp
            text: "󰯄"
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontGlyph
            color: Style.green
        }
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
