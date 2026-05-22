import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland as Hypr
import ".." as Remix

PanelWindow {
    id: root

    property bool shouldShow: false
    property string query: ""
    property int selectedIndex: 0

    readonly property color cSurface: "#1a1b26"
    readonly property color cSurfaceContainer: "#313244"
    readonly property color cPrimary: "#7aa2f7"
    readonly property color cText: "#a9b1d6"
    readonly property color cSubText: "#6c7086"
    readonly property color cBorder: "#45475a"

    readonly property var terminalCommand: ["foot"]

    readonly property var actionEntries: [
        { id: "action-terminal", name: "Open Terminal", comment: "Launch foot", glyph: "󰆍", type: "action", onTriggered: () => Quickshell.execDetached(terminalCommand) },
        { id: "action-files", name: "Open Files", comment: "Home directory", glyph: "󰉋", type: "action", onTriggered: () => Quickshell.execDetached(["xdg-open", Quickshell.env("HOME")]) },
        { id: "action-screenshots", name: "Screenshots", comment: "Open captures folder", glyph: "󰄄", type: "action", onTriggered: () => {} },
        { id: "action-network", name: "Network", comment: "nm-connection-editor", glyph: "󰖩", type: "action", onTriggered: () => Quickshell.execDetached(["nm-connection-editor"]) }
    ]

    readonly property var favoriteApps: []

    readonly property var appEntries: {
        const apps = DesktopEntries.applications.values ?? []
        const q = query.trim().toLowerCase()

        function score(entry) {
            const name = (entry.name ?? "").toLowerCase()
            if (!q.length) return 100
            if (name === q) return 1000
            if (name.startsWith(q)) return 900
            if (name.includes(q)) return 680
            return 0
        }

        return apps
            .map(entry => ({ entry, rank: score(entry) }))
            .filter(item => item.rank > 0)
            .sort((a, b) => b.rank - a.rank || a.entry.name.localeCompare(b.entry.name))
            .slice(0, 12)
            .map(item => item.entry)
    }

    readonly property var visibleEntries: {
        const q = query.trim()
        if (q.startsWith(">")) {
            const aq = q.slice(1).trim().toLowerCase()
            return actionEntries.filter(e => !aq.length || e.name.toLowerCase().includes(aq) || e.comment.toLowerCase().includes(aq))
        }
        return appEntries.length > 0 ? appEntries : (DesktopEntries.applications.values ?? []).slice(0, 12)
    }

    function closeLauncher() {
        shouldShow = false
        query = ""
        selectedIndex = 0
    }

    function launchEntry(entry) {
        if (!entry) return
        if (entry.type === "action") {
            entry.onTriggered()
            closeLauncher()
            return
        }
        Quickshell.execDetached(entry.command ?? [entry.execString])
        closeLauncher()
    }

    // Show launcher on the currently focused monitor
    screen: {
        const mon = Hypr.Hyprland.focusedMonitor
        if (!mon) return Quickshell.screens[0]
        return Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]
    }

    anchors {
        top: true
        left: true
    }
    margins {
        top: 60
        left: Math.max(0, Math.round((screen.width - 420) / 2))
    }
    implicitWidth: 420
    implicitHeight: shouldShow ? contentColumn.implicitHeight + 32 : 0
    color: "transparent"
    visible: shouldShow || (content.opacity > 0)

    WlrLayershell.keyboardFocus: shouldShow ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    FocusScope {
        id: content
        anchors.fill: parent
        opacity: shouldShow ? 1 : 0
        scale: shouldShow ? 1 : 0.96
        focus: shouldShow

        Keys.onEscapePressed: closeLauncher()
        Keys.onDownPressed: selectedIndex = Math.min(selectedIndex + 1, visibleEntries.length - 1)
        Keys.onUpPressed: selectedIndex = Math.max(selectedIndex - 1, 0)
        Keys.onReturnPressed: launchEntry(visibleEntries[selectedIndex])

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 200 } }

        Rectangle {
            anchors.fill: parent
            color: cSurface
            radius: 16
            border.color: cBorder
            border.width: 1

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // Search bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: 12
                    color: cSurfaceContainer
                    border.color: cBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Text {
                            text: query.startsWith(">") ? "󰘳" : "󰍉"
                            font.family: "Material Design Icons"
                            font.pixelSize: 18
                            color: cPrimary
                        }

                        QQC.TextField {
                            id: searchField
                            Layout.fillWidth: true
                            color: cText
                            font.pixelSize: 14
                            placeholderText: "Search or type > for actions"
                            placeholderTextColor: cSubText
                            background: Item {}
                            onTextChanged: {
                                root.query = text
                                selectedIndex = 0
                            }
                        }
                    }
                }

                // Results
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(400, list.implicitHeight)
                    clip: true
                    contentHeight: list.implicitHeight

                    Column {
                        id: list
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: visibleEntries

                            Rectangle {
                                required property var modelData
                                required property int index

                                width: list.width
                                height: 48
                                radius: 10
                                color: selectedIndex === index ? Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.15) : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 10

                                    Text {
                                        text: modelData.type === "action" ? (modelData.glyph ?? "󰣆") : (modelData.name ?? "?").charAt(0)
                                        font.pixelSize: 16
                                        color: cPrimary
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: modelData.name ?? "Unknown"
                                            color: cText
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: modelData.comment || ""
                                            color: cSubText
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: launchEntry(modelData)
                                    onEntered: selectedIndex = index
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function openLauncher() {
        shouldShow = true
        selectedIndex = 0
        Qt.callLater(() => searchField.forceActiveFocus())
    }
}
