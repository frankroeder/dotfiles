import QtQuick
import "../../"

// Velocity-keeping spring for motion that is retargeted mid-flight (held arrow / volume keys): a new target keeps the
// current speed instead of restarting a curve from rest. Overdamped (no overshoot): 90 % in ~110 ms, `slow` 1.5 for a
// trailing edge (~180 ms); a faster motionScale stops at 0.75. Owners turn their Behavior off under `Style.reduceMotion`.
SpringAnimation {
  property real slow: 1
  spring: 12 / (slow * Math.max(0.75, Style.motionScale))   // below 0.75 the fixed damping lets it overshoot
  damping: 0.7
  epsilon: 0.25   // Qt's advice for pixels; 0.005 ran ~0.3 s of sub-pixel frames per move
}
