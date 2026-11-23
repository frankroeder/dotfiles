import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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

  readonly property var heatColors: [Style.green, Style.yellow, Style.red]
  readonly property real topCpu: root.procs.length ? Math.max(1, root.procs[0].cpu) : 1
  readonly property real heatpipeW: (root.barHost && root.barHost.heatpipeW >= 0) ? root.barHost.heatpipeW : NaN
  readonly property var cores: (root.barHost && root.barHost.cpuCores) ? root.barHost.cpuCores : []

  visible: root.panelOpen || popOut.running
  onPanelOpenChanged: if (root.panelOpen) { popOut.stop(); popIn.restart() } else popOut.restart()
  color: "transparent"
  anchor.edges: Edges.Bottom
  anchor.margins.bottom: -BarModel.popupDrop(root.barHost ? root.barHost.height : Style.barHeight, Style.barHeight)  // negative = below
  implicitWidth: 400
  implicitHeight: Math.min(640, col.implicitHeight + 32)

  function close() { if (root.barHost && root.barHost.openPanel === "sys") root.barHost.openPanel = "" }

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
      Text {
        text: caption
        color: Style.menuInkDeep; font.family: Style.menuSans; font.pixelSize: Style.typeCaption; font.weight: Font.DemiBold
        font.letterSpacing: 1.2; font.capitalization: Font.AllUppercase
      }
      Menu.MenuFadeText {
        text: unit === "%" ? (Math.round(value) + "%") : (isFinite(value) ? value.toFixed(1) + " " + unit : "–")
        color: accent; font.family: Style.fontUi; font.features: Style.fontTabular; font.pixelSize: Style.typeDisplay; font.weight: Font.DemiBold
      }
      Text {
        text: detail; color: Style.menuInk; font.family: Style.fontUi; font.features: Style.fontTabular; font.pixelSize: Style.typeCaption
        maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true
      }
      Item { Layout.fillHeight: true }
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
    // Same small tracked caps as the tile captions above.
    color: Style.menuInkDeep
    font.family: Style.menuSans
    font.pixelSize: Style.typeCaption
    font.weight: Font.DemiBold
    font.letterSpacing: 1.2
    font.capitalization: Font.AllUppercase
  }

  component SparkBox: Rectangle {
    property var points: []
    property color accent: Style.orange
    Layout.fillWidth: true
    implicitHeight: 48
    radius: Style.menuRadiusMd
    color: Style.menuCardBg
    border.color: Style.menuSep
    border.width: 1
    onPointsChanged: boxCanvas.requestPaint()
    Canvas {
      id: boxCanvas
      anchors.fill: parent
      anchors.margins: 8
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
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
    }
  }

  Menu.MenuPopIn { id: popIn; target: card }
  Menu.MenuPopOut { id: popOut; target: card }

  Rectangle {
    id: card
    anchors.fill: parent
    transformOrigin: Item.Top
    color: Style.m3surfaceSolid
    radius: Style.menuRadiusLg
    border.color: Style.popupBorder
    border.width: Style.popupBorderWidth

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
            Text { text: "󰈐"; color: Style.sky; font.family: Style.fontUi; font.features: Style.fontTabular; font.pixelSize: 13 }
            Text {
              Layout.fillWidth: true
              text: modelData.displayLabel || modelData.label || "Fan"
              color: Style.menuInk; font.family: Style.fontUi; font.pixelSize: Style.typeBody
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
