import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"
import "../../../services" as Services
import "../../launcher/arg_commands.js" as ArgCommands

RowLayout {
  id: root

  property var notificationCenter: null
  property bool isRecording: false
  property bool updatesAvailable: false
  property bool stayAwake: false
  property bool nightLightOn: false
  property int nightLightTemp: 6500
  // Soonest asahi-timer (systemd user timers); left ticks locally between polls.
  property int timerCount: 0
  property int timerLeft: 0
  property string timerLabel: ""
  property string timerUnit: ""
  property var barHost: null
  readonly property alias recChip: recChip
  readonly property bool solidBar: barHost !== null && barHost !== undefined

  readonly property string nightLightStatePath: Quickshell.env("HOME") + "/.local/state/asahi/nightlight.json"
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  spacing: solidBar ? 2 : 6

  function refreshStayAwake() {
    if (!stayAwakeProc.running) stayAwakeProc.running = true
  }

  function refreshNightLight() {
    if (!nightLightProc.running) nightLightProc.running = true
  }

  function toggleNightLight() {
    Quickshell.execDetached(["bash", binDir + "/asahi-nightlight", "toggle"])
    nightLightRefresh.restart()
  }

  function toggleStayAwake() {
    Quickshell.execDetached(["bash", root.binDir + "/asahi-stay-awake", "toggle"])
    stayAwakeRefresh.restart()
  }

  Process {
    id: nightLightProc
    command: ["bash", root.binDir + "/asahi-nightlight", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          root.nightLightOn = !!data.on
          root.nightLightTemp = data.temperature || 6500
        } catch (e) {
          root.nightLightOn = false
        }
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshNightLight()
  }

  Timer {
    id: nightLightRefresh
    interval: 400
    onTriggered: root.refreshNightLight()
  }

  Process {
    id: stayAwakeProc
    command: ["bash", root.binDir + "/asahi-stay-awake", "status"]
    onExited: code => { root.stayAwake = (code === 0) }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshStayAwake()
  }

  Timer {
    id: stayAwakeRefresh
    interval: 250
    onTriggered: root.refreshStayAwake()
  }

  Process {
    id: timerProc
    command: ["bash", root.binDir + "/asahi-timer", "list", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const list = JSON.parse(text.trim() || "[]")
          root.timerCount = list.length
          root.timerLeft = list.length ? list[0].left : 0
          root.timerLabel = list.length ? list[0].label : ""
          root.timerUnit = list.length ? list[0].unit : ""
        } catch (e) {
          root.timerCount = 0
        }
      }
    }
  }

  Timer {
    interval: root.timerCount > 0 ? 1000 : 4000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (root.timerCount > 0 && root.timerLeft > 0) root.timerLeft--
      if (!timerProc.running && (root.timerCount === 0 || root.timerLeft % 5 === 0)) timerProc.running = true
    }
  }

  Timer {
    id: timerRefresh
    interval: 300
    onTriggered: if (!timerProc.running) timerProc.running = true
  }

  Rectangle {
    id: stayAwakeChip
    width: solidBar ? stayAwakeGlyph.implicitWidth + 10 : 30
    height: solidBar ? Style.barHeight : 30
    radius: solidBar ? 0 : Style.radius
    color: solidBar ? "transparent" : (stayAwakeMouse.containsMouse ? Style.panelWarningBg : Style.barBg)
    border.width: solidBar ? 0 : 1
    border.color: root.stayAwake ? Style.yellow : (stayAwakeMouse.containsMouse ? Style.barHoverBorder : Style.barBorder)
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: Style.barChipInset
      anchors.bottomMargin: Style.barChipInset
      radius: Style.radiusSm
      visible: solidBar
      color: stayAwakeMouse.containsMouse ? Style.barStripHover : "transparent"
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    Text {
      id: stayAwakeGlyph
      anchors.centerIn: parent
      text: "󰅶"
      font.family: Style.fontFamily
      font.pixelSize: solidBar ? Style.barFontGlyph : 15
      color: root.stayAwake ? Style.yellow : (solidBar && barHost ? barHost.barForeground : Style.textMuted)
    }

    MouseArea {
      id: stayAwakeMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggleStayAwake()
    }

    TooltipWindow { target: stayAwakeChip; text: root.stayAwake ? "Stay awake (idle lock off)" : "Allow idle lock"; show: stayAwakeMouse.containsMouse }
  }

  Rectangle {
    id: nightChip
    width: solidBar ? Style.barIconSlot : 26
    height: solidBar ? Style.barHeight : 26
    radius: solidBar ? 0 : Style.radius
    color: solidBar ? "transparent" : (nightMouse.containsMouse ? Style.panelWarningBg : Style.barBg)
    border.width: solidBar ? 0 : 1
    border.color: root.nightLightOn ? Style.orange : (solidBar ? "transparent" : Style.barBorder)
    visible: true

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: Style.barChipInset
      anchors.bottomMargin: Style.barChipInset
      radius: Style.radiusSm
      visible: solidBar
      color: nightMouse.containsMouse ? Style.barStripHover : "transparent"
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    Text {
      id: nightGlyph
      anchors.centerIn: parent
      text: root.nightLightOn ? "󰽥" : "󰖔"
      font.family: Style.fontFamily
      font.pixelSize: solidBar ? Style.barFontGlyph : 15
      color: root.nightLightOn ? Style.orange : (solidBar && barHost ? barHost.barForeground : Style.textMuted)
    }

    MouseArea {
      id: nightMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggleNightLight()
    }

    TooltipWindow {
      target: nightChip
      text: root.nightLightOn ? ("Night light " + root.nightLightTemp + "K") : "Night light off"
      show: nightMouse.containsMouse
    }
  }

  // Recorder chip: only while recording, with the running clock. Click opens
  // the panel, right-click stops. Idle, the panel comes from Super+Alt+R.
  Rectangle {
    id: recChip
    readonly property bool rec: Services.Recorder.running
    readonly property color tone: Style.red
    visible: rec
    width: recRow.implicitWidth + (solidBar ? 8 : 12)
    height: solidBar ? Style.barHeight : 26
    radius: solidBar ? 0 : Style.radius
    color: solidBar ? "transparent" : (recMouse.containsMouse ? Style.panelDangerBg : Style.barBg)
    border.width: solidBar ? 0 : 1
    border.color: solidBar ? "transparent" : (recMouse.containsMouse ? Style.red : Style.barBorder)
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: Style.barChipInset
      anchors.bottomMargin: Style.barChipInset
      radius: Style.radiusSm
      visible: solidBar
      color: recMouse.containsMouse ? Style.barStripHover : "transparent"
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
      id: recRow
      anchors.centerIn: parent
      spacing: 5
      Text {
        text: "󰑋"
        font.family: Style.fontFamily; font.pixelSize: Style.barFontGlyph; color: recChip.tone
        SequentialAnimation on opacity {
          running: recChip.rec
          loops: Animation.Infinite
          NumberAnimation { from: 1; to: 0.25; duration: 700; easing.type: Easing.InOutSine }
          NumberAnimation { from: 0.25; to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
      }
      Text {
        visible: recChip.rec
        text: Services.Recorder.fmtElapsed(Services.Recorder.elapsed)
        font.family: Style.fontFamily; font.pixelSize: Style.barFontCaption; font.bold: true; color: recChip.tone
      }
    }

    MouseArea {
      id: recMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton && recChip.rec) Services.Recorder.stop()
        else if (root.barHost) root.barHost.toggleRecPanel()
      }
    }
    TooltipWindow {
      target: recChip
      text: recChip.rec ? "Recording — click for controls, right-click to stop" : "Screen recorder"
      show: recMouse.containsMouse
    }
  }

  Rectangle {
    id: timerChip
    width: timerRow.implicitWidth + (solidBar ? 8 : 12)
    height: solidBar ? Style.barHeight : 26
    radius: solidBar ? 0 : Style.radius
    color: solidBar ? "transparent" : (timerMouse.containsMouse ? Style.panelWarningBg : Style.barBg)
    border.width: solidBar ? 0 : 1
    border.color: solidBar ? "transparent" : (timerMouse.containsMouse ? Style.yellow : Style.barBorder)
    visible: root.timerCount > 0

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: Style.barChipInset
      anchors.bottomMargin: Style.barChipInset
      radius: Style.radiusSm
      visible: solidBar
      color: timerMouse.containsMouse ? Style.barStripHover : "transparent"
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
      id: timerRow
      anchors.centerIn: parent
      spacing: 5
      Text { text: "󰔛"; font.family: Style.fontFamily; font.pixelSize: Style.barFontGlyph; color: Style.yellow }
      Text {
        text: ArgCommands.formatSeconds(root.timerLeft) + (root.timerCount > 1 ? " +" + (root.timerCount - 1) : "")
        font.family: Style.fontFamily
        font.pixelSize: Style.barFontCaption
        font.bold: true
        color: solidBar && barHost ? barHost.barForeground : Style.text
      }
    }

    MouseArea {
      id: timerMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        Quickshell.execDetached([root.binDir + "/asahi-timer", "cancel", root.timerUnit])
        timerRefresh.restart()
      }
    }
    TooltipWindow { target: timerChip; text: root.timerLabel + " — click to cancel"; show: timerMouse.containsMouse }
  }

  Rectangle {
    id: updateChip
    width: solidBar ? Style.barIconSlot : 26
    height: solidBar ? Style.barHeight : 26
    radius: solidBar ? 0 : Style.radius
    color: solidBar ? "transparent" : (updateMouse.containsMouse ? Style.panelWarningBg : Style.barBg)
    border.width: solidBar ? 0 : 1
    border.color: solidBar ? "transparent" : (updateMouse.containsMouse ? Style.orange : Style.barBorder)
    visible: root.updatesAvailable
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: Style.barChipInset
      anchors.bottomMargin: Style.barChipInset
      radius: Style.radiusSm
      visible: solidBar
      color: updateMouse.containsMouse ? Style.barStripHover : "transparent"
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    Text {
      id: updateGlyph
      anchors.centerIn: parent
      text: "󰚰"
      font.family: Style.fontFamily
      font.pixelSize: solidBar ? Style.barFontGlyph : 15
      color: Style.orange
    }

    MouseArea {
      id: updateMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: Quickshell.execDetached(["qs", "-c", "remix", "ipc", "call", "pkgman", "toggle"])
    }
    TooltipWindow { target: updateChip; text: "dnf updates — click to open"; show: updateMouse.containsMouse }
  }

  Rectangle {
    width: notifRow.implicitWidth + (solidBar ? 8 : 12)
    height: solidBar ? Style.barHeight : 26
    radius: solidBar ? 0 : Style.radius
    border.width: solidBar ? 0 : 1
    border.color: solidBar ? "transparent" : Style.barBorder
    scale: solidBar ? 1.0 : (notifMouse.containsMouse ? 1.018 : 1.0)
    color: solidBar ? "transparent" : (notifMouse.containsMouse ? Style.barHoverBg : Style.barBg)
    visible: root.notificationCenter !== null

    Rectangle {
      anchors.fill: parent
      anchors.topMargin: Style.barChipInset
      anchors.bottomMargin: Style.barChipInset
      radius: Style.radiusSm
      visible: solidBar
      color: notifMouse.containsMouse ? Style.barStripHover : "transparent"
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    RowLayout {
      id: notifRow
      anchors.centerIn: parent
      spacing: 5

      Text {
        text: root.notificationCenter && root.notificationCenter.dndEnabled ? "󰂛" : "󰂚"
        font.family: Style.fontFamily
        font.pixelSize: solidBar ? Style.barFontGlyph : 15
        color: root.notificationCenter && root.notificationCenter.dndEnabled ? Style.yellow : Style.blueAlt
      }

      Text {
        text: root.notificationCenter ? root.notificationCenter.historyCount : 0
        font.family: Style.fontFamily
        font.pixelSize: 11
        color: Style.textMuted
        visible: root.notificationCenter && root.notificationCenter.historyCount > 0
      }
    }

    MouseArea {
      id: notifMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onClicked: (mouse) => {
        if (!root.notificationCenter) return
        if (mouse.button === Qt.RightButton) root.notificationCenter.toggleDnd()
        else root.notificationCenter.toggleHistory()
      }
    }
  }
}
