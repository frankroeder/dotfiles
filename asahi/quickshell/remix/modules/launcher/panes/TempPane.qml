import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Bluetooth
import "../../menu" as Menu
import "../../../"
import "../quick_models.js" as QuickModels
import "../temp_display.js" as TempDisplay
import "../launcher_layout.js" as LauncherGeom

// Temperatures pane: sensor groups from asahi-temperature.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, launcherGeom, quickMode, quickPaneKey, binDir, ...).
// M3 look (caelestia Performance): hero card with the hottest sensor as a ring gauge, group cards with heat bars.
Item {
  property var root
  id: quickTempRoot
  anchors.fill: parent
  // full port of temp: parse/groups/hottest/bars/color/percent/proc/timer/UI (exact old, guards, live)
  property string tempOutput: ""
  property var tempSensors: []
  property var tempGroups: []
  property var tempRows: []
  property var hottestSensor: null
  property string tempUpdated: ""

  function parseTemperatures(out) {
    const parsed = TempDisplay.parseTemperatures(out)
    quickTempRoot.tempSensors = parsed.sensors
    quickTempRoot.tempGroups = parsed.groups
    quickTempRoot.tempRows = TempDisplay.tempDisplayRows(parsed.groups)
    quickTempRoot.hottestSensor = parsed.hottest
    quickTempRoot.tempUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
  }
  function tempColor(value) {
    if (value >= 70) return Style.red
    if (value >= 55) return Style.orange
    if (value >= 45) return Style.yellow
    return Style.green
  }
  function tempPercent(value) { return Math.max(0, Math.min(1, (value - 25) / 55)) }
  function groupGlyph(title) {
    const t = String(title || "").toLowerCase()
    if (t.indexOf("nvme") >= 0) return "󰋊"
    if (t.indexOf("battery") >= 0) return "󰁹"
    if (t.indexOf("speaker") >= 0) return "󰓃"
    if (t.indexOf("smc") >= 0) return "󰘚"
    return "󰔏"
  }

  Process {
    id: tProc
    command: [root.binDir + "/asahi-temperature"]
    stdout: StdioCollector {
      onStreamFinished: {
        quickTempRoot.tempOutput = (text || "").trim()
        quickTempRoot.parseTemperatures(quickTempRoot.tempOutput)
      }
    }
  }
  Timer {
    interval: 2500; running: root.quickMode && root.quickPaneKey === "temp"; repeat: true; triggeredOnStart: true
    onTriggered: if (!tProc.running) tProc.running = true
  }

  Component.onCompleted: Qt.callLater(function(){ if (!tProc.running) tProc.running = true })

  // Full-round fact chip: glyph + text on a tonal container.
  component Chip: Rectangle {
    property string icon: ""
    property string label: ""
    property color bg: Style.m3secondaryContainer
    implicitWidth: chipRow.implicitWidth + 22; implicitHeight: chipRow.implicitHeight + 12
    radius: Style.menuRadiusFull; color: bg
    Row {
      id: chipRow; anchors.centerIn: parent; spacing: 6
      Text {
        visible: icon !== ""; text: icon; color: Style.m3onSurface
        font.family: root.uiFont; font.pixelSize: root.fontPx(11); anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: label; color: Style.m3onSurface
        font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // Sensor row: name + description, thin heat bar, °C value coloured by heat.
  component SensorRow: RowLayout {
    property string name: ""
    property string desc: ""
    property real value: 0
    spacing: 12
    ColumnLayout {
      Layout.fillWidth: true; Layout.preferredWidth: 3; spacing: 0
      Text {
        Layout.fillWidth: true; visible: name !== ""; text: name; color: Style.m3onSurface
        font.family: root.uiSans; font.pixelSize: root.fontPx(11); elide: Text.ElideRight
      }
      Text {
        Layout.fillWidth: true; visible: desc !== ""; text: desc; color: Style.m3onSurfaceVariant
        font.family: root.uiSans; font.pixelSize: root.fontPx(9); elide: Text.ElideRight
      }
    }
    Rectangle {
      Layout.fillWidth: true; Layout.preferredWidth: 2; height: 6; radius: 3; color: Style.m3containerHigh
      Rectangle {
        width: parent.width * quickTempRoot.tempPercent(value); height: parent.height; radius: parent.radius
        color: quickTempRoot.tempColor(value)
        Behavior on width { Menu.MenuAnim {} }
      }
    }
    Text {
      Layout.preferredWidth: Math.round(root.fontPx(12) * 3.6); horizontalAlignment: Text.AlignRight
      text: value.toFixed(1) + "°C"; color: quickTempRoot.tempColor(value)
      font.family: root.uiSans; font.pixelSize: root.fontPx(12); font.weight: Font.DemiBold
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

    // Hero: hottest sensor ring gauge + summary chips.
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: heroRow.implicitHeight + 28
      radius: Style.menuPanelRadius
      color: Style.m3container
      RowLayout {
        id: heroRow
        anchors.fill: parent
        anchors.margins: 14
        spacing: 18
        Menu.MenuHudDial {
          readonly property real hot: quickTempRoot.hottestSensor ? quickTempRoot.hottestSensor.value : 0
          Layout.preferredWidth: 118; Layout.preferredHeight: 118
          value: Math.max(0, Math.min(100, hot))
          accent: quickTempRoot.hottestSensor ? quickTempRoot.tempColor(hot) : Style.m3outline
          label: "Hottest"
          icon: "󰔏"
          suffix: "°"
          fontFamily: root.uiFont
          labelFamily: root.uiSans
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text {
            Layout.fillWidth: true
            text: quickTempRoot.hottestSensor ? quickTempRoot.hottestSensor.value.toFixed(1) + "°C"
              : (quickTempRoot.tempOutput ? "No sensors parsed" : "Loading sensors…")
            color: quickTempRoot.hottestSensor ? quickTempRoot.tempColor(quickTempRoot.hottestSensor.value) : Style.m3onSurfaceVariant
            font.family: root.uiSans; font.pixelSize: root.fontPx(26); font.weight: Font.DemiBold
          }
          Text {
            Layout.fillWidth: true
            visible: !!quickTempRoot.hottestSensor
            readonly property var hs: quickTempRoot.hottestSensor
            text: hs ? (hs.groupDisplayName || hs.group) + "  ·  " + hs.displayLabel : ""
            color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(12); font.weight: Font.Medium; elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            visible: !!quickTempRoot.hottestSensor && !!quickTempRoot.hottestSensor.desc
            text: quickTempRoot.hottestSensor ? quickTempRoot.hottestSensor.desc : ""
            color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(10); elide: Text.ElideRight
          }
          RowLayout {
            Layout.topMargin: 6
            spacing: 8
            Chip { icon: "󰔏"; label: (quickTempRoot.tempSensors || []).length + " sensors"; bg: Style.m3secondaryContainer }
            Chip { icon: "󰕰"; label: (quickTempRoot.tempGroups || []).length + " groups"; bg: Style.m3tertiaryContainer }
            Chip { icon: "󰥔"; label: quickTempRoot.tempUpdated || "asahi-temperature"; bg: Style.m3containerHigh }
          }
        }
      }
    }

    // Sensor groups as cards.
    Flickable {
      id: tempFlick
      Layout.fillWidth: true; Layout.fillHeight: true
      clip: true
      contentHeight: tempCol.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: Menu.MenuScrollBar {}
      Column {
        id: tempCol
        width: tempFlick.width
        spacing: 12
        Repeater {
          model: quickTempRoot.tempRows || []
          delegate: Rectangle {
            required property var modelData
            readonly property bool single: modelData.kind === "item"
            width: parent.width; height: groupCol.implicitHeight + 24
            radius: Style.menuRadiusLg; color: Style.m3container
            ColumnLayout {
              id: groupCol
              anchors.fill: parent; anchors.margins: 12
              spacing: 8
              RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                  width: 30; height: 30; radius: Style.menuRadiusMd
                  color: Style.m3primaryContainer
                  Text {
                    anchors.centerIn: parent; text: quickTempRoot.groupGlyph(modelData.title); color: Style.m3primary
                    font.family: root.uiFont; font.pixelSize: root.fontPx(14)
                  }
                }
                Text {
                  Layout.fillWidth: !single
                  text: modelData.title || ""; color: Style.m3onSurface
                  font.family: root.uiSans; font.pixelSize: root.fontPx(13); font.weight: Font.DemiBold; elide: Text.ElideRight
                }
                // Single-sensor group: the row sits right in the header.
                SensorRow {
                  visible: single && modelData.value !== null && modelData.value !== undefined
                  Layout.fillWidth: true; Layout.leftMargin: 8
                  name: ""; desc: modelData.desc || ""; value: modelData.value || 0
                }
              }
              Repeater {
                model: modelData.sensors || []
                delegate: SensorRow {
                  required property var modelData
                  Layout.fillWidth: true; Layout.leftMargin: 40
                  name: modelData.title || ""; desc: modelData.desc || ""; value: modelData.value
                }
              }
            }
          }
        }
      }
    }
  }
}
