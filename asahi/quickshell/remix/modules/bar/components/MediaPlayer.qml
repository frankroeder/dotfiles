import QtQuick
import Quickshell
import Quickshell.Io
import "../../../"
import "../../../services" as Services
import "../cava_bars.js" as CavaBars

Rectangle {
  id: root

  property var barHost: null
  readonly property bool solidBar: barHost !== null && barHost !== undefined
  property real maxChipWidth: 280
  property bool fullMode: false
  property var cavaValues: []
  property bool cavaRunning: false
  property real cavaLast: 0
  // Notch budget from BarHost; 280 caps the chip on notchless externals.
  readonly property int chipCap: Math.min(root.maxChipWidth, 280)
  readonly property int chipPad: solidBar ? 10 : 16

  readonly property string cavaDir: "/tmp/quickshell-remix-" + (Quickshell.env("USER") || "user")
  readonly property string cavaCfg: root.cavaDir + "/cava.conf"
  readonly property string cavaFrame: root.cavaDir + "/cava-frame"

  color: solidBar ? "transparent" : (mediaMouse.containsMouse ? Style.barHoverBg : Style.barBg)
  radius: solidBar ? 0 : Style.radius
  border.width: solidBar ? 0 : 1
  border.color: solidBar ? "transparent" : (mediaMouse.containsMouse ? Style.barHoverBorder : Style.barBorder)
  Behavior on color { ColorAnimation { duration: 140 } }
  Behavior on border.color { ColorAnimation { duration: 140 } }
  scale: solidBar ? 1.0 : (mediaMouse.containsMouse ? 1.018 : 1.0)

  implicitWidth: Math.min(root.chipCap, contentCol.implicitWidth + root.chipPad)
  implicitHeight: solidBar ? Style.barHeight : 26

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: Style.barChipInset
    anchors.bottomMargin: Style.barChipInset
    radius: Style.radiusSm
    visible: solidBar
    color: mediaMouse.containsMouse ? Style.barStripHover : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  property bool hasMedia: Services.Players.hasPlayer
  property string mediaText: {
    if (!hasMedia) return ""
    const title = Services.Players.title || "Media"
    const artist = Services.Players.artist || ""
    return (Services.Players.isPlaying ? " " : " ") + (artist ? artist + " - " + title : title)
  }

  visible: hasMedia
  onHasMediaChanged: if (!root.hasMedia) root.fullMode = false

  // Same config/frame file as the launcher media pane; pgrep keeps it one cava process.
  function startCava() {
    if (root.cavaRunning) return
    root.cavaRunning = true
    root.cavaLast = 0
    Quickshell.execDetached([
      "sh", "-c",
      "dir=$1;cfg=$2;frm=$3; if ! command -v cava >/dev/null 2>&1; then exit 0; fi; " +
      "mkdir -p \"$dir\"; " +
      "printf '%s\\n' '[general]' 'bars=24' 'framerate=30' 'autosens=1' 'sensitivity=180' '' '[input]' 'method=pulse' 'source=auto' '' " +
      "'[output]' 'method=raw' 'raw_target=/dev/stdout' 'data_format=ascii' 'ascii_max_range=100' 'bar_delimiter=59' 'frame_delimiter=10' > \"$cfg\"; " +
      "if ! pgrep -f \"cava -p $cfg\" >/dev/null 2>&1; then " +
      ": > \"$frm\"; (stdbuf -oL cava -p \"$cfg\" 2>/dev/null | while IFS= read -r ln; do printf '%s\\n' \"$ln\" > \"$frm\"; done) & fi",
      "sh", root.cavaDir, root.cavaCfg, root.cavaFrame
    ])
  }

  function stopCava() {
    root.cavaRunning = false
    root.cavaValues = []
    Quickshell.execDetached(["pkill", "-f", "cava -p " + root.cavaCfg])
  }

  onFullModeChanged: {
    if (root.fullMode && root.hasMedia) root.startCava()
    else root.stopCava()
  }

  Column {
    id: contentCol
    anchors.centerIn: parent
    spacing: 1

    Text {
      id: titleText
      text: root.mediaText
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontBody
      color: solidBar && barHost ? barHost.barForeground : Style.text
      elide: Text.ElideRight
      width: Math.min(implicitWidth, root.chipCap - root.chipPad)
    }

    Row {
      visible: root.fullMode
      width: titleText.width
      height: 10
      spacing: 1
      Repeater {
        model: 24
        Rectangle {
          required property int index
          width: Math.max(2, (parent.width - 23) / 24)
          anchors.bottom: parent.bottom
          height: CavaBars.barHeight((root.cavaValues[index] || 0), 10)
          radius: 1
          color: Style.teal
        }
      }
    }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: 6
    anchors.rightMargin: 6
    anchors.bottomMargin: 3
    height: 2
    radius: 1
    color: Qt.alpha(Style.text, 0.12)
    visible: !root.fullMode && Services.Players.progress > 0

    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, Services.Players.progress))
      height: parent.height
      radius: parent.radius
      color: Style.teal
      Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }
  }

  Process {
    id: cavaRd
    command: ["cat", root.cavaFrame]
    stdout: StdioCollector {
      // Writer truncates before it writes, so an empty read is a race, not a frame.
      onStreamFinished: if (text.trim()) { root.cavaValues = CavaBars.parseFrame(text); root.cavaLast = Date.now() }
    }
  }

  Timer {
    interval: 90
    running: root.fullMode && root.visible && Services.Players.isPlaying
    repeat: true
    triggeredOnStart: true
    onRunningChanged: if (!running) root.cavaValues = []
    onTriggered: {
      // Launcher media pane pkills cava on close: frames stop, restart ours.
      if (root.cavaRunning && root.cavaLast > 0 && Date.now() - root.cavaLast > 3000) root.cavaRunning = false
      if (!root.cavaRunning) root.startCava()
      if (!cavaRd.running) cavaRd.running = true
    }
  }

  Timer {
    id: clickWait
    interval: 220
    onTriggered: Services.Players.playPause()
  }

  MouseArea {
    id: mediaMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) Services.Players.next()
      else if (mouse.button === Qt.MiddleButton) Services.Players.previous()
      else clickWait.restart()
    }
    onDoubleClicked: (mouse) => {
      if (mouse.button !== Qt.LeftButton) return
      clickWait.stop()
      root.fullMode = !root.fullMode
    }
  }
}
