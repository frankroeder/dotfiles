import QtQuick
import "../../"

// The line under / beside the Touch ID orb, like the lock screen's caption: `strong` bold in the state's tone,
// `hint` muted after a dot. Animated here, unlike on the lock screen: a new message rises in, and "Reading" has three
// dots with a wave running through them. view = touchid_model.js view().
Row {
  id: line

  property var view: ({ orb: "off", tone: "", strong: "", hint: "" })
  property bool live: true
  property real pixelSize: 11
  spacing: 0

  readonly property color tone: view.tone === "accent2" ? Style.vivid2 : view.tone === "ok" ? Style.green
    : view.tone === "fail" ? Style.red : view.tone === "warn" ? Style.yellow : view.tone === "accent" ? Style.vivid
    : Style.m3onSurfaceVariant

  readonly property string message: view.strong + "|" + view.hint
  onMessageChanged: if (line.live) rise.restart()
  transform: Translate { id: lift }
  ParallelAnimation {
    id: rise
    NumberAnimation { target: line; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
    NumberAnimation { target: lift; property: "y"; from: line.pixelSize * 0.5; to: 0; duration: 240; easing.type: Easing.OutCubic }
  }

  // 0 → 3 once per wave; a dot is brightest as the wave passes it.
  property real wave: 0
  NumberAnimation on wave {
    running: line.live && line.view.orb === "reading"
    from: 0; to: 3; duration: 900
    loops: Animation.Infinite
  }

  Text {
    text: line.view.strong
    color: line.tone
    font.family: Style.menuSans
    font.pixelSize: line.pixelSize
    font.weight: Font.DemiBold
  }
  Repeater {
    model: line.view.orb === "reading" ? 3 : 0
    Text {
      required property int index
      // Distance from the wave's crest, round the three dots.
      readonly property real gap: Math.min(Math.abs(line.wave - index), 3 - Math.abs(line.wave - index))
      text: "  ●"
      color: line.tone
      opacity: 0.3 + 0.7 * Math.max(0, 1 - gap)
      font.family: Style.menuSans
      font.pixelSize: line.pixelSize * 0.72
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  Text {
    visible: line.view.hint !== ""
    text: (line.view.strong !== "" ? "  ·  " : "") + line.view.hint
    color: Style.m3onSurfaceVariant
    font.family: Style.menuSans
    font.pixelSize: line.pixelSize
  }
}
