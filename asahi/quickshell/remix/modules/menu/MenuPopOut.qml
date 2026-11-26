import QtQuick
import "../../"

// Exit of a popup card: MenuPopIn backwards on the short exit curve (150 ms). The owner keeps its
// window mapped while this runs (`visible: open || popOut.running`); grabs and Esc follow `open`, not `visible`.
ParallelAnimation {
  id: root
  property Item target: null
  NumberAnimation {
    target: root.target; property: "opacity"; to: 0
    duration: Style.menuExitMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.menuExit
  }
  NumberAnimation {
    target: root.target; property: "scale"; to: 0.96
    duration: Style.menuExitMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Style.menuExit
  }
}
