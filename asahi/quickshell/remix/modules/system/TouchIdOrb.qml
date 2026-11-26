import QtQuick
import QtQuick.Shapes
import "../../"

// The Touch ID orb, shared by the lock screen (remix/lock.qml, no breathing there) and the shell's own prompts: a glass disc with a
// hairline ring and the glyph in the state's colour; once something happens the disc turns solid in that colour and
// the glyph takes the text-on-accent colour. No glow, no bold ring. It animates:
// the glyph breathes while it waits, an arc scans round the rim while the finger is read, and every other state lands
// with a small pop (the new glyph — check, crossed fingerprint — grows in).
// view = touchid_model.js view(); its orb phase:
//   ready    ring + fingerprint in the accent, breathing   reading  solid second accent, scanning arc
//   nomatch  solid red      retry  solid amber             match    solid green, a check
//   failed   crossed fingerprint, solid red / amber (tone) off      a lock, dim ring (no Touch ID in play)
Item {
  id: orb

  property var view: ({ orb: "off", tone: "" })
  property bool live: true                // animate: false while hidden (no per-frame work)
  property bool breathe: true             // the waiting glyph's loop; the lock turns it off (it would redraw all lock long)
  readonly property string phase: view.orb
  property real size: 46
  implicitWidth: size
  implicitHeight: size

  readonly property color ink: phase === "reading" ? Style.vivid2 : phase === "match" ? Style.green
    : phase === "nomatch" ? Style.red : phase === "retry" ? Style.yellow
    : phase === "failed" ? (view.tone === "fail" ? Style.red : Style.yellow)
    : phase === "off" ? Style.menuInk : Style.vivid
  readonly property string glyph: phase === "match" ? "󰄬" : phase === "failed" ? "󰺱" : phase === "off" ? "󰌾" : "󰈷"
  // Lit once something happens: the disc goes solid. Not while it waits or when Touch ID is not in play.
  readonly property bool lit: phase !== "ready" && phase !== "off"
  readonly property color glass: Style.isDark ? Qt.darker(Style.menuBg, 1.25) : Qt.lighter(Style.menuBg, 1.04)

  // 1 → 0 → 1 while it waits for a finger.
  property real beat: 1
  SequentialAnimation on beat {
    running: orb.live && orb.breathe && orb.phase === "ready"
    loops: Animation.Infinite
    onRunningChanged: if (!running) orb.beat = 1
    NumberAnimation { to: 0; duration: 1400; easing.type: Easing.InOutSine }
    NumberAnimation { to: 1; duration: 1400; easing.type: Easing.InOutSine }
  }
  // A lit state lands: the disc settles from a little smaller, the glyph grows in.
  // From `phase` itself: `lit` (a binding on it) still held the old phase here.
  onPhaseChanged: if (orb.live && orb.phase !== "ready" && orb.phase !== "off") land.restart()
  ParallelAnimation {
    id: land
    NumberAnimation { target: disc; property: "scale"; from: 0.86; to: 1; duration: 300; easing.type: Easing.OutBack }
    NumberAnimation {
      target: mark; property: "scale"; from: 0.5; to: 1; duration: 340
      easing.type: Easing.OutBack; easing.overshoot: 2.4
    }
  }
  Rectangle {
    id: disc
    anchors.fill: parent
    radius: width / 2
    // Each colour eases once, straight to its target (easing the disc toward an easing ink lagged the miss by 0.2 s).
    color: orb.lit ? orb.ink : orb.glass
    border.width: Math.max(1, orb.size * 0.028)
    border.color: Qt.alpha(orb.ink, orb.phase === "off" ? 0.55 : 1)
    Behavior on color { ColorAnimation { duration: 180 } }
    Behavior on border.color { ColorAnimation { duration: 180 } }

    // Reading: a quarter arc runs round inside the rim, in the glyph's colour.
    Shape {
      id: scan
      anchors.fill: parent
      visible: orb.phase === "reading"
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Qt.alpha(Style.menuOnAccent, 0.7)
        strokeWidth: Math.max(1.5, orb.size * 0.05)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: orb.size / 2; centerY: orb.size / 2
          radiusX: orb.size * 0.4; radiusY: orb.size * 0.4
          startAngle: -90; sweepAngle: 100
        }
      }
      RotationAnimator on rotation {
        running: orb.live && scan.visible
        from: 0; to: 360; duration: 900
        loops: Animation.Infinite
      }
    }
  }
  Text {
    id: mark
    anchors.centerIn: parent
    text: orb.glyph
    color: orb.lit ? Style.menuOnAccent : orb.ink
    Behavior on color { ColorAnimation { duration: 180 } }
    font.family: Style.menuMono
    font.pixelSize: orb.size * 0.52
    opacity: orb.phase === "ready" ? 0.45 + 0.55 * orb.beat : 1
  }
}
