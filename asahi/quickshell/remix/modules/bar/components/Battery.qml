import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import "../../../"

// Glyph and percent straight from UPower (no script, no poll). Click: Quick > Battery.
Item {
  id: root

  property var barHost: null

  readonly property var dev: UPower.displayDevice
  readonly property int percentage: dev.ready ? Math.round(dev.percentage * 100) : 0
  // asahi-battery's glyphs: ten steps, charging bolts, plug while the charge limit holds.
  readonly property string iconGlyph: {
    const i = Math.min(9, Math.floor(percentage / 10))
    if (dev.state === UPowerDeviceState.Charging) return ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"][i]
    if (dev.state === UPowerDeviceState.FullyCharged) return "󰂅"
    if (dev.state === UPowerDeviceState.PendingCharge) return "\uf1e6"
    return ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"][i]
  }

  visible: dev.ready
  implicitWidth: row.implicitWidth + 6
  implicitHeight: Style.barHeight

  HoverTint { lit: chipMouse.containsMouse }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 4

    Text {
      text: root.iconGlyph
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontMicVolIcon
      color: root.percentage <= 10 ? Style.red : (root.percentage <= 20 ? Style.orange : Style.green)
    }

    Text {
      text: root.percentage + "%"
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontBody
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
