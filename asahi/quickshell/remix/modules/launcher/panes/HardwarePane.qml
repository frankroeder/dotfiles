import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../menu" as Menu
import "../../../"

// Hardware pane (Super+Ctrl+H): what only this pane knows about this Mac. Hero (model, board identifiers, serial),
// four tiles (CPU cluster clocks and GPU every 2 s while shown, the last sleep, asahi-debug's health checks), then a
// 2 × 2 grid of cards: ports with what hangs off them, sensors, Touch ID, kernel + boot chain + firmware. What a
// sibling owns stays out: system / SoC power live in Battery, fans in Temperatures, the SSD in Storage, OS, chip and
// memory on the Dashboard (its Host / Kernel / CPU / GPU rows open this pane; the kernel is here too, on purpose: it
// heads the boot chain). Sized to fit the laptop pane without scrolling, docked too.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, binDir, shouldShow, quickMode, quickPaneKey, execAndClose, ...).
Item {
  property var root
  id: hwRoot
  anchors.fill: parent

  property var hw: ({})
  // asahi-debug --json: {passed, warnings, failed, skipped, checks: [{id, status, detail}]}; null until it answered.
  property var health: null
  readonly property bool shown: root.shouldShow && root.quickMode && root.quickPaneKey === "hardware"
  function load() {
    if (!fullProc.running) fullProc.running = true
    if (!healthProc.running) healthProc.running = true
  }
  onShownChanged: if (shown) load()
  Component.onCompleted: if (shown) load()

  Process {
    id: fullProc
    command: [root.binDir + "/asahi-hardware"]
    stdout: StdioCollector { onStreamFinished: { try { hwRoot.hw = JSON.parse(text) } catch (_) {} } }
  }
  Process {
    id: liveProc
    command: [root.binDir + "/asahi-hardware", "--live"]
    stdout: StdioCollector { onStreamFinished: {
      try {
        const l = JSON.parse(text)   // keeps the static fields (GPU core count …)
        hwRoot.hw = Object.assign({}, hwRoot.hw, l, { gpu: Object.assign({}, hwRoot.hw.gpu, l.gpu) })
      } catch (_) {}
    } }
  }
  // ~0.7 s, once per open (exit 1 with a failed check: the JSON still comes).
  Process {
    id: healthProc
    command: [root.binDir + "/asahi-debug", "--json"]
    stdout: StdioCollector { onStreamFinished: { try { hwRoot.health = JSON.parse(text) } catch (_) {} } }
  }
  Timer {
    interval: 2000; running: hwRoot.shown; repeat: true
    onTriggered: if (!fullProc.running && !liveProc.running) liveProc.running = true
  }

  function val(v, unit) { return v === null || v === undefined || v === "" ? "—" : v + (unit || "") }
  readonly property bool loaded: !!hwRoot.hw.model
  readonly property var g: hwRoot.hw.gpu || ({})
  readonly property var s: hwRoot.hw.sensors || ({})
  readonly property var sep: hwRoot.hw.sep || ({})
  readonly property var boot: hwRoot.hw.boot || ({})
  readonly property var radios: hwRoot.hw.radios || ({})
  readonly property var sleep: hwRoot.hw.sleep || ({})
  readonly property var clusters: (hwRoot.hw.cpu && hwRoot.hw.cpu.clusters) || []
  // Efficiency clusters are the ones with the lowest top clock (none on a chip with one kind of core).
  readonly property real eTop: {
    const tops = hwRoot.clusters.map(c => c.max_mhz)
    return tops.length && Math.min(...tops) !== Math.max(...tops) ? Math.min(...tops) : -1
  }
  readonly property string coreLine: {
    const n = l => l.reduce((a, c) => a + c.cores, 0)
    const e = hwRoot.clusters.filter(c => c.max_mhz === hwRoot.eTop)
    const p = hwRoot.clusters.filter(c => c.max_mhz !== hwRoot.eTop)
    return !hwRoot.clusters.length ? "" : e.length ? n(e) + "E · " + n(p) + "P cores" : n(p) + " cores"
  }
  // Live clock per kind, in GHz: the fastest cluster of each (the two P clusters run their own clocks).
  readonly property string clockLine: {
    const cur = hwRoot.hw.cpu_mhz || []
    let e = -1, p = -1
    for (let i = 0; i < hwRoot.clusters.length; i++) {
      const v = cur[i]
      if (v === null || v === undefined) continue
      if (hwRoot.clusters[i].max_mhz === hwRoot.eTop) e = Math.max(e, v)
      else p = Math.max(p, v)
    }
    const ghz = v => (v / 1000).toFixed(2)
    return e >= 0 && p >= 0 ? ghz(e) + " · " + ghz(p) : p >= 0 ? ghz(p) : e >= 0 ? ghz(e) : "—"
  }
  function span(minutes) {
    const h = Math.floor(minutes / 60), m = minutes % 60
    return h > 0 ? h + "h " + m + "m" : m + "m"
  }
  function speed(mbps) { return !mbps ? "" : mbps >= 1000 ? (mbps / 1000) + " Gb/s" : mbps + " Mb/s" }
  // Port row: who is plugged in; underneath what it does (power direction as the port sees it, USB PD, DP alt mode,
  // data role) and the USB devices behind the port, hubs left out. A lone device without a PD identity names the
  // row itself. The card says "Ports": the label loses its "USB-C ".
  function portRow(pt) {
    const name = String(pt.name || "").replace(/^USB-C /, "")
    const devs = pt.devices || []
    if (!pt.partner && !devs.length) return [name, "empty"]
    const who = pt.vendor_name ? pt.vendor_name.replace(/,? (Inc|Co|Corp|Ltd)\.?.*$/, "") : (pt.vendor ? "vendor " + pt.vendor : "")
    const sink = pt.power === "sink"
    const role = !pt.partner ? "" : sink ? "charging the Mac" : "powered by the Mac"
    const solo = !who && devs.length === 1
    const title = who || (solo ? devs[0].name : role) || "connected"
    const sub = [title === role || !pt.partner ? "" : sink ? "power in" : "power out", pt.pd ? "USB PD" : "",
      pt.dp ? "DP alt mode" : "", pt.data || "", solo ? hwRoot.speed(devs[0].mbps) : ""].filter(x => x).join(" · ")
    return [name, title, sub, solo ? [] : devs.map(d => [d.name, hwRoot.speed(d.mbps)].filter(x => x).join(" · "))]
  }
  // Label column of every card: fits "Ambient light".
  readonly property int labelW: Math.round(root.fontPx(11) * 7)

  // Health: the checks that did not pass (asahi-debug skips what this machine does not have).
  readonly property var issues: ((hwRoot.health && hwRoot.health.checks) || []).filter(c => c.status !== "PASS" && c.status !== "SKIP")
  readonly property int failed: hwRoot.health ? (hwRoot.health.failed || 0) : 0
  readonly property int warnings: hwRoot.health ? (hwRoot.health.warnings || 0) : 0

  property bool serialCopied: false
  Timer { id: serialCopiedClear; interval: 1200; onTriggered: hwRoot.serialCopied = false }
  function copySerial() {
    Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", String(hwRoot.hw.serial || "")])
    hwRoot.serialCopied = true
    serialCopiedClear.restart()
  }

  // Tile: glyph + caption, the value, one detail line. `clickable` adds the chevron, the hover layer and `clicked`.
  component Tile: Rectangle {
    id: tile
    property string glyph: ""
    property color accent: Style.m3primary
    property string label: ""
    property string value: ""
    property color valueColor: Style.m3onSurface
    property string detail: ""
    property bool clickable: false
    signal clicked()
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredWidth: 1
    implicitHeight: tileCol.implicitHeight + 24
    radius: Style.menuRadiusLg
    color: Style.m3container
    Rectangle { anchors.fill: parent; radius: parent.radius; color: Style.m3stateHover; visible: tileMa.containsMouse }
    ColumnLayout {
      id: tileCol
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.margins: 12
      spacing: 2
      RowLayout {
        Layout.fillWidth: true
        spacing: 7
        Text { text: tile.glyph; color: tile.accent; font.family: root.uiFont; font.pixelSize: root.fontPx(13) }
        Text {
          Layout.fillWidth: true
          text: tile.label; color: Style.m3onSurfaceVariant; elide: Text.ElideRight
          font.family: root.uiSans; font.pixelSize: root.fontPx(10); font.weight: Font.Medium
        }
        Text {
          visible: tile.clickable
          text: "󰅂"; color: Style.m3onSurfaceVariant; opacity: tileMa.containsMouse ? 1 : 0.5
          font.family: root.uiFont; font.pixelSize: root.fontPx(12)
        }
      }
      Text {
        Layout.fillWidth: true
        text: tile.value; color: tile.valueColor; elide: Text.ElideRight; textFormat: Text.PlainText
        font.family: root.uiSans; font.pixelSize: root.fontPx(18); font.weight: Font.DemiBold
      }
      Text {
        Layout.fillWidth: true
        text: tile.detail || " "; color: Style.m3onSurfaceVariant; elide: Text.ElideRight; textFormat: Text.PlainText
        font.family: root.uiSans; font.pixelSize: root.fontPx(10)
      }
    }
    MouseArea {
      id: tileMa
      anchors.fill: parent
      enabled: tile.clickable
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: tile.clicked()
    }
  }

  // Card: glyph + title, then rows ([[label, value, small line under the value?, [more small lines]?], ...]). Rows
  // bind by index: a live update changes the texts, it does not rebuild the delegates. Spare card height opens the
  // row gaps up to 2×, the rest stays below.
  component Card: Rectangle {
    id: card
    property string title: ""
    property string glyph: ""
    property var rows: []
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredWidth: 1
    implicitHeight: cardCol.implicitHeight + 24
    radius: Style.menuRadiusLg
    color: Style.m3container
    ColumnLayout {
      id: cardCol
      anchors.fill: parent
      anchors.margins: 12
      spacing: Math.max(6, Math.round(root.fontPx(4.5)))
      RowLayout {
        Layout.bottomMargin: 2
        spacing: 10
        Rectangle {
          width: 30; height: 30; radius: Style.menuRadiusMd; color: Style.m3primaryContainer
          Text {
            anchors.centerIn: parent; text: card.glyph; color: Style.m3primary
            font.family: root.uiFont; font.pixelSize: root.fontPx(14)
          }
        }
        Text {
          text: card.title; color: Style.m3onSurface
          font.family: root.uiSans; font.pixelSize: root.fontPx(13); font.weight: Font.DemiBold
        }
      }
      Repeater {
        model: card.rows.length
        RowLayout {
          id: cardRow
          required property int index
          readonly property var row: card.rows[index] || ["", ""]
          readonly property var more: row[3] || []
          readonly property bool blank: row[1] === "empty" || row[1] === "—" || row[1] === "off"
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.maximumHeight: implicitHeight + cardCol.spacing
          spacing: 12
          Text {
            Layout.preferredWidth: hwRoot.labelW
            Layout.alignment: Qt.AlignTop
            text: cardRow.row[0]; color: Style.m3onSurfaceVariant; textFormat: Text.PlainText
            font.family: root.uiSans; font.pixelSize: root.fontPx(11); elide: Text.ElideRight
          }
          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 0
            Text {
              Layout.fillWidth: true
              text: cardRow.row[1]; color: cardRow.blank ? Style.m3outline : Style.m3onSurface; textFormat: Text.PlainText
              font.family: root.uiSans; font.pixelSize: root.fontPx(11); elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              visible: !!cardRow.row[2]
              text: cardRow.row[2] || ""; color: Style.m3onSurfaceVariant; textFormat: Text.PlainText
              font.family: root.uiSans; font.pixelSize: root.fontPx(9); elide: Text.ElideRight
            }
            Repeater {
              model: cardRow.more.length
              Text {
                required property int index
                Layout.fillWidth: true
                text: cardRow.more[index] || ""; color: Style.m3onSurface; textFormat: Text.PlainText
                font.family: root.uiSans; font.pixelSize: root.fontPx(9); elide: Text.ElideRight
              }
            }
          }
        }
      }
      Item { Layout.fillHeight: true }
    }
  }

  Flickable {
    id: hwFlick
    anchors.fill: parent
    clip: true
    contentHeight: hwCol.height
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: Menu.MenuScrollBar { id: hwScroll }
    ColumnLayout {
      id: hwCol
      width: hwFlick.width - (hwScroll.overflow ? hwScroll.implicitWidth + 4 : 0)
      height: Math.max(implicitHeight, hwFlick.height)
      spacing: 12

      // Hero: which Mac this is (the Dashboard's user card, for the machine). The serial copies on click.
      Rectangle {
        id: hero
        Layout.fillWidth: true
        implicitHeight: heroRow.implicitHeight + 20
        radius: Style.menuPanelRadius
        color: Style.m3container
        RowLayout {
          id: heroRow
          anchors.fill: parent; anchors.margins: 10; anchors.leftMargin: 12; anchors.rightMargin: 16
          spacing: 14
          Rectangle {
            width: 50; height: 50; radius: Style.menuRadiusLg
            color: Style.m3primaryContainer
            Text { anchors.centerIn: parent; text: "󰀵"; color: Style.m3primary; font.family: root.uiFont; font.pixelSize: 32 }
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
              Layout.fillWidth: true
              text: (hwRoot.hw.model || "Loading…").replace(/^Apple /, "")
              color: Style.m3onSurface; textFormat: Text.PlainText; elide: Text.ElideRight
              font.family: root.uiSans; font.pixelSize: root.fontPx(17); font.weight: Font.DemiBold
            }
            Text {
              Layout.fillWidth: true
              visible: !!hwRoot.hw.sku
              text: [hwRoot.hw.sku, hwRoot.hw.board, hwRoot.hw.part, hwRoot.hw.page_kb ? hwRoot.hw.page_kb + "K pages" : ""].filter(x => x).join(" · ")
              color: Style.m3onSurfaceVariant; textFormat: Text.PlainText; elide: Text.ElideRight
              font.family: root.uiSans; font.pixelSize: root.fontPx(11)
            }
          }
          Menu.MenuChip {
            visible: !!hwRoot.hw.serial
            fontScale: root.uiFontScale
            clickable: true
            // The check mark is the feedback: a "Copied" label would resize the chip under the pointer.
            icon: hwRoot.serialCopied ? "󰄬" : "󰆏"
            label: String(hwRoot.hw.serial || "")
            bg: Style.m3secondaryContainer
            onClicked: hwRoot.copySerial()
          }
        }
      }

      // Tiles. Spare pane height grows them up to 1.4×; the rest goes to the cards.
      RowLayout {
        id: tileRow
        readonly property int minH: cpuTile.implicitHeight
        Layout.fillWidth: true
        Layout.preferredHeight: minH + Math.max(0, Math.min(Math.round(minH * 0.4),
          hwFlick.height - hero.implicitHeight - cardGrid.implicitHeight - 2 * hwCol.spacing - minH))
        spacing: 12
        Tile {
          id: cpuTile
          glyph: "󰍛"; accent: Style.orange; label: hwRoot.eTop >= 0 ? "CPU · E · P GHz" : "CPU · GHz"
          value: hwRoot.clockLine
          detail: !hwRoot.loaded ? "" : [hwRoot.coreLine, hwRoot.hw.cpu ? hwRoot.hw.cpu.governor : ""].filter(x => x).join(" · ")
        }
        Tile {
          glyph: "󰢮"; accent: Style.menuIndigo; label: hwRoot.g.cores ? "GPU · " + hwRoot.g.cores + " cores" : "GPU"
          value: hwRoot.val(hwRoot.g.util, " %")
          detail: !hwRoot.loaded ? "" : [hwRoot.val(hwRoot.g.mhz, " MHz"),
            hwRoot.g.mw === undefined || hwRoot.g.mw === null ? "" : (hwRoot.g.mw / 1000).toFixed(2) + " W"].filter(x => x).join(" · ")
        }
        // The last sleep asahi-idle logged (its drain is the number to watch on this kernel) + the kernel's counters.
        Tile {
          readonly property var last: hwRoot.sleep.last || null
          glyph: "󰒲"; accent: Style.mauve; label: "Last sleep"
          value: !last ? "—" : last.w !== null ? last.w.toFixed(2) + " W"
            : last.gained_wh !== null ? "+" + last.gained_wh.toFixed(2) + " Wh" : "on AC"
          detail: !hwRoot.loaded ? "" : [last ? hwRoot.span(last.minutes) + (last.ac ? " on AC" : "") : "none logged",
            hwRoot.sleep.ok ? hwRoot.sleep.ok + " ok" : "", hwRoot.sleep.failed ? hwRoot.sleep.failed + " failed" : ""].filter(x => x).join(" · ")
        }
        // asahi-debug: the count here, the names of what did not pass underneath; a click opens the full report.
        Tile {
          readonly property color tone: hwRoot.failed > 0 ? Style.red : hwRoot.warnings > 0 ? Style.orange : Style.green
          glyph: "󰗶"; accent: tone; label: "Health"; clickable: true
          value: !hwRoot.health ? "…" : hwRoot.failed > 0 ? hwRoot.failed + " failed"
            : hwRoot.warnings > 0 ? hwRoot.warnings + (hwRoot.warnings === 1 ? " warning" : " warnings") : "All good"
          valueColor: hwRoot.health && (hwRoot.failed > 0 || hwRoot.warnings > 0) ? tone : Style.m3onSurface
          detail: !hwRoot.health ? "checking" : hwRoot.issues.length ? hwRoot.issues.map(c => c.id).join(", ")
            : (hwRoot.health.passed || 0) + " checks pass"
          onClicked: root.execAndClose(["env", "ASAHI_TUI_WAIT=1", root.binDir + "/asahi-launch-tui", root.binDir + "/asahi-debug"])
        }
      }

      GridLayout {
        id: cardGrid
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 2
        columnSpacing: 12
        rowSpacing: 12
        Card {
          title: "Ports"; glyph: "󰕓"
          rows: (hwRoot.hw.ports || []).map(hwRoot.portRow)
        }
        Card {
          title: "Sensors"; glyph: "󰃠"
          rows: [
            ["Ambient light", hwRoot.s.lux === null || hwRoot.s.lux === undefined ? "—" : hwRoot.s.lux + " lux" + (hwRoot.s.kelvin ? " · " + hwRoot.s.kelvin + " K" : "")],
            ["Lid", hwRoot.val(hwRoot.s.lid_deg, "°")],
            ["Brightness", "display " + hwRoot.val(hwRoot.s.panel, " %") + " · keys " + hwRoot.val(hwRoot.s.kbd, " %")],
            ["Camera", hwRoot.val(hwRoot.hw.camera)]
          ]
        }
        Card {
          title: "Touch ID"; glyph: "󰌾"
          rows: [
            ["Sensor", hwRoot.val(hwRoot.sep.touchid) + (hwRoot.sep.sensor ? " · " + hwRoot.sep.sensor : "")],
            ["Fingers", hwRoot.sep.fingers === null || hwRoot.sep.fingers === undefined ? "—" : hwRoot.sep.fingers + " enrolled"],
            ["Keystore", hwRoot.val(hwRoot.sep.keystore)],
            ["xART guard", !hwRoot.loaded ? "—" : hwRoot.sep.xart_guard ? "on · " + hwRoot.val(hwRoot.sep.refusals) + " refused" : "off"]
          ]
        }
        Card {
          title: "System"; glyph: "󰍛"
          rows: [
            ["Kernel", hwRoot.val(hwRoot.hw.kernel)],
            ["m1n1", hwRoot.val(hwRoot.boot.stage1) + " · stage 2 " + hwRoot.val(hwRoot.boot.stage2)],
            ["U-Boot", hwRoot.val(hwRoot.boot.uboot)],
            ["Firmware", "system " + hwRoot.val(hwRoot.boot.system_fw) + " · OS " + hwRoot.val(hwRoot.boot.os_fw)],
            ["Wi-Fi / BT", hwRoot.radios.wifi ? hwRoot.radios.wifi + " · fw " + hwRoot.val(hwRoot.radios.wifi_fw) : "—"]
          ]
        }
      }
    }
  }
}
