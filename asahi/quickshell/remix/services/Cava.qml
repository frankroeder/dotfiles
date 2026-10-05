pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../modules/bar/cava_bars.js" as CavaBars

// One cava for every visualizer, frames straight from stdout (no frame file / per-frame cat).
// Runs only while someone holds it: hold(owner, true/false); owners release in onDestruction.
Singleton {
  id: root

  property var holders: []
  property var values: []
  // cava not installed: the media pane says so instead of "starting" forever.
  property bool missing: false
  readonly property bool active: values.some(v => v > 0)

  function hold(owner, on) {
    const rest = root.holders.filter(h => h !== owner)
    root.holders = on ? rest.concat([owner]) : rest
  }

  Process {
    running: root.holders.length > 0
    // pdeathsig: cava gets SIGTERM when qs dies (exec keeps it through sh).
    command: ["setpriv", "--pdeathsig", "TERM", "sh", "-c",
      "printf '%s\\n' '[general]' 'bars=24' 'framerate=30' 'autosens=1' 'sensitivity=180' '[input]' 'method=pulse' " +
      "'source=auto' '[output]' 'method=raw' 'raw_target=/dev/stdout' 'data_format=ascii' 'ascii_max_range=100' " +
      "'bar_delimiter=59' 'frame_delimiter=10' > \"$1\" && exec cava -p \"$1\"",
      "sh", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-cava.conf"]
    stdout: SplitParser { onRead: line => root.values = CavaBars.parseFrame(line) }
    onStarted: root.missing = false
    onExited: code => {
      root.missing = code === 127
      root.values = []
      if (!root.missing && root.holders.length) restart.start()
    }
  }
  // cava died on its own while held (pipewire-pulse restart): re-run the binding.
  Timer {
    id: restart
    interval: 2000
    onTriggered: root.holders = root.holders.slice()
  }
}
