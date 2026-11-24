import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../../"
import "../../../services" as Services
import "../../launcher/arg_commands.js" as ArgCommands

// Click-only chips: stay awake, night light, recorder, screen share, timer, updates (bell: Notifications.qml).
// Stay-awake / night-light / timer state follows files their scripts write (FileView watches).
// Claude Code at work (asahi-claude-activity): the cup in dim amber; it holds only idle sleep (asahi-idle why says so).
RowLayout {
  id: root

  property bool updatesAvailable: false
  property bool stayAwake: false
  property int claudeSessions: 0
  property bool nightLightOn: false
  property int nightTemp: 3000
  readonly property Item nightChip: nightChipItem   // NightLightPanel hangs from it
  // Soonest asahi-timer (systemd user timers); left ticks locally between syncs.
  property int timerCount: 0
  property int timerLeft: 0
  property string timerUnit: ""
  property bool timerArmed: false
  property var barHost: null
  // BarHost grants each chip while the right side has room for it (REC first); what each costs, shown or not.
  property bool showCup: true
  property bool showNight: true
  property bool showRec: true
  property bool showShare: true
  property bool showTimer: true
  property bool showUpdates: true
  readonly property real cupWidth: stayAwakeGlyph.implicitWidth + 6 + root.spacing
  readonly property real nightWidth: root.nightLightOn ? Style.barIconSlot + root.spacing : 0
  readonly property real recWidth: recChip.wanted
    ? recGlyph.implicitWidth + (recChip.rec ? recRow.spacing + recText.implicitWidth : 0) + 8 + root.spacing : 0
  // Screen share (ideas: end-4 Privacy, mel-edo's island): xdph's stream node lives while an app shares a screen or
  // window, after its picker is gone; screen capture has no hardware light (the camera has its LED). Our recorder and
  // screenshots use screencopy, not xdph. Bound to PipeWire's node list: no polling.
  readonly property bool sharing: (Pipewire.nodes.values || []).some(n => String(n.name || "").startsWith("xdph-streaming"))
  readonly property real shareWidth: root.sharing ? Style.barIconSlot + root.spacing : 0
  readonly property real timerWidth: root.timerCount > 0
    ? timerGlyph.implicitWidth + timerRow.spacing + timerText.implicitWidth + 8 + root.spacing : 0
  readonly property real updatesWidth: root.updatesAvailable ? Style.barIconSlot + root.spacing : 0

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
  readonly property string nightLightStatePath: Quickshell.env("ASAHI_NIGHTLIGHT_STATE") || Quickshell.env("HOME") + "/.local/state/asahi/nightlight.json"   // env: asahi-nightlight's, tests
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property color fg: barHost ? barHost.barForeground : Style.text

  spacing: 2

  // --- night light: asahi-nightlight rewrites nightlight.json in place.
  // asahi-nightlight rewrites the file in place (truncate, then write): a read in between is empty or cut short. Keep
  // the last state then — read as "off" it hid the chip and closed its popup on every slider step (flicker).
  function parseNightLight(raw) {
    let s = null
    try { s = JSON.parse(String(raw || "").trim()) } catch (e) { return }
    root.nightLightOn = !!s.on
    if (s.temperature > 0) root.nightTemp = s.temperature
  }
  FileView {
    id: nightLightFile
    path: root.nightLightStatePath
    watchChanges: true
    blockLoading: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseNightLight(nightLightFile.text())
    onTextChanged: root.parseNightLight(nightLightFile.text())
    onLoadFailed: root.nightLightOn = false
  }

  // --- stay awake: asahi-stay-awake creates / removes a flag file (the watch sees both).
  FileView {
    path: root.runtimeDir + "/asahi-stay-awake"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.stayAwake = true
    onLoadFailed: root.stayAwake = false
  }

  // --- Claude Code at work: the hooks keep the live session count in a file (rewritten on change, gone at 0). A
  // crashed session sends no hook: while the count lives, its status prunes stale markers every 5 min.
  FileView {
    id: claudeFile
    path: root.runtimeDir + "/claude-activity.count"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    // A read between the shell's truncate and write is empty: keep the last count, the write's own event follows.
    onLoaded: { const n = parseInt(claudeFile.text()); if (!isNaN(n)) root.claudeSessions = n }
    onLoadFailed: root.claudeSessions = 0
  }
  Timer {
    interval: 300000
    running: root.claudeSessions > 0
    repeat: true
    onTriggered: Quickshell.execDetached([root.binDir + "/asahi-claude-activity", "status"])
  }

  // --- timers: asahi-timer touches a stamp on add/cancel; tick locally while one runs.
  function refreshTimers() { if (!timerProc.running) timerProc.running = true }
  Process {
    id: timerProc
    command: [root.binDir + "/asahi-timer", "list", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const list = JSON.parse(text.trim() || "[]")
          root.timerCount = list.length
          root.timerLeft = list.length ? list[0].left : 0
          root.timerUnit = list.length ? list[0].unit : ""
        } catch (e) {
          root.timerCount = 0
        }
      }
    }
  }
  FileView {
    path: root.runtimeDir + "/asahi-timer.stamp"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refreshTimers()
  }
  // 1 s countdown while a timer runs (resync every 5 s catches expiry); new timers touch the stamp.
  Timer {
    interval: 1000
    running: root.timerCount > 0
    repeat: true
    onTriggered: {
      if (root.timerLeft > 0) root.timerLeft--
      if (root.timerLeft % 5 === 0) root.refreshTimers()
    }
  }
  Component.onCompleted: root.refreshTimers()
  Timer {
    id: disarmTimer
    interval: 3000
    onTriggered: root.timerArmed = false
  }

  Item {
    visible: root.showCup
    implicitWidth: stayAwakeGlyph.implicitWidth + 6
    implicitHeight: Style.barHeight

    Text {
      id: stayAwakeGlyph
      anchors.centerIn: parent
      text: "󰅶"
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontGlyph
      color: root.stayAwake ? Style.yellow : root.claudeSessions > 0 ? Qt.alpha(Style.yellow, 0.5) : root.fg
    }

    HoverTint { down: chipMouse1.pressed; lit: chipMouse1.containsMouse }
    MouseArea {
      id: chipMouse1
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: Quickshell.execDetached([root.binDir + "/asahi-stay-awake", "toggle"])
    }
  }

  // Only while on (Launcher > Actions): frees room next to the notch. Click = warmth popup, right-click = off.
  Item {
    id: nightChipItem
    visible: root.nightLightOn && root.showNight
    implicitWidth: Style.barIconSlot
    implicitHeight: Style.barHeight

    Text {
      anchors.centerIn: parent
      text: "󰽥"
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontGlyphTall
      color: Style.orange
    }

    HoverTint { down: chipMouse2.pressed; lit: chipMouse2.containsMouse }
    MouseArea {
      id: chipMouse2
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: mouse => {
        if (mouse.button === Qt.RightButton || !root.barHost) Quickshell.execDetached([root.binDir + "/asahi-nightlight", "toggle"])
        else root.barHost.togglePanel("night")
      }
      // Wheel: warmer (up) / cooler (down), 250 K a notch; accumulates to 120 like the audio chips. A gesture's notches
      // go out as one step count 250 ms after the wheel stops: a run per notch raced (two runs set their own
      // temperature in turns: flicker, and each saw the other's value: a "Night light failed" card each).
      property real wheelAcc: 0
      property int wheelSteps: 0
      onWheel: wheel => {
        if (Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)) return
        wheelAcc += wheel.angleDelta.y
        if (Math.abs(wheelAcc) < 120) return
        wheelSteps += wheelAcc > 0 ? 1 : -1
        wheelAcc = 0
        nightWheelSend.restart()
      }
      Timer {
        id: nightWheelSend
        interval: 250
        onTriggered: {
          const n = chipMouse2.wheelSteps
          chipMouse2.wheelSteps = 0
          if (n !== 0) Quickshell.execDetached([root.binDir + "/asahi-nightlight", n > 0 ? "warmer" : "cooler", String(Math.abs(n))])
        }
      }
    }
  }

  // Recorder chip: only while recording, with the running clock. Click opens
  // the panel, right-click stops. Idle, the panel comes from Super+Alt+R.
  Item {
    id: recChip
    readonly property bool rec: Services.Recorder.running
    readonly property bool panelShown: !!root.barHost && root.barHost.openPanel === "rec"
    // Stays visible while the panel is open even after recording stops, so the chip
    // that opened it is still there to close it (it used to vanish and strand the popup).
    readonly property bool wanted: rec || panelShown
    visible: wanted && root.showRec
    Layout.preferredWidth: recRow.implicitWidth + 8
    implicitHeight: Style.barHeight

    RowLayout {
      id: recRow
      anchors.centerIn: parent
      spacing: 5
      Text {
        id: recGlyph
        text: "󰑋"
        font.family: Style.fontFamily; font.pixelSize: Style.barFontGlyph; color: Style.red
        // 1 Hz blink on the repaint the elapsed clock causes anyway (a pulse redrew the bar every frame).
        opacity: recChip.rec && Services.Recorder.elapsed % 2 ? 0.35 : 1
      }
      Text {
        id: recText
        visible: recChip.rec
        text: Services.Recorder.fmtElapsed(Services.Recorder.elapsed)
        font.family: Style.fontFamily; font.pixelSize: Style.barFontCaption; font.bold: true; color: Style.red
      }
    }

    HoverTint { down: chipMouse3.pressed; lit: chipMouse3.containsMouse }
    MouseArea {
      id: chipMouse3
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton && recChip.rec) Services.Recorder.stop()
        else if (root.barHost) root.barHost.togglePanel("rec")
      }
    }
  }

  // Screen-share chip: shown while sharing, nothing to click (stop the share in the app that runs it).
  Item {
    visible: root.sharing && root.showShare
    implicitWidth: Style.barIconSlot
    implicitHeight: Style.barHeight
    Text {
      anchors.centerIn: parent
      text: "󰹑"
      font.family: Style.fontFamily; font.pixelSize: Style.barFontGlyph; color: Style.red
    }
  }

  // Timer chip: first click arms (turns red, "cancel?"), a second click within 3 s cancels.
  Item {
    visible: root.timerCount > 0 && root.showTimer
    Layout.preferredWidth: timerRow.implicitWidth + 8
    implicitHeight: Style.barHeight

    RowLayout {
      id: timerRow
      anchors.centerIn: parent
      spacing: 5
      Text { id: timerGlyph; text: "󰔛"; font.family: Style.fontFamily; font.pixelSize: Style.barFontGlyphTall; color: root.timerArmed ? Style.red : Style.yellow }
      Text {
        id: timerText
        text: root.timerArmed ? "cancel?"
          : ArgCommands.formatShort(root.timerLeft) + (root.timerCount > 1 ? " +" + (root.timerCount - 1) : "")
        font.family: Style.fontFamily
        font.pixelSize: Style.barFontCaption
        font.bold: true
        color: root.timerArmed ? Style.red : root.fg
      }
    }

    HoverTint { down: chipMouse4.pressed; lit: chipMouse4.containsMouse }
    MouseArea {
      id: chipMouse4
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (!root.timerArmed) { root.timerArmed = true; disarmTimer.restart(); return }
        root.timerArmed = false
        disarmTimer.stop()
        Quickshell.execDetached([root.binDir + "/asahi-timer", "cancel", root.timerUnit])
      }
    }
  }

  Item {
    visible: root.updatesAvailable && root.showUpdates
    implicitWidth: Style.barIconSlot
    implicitHeight: Style.barHeight

    Text {
      anchors.centerIn: parent
      text: "󰏖"
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontGlyph
      color: Style.orange
    }

    HoverTint { down: chipMouse5.pressed; lit: chipMouse5.containsMouse }
    MouseArea {
      id: chipMouse5
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: if (root.barHost) root.barHost.quickRequested("updates")
    }
  }
}
