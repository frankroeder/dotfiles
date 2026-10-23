import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import "../../../"

// Glyph and percent straight from UPower (no script, no poll); the time to empty (to full while charging) when
// BarHost grants the room. Click: Quick > Battery.
Item {
  id: root

  property var barHost: null
  property bool showTime: false

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

  // UPower's estimate in seconds, 0 = unknown (it has none for a while after plugging / unplugging).
  readonly property real secondsLeft: dev.state === UPowerDeviceState.Charging ? dev.timeToFull
    : dev.state === UPowerDeviceState.Discharging ? dev.timeToEmpty : 0
  readonly property string timeText: {
    const s = root.secondsLeft
    if (!(s > 60)) return ""
    const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60)
    return h > 0 ? h + "h " + m + "m" : m + "m"
  }
  // What the chip costs without the time, and what the time adds (BarHost decides from these).
  readonly property real baseWidth: glyph.implicitWidth + pct.implicitWidth + 4 + 6
  readonly property real timeWidth: root.timeText !== "" ? timeMetrics.advanceWidth + 4 : 0
  TextMetrics { id: timeMetrics; font: timeLabel.font; text: root.timeText }

  visible: dev.ready
  implicitWidth: row.implicitWidth + 6
  implicitHeight: Style.barHeight

  HoverTint { lit: chipMouse.containsMouse }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 4

    Text {
      id: glyph
      text: root.iconGlyph
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontGlyphTall
      color: root.percentage <= 10 ? Style.red : (root.percentage <= 20 ? Style.orange : Style.green)
    }

    Text {
      id: pct
      text: root.percentage + "%"
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontBody
      color: barHost ? barHost.barForeground : Style.text
    }

    Text {
      id: timeLabel
      visible: root.showTime && root.timeText !== ""
      text: root.timeText
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontCaption
      color: Style.textMuted
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
