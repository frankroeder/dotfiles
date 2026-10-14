import QtQuick
import "../../"

// Round link / link_off button: filled primary while connected (caelestia); busy = spinner, no clicks.
MenuIconBtn {
  property bool active: false
  property bool busy: false
  implicitWidth: 32
  implicitHeight: 32
  iconPx: 14
  icon: busy ? "󰔟" : (active ? "󰌷" : "󰌸")
  bg: active ? Style.m3primary : "transparent"
  tone: active ? Style.m3onPrimary : Style.m3onSurface
  opacity: busy ? 0.6 : 1
  enabled: !busy
}
