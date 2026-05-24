import QtQuick
import QtQuick.Layouts
import "../../../"

// Simple Status Indicators (caffeine, DND, etc.)
// Placeholder that can be expanded with real IdleInhibitor / Notifs logic later
RowLayout {
    id: root
    spacing: 6

    // Example: Caffeine indicator
    Rectangle {
        width: 18
        height: 18
        radius: Style.radiusSm
        color: Style.moduleBg
        visible: false   // enable when we wire real logic

        Text {
            anchors.centerIn: parent
            text: "󰅶"
            font.family: Style.fontFamily
            font.pixelSize: 14
            color: Style.green
        }
    }

    // Example: DND indicator
    Rectangle {
        width: 18
        height: 18
        radius: Style.radiusSm
        color: Style.moduleBg
        visible: false

        Text {
            anchors.centerIn: parent
            text: "󰂛"
            font.family: Style.fontFamily
            font.pixelSize: 14
            color: Style.yellow
        }
    }
}
