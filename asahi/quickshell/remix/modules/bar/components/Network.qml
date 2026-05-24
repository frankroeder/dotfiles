import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../../"

Rectangle {
    id: root

    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    color: Style.moduleBg
    radius: 6

    implicitWidth: content.implicitWidth + 14
    implicitHeight: 26

    property string icon: "󰤨"
    property string text: "WiFi"
    property string tooltip: ""

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 2

        Text {
            text: root.text
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 30
            color: Style.blueAlt
        }
    }

    Process {
        id: netProc
        command: ["bash", binDir + "/asahi-network"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.text = data.text || "󰤮"
                    root.tooltip = data.tooltip || ""
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }

    Component.onCompleted: netProc.running = true

    MouseArea {
        id: ma
        anchors.fill: parent
        anchors.margins: -12   // much larger hit area so hover and click are reliable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property var networkPopup: null

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Quickshell.execDetached([binDir + "/asahi-network-menu"])
            } else {
                if (!networkPopup) {
                    const mon = Hyprland.focusedMonitor
                    const scr = mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
                    networkPopup = Qt.createComponent("NetworkPopupWindow.qml").createObject(root, {screen: scr})
                }
                networkPopup.shouldShow = !networkPopup.shouldShow
            }
        }
    }

    TooltipWindow {
        target: root
        text: root.tooltip
        show: ma.containsMouse
        maxWidth: 380
    }
}
