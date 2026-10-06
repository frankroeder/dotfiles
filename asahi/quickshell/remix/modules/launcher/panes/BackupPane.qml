import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../menu" as Menu
import "../../../"

// Time Machine pane: restic backups on the USB drive or the SFTP host (asahi-timemachine).
// Status + "Back up now", snapshot list, browse a snapshot and restore into ~/Restored.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, launcherGeom, binDir, prettyBytes, ...).
Item {
  property var root
  id: tmRoot
  anchors.fill: parent

  readonly property string helper: root.binDir + "/asahi-timemachine"
  property var status: ({})
  property var snapshots: []
  property var liveOv: null
  // Live `overview` once it answers, else the copy cached in the state file (shown at once).
  readonly property var ov: liveOv || status.overview || ({})
  readonly property var legacy: (ov.legacy || []).map(function(n) { return n.replace("fedora-home-backup-", "") }).sort().reverse()
  readonly property string destName: ov.where || (status.dest ? (status.dest.drive ? status.dest.label + " (USB)" : status.dest.host) : "")
  // Snapshot list rows: restic snapshots, then the old rsync ones (not browsable here).
  readonly property var rows: snapshots.concat(legacy.map(function(d) { return { legacy: true, id: "rsync-" + d, time: d + "T12:00:00" } }))
  property string snapError: ""
  property string snapsState: "loading"   // loading | ok | error
  property var selected: null              // snapshot object
  property string browsePath: ""
  property var entries: []
  property bool browsing: false
  property bool browseFailed: false
  property string restoreMsg: ""
  property bool restoreFailed: false
  property string restoreTarget: ""
  readonly property string home: Quickshell.env("HOME")

  function ago(iso) {
    if (!iso) return "never"
    const s = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000)
    if (s < 90) return "just now"
    if (s < 5400) return Math.round(s / 60) + " min ago"
    if (s < 129600) return Math.round(s / 3600) + " h ago"
    return Math.round(s / 86400) + " days ago"
  }
  function due(iso) {
    if (!iso) return "now"
    const s = (new Date(iso).getTime() - Date.now()) / 1000
    if (s <= 0) return "now"
    if (s < 5400) return "in " + Math.round(s / 60) + " min"
    if (s < 129600) return "in " + Math.round(s / 3600) + " h"
    return "in " + Math.round(s / 86400) + " days"
  }
  function dur(sec) {
    const s = Math.max(0, Math.round(sec || 0))
    return s >= 3600 ? Math.floor(s / 3600) + "h " + Math.round(s % 3600 / 60) + "m" : Math.max(1, Math.round(s / 60)) + " min"
  }
  // Last 30 days, oldest first: snapshot count per day for the timeline strip.
  readonly property var days: {
    const out = []
    const today = new Date(); today.setHours(0, 0, 0, 0)
    for (let i = 29; i >= 0; i--) out.push({ t: today.getTime() - i * 86400000, n: 0, l: 0 })
    for (const s of rows) {
      const d = new Date(s.time); d.setHours(0, 0, 0, 0)
      const i = Math.round((d.getTime() - out[0].t) / 86400000)
      if (i >= 0 && i < 30) { if (s.legacy) out[i].l++; else out[i].n++ }
    }
    return out
  }
  function tilde(p) { return p.indexOf(home) === 0 ? "~" + p.slice(home.length) : p }

  function listSnapshots() {
    if (snapProc.running) return
    snapsState = "loading"
    snapProc.running = true
  }
  function useSnapshots(list) {
    snapshots = list
    if (!selected && list.length > 0) {
      selected = list[0]
      browse(home)
    }
  }
  function browse(path) {
    if (!selected) return
    browsePath = path
    browsing = true
    entries = []
    browseFailed = false
    // exec restarts a listing still running for the previous folder (assigning command would not).
    lsProc.exec([helper, "ls", selected.id, path])
  }
  function restore(path) {
    if (restoreProc.running || !selected) return
    restoreFailed = false
    restoreMsg = "Restoring " + tilde(path) + "…"
    restoreTarget = "~/Restored/" + selected.time.slice(0, 10) + "-" + selected.id + path
    // Transient unit: closing the launcher must not kill a half-done restore.
    restoreProc.command = ["systemd-run", "--user", "--wait", "--quiet", "--collect",
      helper, "restore", selected.id, path]
    restoreProc.running = true
  }

  Process {
    id: statusProc
    command: [tmRoot.helper, "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const raw = String(text || "").trim()
          if (!raw) return
          const was = !!tmRoot.status.running
          tmRoot.status = JSON.parse(raw)
          if (was && !tmRoot.status.running) tmRoot.listSnapshots()
          const cached = (tmRoot.status.overview || {}).snapshots
          if (tmRoot.snapshots.length === 0 && cached) tmRoot.useSnapshots(cached)
        } catch (e) {}
      }
    }
  }
  Timer {
    interval: 2000
    running: root.shouldShow
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }
  Process {
    id: snapProc
    command: [tmRoot.helper, "overview"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          tmRoot.liveOv = JSON.parse(String(text || "").trim() || "{}")
          tmRoot.useSnapshots(tmRoot.liveOv.snapshots || [])
          tmRoot.snapsState = "ok"
        } catch (e) { tmRoot.snapsState = "error" }
      }
    }
    stderr: StdioCollector { onStreamFinished: tmRoot.snapError = String(text || "").trim().split("\n").pop() }
    onExited: function(code) { if (code !== 0) tmRoot.snapsState = "error" }
  }
  Process {
    id: lsProc
    stdout: StdioCollector {
      onStreamFinished: {
        try { tmRoot.entries = JSON.parse(String(text || "").trim() || "[]") } catch (e) { tmRoot.entries = [] }
        tmRoot.browsing = false
      }
    }
    onExited: function(code) { tmRoot.browseFailed = code !== 0 }
  }
  Process {
    id: restoreProc
    onExited: function(code) {
      tmRoot.restoreFailed = code !== 0
      tmRoot.restoreMsg = code === 0 ? "Restored → " + tmRoot.restoreTarget : "Restore failed (exit " + code + ")"
    }
  }
  Component.onCompleted: listSnapshots()

  readonly property string tmState: status.running ? "running" : (status.state || (status.ready ? "idle" : "setup"))
  readonly property color stateColor: tmState === "failed" || tmState === "interrupted" ? Style.red
    : tmState === "offline" ? Style.orange : Style.m3secondary

  // ---- M3 building blocks (same look as StoragePane) ----
  component Pill: Rectangle {
    property string icon
    property string label
    property color bg: Style.m3containerHigh
    property color fg: Style.m3onSurface
    signal clicked()
    implicitWidth: pillRow.implicitWidth + 24
    implicitHeight: 32
    radius: Style.menuRadiusFull
    color: pillMa.containsMouse ? Qt.lighter(bg, 1.15) : bg
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: 6
      Text {
        visible: !!parent.parent.icon; text: parent.parent.icon; color: parent.parent.fg
        font.family: tmRoot.root.uiFont; font.pixelSize: tmRoot.root.fontPx(12); anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: parent.parent.label; color: parent.parent.fg; font.weight: Font.Medium
        font.family: tmRoot.root.uiSans; font.pixelSize: tmRoot.root.fontPx(10); anchors.verticalCenter: parent.verticalCenter
      }
    }
    MouseArea { id: pillMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }
  component CardTitle: Text {
    color: Style.m3onSurface
    font.family: tmRoot.root.uiSans
    font.pixelSize: tmRoot.root.fontPx(12)
    font.weight: Font.DemiBold
  }
  component Secondary: Text {
    color: Style.m3onSurfaceVariant
    font.family: tmRoot.root.uiSans
    font.pixelSize: tmRoot.root.fontPx(10)
    elide: Text.ElideRight
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

    // Hero: progress ring, last backup, Back up now.
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(root.launcherGeom.rowHTall * 3.2)
      radius: Style.menuPanelRadius
      color: Style.m3container
      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 18
        Menu.MenuHudDial {
          Layout.fillHeight: true
          Layout.preferredWidth: height
          value: tmRoot.status.running ? Math.round((tmRoot.status.percent || 0) * 100) : (tmRoot.tmState === "ok" ? 100 : 0)
          accent: tmRoot.stateColor
          label: tmRoot.status.running ? "Backing up" : tmRoot.tmState
          icon: "󰁯"
          fontFamily: root.uiFont
          labelFamily: root.uiSans
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text {
            text: "Time Machine"
            color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(17); font.weight: Font.DemiBold
          }
          Text {
            Layout.fillWidth: true
            text: tmRoot.tmState === "setup" ? "Not set up — run asahi-timemachine init"
              : tmRoot.status.running ? Math.round((tmRoot.status.percent || 0) * 100) + "% · "
                + (tmRoot.status.eta !== null && tmRoot.status.eta !== undefined ? "about " + tmRoot.dur(tmRoot.status.eta) + " left" : "scanning…")
              : "Last backup " + tmRoot.ago(tmRoot.status.last_success)
            color: Style.m3secondary; font.family: root.uiSans; font.pixelSize: root.fontPx(13); font.weight: Font.Medium; elide: Text.ElideRight
          }
          Secondary {
            Layout.fillWidth: true
            text: tmRoot.status.running
              ? root.prettyBytes(tmRoot.status.bytes_done || 0) + " / " + root.prettyBytes(tmRoot.status.bytes_total || 0)
                + " → " + tmRoot.destName
              : tmRoot.tmState === "offline" ? "Backup drive not connected, host not reachable — retries hourly"
              : tmRoot.status.last_run && tmRoot.status.last_run.data_added !== undefined
                ? "Last run added " + root.prettyBytes(tmRoot.status.last_run.data_added)
                  + " in " + tmRoot.dur(tmRoot.status.last_run.total_duration)
                  + " · " + (tmRoot.status.last_run.files_new || 0) + " new, " + (tmRoot.status.last_run.files_changed || 0) + " changed files"
                : "restic · encrypted · deduplicated"
            font.pixelSize: root.fontPx(11)
          }
          Secondary {
            Layout.fillWidth: true
            visible: text !== ""
            text: tmRoot.status.running
              ? "Started " + Qt.formatDateTime(new Date(tmRoot.status.started), "HH:mm") + " (" + tmRoot.ago(tmRoot.status.started) + ")"
                + (tmRoot.status.files_done ? " · " + tmRoot.status.files_done + " / " + (tmRoot.status.files_total || "?") + " files" : "")
              : tmRoot.tmState === "ok" ? "Encrypted with the password in ~/.config/asahi-timemachine — keep a copy elsewhere"
              : ""
            font.pixelSize: root.fontPx(10)
          }
          Text {
            visible: !!tmRoot.status.error && tmRoot.tmState === "failed"
            Layout.fillWidth: true
            text: tmRoot.status.error || ""
            color: Style.red; font.family: root.uiSans; font.pixelSize: root.fontPx(10); elide: Text.ElideRight
          }
          Item { Layout.fillHeight: true }
          RowLayout {
            Layout.topMargin: 6
            spacing: 8
            Pill {
              icon: tmRoot.status.running ? "󰔟" : "󰁯"
              label: tmRoot.status.running ? "Backing up…" : "Back up now"
              bg: Style.m3primaryContainer; fg: Style.m3primary
              onClicked: if (!tmRoot.status.running && tmRoot.tmState !== "setup") Quickshell.execDetached([tmRoot.helper, "start"])
            }
            Pill {
              icon: "󰉋"; label: "Restored"
              onClicked: Quickshell.execDetached([root.binDir + "/asahi-launch", "xdg-open", tmRoot.home + "/Restored"])
            }
            Pill { icon: "󰑐"; label: "Refresh"; onClicked: tmRoot.listSnapshots() }
          }
        }
      }
    }

    // Overview: stat tiles, then drive space + retention, then a 30-day strip (old rsync snapshots too).
    RowLayout {
      Layout.fillWidth: true
      spacing: 12
      Repeater {
        model: [
          { icon: "󰥔", label: "Last backup",
            value: tmRoot.status.last_success ? tmRoot.ago(tmRoot.status.last_success) : (tmRoot.legacy.length ? "rsync " + tmRoot.legacy[0] : "never"),
            sub: tmRoot.status.last_success ? Qt.formatDateTime(new Date(tmRoot.status.last_success), "ddd d MMM · HH:mm")
              : tmRoot.status.running ? "first restic backup running" : "" },
          { icon: "󰃰", label: "Next backup",
            value: tmRoot.status.running ? "running now" : tmRoot.due(tmRoot.status.next_due),
            sub: "every " + Math.round((tmRoot.status.min_age_h || 72) / 24) + " days" },
          { icon: "󰆼", label: "Snapshots",
            value: tmRoot.snapshots.length + " restic",
            sub: tmRoot.legacy.length ? "+" + tmRoot.legacy.length + " rsync · last " + Qt.formatDate(new Date(tmRoot.legacy[0] + "T12:00:00"), "d MMM")
              : "encrypted · deduplicated" },
          { icon: tmRoot.ov.target === "local" || (tmRoot.status.dest && tmRoot.status.dest.drive) ? "󰕓" : "󰒍", label: "Destination",
            value: tmRoot.destName || "—",
            sub: tmRoot.tmState === "offline" ? "not reachable"
              : tmRoot.status.dest && tmRoot.status.dest.drive ? "USB drive connected"
              : "SFTP · " + (tmRoot.status.dest ? tmRoot.status.dest.label : "") }
        ]
        delegate: Rectangle {
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          implicitHeight: tileCol.implicitHeight + 20
          radius: Style.menuRadiusLg
          color: Style.m3container
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 12
            spacing: 10
            Text { text: modelData.icon; color: Style.m3secondary; font.family: root.uiFont; font.pixelSize: root.fontPx(16) }
            ColumnLayout {
              id: tileCol
              Layout.fillWidth: true
              spacing: 1
              Secondary { text: modelData.label; font.pixelSize: root.fontPx(9) }
              Text {
                Layout.fillWidth: true
                text: modelData.value
                color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(12); font.weight: Font.DemiBold
                elide: Text.ElideRight
              }
              Secondary { Layout.fillWidth: true; visible: text !== ""; text: modelData.sub; font.pixelSize: root.fontPx(8) }
            }
          }
        }
      }
    }
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: overviewCol.implicitHeight + 24
      radius: Style.menuRadiusLg
      color: Style.m3container
      ColumnLayout {
        id: overviewCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12; anchors.rightMargin: 12
        spacing: 8
        // Drive space on the backup disk (restic repo + old rsync snapshots share it).
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Text { text: "󰋊"; color: Style.m3tertiary; font.family: root.uiFont; font.pixelSize: root.fontPx(14) }
          Text {
            text: tmRoot.ov.disk ? root.prettyBytes(tmRoot.ov.disk.avail) + " free of " + root.prettyBytes(tmRoot.ov.disk.size) : "Drive space unknown"
            color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.Medium
          }
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6; radius: 3
            color: Style.m3containerHigh
            Rectangle {
              width: tmRoot.ov.disk && tmRoot.ov.disk.size > 0 ? parent.width * tmRoot.ov.disk.used / tmRoot.ov.disk.size : 0
              height: parent.height; radius: 3
              color: Style.m3tertiary
            }
          }
          Secondary {
            text: "keep 7 daily · 4 weekly · 12 monthly · 3 yearly"
            font.pixelSize: root.fontPx(9)
          }
        }
        Row {
          Layout.fillWidth: true
          spacing: 3
          Repeater {
            model: tmRoot.days
            delegate: Rectangle {
              required property var modelData
              required property int index
              width: (overviewCol.width - 29 * 3) / 30
              height: 14
              radius: 3
              color: modelData.n > 0 ? Style.m3primary : modelData.l > 0 ? Style.m3tertiary : Style.m3containerHigh
              border.width: index === 29 ? 1 : 0
              border.color: Style.m3onSurfaceVariant
            }
          }
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          Secondary { text: Qt.formatDate(new Date(tmRoot.days[0].t), "d MMM"); font.pixelSize: root.fontPx(8) }
          Item { Layout.fillWidth: true }
          Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 2; color: Style.m3primary }
          Secondary { text: "restic"; font.pixelSize: root.fontPx(8) }
          Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 2; color: Style.m3tertiary }
          Secondary { text: "rsync"; font.pixelSize: root.fontPx(8) }
          Item { Layout.fillWidth: true }
          Secondary { text: "today"; font.pixelSize: root.fontPx(8) }
        }
      }
    }

    // Snapshots (left) + browser (right).
    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 12

      Rectangle {
        Layout.preferredWidth: Math.round(tmRoot.width * 0.34)
        Layout.fillHeight: true
        radius: Style.menuRadiusLg
        color: Style.m3container
        clip: true
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "󰃭"; color: Style.m3secondary; font.family: root.uiFont; font.pixelSize: root.fontPx(14) }
            CardTitle { text: "Snapshots"; Layout.fillWidth: true }
          }
          Secondary {
            visible: tmRoot.snapshots.length === 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: tmRoot.snapsState === "error" ? "Could not list snapshots" + (tmRoot.snapError ? ": " + tmRoot.snapError : "")
              : tmRoot.status.running ? "The first snapshot appears when the running backup finishes."
              : tmRoot.snapsState === "loading" ? "Reading snapshots…"
              : "No restic snapshots yet"
            color: tmRoot.snapsState === "error" ? Style.red : Style.m3onSurfaceVariant
          }
          ListView {
            id: snapList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: tmRoot.rows
            ScrollBar.vertical: Menu.MenuScrollBar { id: snapScroll }
            delegate: Rectangle {
              id: snapRow
              required property var modelData
              readonly property bool sel: !!tmRoot.selected && tmRoot.selected.id === modelData.id
              width: snapList.width - (snapScroll.overflow ? snapScroll.implicitWidth + 4 : 0)
              height: 44
              radius: Style.menuRadiusMd
              color: sel ? Style.m3secondaryContainer : (sma.containsMouse && !modelData.legacy ? Style.m3stateHover : "transparent")
              Behavior on color { ColorAnimation { duration: 120 } }
              ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                spacing: 2
                Item { Layout.fillHeight: true }
                Text {
                  Layout.fillWidth: true
                  text: Qt.formatDateTime(new Date(snapRow.modelData.time), snapRow.modelData.legacy ? "ddd d MMM yyyy" : "ddd d MMM · HH:mm")
                  color: snapRow.modelData.legacy ? Style.m3onSurfaceVariant : Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.Medium
                  elide: Text.ElideRight
                }
                Secondary {
                  Layout.fillWidth: true
                  text: snapRow.modelData.legacy ? "rsync copy · read-only"
                    : tmRoot.ago(snapRow.modelData.time)
                      + (snapRow.modelData.added !== null && snapRow.modelData.added !== undefined ? " · +" + root.prettyBytes(snapRow.modelData.added) : "")
                  font.pixelSize: root.fontPx(9)
                }
                Item { Layout.fillHeight: true }
              }
              MouseArea {
                id: sma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: snapRow.modelData.legacy ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: if (!snapRow.modelData.legacy) { tmRoot.selected = snapRow.modelData; tmRoot.browse(tmRoot.browsePath || tmRoot.home) }
              }
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.menuRadiusLg
        color: Style.m3container
        clip: true
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
              implicitWidth: 26; implicitHeight: 26; radius: 13
              visible: tmRoot.browsePath !== "" && tmRoot.browsePath !== tmRoot.home
              color: upMa.containsMouse ? Style.m3stateHover : "transparent"
              Text { anchors.centerIn: parent; text: "󰁍"; color: Style.m3onSurface; font.family: root.uiFont; font.pixelSize: root.fontPx(13) }
              MouseArea {
                id: upMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tmRoot.browse(tmRoot.browsePath.replace(/\/[^\/]+$/, "") || "/")
              }
            }
            Text { text: "󰉋"; color: Style.m3tertiary; font.family: root.uiFont; font.pixelSize: root.fontPx(14) }
            CardTitle {
              Layout.fillWidth: true
              text: tmRoot.browsePath ? tmRoot.tilde(tmRoot.browsePath) : "Browse"
              elide: Text.ElideMiddle
            }
            Pill {
              visible: tmRoot.browsePath.length > tmRoot.home.length
              icon: "󰦛"; label: "Restore folder"
              bg: Style.m3tertiaryContainer
              onClicked: tmRoot.restore(tmRoot.browsePath)
            }
          }
          Secondary {
            visible: tmRoot.restoreMsg !== ""
            Layout.fillWidth: true
            text: tmRoot.restoreMsg
            color: tmRoot.restoreFailed ? Style.red : Style.m3primary
          }
          Secondary {
            visible: tmRoot.browsing || tmRoot.entries.length === 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: tmRoot.browsing ? "Listing…"
              : tmRoot.browseFailed ? "Could not list this folder (backup drive / host not reachable?)"
              : tmRoot.selected ? "Empty folder"
              : tmRoot.snapshots.length === 0 ? "Files of a snapshot show up here once one exists. Restores land in ~/Restored, never over your files."
              : "Pick a snapshot on the left."
            leftPadding: 8
          }
          ListView {
            id: entryList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: tmRoot.entries
            ScrollBar.vertical: Menu.MenuScrollBar { id: entryScroll }
            delegate: Rectangle {
              id: entryRow
              required property var modelData
              readonly property bool isDir: modelData.type === "dir"
              width: entryList.width - (entryScroll.overflow ? entryScroll.implicitWidth + 4 : 0)
              height: 36
              radius: Style.menuRadiusMd
              color: ema.containsMouse ? Style.m3stateHover : "transparent"
              Behavior on color { ColorAnimation { duration: 120 } }
              MouseArea {
                id: ema
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: entryRow.isDir ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (entryRow.isDir) tmRoot.browse(entryRow.modelData.path)
              }
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8; anchors.rightMargin: 6
                spacing: 10
                Text {
                  Layout.preferredWidth: 20
                  text: entryRow.isDir ? "󰉋" : entryRow.modelData.type === "symlink" ? "󰌷" : "󰈔"
                  color: entryRow.isDir ? Style.m3tertiary : Style.m3onSurfaceVariant
                  font.family: root.uiFont; font.pixelSize: root.fontPx(13)
                  horizontalAlignment: Text.AlignHCenter
                }
                Text {
                  Layout.fillWidth: true
                  text: entryRow.modelData.name
                  color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(11); elide: Text.ElideMiddle
                }
                Secondary {
                  visible: !entryRow.isDir
                  text: root.prettyBytes(entryRow.modelData.size)
                  font.pixelSize: root.fontPx(9)
                }
                // Restore just this entry.
                Rectangle {
                  implicitWidth: 26; implicitHeight: 26; radius: 13
                  opacity: ema.containsMouse || rma.containsMouse ? 1 : 0
                  color: rma.containsMouse ? Style.m3tertiaryContainer : "transparent"
                  Text { anchors.centerIn: parent; text: "󰦛"; color: Style.m3onSurface; font.family: root.uiFont; font.pixelSize: root.fontPx(12) }
                  MouseArea {
                    id: rma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tmRoot.restore(entryRow.modelData.path)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
