import QtQuick
import "../../"

// M3 expressive "default spatial" spring: the one easing every panel,
// highlight and size change shares (caelestia Anim {}).
NumberAnimation {
  property bool effects: false
  duration: effects ? Style.menuAnimMs : Style.menuSpringMs
  easing.type: Easing.BezierSpline
  easing.bezierCurve: effects ? Style.menuEffects : Style.menuSpring
}
