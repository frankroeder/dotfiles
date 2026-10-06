import QtQuick
import Quickshell
import Quickshell.Io
import "../../../"

// Backup chip (left of the notch, after CPU/RAM): only while asahi-timemachine runs
// (glyph · percent · ETA over a thin progress bar) or after a failure (red glyph).
// Click opens the Backup pane.
Item {
  id: chip
  property var barHost: null
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property color fg: barHost ? barHost.barForeground : Style.text

  // --- backup: asahi-timemachine replaces timemachine.json atomically. While it says "running",
  // poll `status` (percent / ETA from restic); the poll also catches a killed run ("interrupted").
  property string backupState: ""
  property bool backupRunning: false
  property real backupPct: 0
  property real backupEta: -1
  FileView {
    id: backupFile
    path: Quickshell.env("HOME") + "/.local/state/asahi/timemachine.json"
    watchChanges: true
    blockLoading: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: chip.parseBackup(backupFile.text())
    onTextChanged: chip.parseBackup(backupFile.text())
    onLoadFailed: chip.backupState = ""
  }
  function parseBackup(raw) {
    try { chip.backupState = JSON.parse(raw || "{}").state || "" } catch (e) {}
    if (chip.backupState === "running" && !backupProc.running) backupProc.running = true
    if (chip.backupState !== "running") chip.backupRunning = false
  }
  Process {
    id: backupProc
    command: [chip.binDir + "/asahi-timemachine", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const raw = String(text || "").trim()
          if (!raw) return
          const st = JSON.parse(raw)
          chip.backupRunning = !!st.running
          chip.backupPct = st.percent || 0
          chip.backupEta = st.eta === null || st.eta === undefined ? -1 : st.eta
          if (!st.running && st.state) chip.backupState = st.state
        } catch (e) {}
      }
    }
  }
  Timer {
    interval: 3000
    repeat: true
    running: chip.backupState === "running"
    onTriggered: if (!backupProc.running) backupProc.running = true
  }
  function backupEtaText(s) {
    if (s < 0) return ""
    return s >= 3600 ? Math.floor(s / 3600) + "h" + ("0" + Math.floor(s % 3600 / 60)).slice(-2) : Math.max(1, Math.round(s / 60)) + "m"
  }

  visible: chip.backupRunning || chip.backupState === "failed"
  implicitWidth: backupRow.implicitWidth + 12
  implicitHeight: Style.barHeight

  Row {
    id: backupRow
    anchors.centerIn: parent
    spacing: 4
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: chip.backupRunning ? "󰁯" : "󱙄"
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontGlyph
      color: chip.backupRunning ? chip.fg : Style.red
    }
    Text {
      visible: chip.backupRunning
      anchors.verticalCenter: parent.verticalCenter
      text: Math.round(chip.backupPct * 100) + "%" + (chip.backupEta >= 0 ? " · " + chip.backupEtaText(chip.backupEta) : "")
      font.family: Style.fontFamily
      font.pixelSize: Style.barFontCaption
      font.bold: true
      color: chip.fg
    }
  }
  Rectangle {
    visible: chip.backupRunning
    anchors.left: backupRow.left; anchors.right: backupRow.right; anchors.top: backupRow.bottom; anchors.topMargin: 1
    height: 2; radius: 1
    color: Qt.rgba(chip.fg.r, chip.fg.g, chip.fg.b, 0.25)
    Rectangle { width: parent.width * chip.backupPct; height: parent.height; radius: 1; color: Style.m3primary }
  }

  HoverTint { lit: backupMouse.containsMouse }
  MouseArea {
    id: backupMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (chip.barHost) chip.barHost.quickRequested("backup")
  }
}
