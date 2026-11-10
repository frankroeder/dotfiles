import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../menu" as Menu
import "../../../"

// Hardware pane (Super+Ctrl+H): this Mac from asahi-hardware — chip, power rails, GPU, USB-C ports, sensors, Touch ID,
// boot chain and firmware. Everything once per open, power / GPU / ports / sensors every 2 s while shown.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, binDir, shouldShow, quickMode, quickPaneKey, ...).
Item {
  property var root
  id: hwRoot
  anchors.fill: parent

  property var hw: ({})
  readonly property bool shown: root.shouldShow && root.quickMode && root.quickPaneKey === "hardware"
  onShownChanged: if (shown && !fullProc.running) fullProc.running = true
  Component.onCompleted: if (shown) fullProc.running = true

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
  Timer {
    interval: 2000; running: hwRoot.shown; repeat: true
    onTriggered: if (!fullProc.running && !liveProc.running) liveProc.running = true
  }

  function w(v) { return v === null || v === undefined ? "—" : Number(v).toFixed(1) + " W" }
  function val(v, unit) { return v === null || v === undefined || v === "" ? "—" : v + (unit || "") }
  readonly property var p: hwRoot.hw.power || ({})
  readonly property var g: hwRoot.hw.gpu || ({})
  readonly property var s: hwRoot.hw.sensors || ({})
  readonly property var sep: hwRoot.hw.sep || ({})
  readonly property var boot: hwRoot.hw.boot || ({})
  readonly property var cpuLine: {
    const cl = (hwRoot.hw.cpu && hwRoot.hw.cpu.clusters) || []
    if (!cl.length) return ""
    const e = cl.filter(c => c.max_mhz === Math.min(...cl.map(x => x.max_mhz)))
    const pc = cl.filter(c => e.indexOf(c) < 0)
    const n = l => l.reduce((a, c) => a + c.cores, 0)
    return pc.length ? n(e) + "E + " + n(pc) + "P cores" : n(e) + " cores"
  }
  function portLine(pt) {
    if (!pt.partner) return "empty"
    const who = pt.vendor_name ? pt.vendor_name.replace(/,? (Inc|Co|Corp|Ltd)\.?.*$/, "") : (pt.vendor ? "vendor " + pt.vendor : "")
    return [pt.power === "sink" ? "charging the Mac" : "powered by the Mac", who, pt.dp ? "DP alt mode" : ""].filter(x => x).join(" · ")
  }

  // Card: glyph + title, then label · value rows ([[label, value], ...]).
  component Card: Rectangle {
    property string title: ""
    property string glyph: ""
    property var rows: []
    Layout.fillWidth: true
    implicitHeight: cardCol.implicitHeight + 24
    radius: Style.menuRadiusLg
    color: Style.m3container
    ColumnLayout {
      id: cardCol
      anchors.fill: parent; anchors.margins: 12
      spacing: 6
      RowLayout {
        spacing: 10
        Rectangle {
          width: 30; height: 30; radius: Style.menuRadiusMd; color: Style.m3primaryContainer
          Text {
            anchors.centerIn: parent; text: glyph; color: Style.m3primary
            font.family: root.uiFont; font.pixelSize: root.fontPx(14)
          }
        }
        Text {
          text: title; color: Style.m3onSurface
          font.family: root.uiSans; font.pixelSize: root.fontPx(13); font.weight: Font.DemiBold
        }
      }
      Repeater {
        model: rows
        RowLayout {
          required property var modelData
          Layout.fillWidth: true; Layout.leftMargin: 40
          spacing: 12
          Text {
            Layout.preferredWidth: Math.round(root.fontPx(11) * 9)
            text: modelData[0]; color: Style.m3onSurfaceVariant; textFormat: Text.PlainText
            font.family: root.uiSans; font.pixelSize: root.fontPx(11); elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            text: modelData[1]; color: Style.m3onSurface; textFormat: Text.PlainText
            font.family: root.uiSans; font.pixelSize: root.fontPx(11); elide: Text.ElideRight
          }
        }
      }
    }
  }

  Flickable {
    id: hwFlick
    anchors.fill: parent
    clip: true
    contentHeight: hwCol.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: Menu.MenuScrollBar { id: hwScroll }
    ColumnLayout {
      id: hwCol
      width: hwFlick.width - (hwScroll.overflow ? hwScroll.implicitWidth + 4 : 0)
      spacing: 12

      // Hero: model + chip line.
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: heroCol.implicitHeight + 28
        radius: Style.menuPanelRadius
        color: Style.m3container
        RowLayout {
          anchors.fill: parent; anchors.margins: 14
          spacing: 16
          Text {
            text: "󰀵"; color: Style.m3primary
            font.family: root.uiFont; font.pixelSize: root.fontPx(40)
          }
          ColumnLayout {
            id: heroCol
            Layout.fillWidth: true
            spacing: 2
            Text {
              Layout.fillWidth: true
              text: (hwRoot.hw.model || "Loading…").replace(/^Apple /, "")
              color: Style.m3onSurface; textFormat: Text.PlainText; elide: Text.ElideRight
              font.family: root.uiSans; font.pixelSize: root.fontPx(18); font.weight: Font.DemiBold
            }
            Text {
              Layout.fillWidth: true
              visible: !!hwRoot.hw.chip
              text: [hwRoot.hw.chip, hwRoot.cpuLine, hwRoot.g.cores ? hwRoot.g.cores + "-core GPU" : "",
                hwRoot.hw.mem_gb ? hwRoot.hw.mem_gb + " GB" : ""].filter(x => x).join(" · ")
              color: Style.m3onSurface; textFormat: Text.PlainText; elide: Text.ElideRight
              font.family: root.uiSans; font.pixelSize: root.fontPx(12)
            }
            Text {
              Layout.fillWidth: true
              visible: !!hwRoot.hw.sku
              text: [hwRoot.hw.sku, hwRoot.hw.board, hwRoot.hw.part, hwRoot.hw.ssd ? hwRoot.hw.ssd.model : ""].filter(x => x).join(" · ")
              color: Style.m3onSurfaceVariant; textFormat: Text.PlainText; elide: Text.ElideRight
              font.family: root.uiSans; font.pixelSize: root.fontPx(10)
            }
          }
        }
      }

      Card {
        title: "Power"; glyph: "󱐋"
        rows: [
          ["System", hwRoot.w(hwRoot.p.system_w)],
          ["SoC (heatpipe)", hwRoot.w(hwRoot.p.soc_w)],
          ["Charger", hwRoot.p.ac_w ? hwRoot.w(hwRoot.p.ac_w) + " of " + hwRoot.w(hwRoot.p.charger_w) : "on battery"],
          ["Fans", (hwRoot.p.fans || []).some(f => f > 0) ? hwRoot.p.fans.map(f => f + " rpm").join(" · ") : "off"],
          ["Profile", hwRoot.val(hwRoot.hw.profile) + (hwRoot.hw.cpu ? " · boost " + (hwRoot.hw.cpu.boost ? "on" : "off") : "")]
        ]
      }
      Card {
        title: "GPU"; glyph: "󰢮"
        rows: [
          ["Load", hwRoot.val(hwRoot.g.util, " %")],
          ["Clock", hwRoot.val(hwRoot.g.mhz, " MHz")],
          ["Power", hwRoot.g.mw === undefined || hwRoot.g.mw === null ? "—" : (hwRoot.g.mw / 1000).toFixed(2) + " W"]
        ]
      }
      Card {
        title: "Ports"; glyph: "󰕓"
        rows: (hwRoot.hw.ports || []).map(pt => [pt.name, hwRoot.portLine(pt)])
      }
      Card {
        title: "Sensors"; glyph: "󰃠"
        rows: [
          ["Ambient light", hwRoot.s.lux === null || hwRoot.s.lux === undefined ? "—" : hwRoot.s.lux + " lux" + (hwRoot.s.kelvin ? " · " + hwRoot.s.kelvin + " K" : "")],
          ["Lid", hwRoot.val(hwRoot.s.lid_deg, "°")],
          ["Display", hwRoot.val(hwRoot.s.panel, " %")],
          ["Keyboard light", hwRoot.val(hwRoot.s.kbd, " %")]
        ]
      }
      Card {
        title: "Touch ID"; glyph: "󰌾"
        rows: [
          ["Sensor", hwRoot.val(hwRoot.sep.touchid) + (hwRoot.sep.sensor ? " · " + hwRoot.sep.sensor : "")],
          ["Fingers", hwRoot.sep.fingers === null || hwRoot.sep.fingers === undefined ? "—" : String(hwRoot.sep.fingers)],
          ["Keystore", hwRoot.val(hwRoot.sep.keystore)],
          ["xART guard", hwRoot.sep.xart_guard ? "on · " + hwRoot.val(hwRoot.sep.refusals) + " refused" : "off"]
        ]
      }
      Card {
        title: "System"; glyph: "󰍛"
        rows: [
          ["OS", hwRoot.val(hwRoot.hw.os)],
          ["Kernel", hwRoot.val(hwRoot.hw.kernel) + (hwRoot.hw.page_kb ? " · " + hwRoot.hw.page_kb + "K pages" : "")],
          ["Boot", ["m1n1 " + hwRoot.val(hwRoot.boot.stage1), "Stage 2 " + hwRoot.val(hwRoot.boot.stage2), "U-Boot " + hwRoot.val(hwRoot.boot.uboot)].join(" · ")],
          ["Firmware", "system " + hwRoot.val(hwRoot.boot.system_fw) + " · OS " + hwRoot.val(hwRoot.boot.os_fw)],
          ["Radios", hwRoot.hw.radios ? hwRoot.val(hwRoot.hw.radios.wifi) + " Wi-Fi " + hwRoot.val(hwRoot.hw.radios.wifi_fw) + " · Bluetooth" : "—"],
          ["Camera", hwRoot.val(hwRoot.hw.camera)]
        ]
      }
    }
  }
}
