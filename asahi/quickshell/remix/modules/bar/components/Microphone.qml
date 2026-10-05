import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../../../"

// Default source volume, bound to PipeWire (no polling). Click: mute; wheel: step.
Item {
  id: root

  property var barHost: null
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  readonly property var source: Pipewire.defaultAudioSource
  PwObjectTracker { objects: [root.source] }
  readonly property bool muted: !!(source && source.audio && source.audio.muted)
  readonly property int level: source && source.audio ? Math.round(source.audio.volume * 100) : -1

  implicitWidth: content.implicitWidth + 6
  implicitHeight: Style.barHeight

  HoverTint { lit: chipMouse.containsMouse }

  RowLayout {
    id: content
    anchors.centerIn: parent
    spacing: 4

    Text {
      text: root.muted ? "󰍭" : "󰍬"
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontMicVolIcon
      color: root.muted ? Style.red : Style.blueAlt
    }

    Text {
      text: root.level >= 0 ? root.level + "%" : "--%"
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontBody
      color: barHost ? barHost.barForeground : Style.text
    }
  }

  // One step per wheel notch (120); trackpad swipes accumulate, horizontal ones are ignored.
  property real wheelAcc: 0

  MouseArea {
    id: chipMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached([root.binDir + "/asahi-media-control", "input-volume", "mute-toggle"])
    onWheel: wheel => {
      if (Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)) return
      root.wheelAcc += wheel.angleDelta.y
      if (Math.abs(root.wheelAcc) < 120) return
      const direction = root.wheelAcc > 0 ? "raise" : "lower"
      root.wheelAcc = 0
      Quickshell.execDetached([root.binDir + "/asahi-media-control", "input-volume", direction])
    }
  }
}
