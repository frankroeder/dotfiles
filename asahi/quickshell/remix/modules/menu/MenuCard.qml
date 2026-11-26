import QtQuick
import QtQuick.Effects
import "../../"

// Surface panel: no border, extra-large rounding, soft drop shadow.
// The owner slides it in from a screen edge; this only fades.
Item {
  id: root
  property int cardRadius: Style.menuPanelRadius
  property int cardMargin: 18
  property real chromeReveal: 1.0
  default property alias content: inner.data

  opacity: chromeReveal
  // `exit` from the Behavior's target: bound to chromeReveal it was read stale (the open faded on the exit curve).
  Behavior on opacity { id: fade; MenuAnim { effects: true; exit: fade.targetValue < 1 } }

  // Analytic shadow (one shader quad): a MultiEffect blur re-rendered its offscreen passes on every frame of a
  // pane switch's size animation.
  RectangularShadow {
    anchors.fill: parent
    anchors.topMargin: 6
    radius: root.cardRadius
    blur: 32
    color: Style.m3shadow
    cached: true
  }

  Rectangle {
    id: body
    anchors.fill: parent
    color: Style.m3surface
    radius: root.cardRadius
    // Hairline rim: keeps the edge on a wallpaper as bright (or dark) as the panel.
    border.width: Style.rim(Screen.devicePixelRatio)
    border.color: Style.menuHairline
    clip: true

    MouseArea {
      anchors.fill: parent
      onClicked: mouse => mouse.accepted = true
    }

    Item {
      id: inner
      anchors.fill: parent
      anchors.margins: root.cardMargin
      z: 1
    }
  }
}
