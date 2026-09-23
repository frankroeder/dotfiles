pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen recorder state for the bar chip and its panel. Polls
// `asahi-cmd-record status --json` (1 s while recording, 3 s idle), ticks
// the elapsed clock locally, and lists recent recordings.
Singleton {
  id: root

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property string videosDir: Quickshell.env("HOME") + "/Videos"

  property bool running: false
  property string file: ""
  property int startEpoch: 0
  property real bytes: 0
  property int elapsed: 0
  property var recent: []
  // Global panel toggle for the IPC / launcher entry; the bar chip has its own per-screen toggle.
  property bool panelOpen: false

  function refresh() { if (!statusProc.running) statusProc.running = true }
  function scanRecent() { if (!recentProc.running) recentProc.running = true }

  function start(mode, webcam) {
    const cmd = [root.binDir + "/asahi-cmd-record", mode || "fullscreen"]
    if (webcam) cmd.push("--webcam")
    Quickshell.execDetached(cmd)
    poke.restart()
  }
  function stop() { Quickshell.execDetached([root.binDir + "/asahi-cmd-record", "stop"]); poke.restart() }
  function open(path) { Quickshell.execDetached(["xdg-open", path]) }
  function revealFolder() { Quickshell.execDetached(["xdg-open", root.videosDir]) }
  function remove(path) { Quickshell.execDetached(["rm", "-f", path]); rescanDelay.restart() }

  function fmtElapsed(s) {
    s = Math.max(0, Math.floor(s))
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60
    const mm = (h > 0 ? String(m).padStart(2, "0") : String(m))
    return (h > 0 ? h + ":" : "") + mm + ":" + String(sec).padStart(2, "0")
  }
  function fmtBytes(b) {
    b = Number(b) || 0
    const units = ["B", "KiB", "MiB", "GiB"]
    let i = 0
    while (b >= 1024 && i < units.length - 1) { b /= 1024; i++ }
    return b.toFixed(i >= 2 ? 1 : 0) + " " + units[i]
  }

  Process {
    id: statusProc
    command: [root.binDir + "/asahi-cmd-record", "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(text)
          root.file = d.file || ""
          root.startEpoch = Number(d.start) || 0
          root.bytes = Number(d.bytes) || 0
          root.running = !!d.recording
        } catch (e) {}
      }
    }
  }

  Process {
    id: recentProc
    command: ["sh", "-c", "find \"$HOME/Videos\" -maxdepth 1 -name 'recording-*.mp4' -printf '%T@ %s %p\\n' 2>/dev/null | sort -rn | head -6"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.recent = text.trim().split("\n").filter(l => l).map(l => {
          const m = l.match(/^(\S+) (\d+) (.*)$/)
          if (!m) return null
          return { path: m[3], bytes: Number(m[2]), label: m[3].split("/").pop().replace(/^recording-/, "").replace(/\.mp4$/, "") }
        }).filter(x => x)
      }
    }
  }

  Timer { interval: root.running ? 1000 : 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
  Timer { id: poke; interval: 600; onTriggered: root.refresh() }
  Timer { id: rescanDelay; interval: 400; onTriggered: root.scanRecent() }
  Timer { interval: 1000; running: root.running; repeat: true; onTriggered: root.elapsed += 1 }

  onRunningChanged: {
    // start is 0 for a wf-recorder we did not launch: count from now, not from 1970.
    if (running) root.elapsed = root.startEpoch > 0 ? Math.max(0, Math.round(Date.now() / 1000) - root.startEpoch) : 0
    else rescanDelay.restart()
  }
  Component.onCompleted: scanRecent()
}
