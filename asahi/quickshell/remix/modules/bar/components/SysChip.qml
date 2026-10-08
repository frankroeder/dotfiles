import QtQuick
import "../../../"
import "../sys_panel.js" as Sys

// One CPU + RAM chip. Each half keeps its themed accent (peach / sky); click → SysPanel, right-click → btop.
// Warning/critical tints follow CPU, RAM, and heatpipe pressure — Adaptive bar modes stay off the notch.
Item {
  id: root

  property var barHost: null
  readonly property bool solidBar: barHost !== null && barHost !== undefined
  signal pressed(int button)

  readonly property bool showTemp: !!barHost && barHost.showTemp
  // CPU + RAM only, and the temperature stat's share: BarHost decides showTemp from these.
  readonly property real baseWidth: cpuStat.implicitWidth + memStat.implicitWidth + row.spacing + 16
  readonly property real tempWidth: tempStat.implicitWidth + row.spacing
  implicitWidth: baseWidth + (showTemp ? tempWidth : 0)
  implicitHeight: solidBar ? barHost.barSize : Style.barHeight

  function accentFor(base, percent, heatpipe) {
    const cpuMem = Sys.pressureClass(percent)
    const pipe = heatpipe != null && heatpipe >= 0 ? Sys.heatW(heatpipe) : 0
    if (cpuMem === "critical" || pipe === 2) return Style.red
    if (cpuMem === "warning" || pipe === 1) return Style.yellow
    return base
  }

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: Style.barChipInset
    anchors.bottomMargin: Style.barChipInset
    radius: Style.radiusSm
    // Lit on hover and while its panel is open.
    color: chipMa.containsMouse || (root.barHost && root.barHost.sysPanelOpen) ? Style.barStripHover : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  component Stat: Row {
    property string icon
    property color accent
    property real value: 0
    property string suffix: "%"
    spacing: 4
    Text {
      text: icon; color: accent
      font.family: Style.fontFamily; font.pixelSize: Style.barFontGlyph; renderType: Text.NativeRendering
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: (root.barHost ? root.barHost.fmt2(value) : "--") + suffix; color: accent
      font.family: Style.fontFamily; font.pixelSize: Style.barFontBody; renderType: Text.NativeRendering
      anchors.verticalCenter: parent.verticalCenter
      Behavior on color { ColorAnimation { duration: 160 } }
    }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 10
    Stat {
      id: cpuStat
      icon: "󰍛"
      accent: root.accentFor(Style.orange, root.barHost ? root.barHost.cpuPerc : 0, root.barHost ? root.barHost.heatpipeW : -1)
      value: root.barHost ? root.barHost.cpuPerc : 0
    }
    Stat {
      id: memStat
      icon: "󰘚"
      accent: root.accentFor(Style.sky, root.barHost ? root.barHost.memPerc : 0, -1)
      value: root.barHost ? root.barHost.memPerc : 0
    }
    // Average SMC temperature (°C), only when the left cluster has room (BarHost.showTemp).
    Stat {
      id: tempStat
      visible: root.showTemp
      icon: "󰔏"
      suffix: "°"
      readonly property real t: root.barHost ? root.barHost.tempAvg : -1
      accent: t >= 75 ? Style.red : t >= 60 ? Style.yellow : Style.teal
      value: t
    }
  }

  MouseArea {
    id: chipMa
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) { root.pressed(mouse.button) }
  }
}
