import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"
import "../../../services" as Services
import "../BarModel.js" as BarModel

// Wi-Fi / ethernet glyph (drawn larger: its glyph reads small) and the VPN shield while one is up, from the shared
// BarData (one nmcli monitor for every bar). BarHost grants the optional words when they fit: the VPN's name, its
// uptime, the network's name. Full overview lives in the launcher's Quick > Network (click).
Item {
    id: root

    property var barHost: null
    property bool showName: false
    property bool showVpnName: false
    property bool showVpnAge: false

    readonly property string text: Services.BarData.netText
    readonly property string netName: Services.BarData.netName
    readonly property bool vpnUp: Services.BarData.vpnUp
    readonly property string vpnName: Services.BarData.vpnName
    readonly property int vpnSince: Services.BarData.vpnSince
    property int nowTick: 0
    readonly property string vpnAge: {
        nowTick
        return BarModel.formatAge(root.vpnSince, Date.now() / 1000)
    }

    // What each part costs, measured whether shown or not (BarHost decides from these; 4 = the row spacing).
    readonly property real baseWidth: wifiGlyph.implicitWidth + (root.vpnUp ? shield.implicitWidth + 4 : 0) + 6
    readonly property real nameWidth: root.netName !== "" ? nameMetrics.advanceWidth + 4 : 0
    readonly property real vpnNameWidth: root.vpnUp && root.vpnName !== "" ? vpnNameMetrics.advanceWidth + 4 : 0
    readonly property real vpnAgeWidth: root.vpnUp && root.vpnAge !== "" ? ageMetrics.advanceWidth + 4 : 0

    implicitWidth: content.implicitWidth + 6
    implicitHeight: Style.barHeight

    TextMetrics { id: nameMetrics; font: nameText.font; text: root.netName }
    TextMetrics { id: vpnNameMetrics; font: vpnNameText.font; text: root.vpnName }
    TextMetrics { id: ageMetrics; font: ageText.font; text: root.vpnAge }

    HoverTint { lit: chipMouse.containsMouse }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: wifiGlyph
            text: root.text
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontGlyph + 1
            color: Style.blueAlt
        }

        Text {
            id: nameText
            visible: root.showName && root.netName !== ""
            text: root.netName
            textFormat: Text.PlainText
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontCaption
            color: Style.textMuted
        }

        Text {
            id: shield
            visible: root.vpnUp
            text: "󰯄"
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontGlyphTall
            color: Style.green
        }

        Text {
            id: vpnNameText
            visible: root.showVpnName && root.vpnName !== ""
            text: root.vpnName
            textFormat: Text.PlainText
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontCaption
            font.weight: Font.Medium
            color: Style.green
        }

        Text {
            id: ageText
            visible: root.showVpnAge && root.vpnAge !== ""
            text: root.vpnAge
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontCaption
            color: Qt.alpha(Style.green, 0.75)
        }
    }

    Timer {
        interval: 30000
        running: root.vpnUp && root.showVpnAge
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
