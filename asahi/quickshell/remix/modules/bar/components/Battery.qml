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

  visible: dev.ready
  implicitWidth: row.implicitWidth + 6
  implicitHeight: Style.barHeight

  HoverTint { down: chipMouse.pressed; lit: chipMouse.containsMouse }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 4

    Text {
      text: root.iconGlyph
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
