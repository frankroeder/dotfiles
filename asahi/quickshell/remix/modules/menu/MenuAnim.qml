import QtQuick
import "../../"

// M3 expressive "default spatial" spring: the one easing every panel,
// highlight and size change shares (caelestia Anim {}). `exit`: the short
// accelerating curve a closing surface leaves on. `fast`: the shorter, bouncier spring of small parts.
NumberAnimation {
  property bool effects: false
  property bool exit: false
  property bool fast: false
  duration: exit ? Style.menuExitMs : effects ? Style.menuAnimMs : fast ? Style.menuSpringFastMs : Style.menuSpringMs
  easing.type: Easing.BezierSpline
  easing.bezierCurve: exit ? Style.menuExit : effects ? Style.menuEffects : fast ? Style.menuSpringFast : Style.menuSpring
}
