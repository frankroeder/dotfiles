import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"
import "../sys_panel.js" as Sys

// CPU / RAM chip popup: tiles, history, cores, fans, sensors, processes.
PopupWindow {
  id: root

  property var barHost: null
  property bool panelOpen: false
  property var cpu: ({})
  property var mem: ({})
  property var procs: []
  property var hot: []
  property var spark: []
  property var memSpark: []
  property var fans: []

  readonly property var heatColors: [Style.green, Style.yellow, Style.red]
  readonly property real topCpu: root.procs.length ? Math.max(1, root.procs[0].cpu) : 1
  readonly property real heatpipeW: (root.barHost && root.barHost.heatpipeW >= 0) ? root.barHost.heatpipeW : NaN
  readonly property var cores: (root.barHost && root.barHost.cpuCores) ? root.barHost.cpuCores : []

  visible: root.panelOpen
  color: "transparent"
  anchor.edges: Edges.Bottom
  implicitWidth: 400
  implicitHeight: Math.min(640, col.implicitHeight + 32)

  function refresh() {
    if (!root.barHost) return
    root.cpu = Sys.parseCpuTooltip(root.barHost.cpuTooltip)
    root.mem = Sys.parseMemTooltip(root.barHost.memTooltip)
    root.spark = Sys.sparkPoints(root.barHost.cpuHistory)
    root.memSpark = Sys.sparkPoints(root.barHost.memHistory)
    if (!psProc.running) psProc.running = true
    if (!tempProc.running) tempProc.running = true
  }

  Timer { interval: 2000; repeat: true; triggeredOnStart: true; running: root.panelOpen; onTriggered: root.refresh() }

  Process {
    id: psProc
    command: ["ps", "-eo", "pcpu,comm", "--sort=-pcpu"]
    stdout: StdioCollector { onStreamFinished: root.procs = Sys.parsePs(text) }
  }
  Process {
    id: tempProc
    command: root.barHost ? [root.barHost.binDir + "/asahi-temperature", "--json"] : ["true"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(String(text || "").trim() || "{}")
          root.hot = Sys.hottest(data.temps || [], 3)
          root.fans = data.fans || []
        } catch (e) {
          root.hot = []
          root.fans = []
        }
      }
    }
  }

  component StatTile: Rectangle {
    property color accent
    property string caption
    property real value: 0
    property string detail
    property string unit: "%"
    property real barMax: 100
    Layout.fillWidth: true
    implicitHeight: tileCol.implicitHeight + 24
    radius: Style.menuRadius
    color: Qt.alpha(accent, 0.09)
    border.color: Qt.alpha(accent, 0.25)
    border.width: 1
    ColumnLayout {
      id: tileCol
      anchors.fill: parent
      anchors.margins: 12
      spacing: 4
      Text {
        text: caption
        color: Style.menuInkDeep; font.family: Style.fontFamily; font.pixelSize: 9
        font.letterSpacing: 1.2; font.capitalization: Font.AllUppercase
      }
      Text {
        text: unit === "%" ? (Math.round(value) + "%") : (isFinite(value) ? value.toFixed(1) + " " + unit : "–")
        color: accent; font.family: Style.fontFamily; font.pixelSize: 22; font.weight: Font.DemiBold
      }
      Text { text: detail; color: Style.menuInk; font.family: Style.fontFamily; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
      Rectangle {
        Layout.fillWidth: true
        height: 3; radius: 1.5
        color: Qt.alpha(accent, 0.18)
        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, (isFinite(value) ? value : 0) / Math.max(1, barMax)))
          height: parent.height; radius: parent.radius; color: accent
          Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        }
      }
    }
  }

  component SectionTitle: Text {
    Layout.fillWidth: true
    Layout.topMargin: 4
    color: Style.menuInkDeep
    font.family: Style.fontFamily
    font.pixelSize: 9
    font.letterSpacing: 1.6
    font.capitalization: Font.AllUppercase
    opacity: 0.8
  }

  component SparkBox: Rectangle {
    property var points: []
    property color accent: Style.orange
    Layout.fillWidth: true
    implicitHeight: 48
    radius: Style.menuRadius
    color: Style.menuCardBg
    border.color: Style.menuSep
    border.width: 1
    Canvas {
      id: boxCanvas
      anchors.fill: parent
      anchors.margins: 8
      onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const pts = parent.points || []
        if (pts.length < 2) return
        ctx.beginPath()
        ctx.moveTo(0, height)
        for (let i = 0; i < pts.length; i++) ctx.lineTo(pts[i].x * width, pts[i].y * height)
        ctx.lineTo(width, height)
        ctx.closePath()
        ctx.fillStyle = Qt.alpha(parent.accent, 0.16)
        ctx.fill()
        ctx.beginPath()
        ctx.moveTo(pts[0].x * width, pts[0].y * height)
        for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x * width, pts[i].y * height)
        ctx.strokeStyle = parent.accent
        ctx.lineWidth = 1.5
        ctx.stroke()
      }
      Connections { target: parent; function onPointsChanged() { boxCanvas.requestPaint() } }
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Style.menuBg
    border.color: Style.menuSep
    border.width: 1
    radius: Style.menuRadius

    Flickable {
      id: flick
      anchors.fill: parent
      anchors.margins: 16
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      contentHeight: col.implicitHeight
      ColumnLayout {
        id: col
        width: flick.width
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          StatTile {
            accent: Style.orange; caption: "CPU"; value: root.barHost ? root.barHost.cpuPerc : 0
            detail: (root.cpu.freq ? root.cpu.freq : "")
              + (root.cpu.cores ? (root.cpu.freq ? "  ·  " : "") + root.cpu.cores + " cores" : "")
          }
          StatTile {
            accent: Style.sky; caption: "RAM"; value: root.barHost ? root.barHost.memPerc : 0
            detail: (root.mem.ramUsed ? root.mem.ramUsed + " / " + root.mem.ramTotal + " GiB" : "")
              + (root.mem.swapTotal ? "  ·  swap " + root.mem.swapUsed + " / " + root.mem.swapTotal : "")
          }
          StatTile {
            visible: root.heatpipeW >= 0
            accent: root.heatColors[Sys.heatW(root.heatpipeW)]
            caption: "HEAT"; unit: "W"; value: root.heatpipeW; barMax: 25
            detail: "heatpipe · no die °C"
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          SparkBox { points: root.spark; accent: Style.orange }
          SparkBox { points: root.memSpark; accent: Style.sky }
        }

        Text {
          Layout.fillWidth: true
          text: [
            root.cpu.load ? ("load " + root.cpu.load) : "",
            isFinite(root.cpu.temp) ? ("peak " + root.cpu.temp.toFixed(1) + "°C") : ""
          ].filter(function(s) { return s !== "" }).join("  ·  ")
          color: Style.menuInkDeep; font.family: Style.fontFamily; font.pixelSize: 10
          visible: text !== ""
        }

        SectionTitle { text: "per-core"; visible: root.cores.length > 0 }
        Row {
          Layout.fillWidth: true
          spacing: 3
          visible: root.cores.length > 0
          Repeater {
            model: root.cores
            Rectangle {
              required property var modelData
              width: Math.max(6, (col.width - Math.max(0, root.cores.length - 1) * 3) / Math.max(1, root.cores.length))
              height: 28
              radius: 2
              color: Style.menuControlBg
              Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: parent.height * Math.max(0, Math.min(1, (modelData.percent || 0) / 100))
                radius: 2
                color: Style.orange
              }
            }
          }
        }

        SectionTitle { text: "fans"; visible: root.fans.length > 0 }
        Repeater {
          model: root.fans
          RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            Text { text: "󰈐"; color: Style.sky; font.family: Style.fontFamily; font.pixelSize: 13 }
            Text {
              Layout.fillWidth: true
              text: modelData.displayLabel || modelData.label || "Fan"
              color: Style.menuInk; font.family: Style.fontFamily; font.pixelSize: 11
            }
            Rectangle {
              Layout.preferredWidth: 72
              height: 4; radius: 2
              color: Style.menuControlBg
              Rectangle {
                width: parent.width * Sys.fanFraction(modelData)
                height: parent.height; radius: parent.radius; color: Style.sky
              }
            }
            Text {
              text: Math.round(modelData.value || 0) + " RPM"
              color: Style.menuInkDeep; font.family: Style.fontFamily; font.pixelSize: 10
            }
          }
        }

        SectionTitle { text: "hottest sensors"; visible: root.hot.length > 0 }
        Repeater {
          model: root.hot
          RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            Rectangle { width: 6; height: 6; radius: 3; color: root.heatColors[Sys.heat(modelData.value)] }
            Text {
              Layout.fillWidth: true
              text: modelData.label || modelData.name || ""
              color: Style.menuInk; font.family: Style.fontFamily; font.pixelSize: 11; elide: Text.ElideRight
            }
            Text {
              text: (isFinite(modelData.value) ? modelData.value.toFixed(1) : "–") + "°C"
              color: root.heatColors[Sys.heat(modelData.value)]; font.family: Style.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold
            }
          }
        }

        SectionTitle { text: "top processes"; visible: root.procs.length > 0 }
        Repeater {
          model: root.procs
          Item {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 20
            Rectangle {
              anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
              width: parent.width * Math.min(1, modelData.cpu / root.topCpu)
              radius: 4
              color: Qt.alpha(Style.orange, 0.10)
            }
            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8; anchors.rightMargin: 8
              Text {
                Layout.fillWidth: true; text: modelData.comm; color: Style.menuInk; font.family: Style.fontFamily; font.pixelSize: 11
                elide: Text.ElideRight
              }
              Text { text: modelData.cpu.toFixed(1) + "%"; color: Style.menuInkDeep; font.family: Style.fontFamily; font.pixelSize: 10 }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          Layout.topMargin: 2
          text: "right-click chip: btop"
          color: Style.menuInkDeep
          font.family: Style.fontFamily
          font.pixelSize: 9
          horizontalAlignment: Text.AlignHCenter
          opacity: 0.6
        }
      }
    }
  }
}
