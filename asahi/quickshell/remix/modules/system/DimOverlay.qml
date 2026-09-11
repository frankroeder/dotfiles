import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Click-through black shade per output. Asahi HDMI has no DDC I2C, so this is
// the brightness control for focused externals.
Scope {
  id: root

  property var levels: ({})

  readonly property string stateDir: {
    const runtime = Quickshell.env("XDG_RUNTIME_DIR")
    if (runtime && runtime.length) return runtime + "/asahi-brightness"
    return "/tmp/asahi-brightness-" + Quickshell.env("USER")
  }

  function percentFor(name) {
    const v = root.levels[name]
    if (v === undefined || v === null) return 100
    return v
  }

  function setPercent(name, pct) {
    if (!name) return 100
    let n = Math.round(Number(pct))
    if (!isFinite(n)) n = 100
    if (n < 1) n = 1
    if (n > 100) n = 100
    const next = Object.assign({}, root.levels)
    next[name] = n
    root.levels = next
    return n
  }

  IpcHandler {
    target: "dim"
    function get(monitor: string): string {
      return String(root.percentFor(monitor))
    }
    function set(monitor: string, percent: string): string {
      return String(root.setPercent(monitor, percent))
    }
  }

  Process {
    id: restoreProc
    command: [
      "bash", "-c",
      "d=\"" + root.stateDir + "\"; [ -d \"$d\" ] || exit 0; " +
      "for f in \"$d\"/*; do [ -f \"$f\" ] || continue; " +
      "printf '%s %s\\n' \"$(basename \"$f\")\" \"$(tr -d '\\n' < \"$f\")\"; done"
    ]
    stdout: SplitParser {
      onRead: function(line) {
        const parts = String(line).trim().split(" ")
        if (parts.length < 2) return
        root.setPercent(parts[0], parts[1])
      }
    }
  }

  Component.onCompleted: restoreProc.running = true

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: dimWin
      required property var modelData
      screen: modelData
      readonly property int shadePercent: {
        const v = root.levels[modelData.name]
        if (v === undefined || v === null) return 100
        return v
      }
      visible: dimWin.shadePercent < 100
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      exclusiveZone: 0
      focusable: false
      mask: Region {}
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "asahi-dim"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      anchors { top: true; left: true; right: true; bottom: true }

      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: Math.max(0, Math.min(0.92, 1 - dimWin.shadePercent / 100))
      }
    }
  }
}
