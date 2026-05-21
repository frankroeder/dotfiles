import QtQuick
import QtQuick.Layouts

// Simple Status Indicators (caffeine, DND, etc.)
// Placeholder that can be expanded with real IdleInhibitor / Notifs logic later
RowLayout {
    id: root
    spacing: 6

    // Example: Caffeine indicator
    Rectangle {
        width: 18
        height: 18
        radius: 4
        color: "#313244"
        visible: false   // enable when we wire real logic

        Text {
            anchors.centerIn: parent
            text: "󰅶"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: "#a6e3a1"
        }
    }

    // Example: DND indicator
    Rectangle {
        width: 18
        height: 18
        radius: 4
        color: "#313244"
        visible: false

        Text {
            anchors.centerIn: parent
            text: "󰂛"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: "#f9e2af"
        }
    }
}
