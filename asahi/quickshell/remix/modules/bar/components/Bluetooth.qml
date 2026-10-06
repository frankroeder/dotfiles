import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../../../"

// BlueZ adapter state (no polling). Click: Quick > Bluetooth.
Item {
    id: root

    property var barHost: null

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: !!(adapter && adapter.enabled)
    readonly property bool anyConnected: {
        const devs = (Bluetooth.devices && Bluetooth.devices.values) ? Bluetooth.devices.values : []
        for (let i = 0; i < devs.length; i++) if (devs[i] && devs[i].connected) return true
        return false
    }

    implicitWidth: row.implicitWidth + 6
    implicitHeight: Style.barHeight

    HoverTint { lit: chipMouse.containsMouse }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Text {
            text: !root.powered ? "󰂲" : (root.anyConnected ? "󰂱" : "󰂯")
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontMicVolIcon
            color: Style.magenta
        }
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.barHost) root.barHost.quickRequested("bluetooth")
    }
}
