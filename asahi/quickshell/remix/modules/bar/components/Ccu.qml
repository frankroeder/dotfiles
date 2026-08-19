import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../"

// Compact CCu chip (credit used) — quota remaining overview on click.
Rectangle {
    id: root

    readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

    color: ccuMouse.containsMouse || popup.shouldShow ? Style.barHoverBg : Style.barBg
    radius: Style.radius
    border.width: 1
    border.color: ccuMouse.containsMouse || popup.shouldShow ? Style.barHoverBorder : Style.barBorder
    scale: ccuMouse.containsMouse || popup.shouldShow ? 1.018 : 1.0
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    implicitWidth: Math.max(68, row.implicitWidth + 14)
    implicitHeight: 26
    visible: available

    property bool available: true
    property var usedPct: null
    property bool hasError: false
    property var rows: []
    property var links: []
    property string tooltip: ""
    property double lastFetch: 0

    readonly property bool hasValue: usedPct !== null && usedPct !== undefined
    readonly property string valueText: {
        if (hasError && !hasValue)
            return "?"
        if (hasValue)
            return Math.round(usedPct) + "%"
        return "··"
    }
    readonly property color valueColor: {
        if (hasError && !hasValue)
            return Style.red
        return usageColor(usedPct)
    }

    function usageColor(used) {
        if (used === null || used === undefined)
            return Style.textMuted
        if (used >= 90)
            return Style.red
        if (used >= 75)
            return Style.orange
        if (used >= 50)
            return Style.yellow
        return Style.teal
    }

    function rowAccent(row) {
        const accent = (row && row.accent) || (row && row.id) || ""
        if (accent === "session" || accent === "total")
            return Style.mauve
        if (accent === "weekly")
            return Style.blue
        if (accent === "grok")
            return Style.teal
        if (accent === "today")
            return Style.orange
        if (accent === "week")
            return Style.green
        if (accent === "month")
            return Style.lavender
        return Style.textAlt
    }

    function rowFill(row) {
        if (!row || row.no_bar)
            return 0
        if (row.kind === "cost")
            return Math.max(0, Math.min(1, (Number(row.percent) || 0) / 100))
        return Math.max(0, Math.min(1, (Number(row.remaining) || 0) / 100))
    }

    function rowValueColor(row) {
        if (row && row.error)
            return Style.red
        if (row && row.kind === "cost")
            return Style.text
        return usageColor(row ? row.used : null)
    }

    function refresh() {
        if (ccuProc.running)
            return
        const now = Date.now()
        if (root.lastFetch > 0 && now - root.lastFetch < 15000)
            return
        root.lastFetch = now
        ccuProc.running = true
    }

    function apply(data) {
        root.available = data.visible !== false
        root.usedPct = (data.percentage === null || data.percentage === undefined) ? null : data.percentage
        root.hasError = !!data.error
        root.rows = data.rows || []
        root.links = data.links || []
        root.tooltip = data.tooltip || ""
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: "CCu"
            font { family: Style.fontFamily; pixelSize: 12; bold: true }
            color: Style.textAlt
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            text: root.valueText
            font { family: Style.fontFamily; pixelSize: 17 }
            color: root.valueColor
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Process {
        id: ccuProc
        command: ["/usr/bin/python3", binDir + "/asahi-ccu"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.apply(JSON.parse(text.trim()))
                } catch (e) {
                    root.hasError = true
                }
            }
        }
    }

    Timer {
        id: pollTimer
        interval: popup.shouldShow ? 45000 : 90000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.lastFetch = 0
            root.refresh()
        }
    }

    MouseArea {
        id: ccuMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            popup.shouldShow = !popup.shouldShow
            if (popup.shouldShow) {
                root.lastFetch = 0
                root.refresh()
            }
        }
    }

    PopupWindow {
        id: popup
        property bool shouldShow: false
        visible: shouldShow
        color: "transparent"
        anchor.item: root
        anchor.edges: Edges.Bottom

        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight

        Rectangle {
            id: card
            anchors.fill: parent
            color: Style.surface
            border.color: Style.barBorder
            border.width: 1
            radius: Style.radius
            implicitWidth: col.implicitWidth + 20
            implicitHeight: col.implicitHeight + 20

            Column {
                id: col
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 5
                // title 88 + gap 8 + bar 72 + gap 8 + spark 72 + gap 8 + value 120
                width: 376

                Repeater {
                    model: root.rows
                    Column {
                        required property var modelData
                        width: col.width
                        spacing: 0

                        Text {
                            visible: (modelData.kind || "") === "div"
                            width: col.width
                            height: 18
                            text: modelData.title || ""
                            font { family: Style.fontFamily; pixelSize: 10; bold: true }
                            color: Style.textMuted
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Row {
                            id: metricRow
                            visible: (modelData.kind || "") !== "div"
                            width: col.width
                            height: 18
                            spacing: 10
                            readonly property var row: modelData

                            Text {
                                width: 88
                                height: parent.height
                                text: metricRow.row.title || ""
                                font { family: Style.fontFamily; pixelSize: 11; bold: true }
                                color: root.rowAccent(metricRow.row)
                                elide: Text.ElideRight
                                clip: true
                                verticalAlignment: Text.AlignVCenter
                            }

                            Item {
                                width: 72
                                height: parent.height
                                clip: true
                                Rectangle {
                                    width: 72
                                    height: 6
                                    radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: metricRow.row.no_bar ? 0 : 1
                                    color: Qt.alpha(root.rowAccent(metricRow.row), 0.22)
                                    Rectangle {
                                        width: parent.width * root.rowFill(metricRow.row)
                                        height: parent.height
                                        radius: 3
                                        color: root.rowAccent(metricRow.row)
                                    }
                                }
                            }

                            Item {
                                width: 72
                                height: parent.height
                                clip: true
                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Repeater {
                                        model: metricRow.row.spark_levels || []
                                        Item {
                                            required property int modelData
                                            width: 6
                                            height: 14
                                            Rectangle {
                                                width: 6
                                                height: 3 + parent.modelData * 3
                                                radius: 1
                                                anchors.bottom: parent.bottom
                                                color: root.rowAccent(metricRow.row)
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                width: 114
                                height: parent.height
                                text: metricRow.row.label || "—"
                                font { family: Style.fontFamily; pixelSize: 11 }
                                color: root.rowValueColor(metricRow.row)
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                clip: true
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.links.length > 0
                    width: col.width
                    height: 1
                    color: Style.barBorder
                    opacity: 0.5
                }

                Row {
                    visible: root.links.length > 0
                    spacing: 14
                    Repeater {
                        model: root.links
                        Text {
                            required property var modelData
                            text: "↗  " + (modelData.title || "")
                            font { family: Style.fontFamily; pixelSize: 11 }
                            color: linkMa.containsMouse ? Style.sky : Style.textMuted

                            MouseArea {
                                id: linkMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.url)
                                        Quickshell.execDetached(["xdg-open", modelData.url])
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
