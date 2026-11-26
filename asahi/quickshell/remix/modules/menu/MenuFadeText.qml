import QtQuick
import "../../"

// A big readout that changes in place (bar popup tiles, pane heroes; never the bar): the old value fades out, the new
// one in (caelestia's StyledText `animate`). Runs only when the text changes and its window is shown (SysPanel lives
// in every bar: closed, its tiles still faded on every 3 s sample); off under reduced motion. Its owner must not bind
// `opacity`. Not while hidden either: a pane building in the background (cached values) came in mid-fade.
Text {
  id: root
  // The old value lifts out, the new one rises in (end-4 StyledText `animateChange`: slide + fade).
  transform: Translate { id: lift }
  Behavior on text {
    enabled: !Style.reduceMotion && root.visible && root.Window.window !== null && root.Window.window.visible
    SequentialAnimation {
      ParallelAnimation {
        NumberAnimation { target: root; property: "opacity"; to: 0.15; duration: 80; easing.type: Easing.InSine }
        NumberAnimation { target: lift; property: "y"; to: -3; duration: 80; easing.type: Easing.InSine }
      }
      PropertyAction {}
      PropertyAction { target: lift; property: "y"; value: 3 }
      ParallelAnimation {
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutSine }
        NumberAnimation { target: lift; property: "y"; to: 0; duration: 160; easing.type: Easing.OutSine }
      }
    }
  }
}
