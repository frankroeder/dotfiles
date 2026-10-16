import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../../../"
import "../../../services" as Services

// BlueZ adapter state (no polling). A visible peripheral at or below its alert threshold
// (asahi-bluetooth-monitor, any connection) shows that device's glyph instead: orange low, red critical.
// Click: Quick > Bluetooth; right-click: rescan now (upstream's refresh). Tooltip: upstream's battery list (pane setting).
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
    readonly property var alert: Services.BtMonitor.alert
    readonly property bool warn: alert.state === "low" || alert.state === "critical"

    implicitWidth: row.implicitWidth + 6
    implicitHeight: Style.barHeight

    HoverTint { lit: chipMouse.containsMouse }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Text {
            text: root.warn ? Services.BtMonitor.kindGlyph(root.alert.kind) : (!root.powered ? "󰂲" : (root.anyConnected ? "󰂱" : "󰂯"))
            font.family: Style.fontFamily
            font.pixelSize: Style.barFontMicVolIcon
            color: root.alert.state === "critical" ? Style.red : (root.warn ? Style.orange : (root.powered ? Style.magenta : Style.textMuted))
        }
    }

    // Upstream's per-device battery list, on unless switched off in the pane's settings.
    TooltipWindow {
        target: root
        barHeight: root.barHost ? root.barHost.notchFloor : Style.barHeight
        text: Services.BtMonitor.tooltipText
        show: chipMouse.containsMouse
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) Services.BtMonitor.refresh()
            else if (root.barHost) root.barHost.quickRequested("bluetooth")
        }
    }
}
