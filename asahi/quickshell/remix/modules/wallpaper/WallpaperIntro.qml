import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../"
import "wallpaper_intro_geom.js" as Geom

// Background intros (omarchy): <wallpaper dir>/intros/<stem>.mp4 plays once on every output, above hyprpaper (which
// keeps the still) and below windows, and fades out onto the still it ends on. Until an output's video shows fresh
// frames it shows a cover: the clip's first frame (cached png, decoded synchronously in arm(), so it is in the
// window's first buffer, on screen before hyprlock locks: nothing presents while it holds the session; a VideoOutput
// may still hold the last run's end frame).
// With wallpaper span on, each output shows its slice of one canvas, cut like asahi-wallpaper-span (logical layout,
// `gap` per seam, cover + centred).
// Triggers: login (once per boot), WallpaperService.setWallpaper (picker, Super+B), and every unlock: asahi-lock
// calls `arm` before hyprlock and waits for `ready` (every output swapped the cover onto the screen), and `play`
// on hyprlock's unlock line (starts unlockDelayMs later). No clip: nothing shows.
Scope {
  id: root

  readonly property int fadeMs: 420
  readonly property int unlockDelayMs: 400
  property string src: ""
  property string frame: ""
  property bool active: false
  property bool go: false
  property int restart: 0
  property real fade: 1
  property int shown: 0             // outputs showing the cover (or with no cover to wait for)
  property bool played: false       // this arm's play() ran: asahi-lock calls it on hyprlock's unlock line and at its exit
  property var span: ({ enabled: false, gap: 0 })
  signal armed()

  FileView {
    path: WallpaperService.stateHome + "/asahi/wallpaper-span.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.span = JSON.parse(text()) } catch (_) {} }
  }

  // Where the video sits in this output's window (wallpaper_intro_geom.js, tested against asahi-wallpaper-span).
  function videoRect(screen) {
    const rects = Quickshell.screens.map(s => ({ name: s.name, x: s.x, y: s.y, w: s.width, h: s.height }))
    return Geom.videoRect(rects, screen.name, !!root.span.enabled, root.span.gap || 0)
  }

  function arm(path, start) {
    if (!path) return
    endTimer.stop()
    fadeOut.stop()
    delayTimer.stop()
    root.fade = 1   // snap: a fade-in would show the still first
    root.frame = WallpaperService.introFrame(path)
    root.shown = 0
    root.armed()
    const src = "file://" + WallpaperService.introClip(path)
    root.go = start   // before restart++: its handler pauses a clip still playing (lock during an intro)
    root.played = start
    if (root.active && root.src === src) root.restart++
    else { root.src = src; root.active = true }
    if (start) failsafe.restart()
    else failsafe.stop()
    console.info("intro: arm", path.slice(path.lastIndexOf("/") + 1), start ? "+ play" : "(hold)")
  }
  function play() {
    if (root.played) return
    if (!root.active) root.arm(WallpaperService.currentWallpaper, false)
    root.played = true
    delayTimer.restart()
  }
  Timer {
    id: delayTimer
    interval: root.unlockDelayMs
    onTriggered: { root.go = true; failsafe.restart(); console.info("intro: play") }
  }
  function finish() {
    if (endTimer.running || !root.active) return
    failsafe.stop()
    fadeOut.start()
    endTimer.restart()
  }
  Timer { id: failsafe; interval: 15000; onTriggered: root.finish() }   // a stalled decoder must not leave the cover up
  NumberAnimation { id: fadeOut; target: root; property: "fade"; to: 0; duration: root.fadeMs; easing.type: Easing.OutCubic }
  Timer {
    id: endTimer
    interval: root.fadeMs
    onTriggered: { root.active = false; root.go = false; root.src = ""; root.frame = "" }
  }

  Connections {
    target: WallpaperService
    function onWallpaperSet(path) { root.arm(path, true) }
  }

  IpcHandler {
    target: "wallpaperIntro"
    function arm(): void { root.arm(WallpaperService.currentWallpaper, false) }
    function ready(): bool { return !root.active || root.shown >= Quickshell.screens.length }
    function play(): void { root.play() }
  }

  // Login: once per boot ($XDG_RUNTIME_DIR is per boot), after the saved wallpaper is loaded.
  Process {
    id: bootMark
    command: ["sh", "-c", "m=\"${XDG_RUNTIME_DIR:-/tmp}/asahi-wallpaper-intro-boot\"; [ -e \"$m\" ] && exit 1; : >\"$m\""]
    onExited: (code) => { if (code === 0) root.arm(WallpaperService.currentWallpaper, true) }
  }
  Timer { interval: 1500; running: true; onTriggered: bootMark.running = true }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      visible: root.active && (cover.status === Image.Ready || player.ready)
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      exclusiveZone: 0
      focusable: false
      mask: Region {}
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "asahi-wall-intro"
      anchors { left: true; right: true; top: true; bottom: true }

      // One decoder per output: a MediaPlayer feeds a single VideoOutput.
      MediaPlayer {
        id: player
        readonly property bool ready: mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia
          || mediaStatus === MediaPlayer.EndOfMedia
        videoOutput: output
        loops: 1
        source: root.active ? root.src : ""
        onSourceChanged: if (source != "") pause()   // loads it and holds frame 0
        onReadyChanged: if (ready && root.go) play()
        onPositionChanged: if (root.active && player.duration > 0 && player.position >= player.duration - root.fadeMs) root.finish()
        onErrorOccurred: root.finish()
      }
      // Cover swaps since arm: at 2 it is on screen (the first may predate it).
      property int swaps: 0
      // Video frames since play started: the cover hides at 2 (the sink may still hold the last run's end).
      property int frames: 0
      function settle() { if (win.swaps < 2) { win.swaps = 2; root.shown++ } }
      Connections {
        target: root
        function onArmed() {
          win.frames = 0
          win.swaps = 0
          if (cover.status !== Image.Ready) win.settle()                        // no first frame: nothing to wait for
          else if (win.visible && cover.Window.window) cover.Window.window.update()   // shown and unchanged: swap again
        }
        function onGoChanged() { if (root.go && player.ready) player.play() }
        function onRestartChanged() { player.setPosition(0); if (root.go) player.play(); else player.pause() }
      }
      Connections {
        target: win.visible && win.swaps < 2 ? cover.Window.window : null
        function onFrameSwapped() { if (++win.swaps === 2) root.shown++ }
      }
      Connections {
        target: root.go && win.frames < 2 ? output.videoSink : null
        function onVideoFrameChanged() { if (++win.frames === 2) console.info("intro: video on", win.modelData.name) }
      }

      Item {
        id: canvas
        readonly property var r: root.videoRect(win.modelData)
        anchors.fill: parent
        clip: true
        opacity: root.fade
        VideoOutput {
          id: output
          x: canvas.r.x; y: canvas.r.y; width: canvas.r.w; height: canvas.r.h
          fillMode: VideoOutput.PreserveAspectCrop
        }
        Image {
          id: cover
          x: canvas.r.x; y: canvas.r.y; width: canvas.r.w; height: canvas.r.h
          fillMode: Image.PreserveAspectCrop
          source: root.frame ? "file://" + root.frame : ""
          visible: win.frames < 2
        }
      }
    }
  }
}
