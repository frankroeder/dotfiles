import QtQuick
import "../../"

// Entry of a popup card (bar popups, sheet, app grid): fade on the effects curve, 0.96 → 1 on the spring,
// grown from `target.transformOrigin` (the edge it hangs from). Runs once per open: no idle cost.
ParallelAnimation {
  id: root
  property Item target: null
  NumberAnimation {
    target: root.target; property: "opacity"; from: 0; to: 1
    duration: Style.menuAnimMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.menuEffects
  }
  NumberAnimation {
    target: root.target; property: "scale"; from: 0.96; to: 1
    duration: Style.menuSpringMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.menuSpring
  }
}
