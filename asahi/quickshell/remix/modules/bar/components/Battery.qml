import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../../../"

// Glyph and percent straight from UPower (no script, no poll). Click: Quick > Battery.
Item {
  id: root

  property var barHost: null

  readonly property var dev: UPower.displayDevice
  readonly property int percentage: dev.ready ? Math.round(dev.percentage * 100) : 0
  // asahi-battery's glyphs: ten steps; charging bolts while charging or the charge limit holds.
  readonly property string iconGlyph: {
    const i = Math.min(9, Math.floor(percentage / 10))
    const charging = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
    if (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.PendingCharge) return charging[i]
    if (dev.state === UPowerDeviceState.FullyCharged) return "󰂅"
    return ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"][i]
  }

  // Charger surge (surface-dots TopBar onPluggedChanged): once per plug-in, a green ring swells out of the glyph and
  // the glyph pops — the cable is really charging. One-shot (~0.55 s); nothing on unplug, none in the first 3 s.
  property bool settled: false
  Timer { interval: 3000; running: true; onTriggered: root.settled = true }
  Connections {
    target: UPower
    function onOnBatteryChanged() { if (!UPower.onBattery && root.settled) root.surge() }
  }
  function surge() { if (!Style.reduceMotion) surgeAnim.restart() }
  ParallelAnimation {
    id: surgeAnim
    NumberAnimation { target: ring; property: "scale"; from: 0.5; to: 2.1; duration: 560; easing.type: Easing.OutCubic }
    NumberAnimation { target: ring; property: "opacity"; from: 0.55; to: 0; duration: 560; easing.type: Easing.OutQuad }
    SequentialAnimation {
      NumberAnimation { target: glyph; property: "scale"; to: 1.28; duration: 140; easing.type: Easing.OutQuad }
      NumberAnimation { target: glyph; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2 }
    }
  }

  visible: dev.ready
  implicitWidth: row.implicitWidth + 6
  implicitHeight: Style.barHeight

  HoverTint { down: chipMouse.pressed; lit: chipMouse.containsMouse }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 4

    Text {
      id: glyph
      text: root.iconGlyph
      Rectangle {
        id: ring
        anchors.centerIn: parent
        width: parent.height; height: width; radius: width / 2
        color: "transparent"
        border.width: 2; border.color: Style.green
        opacity: 0
      }
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontGlyphTall
      color: root.percentage <= 10 ? Style.red : (root.percentage <= 20 ? Style.orange : Style.green)
      Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
    }

    Text {
      text: root.percentage + "%"
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontBody
        // Level bar (his pick 2026-11-20, variant "Levels"): 2 px under the value, its fill = the value.
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.bottom; topMargin: 1 } height: 2; radius: 1; color: Qt.alpha(Style.textMuted, 0.22)
          Rectangle { height: parent.height; radius: 1; color: (root.percentage <= 10 ? Style.red : root.percentage <= 20 ? Style.orange : Style.green); width: parent.width * Math.max(0, Math.min(1, root.percentage / 100)) } }
      color: barHost ? barHost.barForeground : Style.text
    }
  }

  MouseArea {
    id: chipMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.barHost) root.barHost.quickRequested("battery")
  }
}
