import QtQuick
import "../../"

// Selection pill whose edges travel apart (caelestia ActiveIndicator, end-4 AnimatedTabIndexPair): the leading edge
// on the shared spring, the trailing one 1.5× slower, so it stretches toward the new entry and settles there.
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
  // At the start the edge still holds its old value: moving down, the top trails; moving up, the bottom does.
  Behavior on edgeTop { enabled: pill.animate; MenuAnim { duration: Style.menuSpringMs * (pill.targetTop > pill.edgeTop ? 1.5 : 1) } }
  Behavior on edgeBottom { enabled: pill.animate; MenuAnim { duration: Style.menuSpringMs * (pill.targetBottom < pill.edgeBottom ? 1.5 : 1) } }
}
