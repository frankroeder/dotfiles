import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
  property int batPercentage: -1  // -1 until the first read (no red "0%" flash)
  property var batClass: []
  property var batLines: []
  property string batTimeRemaining: ""
  property bool batHolding: false
  property int batThresholdEnd: 100
  property var smcPower: []
  // Placeholder rows until the first read so the facts card below does not jump.
  property bool smcLoaded: false

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
        if (idx <= 0) continue
        const k = parts[j].substring(0, idx).trim()
        const v = parts[j].substring(idx + 1).trim()
        // Mode is sysfs charge_behaviour: every mode, the active one in brackets ("[auto] inhibit-charge").
        const active = k === "Mode" ? /\[([^\]]+)\]/.exec(v) : null
        out.push({ k: k, v: active ? active[1] : v })
      }
    }
    return out
  }
  function factGlyph(key) {
    const g = { "Energy": "󱐋", "Design": "󰂎", "Health": "󰓙", "Cycles": "󰑐", "Temp": "󰔏", "Voltage": "󰚥", "Current": "󰢝",
      "Charge limits": "󰂅", "Mode": "󰒓", "AC online": "󰚥", "Input limit": "󰚥", "Model": "󰘚", "Mfg": "󰃭", "Power": "󱐋" }
    return g[key] || "󰋼"
  }
  readonly property var batChips: {
    const all = factPairs(quickBatteryRoot.batLines)
    return all.filter(function(f) { return ["Health", "Cycles", "Power", "Temp"].indexOf(f.k) >= 0 })
  }
  // The chip row already shows Health / Cycles / Power / Temp.
  readonly property var batFacts: {
    const chipKeys = quickBatteryRoot.batChips.map(function(f) { return f.k })
    return factPairs(quickBatteryRoot.batDetailLines).filter(function(f) { return f.k.indexOf("Time") !== 0 && chipKeys.indexOf(f.k) < 0 })
  }
  readonly property bool batCharging: (quickBatteryRoot.batClass || []).indexOf("charging") >= 0
  function ringColor() {
    if (quickBatteryRoot.batCharging) return Style.yellow
    if (quickBatteryRoot.batPercentage < 0) return Style.m3onSurfaceVariant
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

      quickBatteryRoot.batLines = raw.slice(1)
      const time = quickBatteryRoot.batLines.find(function(line) { return line.indexOf("Time") === 0 })
      quickBatteryRoot.batTimeRemaining = time ? time.replace(/^Time[^:]*:\s*/, "") : ""
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
        quickBatteryRoot.smcLoaded = true
      }
    }
  }
  Timer {
    interval: 3000
    running: root.shouldShow && root.quickMode && root.quickPaneKey === "battery"
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!batProc.running) batProc.running = true
      if (!smcProc.running) smcProc.running = true
    }
  }
  Timer { id: batDelay; interval: 400; onTriggered: { if (!batProc.running) batProc.running = true } }

  component Chip: Menu.MenuChip { fontScale: root.uiFontScale }
  component Pill: Menu.MenuPill { fontScale: root.uiFontScale }

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
          Layout.preferredWidth: Math.round(100 * root.uiFontScale); Layout.preferredHeight: Layout.preferredWidth
          value: Math.max(0, quickBatteryRoot.batPercentage)
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
              text: quickBatteryRoot.batPercentage < 0 ? "—" : quickBatteryRoot.batPercentage + "%"
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
              icon: "󰁾"; label: "Hold 80%"; selected: quickBatteryRoot.batThresholdEnd === 80
              onClicked: { Quickshell.execDetached([root.binDir + "/asahi-charge-limit", "80"]); batDelay.restart() }
            }
            Pill {
              icon: "󰁹"; label: "Full 100%"; selected: quickBatteryRoot.batThresholdEnd >= 99
              onClicked: { Quickshell.execDetached([root.binDir + "/asahi-charge-limit", "100"]); batDelay.restart() }
            }
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
      visible: !quickBatteryRoot.smcLoaded || (quickBatteryRoot.smcPower || []).length > 0
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
          model: quickBatteryRoot.smcLoaded ? quickBatteryRoot.smcPower : [{ label: " ", value: NaN }, { label: " ", value: NaN }, { label: " ", value: NaN }, { label: " ", value: NaN }]
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

    // Facts card fills the rest: row gaps flex baseGap..2×baseGap with the rows centred,
    // and a pane too short for the rows scrolls.
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 96
      radius: Style.menuRadiusLg
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
        anchors.margins: 14
        clip: true
        contentHeight: factGrid.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: Menu.MenuScrollBar {}
        GridLayout {
          id: factGrid
          width: factFlick.width
          y: Math.max(0, Math.round((factFlick.height - implicitHeight) / 2))
          columns: 2
          columnSpacing: 24
          readonly property int rowCount: Math.ceil(quickBatteryRoot.batFacts.length / 2)
          readonly property real rowH: children.reduce((m, c) => Math.max(m, c.implicitHeight), 0)
          rowSpacing: rowCount > 1 ? Math.floor(Math.min(2 * baseGap, Math.max(baseGap, (factFlick.height - rowH * rowCount) / (rowCount - 1)))) : baseGap
          readonly property int baseGap: Math.max(10, Math.round(root.fontPx(7)))
          Repeater {
            model: quickBatteryRoot.batFacts
            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              spacing: 10
              Rectangle {
                width: Math.max(30, Math.round(root.fontPx(13) * 1.9)); height: width; radius: Style.menuRadiusMd
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
