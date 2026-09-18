import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Bluetooth
import "../../menu" as Menu
import "../../../"

// Battery pane: charge, health, power draw.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, launcherGeom, quickMode, quickPaneKey, binDir, ...).
// M3 look (caelestia Performance): hero card with a charge ring gauge, fact chips, key/value facts card.
Item {
  property var root
  id: quickBatteryRoot
  anchors.fill: parent

  property string batIcon: "󰁹"
  property string batStatus: ""
  property int batPercentage: 0
  property var batClass: []
  property var batLines: []
  property string batUpdated: ""
  property string batTimeRemaining: ""
  property bool batHolding: false
  property int batThresholdEnd: 100
  property var smcPower: []

  readonly property var batDetailLines: {
    const lines = quickBatteryRoot.batLines || []
    return lines.filter(function(l) {
      if (!l) return false
      if (l.indexOf("Power:") === 0) return false
      if (l.indexOf("Time to ") === 0) return false
      return true
    })
  }
  // "Key: value | Key: value" tooltip lines → [{k, v}] pairs.
  function factPairs(lines) {
    const out = []
    for (let i = 0; i < (lines || []).length; i++) {
      const parts = lines[i].split("|")
      for (let j = 0; j < parts.length; j++) {
        const idx = parts[j].indexOf(":")
        if (idx > 0) out.push({ k: parts[j].substring(0, idx).trim(), v: parts[j].substring(idx + 1).trim() })
      }
    }
    return out
  }
  function factGlyph(key) {
    const g = { "Energy": "󱐋", "Design": "󰂎", "Health": "󰓙", "Cycles": "󰑐", "Temp": "󰔏", "Voltage": "󰚥", "Current": "󰢝",
      "Charge limits": "󰂅", "Mode": "󰒓", "AC online": "󰚥", "Input limit": "󰚥", "Model": "󰘚", "Mfg": "󰃭", "Power": "󱐋" }
    return g[key] || "󰋼"
  }
  readonly property var batFacts: factPairs(quickBatteryRoot.batDetailLines).filter(function(f) { return f.k.indexOf("Time") !== 0 })
  readonly property var batChips: {
    const all = factPairs(quickBatteryRoot.batLines)
    return all.filter(function(f) { return ["Health", "Cycles", "Power", "Temp"].indexOf(f.k) >= 0 })
  }
  readonly property bool batCharging: (quickBatteryRoot.batClass || []).indexOf("charging") >= 0
  function ringColor() {
    if (quickBatteryRoot.batCharging) return Style.yellow
    if (quickBatteryRoot.batPercentage < 20) return Style.red
    return Style.green
  }

  function batColor() {
    const cls = quickBatteryRoot.batClass || []
    if (cls.indexOf("critical") >= 0) return Style.red
    if (cls.indexOf("warning") >= 0) return Style.orange
    if (cls.indexOf("charging") >= 0) return Style.yellow
    if (cls.indexOf("full") >= 0) return Style.green
    return Style.green
  }
  function parseBattery(jsonText) {
    try {
      const data = JSON.parse((jsonText || "").trim())
      quickBatteryRoot.batPercentage = Number(data.percentage) || 0
      quickBatteryRoot.batClass = data.class || []

      const text = data.text || "󰁹 —"
      const iconMatch = text.match(/^(.+?)\s+\d+%/)
      quickBatteryRoot.batIcon = iconMatch ? iconMatch[1].trim() : "󰁹"

      const raw = (data.tooltip || "").split("\n").filter(function(line) { return line.length > 0 })
      const statusMatch = (raw[0] || "").match(/\(([^)]+)\)/)
      quickBatteryRoot.batStatus = statusMatch ? statusMatch[1] : ""

      const f = {}
      for (let i = 1; i < raw.length; i++) {
        const line = raw[i]
        if (line.indexOf("Power:") === 0) f.power = line.substring(6).trim()
        else if (line.indexOf("Time") === 0) f.time = line.replace(/^Time[^:]*:\s*/, "")
        else if (line.indexOf("Energy:") === 0) {
          const em = line.match(/Energy:\s*([^/]+)\s*\/\s*(.+)/)
          if (em) { f.energyNow = em[1].trim(); f.energyFull = em[2].trim() }
        } else if (line.indexOf("Design:") === 0) {
          const dm = line.match(/Health:\s*([^(]+)\(([^)]+)\)/)
          if (dm) { f.health = dm[1].trim(); f.healthLabel = dm[2].trim() }
        } else if (line.indexOf("Cycles:") === 0) {
          const cm = line.match(/Cycles:\s*([^|]+)\|\s*Temp:\s*(.+)/)
          if (cm) { f.cycles = cm[1].trim(); f.temp = cm[2].trim() }
        } else if (line.indexOf("Model:") === 0) {
          const mm = line.match(/Model:\s*([^|]+)\|\s*Mfg:\s*(.+)/)
          if (mm) { f.model = mm[1].trim(); f.mfg = mm[2].trim() }
        }
      }

      quickBatteryRoot.batLines = raw.length > 1 ? raw.slice(1) : []
      quickBatteryRoot.batUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
      quickBatteryRoot.batTimeRemaining = f.time || ""
      quickBatteryRoot.batHolding = !!data.holding
      quickBatteryRoot.batThresholdEnd = Number(data.threshold_end) || 0
    } catch (_) {}
  }

  Process {
    id: batProc
    command: ["bash", root.binDir + "/asahi-battery"]
    stdout: StdioCollector { onStreamFinished: quickBatteryRoot.parseBattery(text) }
  }
  Process {
    id: smcProc
    command: [root.binDir + "/asahi-temperature", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(String(text || "").trim() || "{}")
          quickBatteryRoot.smcPower = data.power || []
        } catch (e) { quickBatteryRoot.smcPower = [] }
      }
    }
  }
  Timer {
    interval: 3000
    running: root.quickMode && root.quickPaneKey === "battery"
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!batProc.running) batProc.running = true
      if (!smcProc.running) smcProc.running = true
    }
  }
  Timer { id: batDelay; interval: 400; onTriggered: { if (!batProc.running) batProc.running = true } }
  Component.onCompleted: Qt.callLater(function() {
    if (!batProc.running) batProc.running = true
    if (!smcProc.running) smcProc.running = true
  })

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

  // Tonal action pill; `on` paints it in the primary container.
  component Pill: Rectangle {
    property string icon: ""
    property string label: ""
    property bool on: false
    signal clicked()
    implicitWidth: pillRow.implicitWidth + 28; implicitHeight: 36
    radius: Style.menuRadiusFull
    color: on ? Style.m3primaryContainer : (pillMa.containsMouse ? Qt.lighter(Style.m3containerHigh, 1.15) : Style.m3containerHigh)
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
      id: pillRow; anchors.centerIn: parent; spacing: 8
      Text {
        text: icon; color: on ? Style.m3primary : Style.m3onSurface
        font.family: root.uiFont; font.pixelSize: root.fontPx(12); anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: label; color: on ? Style.m3primary : Style.m3onSurface
        font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter
      }
    }
    MouseArea { id: pillMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

    // Hero: charge ring, state, time estimate, charge-cap pills.
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
          Layout.preferredWidth: 132; Layout.preferredHeight: 132
          value: quickBatteryRoot.batPercentage
          accent: quickBatteryRoot.ringColor()
          label: "Battery"
          icon: quickBatteryRoot.batIcon
          fontFamily: root.uiFont
          labelFamily: root.uiSans
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          RowLayout {
            spacing: 12
            Text {
              text: quickBatteryRoot.batPercentage + "%"
              color: quickBatteryRoot.ringColor()
              font.family: root.uiSans; font.pixelSize: root.fontPx(30); font.weight: Font.DemiBold
            }
            Text {
              visible: quickBatteryRoot.batStatus !== ""
              text: quickBatteryRoot.batStatus
              color: quickBatteryRoot.batColor()
              font.family: root.uiSans; font.pixelSize: root.fontPx(14); font.weight: Font.Medium
              Layout.alignment: Qt.AlignBaseline
            }
          }
          Text {
            visible: quickBatteryRoot.batTimeRemaining !== "" && quickBatteryRoot.batTimeRemaining !== "n/a"
            text: (quickBatteryRoot.batCharging ? "Time to full  " : "Time remaining  ") + quickBatteryRoot.batTimeRemaining
            color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(12)
          }
          Text {
            text: quickBatteryRoot.batHolding
              ? ("Holding at " + quickBatteryRoot.batThresholdEnd + "%")
              : (quickBatteryRoot.batThresholdEnd > 0 && quickBatteryRoot.batThresholdEnd < 99
                ? ("Charge cap " + quickBatteryRoot.batThresholdEnd + "%")
                : "No charge cap")
            color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
          }
          RowLayout {
            Layout.topMargin: 8
            spacing: 8
            Pill {
              icon: "󰁾"; label: "Hold 80%"; on: quickBatteryRoot.batThresholdEnd === 80
              onClicked: { Quickshell.execDetached([root.binDir + "/asahi-charge-limit", "80"]); batDelay.restart() }
            }
            Pill {
              icon: "󰁹"; label: "Full 100%"; on: quickBatteryRoot.batThresholdEnd >= 99
              onClicked: { Quickshell.execDetached([root.binDir + "/asahi-charge-limit", "100"]); batDelay.restart() }
            }
            Item { Layout.fillWidth: true }
            Chip { icon: "󰥔"; label: quickBatteryRoot.batUpdated || "asahi-battery"; bg: Style.m3containerHigh }
          }
        }
      }
    }

    // Key facts as chips.
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      visible: quickBatteryRoot.batChips.length > 0
      Repeater {
        model: quickBatteryRoot.batChips
        delegate: Chip {
          required property var modelData
          required property int index
          icon: quickBatteryRoot.factGlyph(modelData.k)
          label: modelData.k + " " + modelData.v
          bg: index % 2 === 0 ? Style.m3secondaryContainer : Style.m3tertiaryContainer
        }
      }
      Item { Layout.fillWidth: true }
    }

    Rectangle {
      Layout.fillWidth: true
      visible: (quickBatteryRoot.smcPower || []).length > 0
      implicitHeight: smcCol.implicitHeight + 24
      radius: Style.menuRadiusLg
      color: Style.m3container
      ColumnLayout {
        id: smcCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 12
        spacing: 8
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Rectangle {
            width: 30; height: 30; radius: Style.menuRadiusMd
            color: Style.m3primaryContainer
            Text {
              anchors.centerIn: parent; text: "󰓅"; color: Style.m3primary
              font.family: root.uiFont; font.pixelSize: root.fontPx(14)
            }
          }
          Text {
            Layout.fillWidth: true
            text: "SMC Power"
            color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(13); font.weight: Font.DemiBold
          }
        }
        Repeater {
          model: quickBatteryRoot.smcPower
          delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 12
            Text {
              Layout.fillWidth: true
              text: modelData.label || ""
              color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11); elide: Text.ElideRight
            }
            Text {
              text: isFinite(modelData.value) ? Number(modelData.value).toFixed(2) + " W" : "–"
              color: /heatpipe/i.test(modelData.label || "") ? Style.orange : Style.m3onSurface
              font.family: root.uiSans; font.pixelSize: root.fontPx(12); font.weight: Font.DemiBold
            }
          }
        }
      }
    }

    // Facts card: two-column key/value grid.
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Style.menuPanelRadius
      color: Style.m3container
      Text {
        anchors.centerIn: parent
        visible: quickBatteryRoot.batFacts.length === 0
        text: "Loading…"
        color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(11)
      }
      Flickable {
        id: factFlick
        anchors.fill: parent
        anchors.margins: 16
        clip: true
        contentHeight: factGrid.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: Menu.MenuScrollBar {}
        GridLayout {
          id: factGrid
          width: factFlick.width
          columns: 2
          columnSpacing: 24
          rowSpacing: 10
          Repeater {
            model: quickBatteryRoot.batFacts
            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              spacing: 10
              Rectangle {
                width: 30; height: 30; radius: Style.menuRadiusMd
                color: Style.m3primaryContainer
                Text {
                  anchors.centerIn: parent; text: quickBatteryRoot.factGlyph(modelData.k); color: Style.m3primary
                  font.family: root.uiFont; font.pixelSize: root.fontPx(13)
                }
              }
              Text {
                Layout.preferredWidth: Math.round(root.fontPx(11) * 8.4)
                text: modelData.k; color: Style.m3onSurfaceVariant
                font.family: root.uiSans; font.pixelSize: root.fontPx(11); elide: Text.ElideRight
              }
              Text {
                Layout.fillWidth: true
                text: modelData.v; color: Style.m3onSurface
                font.family: root.uiSans; font.pixelSize: root.fontPx(12); font.weight: Font.Medium; elide: Text.ElideRight
              }
            }
          }
        }
      }
    }
  }
}
