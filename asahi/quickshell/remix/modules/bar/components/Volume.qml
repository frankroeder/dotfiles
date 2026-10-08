import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../../../"

// Default sink volume, bound to PipeWire (no polling). Click: mute; wheel: step.
Item {
  id: root

  property var barHost: null
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: [root.sink] }
  readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)
  readonly property int percentage: sink && sink.audio ? Math.round(sink.audio.volume * 100) : -1

  function outputIcon(pct, isMuted) {
    if (isMuted) return "󰖁"
    if (pct <= 30) return "󰕿"
    if (pct <= 60) return "󰖀"
    return "󰕾"
  }

  implicitWidth: content.implicitWidth + 6
  implicitHeight: Style.barHeight

  HoverTint { lit: chipMouse.containsMouse }

  RowLayout {
    id: content
    anchors.centerIn: parent
    spacing: 4

    Text {
      text: root.outputIcon(root.percentage, root.muted)
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontMicVolIcon
      color: root.muted ? Style.red : Style.green
    }

    Text {
      text: root.percentage >= 0 ? root.percentage + "%" : "--%"
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
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    // Click = mute, right-click = Media overview (devices, mixer).
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) { if (root.barHost) root.barHost.quickRequested("media") }
      else Quickshell.execDetached([root.binDir + "/asahi-media-control", "output-volume", "mute-toggle"])
    }
    onWheel: wheel => {
      if (Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)) return
      root.wheelAcc += wheel.angleDelta.y
      if (Math.abs(root.wheelAcc) < 120) return
      const direction = root.wheelAcc > 0 ? "raise" : "lower"
      root.wheelAcc = 0
      Quickshell.execDetached([root.binDir + "/asahi-media-control", "output-volume", direction])
    }
  }
}
