import QtQuick
import QtQuick.Effects
import "../../../"

// Seek bar after serpantinum's WavySeekBar: the played part is a filled, drifting wave ridge on
// the track, the rest a flat dim line. The wave flattens when paused; it only animates (16 ms,
// as upstream) while visible and playing. Click / drag emits seek(fraction) on release.
Item {
  id: root

  property real value: 0          // 0..1
  property bool playing: false
  property bool seekable: true
  property color color: Style.accent
  // The owning window's visibility: an Item stays `visible` inside a hidden popup, so `visible`
  // alone would keep the 16 ms repaint running while the popup is closed.
  property bool live: true
  signal seek(real fraction)

  // Reference (serpantinum WavySeekBar) sizes: track 9, handle 17, amplitude 14.
  readonly property real stroke: 9
  readonly property real handle: 17
  readonly property real amplitude: 14
  readonly property real pad: handle / 2
  readonly property real cy: height - handle * 0.7
  // Upstream eases position updates over 250 ms (never while dragging).
  property real smoothed: root.value
  Behavior on smoothed { enabled: !ma.pressed; NumberAnimation { duration: 250 } }
  readonly property real shown: ma.pressed ? ma.dragValue : root.smoothed
  readonly property real progressX: pad + Math.max(0, Math.min(1, shown)) * (width - 2 * pad)

  property real phase: 0
  property real ampFactor: root.playing ? 1 : 0
  Behavior on ampFactor { NumberAnimation { duration: 600; easing.type: Easing.OutQuad } }

  implicitHeight: 36

  Timer {
    interval: 16
    repeat: true
    running: root.live && root.visible && (root.playing || root.ampFactor > 0.001)
    onTriggered: { root.phase = (root.phase + interval / 3000 * 2 * Math.PI) % (20 * Math.PI); wave.requestPaint() }  // 20π: whole turns for both mults (1, 2.2)
  }
  onShownChanged: wave.requestPaint()
  onWidthChanged: wave.requestPaint()
  onColorChanged: wave.requestPaint()

  // Quintic smoothstep: tapers the ridge in at the start and down into the progress point.
  function ease5(t) { t = Math.max(0, Math.min(1, t)); return t * t * t * (t * (6 * t - 15) + 10) }

  Canvas {
    id: wave
    anchors.fill: parent
    opacity: root.playing || ma.containsMouse ? 1 : 0.55
    Behavior on opacity { NumberAnimation { duration: 350 } }
    onPaint: {
      const ctx = getContext("2d")
      ctx.reset()
      ctx.lineCap = "round"
      ctx.lineWidth = root.stroke
      const c = root.color
      const rgba = (a) => Qt.rgba(c.r, c.g, c.b, a)
      const cy = root.cy, top = cy - root.stroke / 2, endX = root.progressX, pad = root.pad
      const baseLen = Math.max(40, (width - 2 * pad) / 3)

      ctx.strokeStyle = rgba(0.28)
      ctx.beginPath(); ctx.moveTo(endX, cy); ctx.lineTo(width - pad, cy); ctx.stroke()

      // Reference layers: a slow wide wave and a quicker narrow one; `swell` slowly breathes each.
      const layers = [
        { amp: 0.65, alpha: 0.50, taper: 130, len: baseLen * 1.75, mult: 1.0, off: 0, swell: 0 },
        { amp: 0.71, alpha: 0.90, taper: 105, len: baseLen * 1.05, mult: 2.2, off: 1.8, swell: Math.PI }
      ]
      for (const L of layers) {
        const A = root.amplitude * L.amp * root.ampFactor
        if (A < 0.3 || endX <= pad + 1) continue
        const k = 2 * Math.PI / L.len
        ctx.beginPath()
        ctx.moveTo(pad, cy)
        for (let x = pad; ; x += 2.5) {
          const px = Math.min(x, endX)
          const env = root.ease5((px - pad) / 64) * root.ease5((endX - px) / L.taper)
          const n = Math.sin(k * px - root.phase * L.mult + L.off)
          const sw = 0.8 + 0.2 * Math.sin(k / 6 * px - root.phase * L.mult * 0.5 + L.swell)
          ctx.lineTo(px, top - 0.5 * (1 + n) * sw * A * env)
          if (px >= endX) break
        }
        ctx.lineTo(endX, top)
        ctx.lineTo(endX, cy)
        ctx.closePath()
        const g = ctx.createLinearGradient(0, top - A, 0, top)
        g.addColorStop(0, rgba(L.alpha * 0.55))
        g.addColorStop(1, rgba(L.alpha))
        ctx.fillStyle = g
        ctx.fill()
      }

      ctx.strokeStyle = rgba(1)
      ctx.beginPath(); ctx.moveTo(pad, cy); ctx.lineTo(Math.max(pad, endX), cy); ctx.stroke()
    }
  }

  Rectangle {
    width: root.handle; height: root.handle; radius: root.handle / 2
    x: Math.max(0, Math.min(root.width - width, root.progressX - width / 2))
    y: root.cy - height / 2
    color: ma.pressed || ma.containsMouse ? Qt.lighter(root.color, 1.15) : root.color
    Behavior on color { ColorAnimation { duration: 150 } }
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowVerticalOffset: 1; shadowBlur: 0.35; shadowOpacity: 0.45 }
    visible: root.seekable
    scale: ma.pressed ? 1.25 : ma.containsMouse ? 1.15 : 1
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
  }

  MouseArea {
    id: ma
    property real dragValue: 0
    anchors.fill: parent
    enabled: root.seekable
    hoverEnabled: true
    preventStealing: true
    cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
    function frac(mx) { return Math.max(0, Math.min(1, (mx - root.pad) / (root.width - 2 * root.pad))) }
    onPressed: (m) => dragValue = frac(m.x)
    onPositionChanged: (m) => { if (pressed) dragValue = frac(m.x) }
    onReleased: (m) => root.seek(frac(m.x))
  }
}
