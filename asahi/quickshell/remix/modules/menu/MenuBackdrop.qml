import QtQuick
import "../../"

// Dim wash plus one soft accent glow drifting behind the card. Only ticks
// while something is revealed, so a closed launcher costs nothing.
Item {
  id: root
  property real reveal: 1.0
  property real t: 0
  anchors.fill: parent
  opacity: reveal

  Behavior on opacity {
    NumberAnimation {
      duration: Style.menuAnimMs
      easing.type: Easing.OutCubic
    }
  }

  FrameAnimation {
    running: root.reveal > 0 && root.visible
    onTriggered: root.t = elapsedTime
  }

  ShaderEffect {
    anchors.fill: parent
    property real iTime: root.t
    property size iResolution: Qt.size(width, height)
    property color colDim: Qt.alpha(Style.crust, 0.6)
    property color colA: Style.menuNeon
    property color colB: Style.menuNeonAlt
    property color colC: Style.menuSealAlt
    fragmentShader: Qt.resolvedUrl("shaders/aurora.frag.qsb")
  }
}
