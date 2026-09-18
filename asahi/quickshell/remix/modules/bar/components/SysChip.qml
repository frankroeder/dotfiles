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

  implicitWidth: row.implicitWidth + 16
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
    color: chipMa.containsMouse ? Style.barStripHover : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  component Stat: Row {
    property string icon
    property color accent
    property real value: 0
    spacing: 4
    Text {
      text: icon; color: accent
      font.family: Style.fontFamily; font.pixelSize: Style.barFontGlyph; renderType: Text.NativeRendering
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: (root.barHost ? root.barHost.fmt2(value) : "--") + "%"; color: accent
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
      icon: "󰍛"
      accent: root.accentFor(Style.orange, root.barHost ? root.barHost.cpuPerc : 0, root.barHost ? root.barHost.heatpipeW : -1)
      value: root.barHost ? root.barHost.cpuPerc : 0
    }
    Stat {
      icon: "󰘚"
      accent: root.accentFor(Style.sky, root.barHost ? root.barHost.memPerc : 0, -1)
      value: root.barHost ? root.barHost.memPerc : 0
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
