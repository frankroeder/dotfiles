import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"
import "../sys_panel.js" as Sys
import "../../launcher/temp_display.js" as TempDisplay

// CPU / RAM chip popup: two stat tiles, CPU history, disk, hottest sensors, top processes.
PopupWindow {
  id: root

  property var barHost: null
  property bool panelOpen: false
  property var cpu: ({})
  property var mem: ({})
  property var procs: []
  property var hot: []
  property var disk: ({})
  property var spark: []

  readonly property var heatColors: [Style.green, Style.yellow, Style.red]
  readonly property real topCpu: root.procs.length ? Math.max(1, root.procs[0].cpu) : 1

  visible: root.panelOpen
  color: "transparent"
  anchor.edges: Edges.Bottom
  implicitWidth: 360
  implicitHeight: col.implicitHeight + 32

  function refresh() {
    if (!root.barHost) return
    root.cpu = Sys.parseCpuTooltip(root.barHost.cpuTooltip)
    root.mem = Sys.parseMemTooltip(root.barHost.memTooltip)
    root.spark = Sys.sparkPoints(root.barHost.cpuHistory)
    if (!psProc.running) psProc.running = true
    if (!dfProc.running) dfProc.running = true
    if (!tempProc.running) tempProc.running = true
  }

  // cpuHistory is mutated in place (no change signal), so poll while open; nothing runs when closed.
  Timer { interval: 3000; repeat: true; triggeredOnStart: true; running: root.panelOpen; onTriggered: root.refresh() }
  onSparkChanged: sparkCanvas.requestPaint()

  Process {
    id: psProc
    command: ["ps", "-eo", "pcpu,comm", "--sort=-pcpu"]
    stdout: StdioCollector { onStreamFinished: root.procs = Sys.parsePs(text) }
  }
  Process {
    id: dfProc
    command: ["df", "-h", "/"]
    stdout: StdioCollector { onStreamFinished: root.disk = Sys.parseDfRoot(text) }
  }
  Process {
    id: tempProc
    command: [root.barHost ? root.barHost.binDir + "/asahi-temperature" : "true"]
    stdout: StdioCollector {
      onStreamFinished: root.hot = Sys.hottest(TempDisplay.parseTemperatures(text).sensors || [], 3)
    }
  }

  // Stat tile: big percentage, caption, one detail line, thin bar tinted by accent.
  component StatTile: Rectangle {
    property color accent
    property string caption
    property real value: 0
    property string detail
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
      RowLayout {
        spacing: 6
        Text { text: Math.round(value) + "%"; color: accent; font.family: Style.fontFamily; font.pixelSize: 24; font.weight: Font.DemiBold }
        Text {
          text: caption; color: Style.menuInkDeep; font.family: Style.fontFamily; font.pixelSize: 10; font.letterSpacing: 1.2
          Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 5
        }
      }
      Text { text: detail; color: Style.menuInk; font.family: Style.fontFamily; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
      Rectangle {
        Layout.fillWidth: true
        height: 3; radius: 1.5
        color: Qt.alpha(accent, 0.18)
        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, value / 100)); height: parent.height; radius: parent.radius; color: accent
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

  Rectangle {
    anchors.fill: parent
    color: Style.menuBg
    border.color: Style.menuSep
    border.width: 1
    radius: Style.menuRadius

    ColumnLayout {
      id: col
      anchors.fill: parent
      anchors.margins: 16
      spacing: 8

      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        StatTile {
          accent: Style.orange; caption: "CPU"; value: root.barHost ? root.barHost.cpuPerc : 0
          detail: (isFinite(root.cpu.temp) ? root.cpu.temp.toFixed(1) + "°C" : "")
            + (root.cpu.freq ? "  ·  " + root.cpu.freq : "") + (root.cpu.cores ? "  ·  " + root.cpu.cores + " cores" : "")
        }
        StatTile {
          accent: Style.sky; caption: "RAM"; value: root.barHost ? root.barHost.memPerc : 0
          detail: (root.mem.ramUsed ? root.mem.ramUsed + " / " + root.mem.ramTotal + " GiB" : "")
            + (root.mem.swapTotal ? "  ·  swap " + root.mem.swapUsed + " / " + root.mem.swapTotal : "")
        }
      }

      // CPU history: filled area under the line, load average as caption.
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 64
        radius: Style.menuRadius
        color: Style.menuCardBg
        border.color: Style.menuSep
        border.width: 1
        Canvas {
          id: sparkCanvas
          anchors.fill: parent
          anchors.margins: 8
          onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const pts = root.spark || []
            if (pts.length < 2) return
            ctx.beginPath()
            ctx.moveTo(0, height)
            for (let i = 0; i < pts.length; i++) ctx.lineTo(pts[i].x * width, pts[i].y * height)
            ctx.lineTo(width, height)
            ctx.closePath()
            ctx.fillStyle = Qt.alpha(Style.orange, 0.16)
            ctx.fill()
            ctx.beginPath()
            ctx.moveTo(pts[0].x * width, pts[0].y * height)
            for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x * width, pts[i].y * height)
            ctx.strokeStyle = Style.orange
            ctx.lineWidth = 1.5
            ctx.stroke()
          }
        }
        Text {
          anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
          text: root.cpu.load ? "load " + root.cpu.load : ""
          color: Style.menuInkDeep; font.family: Style.fontFamily; font.pixelSize: 9
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Text { text: "󰋊"; color: Style.menuSeal; font.family: Style.fontFamily; font.pixelSize: 13 }
        Text { text: "Disk /"; color: Style.menuInk; font.family: Style.fontFamily; font.pixelSize: 11 }
        Rectangle {
          Layout.fillWidth: true
          height: 4; radius: 2
          color: Style.menuControlBg
          Rectangle {
            width: parent.width * Math.max(0, Math.min(1, (root.disk.pct || 0) / 100)); height: parent.height; radius: parent.radius
            color: Style.menuSeal
          }
        }
        Text {
          text: (root.disk.used || "–") + " / " + (root.disk.size || "–") + (root.disk.pct >= 0 ? "  " + root.disk.pct + "%" : "")
          color: Style.menuInkDeep; font.family: Style.fontFamily; font.pixelSize: 10
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
            text: (modelData.groupDisplayName ? modelData.groupDisplayName + "  ·  " : "") + (modelData.displayLabel || modelData.label || "")
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
