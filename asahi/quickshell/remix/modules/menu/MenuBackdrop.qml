import QtQuick
import "../../"

// Frosted dim — Hyprland layer blur (quickshell.*) shows through translucent alpha.
Item {
  id: root
  property real reveal: 1.0
  anchors.fill: parent
  opacity: reveal

  Behavior on opacity {
    NumberAnimation {
      duration: Style.menuAnimMs
      easing.type: Easing.OutCubic
    }
  }

  // Soft cool wash so the compositor blur reads as glass, not a blackout.
  Rectangle {
    anchors.fill: parent
    color: Style.menuDimFrost
  }

  Rectangle {
    anchors.fill: parent
    color: Style.menuDim
  }
}
