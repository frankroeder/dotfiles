import QtQuick
import "../../"

// Selection pill whose edges travel apart (caelestia ActiveIndicator, end-4 AnimatedTabIndexPair): the leading edge
// on a velocity-keeping spring (held arrow keys glide on), the trailing one 1.5× slower, so it stretches toward the
// new entry and settles there.
// Owners set x / width and the target edges; `animate: false` snaps (a card opening).
Rectangle {
  id: pill
  property real targetTop: 0
  property real targetBottom: 0
  property bool animate: true
  property real edgeTop: targetTop
  property real edgeBottom: targetBottom
  y: edgeTop
  height: Math.max(0, edgeBottom - edgeTop)
  radius: Style.menuRadiusFull
  color: Style.menuSelFill
  border.width: 1
  border.color: Style.menuSelBorder
  // Moving down, the top trails; moving up, the bottom does. The direction is latched when the target moves: read from
  // the edges in a binding it was stale at the start of a move (stretched on the first move only).
  property bool down: true
  onTargetTopChanged: pill.down = pill.targetTop > pill.edgeTop
  Behavior on edgeTop { enabled: pill.animate && !Style.reduceMotion; MenuSpring { slow: pill.down ? 1.5 : 1 } }
  Behavior on edgeBottom { enabled: pill.animate && !Style.reduceMotion; MenuSpring { slow: pill.down ? 1 : 1.5 } }
}
