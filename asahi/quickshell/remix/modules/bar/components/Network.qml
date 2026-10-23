import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"
import "../../../services" as Services
import "../BarModel.js" as BarModel

// Underlay icon (wifi / ethernet) plus a same-size VPN glyph and uptime, from the shared BarData
// (one nmcli monitor for every bar). Full overview lives in the launcher's Quick > Network (click).
Item {
    id: root

    property var barHost: null

    implicitWidth: content.implicitWidth + 6
    implicitHeight: Style.barHeight

    readonly property string text: Services.BarData.netText
    readonly property bool vpnUp: Services.BarData.vpnUp
    readonly property int vpnSince: Services.BarData.vpnSince
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
