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
  Behavior on opacity { MenuAnim { effects: true } }

  Rectangle {
    id: shadowSrc
    anchors.fill: parent
    anchors.topMargin: 6
    radius: root.cardRadius
    color: Style.m3shadow
    visible: false
  }
  MultiEffect {
    source: shadowSrc
    anchors.fill: shadowSrc
    blurEnabled: true
    blur: 1.0
    blurMax: 32
  }

  Rectangle {
    id: body
    anchors.fill: parent
    color: Style.m3surface
    radius: root.cardRadius
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
