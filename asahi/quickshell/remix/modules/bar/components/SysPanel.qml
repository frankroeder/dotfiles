import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import "../../../"
import "../../menu" as Menu
import "../BarModel.js" as BarModel
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
  // I/O tile: rates in bytes/s from the last two samples, histories of the last minute (only while open).
  property var io: ({ rx: 0, tx: 0, rd: 0, wr: 0 })
  property var ioPrev: null
  property var ioHist: ({ rx: [], tx: [], rd: [], wr: [] })

  readonly property var heatColors: [Style.green, Style.yellow, Style.red]
  readonly property real topCpu: root.procs.length ? Math.max(1, root.procs[0].cpu) : 1
  readonly property real heatpipeW: (root.barHost && root.barHost.heatpipeW >= 0) ? root.barHost.heatpipeW : NaN
  readonly property var cores: (root.barHost && root.barHost.cpuCores) ? root.barHost.cpuCores : []

  visible: root.panelOpen || growOut.running
  onPanelOpenChanged: {
    if (root.panelOpen) { growOut.stop(); growIn.restart() } else { growIn.stop(); growOut.restart() }
    if (!root.panelOpen) {   // a fresh minute per open (and no last open's rates for the first 2 s)
      root.ioPrev = null; root.ioHist = { rx: [], tx: [], rd: [], wr: [] }; root.io = { rx: 0, tx: 0, rd: 0, wr: 0 }
    }
  }
  color: "transparent"
  anchor.edges: Edges.Bottom
  anchor.margins.bottom: -BarModel.popupDrop(root.barHost ? root.barHost.height : Style.barHeight, Style.barHeight)  // negative = below
  implicitWidth: 400
  implicitHeight: Math.min(640, col.implicitHeight + 2 * Style.popupPad)

  function close() { if (root.barHost && root.barHost.openPanel === "sys") root.barHost.openPanel = "" }

  function refresh() {
    if (!root.barHost) return
    root.cpu = Sys.parseCpuTooltip(root.barHost.cpuTooltip)
    root.mem = Sys.parseMemTooltip(root.barHost.memTooltip)
    root.spark = Sys.sparkPoints(root.barHost.cpuHistory)
    root.memSpark = Sys.sparkPoints(root.barHost.memHistory)
    if (!psProc.running) psProc.running = true
    if (!tempProc.running) tempProc.running = true
    root.sampleIo()
  }
  FileView { id: netDev; path: "/proc/net/dev"; blockLoading: true }
  FileView { id: diskStats; path: "/proc/diskstats"; blockLoading: true }
  function sampleIo() {
    netDev.reload(); diskStats.reload()
    const now = Object.assign({ t: Date.now() }, Sys.netTotals(netDev.text()), Sys.diskTotals(diskStats.text()))
    const p = root.ioPrev
    root.ioPrev = now
    if (!p || now.t <= p.t) return
    const dt = (now.t - p.t) / 1000, rate = k => Math.max(0, (now[k] - p[k]) / dt)
    root.io = { rx: rate("rx"), tx: rate("tx"), rd: rate("rd"), wr: rate("wr") }
    const h = {}
    for (const k of ["rx", "tx", "rd", "wr"]) h[k] = root.ioHist[k].concat([root.io[k]]).slice(-30)
    root.ioHist = h
  }

  Timer { interval: 2000; repeat: true; triggeredOnStart: true; running: root.panelOpen; onTriggered: root.refresh() }

  // Whitelist the bar window too, else the click that opened this counts as outside and closes it.
  // Esc is an app-wide shortcut: the grab may leave keyboard focus on the bar.
  // Armed once the popup is mapped: armed at show time its surface was not whitelisted yet, and every
  // click inside closed it (no button in a bar popup worked).
  Timer { id: grabArm; interval: 150; running: root.panelOpen }
  HyprlandFocusGrab {
    windows: [root, root.anchor.window]
    active: root.panelOpen && !grabArm.running
    onCleared: root.close()
  }
  Shortcut {
    enabled: root.panelOpen
    sequences: ["Escape"]
    context: Qt.ApplicationShortcut
    onActivated: root.close()
  }

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
    id: statTile
    property color accent
    property string caption
    property real value: 0
    property string detail
    property string unit: "%"
    property real barMax: 100
    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitHeight: tileCol.implicitHeight + 24
    radius: Style.menuRadiusMd
    color: Qt.alpha(accent, 0.09)
    border.color: Qt.alpha(accent, 0.25)
    border.width: 1
    ColumnLayout {
      id: tileCol
      // Fills the tile, the bar pinned to its foot: the heat tile's two detail lines put its bar a line below the others.
      anchors.fill: parent
      anchors.margins: 12
      spacing: 4
      Menu.MenuCaption { text: caption }
      Menu.MenuFadeText {
        text: unit === "%" ? (Math.round(value) + "%") : (isFinite(value) ? value.toFixed(1) + " " + unit : "–")
        color: accent; font.family: Style.fontUi; font.features: Style.fontTabular; font.pixelSize: Style.typeDisplay; font.weight: Font.DemiBold
        font.variableAxes: Style.opsz(Style.typeDisplay)
      }
      Text {
        text: detail; color: Style.menuInk; font.family: Style.fontUi; font.features: Style.fontTabular; font.pixelSize: Style.typeCaption
        maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true
      }
      Item { Layout.fillHeight: true }
      Menu.MenuMeter {
        Layout.fillWidth: true
        value: (isFinite(statTile.value) ? statTile.value : 0) / Math.max(1, statTile.barMax)   // the tile's, not the meter's
        fill: accent
      }
    }
  }

  component SectionTitle: Menu.MenuCaption {
    Layout.fillWidth: true
    Layout.topMargin: 4
  }

  component SparkBox: Rectangle {
    property var points: []
    property color accent: Style.orange
    Layout.fillWidth: true
    implicitHeight: 48
    radius: Style.menuRadiusMd
    color: Style.menuCardBg
    border.color: Style.menuHairline
    border.width: Style.rim(Screen.devicePixelRatio)
    // GPU path (Gren-95 SysGraph): area fades out toward the floor; rebuilt per sample, no CPU raster like the Canvas.
    Shape {
      id: spark
      readonly property var line: (parent.points || []).length < 2 ? [] : parent.points.map(p => Qt.point(p.x * width, p.y * height))
      readonly property color accent: parent.accent
      anchors.fill: parent
      anchors.margins: 8
      visible: line.length > 1
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: -1
        fillGradient: LinearGradient {
          x1: 0; y1: 0; x2: 0; y2: spark.height
          GradientStop { position: 0; color: Qt.alpha(spark.accent, 0.34) }
          GradientStop { position: 1; color: Qt.alpha(spark.accent, 0.02) }
        }
        PathPolyline { path: spark.line.length > 1 ? [Qt.point(0, spark.height)].concat(spark.line, [Qt.point(spark.width, spark.height)]) : [] }
      }
      ShapePath {
        fillColor: "transparent"
        strokeColor: spark.accent
        strokeWidth: 1.5
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap
        PathPolyline { path: spark.line }
      }
    }
  }

  // Mirrored I/O graph (Gren-95 SysGraph `mirror`): download / read above the midline, upload / write below.
  component IoBox: Rectangle {
    id: ioBox
    property string title: ""
    property var up: []
    property var down: []
    property real upRate: 0
    property real downRate: 0
    property string upGlyph: "󰇚"
    property string downGlyph: "󰕒"
    property color upColor: Style.sky
    property color downColor: Style.orange
    readonly property var pts: Sys.mirrorPoints(ioBox.up, ioBox.down)
    Layout.fillWidth: true
    implicitHeight: 74
    radius: Style.menuRadiusMd
    color: Style.menuCardBg
    border.color: Style.menuHairline
    border.width: Style.rim(Screen.devicePixelRatio)
    RowLayout {
      id: ioHead
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
      spacing: 6
      Text { text: ioBox.title; color: Style.menuInkDeep; font.family: Style.fontUi; font.pixelSize: Style.typeCaption; font.weight: Font.DemiBold }
      Item { Layout.fillWidth: true }
      Text { text: ioBox.upGlyph + " " + Sys.fmtRate(ioBox.upRate); color: ioBox.upColor; font.family: Style.fontUi; font.features: Style.fontTabular; font.pixelSize: Style.typeCaption }
      Text { text: ioBox.downGlyph + " " + Sys.fmtRate(ioBox.downRate); color: ioBox.downColor; font.family: Style.fontUi; font.features: Style.fontTabular; font.pixelSize: Style.typeCaption }
    }
    Shape {
      id: ioShape
      anchors { left: parent.left; right: parent.right; top: ioHead.bottom; bottom: parent.bottom; margins: 8; topMargin: 4 }
      preferredRendererType: Shape.CurveRenderer
      readonly property var upLine: ioBox.pts.up.map(p => Qt.point(p.x * width, p.y * height))
      readonly property var downLine: ioBox.pts.down.map(p => Qt.point(p.x * width, p.y * height))
      ShapePath {
        strokeWidth: -1
        fillColor: Qt.alpha(ioBox.upColor, 0.5)
        PathPolyline { path: ioShape.upLine.length > 1 ? [Qt.point(0, ioShape.height / 2)].concat(ioShape.upLine, [Qt.point(ioShape.width, ioShape.height / 2)]) : [] }
      }
      ShapePath {
        strokeWidth: -1
        fillColor: Qt.alpha(ioBox.downColor, 0.5)
        PathPolyline { path: ioShape.downLine.length > 1 ? [Qt.point(0, ioShape.height / 2)].concat(ioShape.downLine, [Qt.point(ioShape.width, ioShape.height / 2)]) : [] }
      }
      ShapePath {
        strokeColor: Style.menuHairline; strokeWidth: 1; fillColor: "transparent"
        PathPolyline { path: [Qt.point(0, ioShape.height / 2), Qt.point(ioShape.width, ioShape.height / 2)] }
      }
    }
  }

  // Unfolds out of its chip (container transform): a chip-wide pill under the chip grows into the card, the content
  // stays where the full card puts it (the clip reveals it) and fades in past a third. Once per open / close.
  property real grow: 0
  readonly property real chipW: root.anchor.item ? Math.min(root.width, root.anchor.item.width + 8) : 140
  NumberAnimation {
    id: growIn; target: root; property: "grow"; to: 1
    duration: Style.reduceMotion ? 100 : Style.menuSpringFastMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.menuEnter
  }
  NumberAnimation {
    id: growOut; target: root; property: "grow"; to: 0
    duration: Style.menuExitMs + 40; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.menuExit
  }

  ClippingRectangle {
    id: card
    x: Math.round((root.width - width) / 2)
    width: root.chipW + (root.width - root.chipW) * root.grow
    height: 34 + (root.height - 34) * root.grow   // 34: about a bar chip
    color: Style.m3surfaceSolid
    radius: Style.menuRadiusLg
    border.color: Style.popupBorder
    border.width: Style.popupBorderWidth

    Flickable {
      id: flick
      x: Style.popupPad - card.x
      y: Style.popupPad
      width: root.width - 2 * Style.popupPad
      height: root.height - 2 * Style.popupPad
      opacity: Math.max(0, Math.min(1, (root.grow - 0.35) / 0.5))
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      contentHeight: col.implicitHeight
      // Past the 640 cap (fans, hottest sensors) the list scrolls: the cut row reads as "more", not clipped.
      Menu.MenuEdgeFade { parent: flick; surface: Style.m3surfaceSolid; atTop: true }
      Menu.MenuEdgeFade { parent: flick; surface: Style.m3surfaceSolid }
      ColumnLayout {
        id: col
        width: flick.width
        spacing: Style.popupGap

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          StatTile {
            accent: Style.orange; caption: "CPU"; value: root.barHost ? root.barHost.cpuPerc : 0
            detail: [root.cpu.freq, root.cpu.cores ? root.cpu.cores + " cores" : ""].filter(s => s).join("\n")
          }
          StatTile {
            accent: Style.sky; caption: "RAM"; value: root.barHost ? root.barHost.memPerc : 0
            detail: [root.mem.ramUsed ? root.mem.ramUsed + " / " + root.mem.ramTotal + " GiB" : "",
              root.mem.swapTotal ? "swap " + root.mem.swapUsed + " / " + root.mem.swapTotal
                + (root.mem.zramRatio ? " · " + root.mem.zramRatio + "×" : "") : ""].filter(s => s).join("\n")
          }
          StatTile {
            visible: root.heatpipeW >= 0
            accent: root.heatColors[Sys.heatW(root.heatpipeW)]
            caption: "HEAT"; unit: "W"; value: root.heatpipeW; barMax: 25
            // The die sensor (BarData.tempAvg, when the kernel has one) under the heatpipe watts.
            detail: "SoC heatpipe\n" + (root.barHost && root.barHost.tempIsDie && root.barHost.tempAvg > 0 ? "die " + root.barHost.tempAvg + "°C" : "SMC estimate")
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
            // PSI: share of the last 10 s something waited for a CPU / for memory (load counts queues, this stalls).
            isFinite(root.cpu.psiCpu) ? ("stall cpu " + Math.round(root.cpu.psiCpu) + "% · mem " + Math.round(root.cpu.psiMem) + "%") : "",
            isFinite(root.cpu.temp) ? ("peak " + root.cpu.temp.toFixed(1) + "°C") : ""
          ].filter(function(s) { return s !== "" }).join("  ·  ")
          color: Style.menuInkDeep; font.family: Style.fontUi; font.features: Style.fontTabular; font.pixelSize: Style.typeCaption
          visible: text !== ""
        }

        SectionTitle { text: "i/o" }
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          IoBox { title: "Network"; up: root.ioHist.rx; down: root.ioHist.tx; upRate: root.io.rx; downRate: root.io.tx }
          IoBox {
            title: "Disk"; up: root.ioHist.rd; down: root.ioHist.wr; upRate: root.io.rd; downRate: root.io.wr
            upGlyph: "R"; downGlyph: "W"; upColor: Style.green; downColor: Style.mauve
          }
        }

        SectionTitle { text: "per-core"; visible: root.cores.length > 0 }
        // Hybrid CPUs: efficiency and performance cores as two groups with their means (Sys.coreGroups); each group as
        // wide as its share of the cores.
        RowLayout {
          Layout.fillWidth: true
          spacing: 12
          visible: root.cores.length > 0
          Repeater {
            model: Sys.coreGroups(root.cores)
            ColumnLayout {
              id: coreGroup
              required property var modelData
              Layout.fillWidth: true
              Layout.horizontalStretchFactor: Math.max(1, modelData.cores.length)
              spacing: 4
              RowLayout {
                visible: coreGroup.modelData.name !== ""
                Layout.fillWidth: true
                Text {
                  Layout.fillWidth: true
                  text: coreGroup.modelData.name + " · " + coreGroup.modelData.cores.length
                  color: Style.menuInkDeep; font.family: Style.fontUi; font.pixelSize: Style.typeCaption
                }
                Text {
                  text: coreGroup.modelData.avg + "%"
                  color: Style.orange; font.family: Style.fontUi; font.features: Style.fontTabular
                  font.pixelSize: Style.typeCaption; font.weight: Font.DemiBold
                }
              }
              Row {
                id: cellRow
                Layout.fillWidth: true
                spacing: 3
                Repeater {
                  model: coreGroup.modelData.cores
                  Rectangle {
                    required property var modelData
                    width: Math.max(6, (cellRow.width - Math.max(0, coreGroup.modelData.cores.length - 1) * 3)
                      / Math.max(1, coreGroup.modelData.cores.length))
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
            }
          }
        }

        // Processes (ps, instant) above the sensors (asahi-temperature, ~150 ms
        // later) so the late sections extend the bottom instead of shoving rows down.
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
                Layout.fillWidth: true; text: modelData.comm; color: Style.menuInk; font.family: Style.fontUi; font.pixelSize: Style.typeBody
                elide: Text.ElideRight
              }
              Text { text: modelData.cpu.toFixed(1) + "%"; color: Style.menuInkDeep; font.family: Style.fontUi; font.features: Style.fontTabular; font.pixelSize: Style.typeCaption }
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
            Text { text: "󰈐"; color: Style.sky; font.family: Style.fontMono; font.pixelSize: 13 }
            Text {
              Layout.fillWidth: true
              text: modelData.displayLabel || modelData.label || "Fan"
              color: Style.menuInk; font.family: Style.fontUi; font.pixelSize: Style.typeBody
            }
            Menu.MenuMeter { Layout.preferredWidth: 72; value: Sys.fanFraction(modelData); fill: Style.sky }
            Text {
              text: Math.round(modelData.value || 0) + " RPM"
              color: Style.menuInkDeep; font.family: Style.fontUi; font.features: Style.fontTabular; font.pixelSize: Style.typeCaption
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
              text: Sys.sensorLabel(modelData)
              color: Style.menuInk; font.family: Style.fontUi; font.pixelSize: Style.typeBody; elide: Text.ElideRight
            }
            Text {
              text: (isFinite(modelData.value) ? modelData.value.toFixed(1) : "–") + "°C"
              color: root.heatColors[Sys.heat(modelData.value)]; font.family: Style.fontUi; font.features: Style.fontTabular; font.pixelSize: Style.typeBody; font.weight: Font.DemiBold
            }
          }
        }

        Text {
          Layout.fillWidth: true
          Layout.topMargin: 2
          text: "right-click chip: btop"
          color: Style.menuInkDeep
          font.family: Style.fontUi; font.features: Style.fontTabular
          font.pixelSize: Style.typeCaption
          horizontalAlignment: Text.AlignHCenter
          opacity: 0.6
        }
      }
    }
  }
}
