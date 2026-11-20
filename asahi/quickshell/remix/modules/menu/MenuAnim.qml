import QtQuick
import "../../"

// M3 expressive "default spatial" spring: the one easing every panel,
// highlight and size change shares (caelestia Anim {}). `exit`: the short
// accelerating curve a closing surface leaves on.
NumberAnimation {
  property bool effects: false
  property bool exit: false
  duration: exit ? Style.menuExitMs : effects ? Style.menuAnimMs : Style.menuSpringMs
  easing.type: Easing.BezierSpline
  easing.bezierCurve: exit ? Style.menuExit : effects ? Style.menuEffects : Style.menuSpring
}
