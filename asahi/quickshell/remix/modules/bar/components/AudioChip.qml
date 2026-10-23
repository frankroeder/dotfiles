import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "../../../"

// Default sink (or source, `input`) volume, bound to PipeWire (no polling). Click: mute; wheel: step;
// right-click: Media overview (devices, mixer).
Item {
  id: root

  property var barHost: null
  property bool input: false
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property string control: root.input ? "input-volume" : "output-volume"

  readonly property var node: root.input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
  PwObjectTracker { objects: [root.node] }
  readonly property bool muted: !!(node && node.audio && node.audio.muted)
  readonly property int percentage: node && node.audio ? Math.round(node.audio.volume * 100) : -1

  // Mic in use (an app records from it): orange glyph, macOS's privacy dot. Muted stays red.
  PwNodeLinkTracker { id: links; node: root.input ? root.node : null }
  readonly property bool inUse: {
    const groups = links.linkGroups
    for (let i = 0; i < groups.length; i++) if (groups[i].source && groups[i].source.id === root.node.id) return true
    return false
  }

  readonly property string glyph: {
    if (root.input) return root.muted ? "󰍭" : "󰍬"
    if (root.muted) return "󰖁"
    if (root.percentage <= 30) return "󰕿"
    if (root.percentage <= 60) return "󰖀"
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
      text: root.glyph
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontGlyphTall
      color: root.muted ? Style.red : root.inUse ? Style.orange : root.input ? Style.blueAlt : Style.green
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
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) { if (root.barHost) root.barHost.quickRequested("media") }
      else Quickshell.execDetached([root.binDir + "/asahi-media-control", root.control, "mute-toggle"])
    }
    onWheel: wheel => {
      if (Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)) return
      root.wheelAcc += wheel.angleDelta.y
      if (Math.abs(root.wheelAcc) < 120) return
      const direction = root.wheelAcc > 0 ? "raise" : "lower"
      root.wheelAcc = 0
      Quickshell.execDetached([root.binDir + "/asahi-media-control", root.control, direction])
    }
  }
}
