import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../../"
import "../../../services" as Services
import "../../launcher/arg_commands.js" as ArgCommands

// Click-only chips: stay awake, night light, recorder, timer, updates, notifications.
// Stay-awake / night-light / timer state follows files their scripts write (FileView watches).
RowLayout {
  id: root

  property var notificationCenter: null
  property bool isRecording: false
  property bool updatesAvailable: false
  property bool stayAwake: false
  property bool nightLightOn: false
  // Soonest asahi-timer (systemd user timers); left ticks locally between syncs.
  property int timerCount: 0
  property int timerLeft: 0
  property string timerUnit: ""
  property bool timerArmed: false
  property var barHost: null

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
  readonly property string nightLightStatePath: Quickshell.env("HOME") + "/.local/state/asahi/nightlight.json"
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property color fg: barHost ? barHost.barForeground : Style.text

  spacing: 2

  // --- night light: asahi-nightlight rewrites nightlight.json in place.
  function parseNightLight(raw) {
    try { root.nightLightOn = !!JSON.parse(raw || "{}").on } catch (e) { root.nightLightOn = false }
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
  Timer {
    // 1 s countdown while a timer runs (resync every 5 s); otherwise a slow safety poll.
    interval: root.timerCount > 0 ? 1000 : 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (root.timerCount > 0 && root.timerLeft > 0) root.timerLeft--
      if (root.timerCount === 0 || root.timerLeft % 5 === 0) root.refreshTimers()
    }
  }
  Timer {
    id: disarmTimer
    interval: 3000
    onTriggered: root.timerArmed = false
  }

  Item {
    implicitWidth: stayAwakeGlyph.implicitWidth + 6
    implicitHeight: Style.barHeight

    Text {
      id: stayAwakeGlyph
      anchors.centerIn: parent
      text: "󰅶"
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontGlyph
      color: root.stayAwake ? Style.yellow : root.fg
    }

    HoverTint { lit: chipMouse1.containsMouse }
    MouseArea {
      id: chipMouse1
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: Quickshell.execDetached([root.binDir + "/asahi-stay-awake", "toggle"])
    }
  }

  // Only while on (Super+Ctrl+N / Quick): frees room next to the notch.
  Item {
    visible: root.nightLightOn
    implicitWidth: Style.barIconSlot
    implicitHeight: Style.barHeight

    Text {
      anchors.centerIn: parent
      text: "󰽥"
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontGlyph
      color: Style.orange
    }

    HoverTint { lit: chipMouse2.containsMouse }
    MouseArea {
      id: chipMouse2
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: Quickshell.execDetached([root.binDir + "/asahi-nightlight", "toggle"])
    }
  }

  // Recorder chip: only while recording, with the running clock. Click opens
  // the panel, right-click stops. Idle, the panel comes from Super+Alt+R.
  Item {
    id: recChip
    readonly property bool rec: Services.Recorder.running
    readonly property bool sameScreen: {
      const mon = Hyprland.focusedMonitor
      const scr = root.barHost ? root.barHost.barScreen : null
      if (!mon || !scr) return true
      return mon.name === scr.name
    }
    readonly property bool panelShown: (root.barHost && root.barHost.recPanelOpen) || (Services.Recorder.panelOpen && sameScreen)
    // Stays visible while the panel is open even after recording stops, so the chip
    // that opened it is still there to close it (it used to vanish and strand the popup).
    visible: rec || panelShown
    Layout.preferredWidth: recRow.implicitWidth + 8
    implicitHeight: Style.barHeight

    RowLayout {
      id: recRow
      anchors.centerIn: parent
      spacing: 5
      Text {
        text: "󰑋"
        font.family: Style.fontFamily; font.pixelSize: Style.barFontGlyph; color: Style.red
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
        font.family: Style.fontFamily; font.pixelSize: Style.barFontCaption; font.bold: true; color: Style.red
      }
    }

    HoverTint { lit: chipMouse3.containsMouse }
    MouseArea {
      id: chipMouse3
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton && recChip.rec) Services.Recorder.stop()
        else if (recChip.panelShown) {
          // Close however it was opened (bar click or the global keybind), not just
          // this bar's own flag — otherwise a keybind-opened panel wouldn't budge.
          if (root.barHost) root.barHost.recPanelOpen = false
          Services.Recorder.panelOpen = false
        }
        else if (root.barHost) root.barHost.toggleRecPanel()
      }
    }
  }

  // Timer chip: first click arms (turns red, "cancel?"), a second click within 3 s cancels.
  Item {
    visible: root.timerCount > 0
    Layout.preferredWidth: timerRow.implicitWidth + 8
    implicitHeight: Style.barHeight

    RowLayout {
      id: timerRow
      anchors.centerIn: parent
      spacing: 5
      Text { text: "󰔛"; font.family: Style.fontFamily; font.pixelSize: Style.barFontGlyph; color: root.timerArmed ? Style.red : Style.yellow }
      Text {
        text: root.timerArmed ? "cancel?"
          : ArgCommands.formatSeconds(root.timerLeft) + (root.timerCount > 1 ? " +" + (root.timerCount - 1) : "")
        font.family: Style.fontFamily
        font.pixelSize: Style.barFontCaption
        font.bold: true
        color: root.timerArmed ? Style.red : root.fg
      }
    }

    HoverTint { lit: chipMouse4.containsMouse }
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
    visible: root.updatesAvailable
    implicitWidth: Style.barIconSlot
    implicitHeight: Style.barHeight

    Text {
      anchors.centerIn: parent
      text: "󰚰"
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontGlyph
      color: Style.orange
    }

    HoverTint { lit: chipMouse5.containsMouse }
    MouseArea {
      id: chipMouse5
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: if (root.barHost) root.barHost.quickRequested("pkgman")
    }
  }

  Item {
    visible: root.notificationCenter !== null
    Layout.preferredWidth: notifRow.implicitWidth + 8
    implicitHeight: Style.barHeight

    RowLayout {
      id: notifRow
      anchors.centerIn: parent
      spacing: 5

      Text {
        text: root.notificationCenter && root.notificationCenter.dndEnabled ? "󰂛" : "󰂚"
        font.family: Style.fontFamily
        font.pixelSize: Style.barFontGlyph
        color: root.notificationCenter && root.notificationCenter.dndEnabled ? Style.yellow : Style.blueAlt
      }

      Text {
        text: root.notificationCenter ? root.notificationCenter.unreadCount : 0
        font.family: Style.fontFamily
        font.pixelSize: 11
        color: Style.textMuted
        visible: root.notificationCenter && root.notificationCenter.unreadCount > 0
      }
    }

    HoverTint { lit: chipMouse6.containsMouse }
    MouseArea {
      id: chipMouse6
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
