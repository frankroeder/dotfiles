import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../../"

Scope {
  id: root

  property bool visible: false
  property var osdScreen: null
  property string icon: ""
  property string label: ""
  property string value: ""
  property real percent: 0
  property color accent: Style.blueAlt
  property string pending: ""
  property bool showBar: true

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  function focusedScreen() {
    const mon = Hyprland.focusedMonitor
    return mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
  }

  function show(kind, nextIcon, nextLabel, nextPercent, nextValue) {
    osdScreen = focusedScreen()
    icon = nextIcon
    label = nextLabel
    percent = Math.max(0, Math.min(100, Number(nextPercent) || 0))
    value = nextValue
    accent = kind === "volume" ? Style.green : (kind === "brightness" ? Style.orange : Style.blueAlt)
    showBar = true
    visible = true
    hideTimer.interval = 1100
    hideTimer.restart()
  }

  // Bar-less text toast (launch feedback). duration 0 = sticky until dismissToast().
  function toast(nextIcon, nextLabel, nextValue, duration) {
    osdScreen = focusedScreen()
    icon = nextIcon
    label = nextLabel
    value = nextValue || ""
    percent = 0
    accent = Style.blueAlt
    showBar = false
    visible = true
    const ms = Number(duration) || 0
    if (ms > 0) {
      hideTimer.interval = ms
      hideTimer.restart()
    } else {
      hideTimer.stop()
    }
  }

  function dismissToast() {
    if (root.showBar) return
    hideTimer.stop()
    root.visible = false
  }

  // A busy Process ignores `running = true` and restarts after the old run, whose output then parsed
  // as the new kind ("Volume 0%" for keyboard 45). The newest request waits in one slot instead.
  property var queued: null
  function query(kind, command) {
    if (osdProc.running) { root.queued = { kind: kind, command: command }; return }
    pending = kind
    osdProc.command = command
    osdProc.running = true
  }

  Timer {
    id: hideTimer
    interval: 1100
    onTriggered: root.visible = false
  }
  // The window stays mapped while the card fades out (it used to unmap at once: no fade-out).
  Timer { id: osdLinger; interval: 140 }
  onVisibleChanged: if (!root.visible) osdLinger.restart()

  Process {
    id: osdProc
    stdout: StdioCollector {
      onStreamFinished: {
        const t = text.trim()
        if (root.pending === "volume" || root.pending === "mic") {
          let data = {}
          try {
            data = JSON.parse(t)
          } catch (_) {
            return
          }
          const muted = (data.class || []).includes("muted")
          const pct = data.percentage || 0
          if (root.pending === "volume") {
            root.show("volume", muted ? "󰖁" : "󰕾", "Volume", pct, muted ? "Muted" : pct + "%")
          } else {
            root.show("volume", muted ? "󰍭" : "󰍬", "Microphone", pct, muted ? "Muted" : pct + "%")
          }
        } else if (root.pending === "keyboard") {
          root.show("brightness", "󰌌", "Keyboard", Number(t) || 0, t + "%")
        } else if (root.pending === "caps") {
          const on = t === "true"
          root.show("caps", on ? "󰪛" : "󰪚", "Caps Lock", on ? 100 : 0, on ? "On" : "Off")
        }
      }
    }
    onRunningChanged: {
      if (running || !root.queued) return
      const next = root.queued
      root.queued = null
      root.query(next.kind, next.command)
    }
  }

  IpcHandler {
    target: "osd"
    function volume(): void { root.query("volume", ["bash", root.binDir + "/asahi-audio", "output"]) }
    function mic(): void { root.query("mic", ["bash", root.binDir + "/asahi-audio", "input"]) }
    function brightnessSet(value: string): void {
      const n = Number(value)
      root.show("brightness", "󰃠", "Brightness", n || 0, (Number.isFinite(n) ? String(n) : value) + "%")
    }
    function keyboard(): void {
      root.query("keyboard", [
        "bash",
        "-c",
        "brightnessctl --device=kbd_backlight -m | awk -F, '{gsub(/%/, \"\", $4); print $4}'"
      ])
    }
    function caps(): void {
      root.query("caps", [
        "bash",
        "-c",
        "hyprctl devices -j | jq -r '[.keyboards[] | select(.main == true) | .capsLock][0] // [.keyboards[] | .capsLock][0] // false'"
      ])
    }
    function message(icon: string, label: string, value: string): void {
      root.toast(icon, label, value, 1400)
    }
  }

  PanelWindow {
    visible: root.visible || osdLinger.running
    focusable: false
    color: "transparent"
    screen: root.osdScreen
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    anchors { bottom: true }
    margins { bottom: 90 }
    implicitWidth: 320
    implicitHeight: 76

    Rectangle {
      anchors.fill: parent
      radius: Style.menuRadiusLg
      color: Style.menuBg
      border.color: Qt.alpha(root.accent, 0.45)
      border.width: 1
      opacity: root.visible ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: 120 } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Text {
          text: root.icon
          font.family: Style.fontFamily
          font.pixelSize: 28
          color: root.accent
          Layout.preferredWidth: 34
          horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 7

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: root.label
              font.family: Style.menuSans
              font.pixelSize: 13
              font.weight: Font.DemiBold
              color: Style.menuInk
              Layout.fillWidth: true
            }
            Text {
              textFormat: Text.PlainText  // Bluetooth device names
              text: root.value
              font.family: Style.menuSans
              font.pixelSize: 12
              font.weight: Font.Medium
              color: Style.menuInkDeep
            }
          }

          Rectangle {
            visible: root.showBar
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: Style.moduleBg
            clip: true

            Rectangle {
              width: parent.width * root.percent / 100
              height: parent.height
              radius: 4
              color: root.accent
              Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            }
          }
        }
      }
    }
  }
}
