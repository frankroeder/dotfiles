import QtQuick
import "../../"

// A big readout that changes in place (bar popup tiles, pane heroes; never the bar): the old value fades out, the new
// one in (caelestia's StyledText `animate`). Runs only when the text changes; off under reduced motion. Its owner
// must not bind `opacity`.
Text {
  id: root
  Behavior on text {
    enabled: !Style.reduceMotion
    SequentialAnimation {
      NumberAnimation { target: root; property: "opacity"; to: 0.15; duration: 80; easing.type: Easing.InSine }
      PropertyAction {}
      NumberAnimation { target: root; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutSine }
    }
  }
}
