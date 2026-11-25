import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../../"
import "../menu" as Menu

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

  // Any change of the default output's volume or mute shows the card (headset buttons, an app, the bar wheel; ideas:
  // end-4, caelestia), not only our keys (they still ask over IPC: feedback at 0 / 100 %). A new default sink only
  // sets the baseline (no output-switch card: declined). Quiet while the launcher is open (Media pane sliders).
  property bool quietVolume: false
  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  property var seenSink: null
  property int seenVolume: -1
  property bool seenMuted: false
  // Only from a bound node (`ready`): a sink that just resolved (shell start, an output switch) reports volume 0
  // until PipeWire binds it, and the real value arriving read as a change (a "Volume N%" card each time). A device
  // route's volume (headphones, HDMI / DP, Bluetooth) can come after `ready`: the first 1.5 s of a sink only move
  // the baseline.
  property double settleUntil: 0
  function sinkMoved() {
    const a = root.sink && root.sink.ready ? root.sink.audio : null
    if (!a) return
    const vol = Math.round(a.volume * 100)
    const moved = root.seenSink === root.sink && (vol !== root.seenVolume || a.muted !== root.seenMuted)
      && Date.now() >= root.settleUntil
    root.seenSink = root.sink
    root.seenVolume = vol
    root.seenMuted = a.muted
    if (moved && !root.quietVolume) root.show("volume", a.muted ? "󰖁" : "󰕾", "Volume", vol, a.muted ? "Muted" : vol + "%")
  }
  onSinkChanged: { root.settleUntil = Date.now() + 1500; root.sinkMoved() }
  Connections {
    target: root.sink
    function onReadyChanged() { root.sinkMoved() }   // the baseline, once bound
  }
  Connections {
    target: root.sink ? root.sink.audio : null
    function onVolumesChanged() { root.sinkMoved() }
    function onMutedChanged() { root.sinkMoved() }
  }

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

  // Mode toggles (surface-dots ThemeOSD): night light, stay awake and DND confirm with a short card — handy for the
  // keybinds and on the external display. The same state files the bar chips watch (no polling); nothing in the first
  // 3 s (loads set the baseline), and only on / off: the night-light slider and wheel change the temperature quietly.
  property var modes: ({})
  property bool modesSettled: false
  Timer { interval: 3000; running: true; onTriggered: root.modesSettled = true }
  function mode(key, on, icon, label, value) {
    const was = root.modes[key]
    const m = Object.assign({}, root.modes)
    m[key] = on
    root.modes = m
    if (root.modesSettled && was !== undefined && was !== on) root.toast(icon, label, value, 1400)
  }
  FileView {
    path: Quickshell.env("ASAHI_NIGHTLIGHT_STATE") || Quickshell.env("HOME") + "/.local/state/asahi/nightlight.json"   // env: asahi-nightlight's, tests
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      let s = {}
      try { s = JSON.parse(text().trim()) } catch (e) { return }   // empty / cut short = mid-rewrite: no "Off" card
      root.mode("night", !!s.on, "󰽥", "Night light", s.on ? s.temperature + " K" : "Off")
    }
  }
  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/asahi-stay-awake"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.mode("awake", true, "󰅶", "Stay awake", "On")
    onLoadFailed: root.mode("awake", false, "󰅶", "Stay awake", "Off")
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
      color: Style.m3surfaceSolid
      border.color: Style.popupBorder
      border.width: Style.popupBorderWidth
      opacity: root.visible ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: Style.menuStateMs } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // The icon follows the value (end-4 OsdValueIndicator, caelestia brightness steps): the speaker gains waves
        // (low / medium / high), the display sun turns (0 → 180°) and grows with the level. Eases, never loops.
        Text {
          readonly property bool sun: root.icon === "󰃠" && root.showBar
          readonly property bool speaker: root.icon === "󰕾" && root.showBar
          text: speaker ? (root.percent < 34 ? "󰕿" : root.percent < 67 ? "󰖀" : "󰕾") : root.icon
          font.family: Style.fontMono
          font.pixelSize: 28
          color: root.accent
          Layout.preferredWidth: 34
          horizontalAlignment: Text.AlignHCenter
          rotation: sun ? root.percent * 1.8 : 0
          scale: sun ? 0.74 + 0.26 * root.percent / 100 : 1
          Behavior on rotation { enabled: !Style.reduceMotion; NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.menuEnter } }
          Behavior on scale { enabled: !Style.reduceMotion; NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.menuEnter } }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 7

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: root.label
              font.family: Style.menuSans
              font.pixelSize: Style.typeTitle
              font.weight: Font.DemiBold
              color: Style.menuInk
              Layout.fillWidth: true
            }
            Text {
              textFormat: Text.PlainText  // Bluetooth device names
              text: root.value
              font.family: Style.menuSans; font.features: Style.fontTabular
              font.pixelSize: Style.typeLead
              font.weight: Font.Medium
              color: Style.menuInkDeep
            }
          }

          Menu.MenuMeter {
            visible: root.showBar
            Layout.fillWidth: true
            value: root.percent / 100
            fill: root.accent
          }
        }
      }
    }
  }
}
