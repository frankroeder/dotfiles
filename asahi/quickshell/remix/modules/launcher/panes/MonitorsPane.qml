import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../../menu" as Menu
import "../../wallpaper" as Wallpaper
import "../../wallpaper/wallpaper_thumbs.js" as WallThumbs
import "../../../"
import "../quick_models.js" as QuickModels
import "../launcher_layout.js" as LauncherGeom

// Monitors pane: layout preview, per-display scale / mode / refresh, brightness, on/off.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, launcherGeom, quickMode, quickPaneKey, binDir, ...).
Item {
  property var root
  id: quickMonitorsRoot
  anchors.fill: parent
  implicitHeight: monLayout.implicitHeight
  // full port monitors (hypr all-j, list, mirror/extend/external/rescan, status, canvas, procs, guards; exact)
  property var mons: []
  property string monRaw: ""
  property var monSaved: ({})
  property int monVersion: 0
  property string monStatus: ""

  function luaString(value) { return "\"" + String(value || "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"" }
  function monitorMode(m) {
    if (!m) return "preferred"
    const rr = m.refreshRate ? "@" + Number(m.refreshRate).toFixed(3) : ""
    return (m.width || 0) + "x" + (m.height || 0) + rr
  }
  // Display text only; monitorMode() is the Hyprland mode string.
  function monitorModeLabel(m) {
    if (!m) return ""
    const hz = m.refreshRate ? " · " + Math.round(Number(m.refreshRate) * 100) / 100 + " Hz" : ""
    return (m.width || 0) + "×" + (m.height || 0) + hz
  }
  // Enabled only: `monitors all -j` lists disabled outputs, and picking one as
  // the mirror source (clamshell'd eDP-1) points the live display at nothing.
  function monitorPrimary() {
    return QuickModels.mirrorSource(quickMonitorsRoot.mons) || (quickMonitorsRoot.mons || [])[0] || null
  }
  // Logical footprint: mode / scale, sides swapped for a 90°/270° transform.
  function monitorLogicalWidth(m) { return ((m.transform || 0) % 2 ? (m.height || 1080) : (m.width || 1920)) / Math.max(0.25, m.scale || 1) }
  function monitorLogicalHeight(m) { return ((m.transform || 0) % 2 ? (m.width || 1920) : (m.height || 1080)) / Math.max(0.25, m.scale || 1) }
  readonly property bool anyMirrored: (quickMonitorsRoot.mons || []).some(QuickModels.isMirroring)

  // Mirror carries the mirror field and nothing else. A mode here forces a DCP
  // modeset (see asahi-hdmi: an HDMI modeset at the wrong moment freezes the
  // laptop) and a pinned position = "0x0" drops the target on top of the source
  // whenever the mirror does not take ("layout is set up incorrectly").
  // Hyprland owns a mirror's geometry.
  function mirrorMonitors() {
    const src = QuickModels.mirrorSource(quickMonitorsRoot.mons)
    const targets = QuickModels.mirrorTargets(quickMonitorsRoot.mons, src)
    if (!src || !targets.length) { quickMonitorsRoot.monStatus = "Nothing to mirror"; return }
    const calls = targets.map(m => "hl.monitor({ output = " + quickMonitorsRoot.luaString(m.name)
      + ", mirror = " + quickMonitorsRoot.luaString(src.name) + " })")
    quickMonitorsRoot.keepLauncherOn(src)
    quickMonitorsRoot.applyRevertable(calls.join("\n"), "Mirroring to " + src.name + "...")
  }
  // A mirrored output leaves the layout, so the workspace rules pinned to it
  // (ws 1-4 → HDMI-A-1 in monitors.lua) have no display. Reload is the way
  // back: it wipes eval'd rules and its config.reloaded hook re-runs
  // asahi-hdmi sync / monitor-scale apply / clamshell apply.
  function unmirrorMonitors() { quickMonitorsRoot.revertLayout("Unmirroring...") }
  // Extend = back to the configured layout: drop kept HDMI positions first,
  // then reload (its asahi-hdmi sync reads the layout file).
  function extendMonitors() {
    const clamshell = quickMonitorsRoot.revertClamshell
    quickMonitorsRoot.keepPositions = ({})
    quickMonitorsRoot.revertClamshell = false
    quickMonitorsRoot.revertLua = ""
    quickMonitorsRoot.disarmRevert()
    quickMonitorsRoot.monStatus = "Reloading monitors..."
    const resets = (quickMonitorsRoot.mons || []).filter(m => /^HDMI/.test(m.name))
      .map(m => root.binDir + "/asahi-hdmi reset " + m.name)
    const last = clamshell ? root.binDir + "/asahi-clamshell open" : "hyprctl reload"
    Quickshell.execDetached(["bash", "-c", resets.concat([last]).join("; ")])
    monDelay.restart()
  }
  property bool revertClamshell: false
  function externalOnlyMonitors() {
    const list = quickMonitorsRoot.mons || []
    const edp = list.find(m => m && m.name === "eDP-1")
    const external = QuickModels.enabledMonitors(list).find(m => m.name !== "eDP-1")
    if (!external) { quickMonitorsRoot.monStatus = "No enabled external"; return }
    if (!edp || edp.disabled) { quickMonitorsRoot.monStatus = "Already external only"; return }
    quickMonitorsRoot.keepLauncherOn(external)
    quickMonitorsRoot.monStatus = "External only..."
    quickMonitorsRoot.revertClamshell = true
    Quickshell.execDetached([root.binDir + "/asahi-clamshell", "close"])
    quickMonitorsRoot.revertLeft = 15
    revertTimer.restart()
    monDelay.restart()
  }
  function rescanMonitors() {
    quickMonitorsRoot.monStatus = "Rescanning..."
    if (!monScan.running) monScan.running = true
  }

  // ---- Topology changes: apply, then revert unless kept ----
  // Mirror / external-only / disable can strand the session on an output that
  // no longer takes input, and the pill that undoes it is then unreachable. So
  // every such change is on probation: `Keep` disarms it, silence reverts it.
  // (Closing the launcher tears the pane down and cancels the timer too.)
  property int revertLeft: 0
  function applyRevertable(lua, status) {
    quickMonitorsRoot.keepPositions = ({})
    quickMonitorsRoot.revertClamshell = false
    quickMonitorsRoot.revertLua = ""
    quickMonitorsRoot.monStatus = status
    Quickshell.execDetached(["hyprctl", "eval", lua])
    quickMonitorsRoot.revertLeft = 15
    revertTimer.restart()
    monDelay.restart()
  }
  // Lua that undoes a position-only change (arrange); reload would re-modeset HDMI.
  property string revertLua: ""
  function revertLayout(status) {
    quickMonitorsRoot.keepPositions = ({})
    const clamshell = quickMonitorsRoot.revertClamshell
    const lua = quickMonitorsRoot.revertLua
    quickMonitorsRoot.revertClamshell = false
    quickMonitorsRoot.revertLua = ""
    quickMonitorsRoot.disarmRevert()
    quickMonitorsRoot.monStatus = status
    if (lua)
      Quickshell.execDetached(["hyprctl", "eval", lua])
    else if (clamshell)
      Quickshell.execDetached([root.binDir + "/asahi-clamshell", "open"])
    else
      Quickshell.execDetached(["hyprctl", "reload"])
    monDelay.restart()
  }
  function disarmRevert() {
    quickMonitorsRoot.revertLeft = 0
    revertTimer.stop()
  }
  // Arranged positions waiting for Keep; Keep writes them via asahi-hdmi save
  // (~/.local/state/asahi/monitor-layout.json) so replug / reload keep them.
  property var keepPositions: ({})
  function keepChange() {
    const kp = quickMonitorsRoot.keepPositions
    for (const n of Object.keys(kp))
      if (/^HDMI/.test(n)) Quickshell.execDetached([root.binDir + "/asahi-hdmi", "save", n, kp[n].x + "x" + kp[n].y])
    quickMonitorsRoot.keepPositions = ({})
    quickMonitorsRoot.revertClamshell = false
    quickMonitorsRoot.revertLua = ""
    quickMonitorsRoot.disarmRevert()
  }
  // Park the launcher on an output that survives the change, so Keep / Unmirror
  // stay visible and clickable (the panel is pinned to root.launcherScreen).
  function keepLauncherOn(m) {
    const scr = m ? Quickshell.screens.find(s => s.name === m.name) : null
    if (scr) root.launcherScreen = scr
  }
  Timer {
    id: revertTimer
    interval: 1000; repeat: true
    onTriggered: {
      quickMonitorsRoot.revertLeft -= 1
      if (quickMonitorsRoot.revertLeft <= 0) quickMonitorsRoot.revertLayout("Reverted")
    }
  }

  // ---- Brightness (omarchy.monitor's slider, via brightnessctl) ----
  property int brightness: -1  // percent; -1 = no controllable backlight
  function setBrightness(pct) {
    quickMonitorsRoot.brightness = QuickModels.clampBrightness(pct)
    brightSet.restart()
  }
  Process {
    id: brightProc
    command: ["bash", "-c", "brightnessctl -m 2>/dev/null | awk -F, '{gsub(/%/,\"\",$4); print $4}'"]
    stdout: StdioCollector {
      onStreamFinished: {
        const v = parseInt((text || "").trim(), 10)
        if (Number.isFinite(v) && !brightSet.running) quickMonitorsRoot.brightness = v
      }
    }
  }
  // Debounced write so dragging the slider doesn't spawn a process per pixel.
  Timer {
    id: brightSet
    interval: 90
    onTriggered: Quickshell.execDetached(["brightnessctl", "set", quickMonitorsRoot.brightness + "%"])
  }

  // ---- Scale presets for the focused monitor (omarchy.monitor) ----
  // cleanScale snaps to values Hyprland actually accepts for the mode.
  readonly property var scalePresets: QuickModels.scalePresetsFor(quickMonitorsRoot.focusedMon)
  // Clicking a monitor in the preview / list selects it; falls back to Hyprland focus.
  property string selectedName: ""
  readonly property var focusedMon: {
    const list = quickMonitorsRoot.mons || []
    return list.find(m => m && m.name === quickMonitorsRoot.selectedName)
      || list.find(m => m && m.focused && !m.disabled) || quickMonitorsRoot.monitorPrimary()
  }
  readonly property var scaleValues: {
    const m = quickMonitorsRoot.focusedMon
    if (!m) return quickMonitorsRoot.scalePresets
    return QuickModels.availableScales(quickMonitorsRoot.scalePresets, m.width, m.height)
  }
  readonly property int activeScaleIdx: {
    const m = quickMonitorsRoot.focusedMon
    if (!m) return -1
    return QuickModels.matchingScaleIndex(quickMonitorsRoot.scaleValues, m.scale, m.width, m.height)
  }
  function setScale(scale) {
    const m = quickMonitorsRoot.focusedMon
    if (!m) { quickMonitorsRoot.monStatus = "No focused monitor"; return }
    const clean = QuickModels.cleanScale(scale, m.width, m.height)
    if (!clean) { quickMonitorsRoot.monStatus = "Invalid scale"; return }
    quickMonitorsRoot.applyMonitorConfig(m, quickMonitorsRoot.monitorMode(m), clean, m.name + " scale " + clean + "...")
  }

  // ---- Resolution / refresh for the focused monitor ----
  readonly property var resolutionOpts: {
    const m = quickMonitorsRoot.focusedMon
    return m ? QuickModels.resolutionOptions(m.availableModes, 6) : []
  }
  readonly property var refreshOpts: {
    const m = quickMonitorsRoot.focusedMon
    return m ? QuickModels.refreshOptions(m.availableModes, m.width, m.height, 6) : []
  }
  function applyMode(w, h, hz) {
    const m = quickMonitorsRoot.focusedMon
    if (!m) { quickMonitorsRoot.monStatus = "No focused monitor"; return }
    const mode = w + "x" + h + "@" + Number(hz).toFixed(2)
    // The scale must stay legal for the NEW mode dimensions.
    const scale = QuickModels.cleanScale(m.scale || 1, w, h) || "1"
    quickMonitorsRoot.applyMonitorConfig(m, mode, scale, m.name + " → " + mode + "...")
  }
  // Lua config (Hyprland 0.56): `hyprctl keyword` is legacy-parser only —
  // apply through hl.monitor via eval, like mirror/external-only do. The
  // position stays explicit (omarchy uses "auto", but this setup pins
  // monitor positions in monitors.lua — auto would rearrange the layout).
  // Re-abut after a size change so a leftover x/y cannot open a cursor gap.
  function applyMonitorConfig(m, mode, scale, status) {
    const parsed = QuickModels.parseModeString(mode)
    const s = Math.max(0.25, Number(scale) || 1)
    const newW = parsed ? parsed.width / s : quickMonitorsRoot.monitorLogicalWidth(m)
    const newH = parsed ? parsed.height / s : quickMonitorsRoot.monitorLogicalHeight(m)
    const pos = QuickModels.abutPosition(m, newW, newH, quickMonitorsRoot.mons)
    quickMonitorsRoot.monStatus = status
    monAction.command = ["hyprctl", "eval",
      "hl.monitor({ output = " + quickMonitorsRoot.luaString(m.name)
      + ", mode = " + quickMonitorsRoot.luaString(mode)
      + ", position = " + quickMonitorsRoot.luaString(pos)
      + ", scale = " + scale + " })"]
    monAction.running = true
  }

  // ---- Rotation (transform 0-3 = 0/90/180/270°), on probation like mirror ----
  function setRotation(t) {
    const m = quickMonitorsRoot.focusedMon
    if (!m || (m.transform || 0) === t) return
    quickMonitorsRoot.applyRevertable("hl.monitor({ output = " + quickMonitorsRoot.luaString(m.name) + ", transform = " + t + " })",
      m.name + " rotate " + (t * 90) + "°...")
  }

  // ---- Arrangement: drag a tile, snap on release, Apply sends positions ----
  // draft = { name: {x, y} } logical px, only for outputs that moved.
  property var draft: ({})
  readonly property bool draftDirty: Object.keys(quickMonitorsRoot.draft).length > 0
  function pos(m) { return quickMonitorsRoot.draft[m.name] || { x: m.x || 0, y: m.y || 0 } }
  function box(m) { const p = quickMonitorsRoot.pos(m); return { x: p.x, y: p.y, w: quickMonitorsRoot.monitorLogicalWidth(m), h: quickMonitorsRoot.monitorLogicalHeight(m) } }
  function dragTo(m, x, y) {
    const d = Object.assign({}, quickMonitorsRoot.draft)
    d[m.name] = { x: x, y: y }
    quickMonitorsRoot.draft = d
  }
  // Snap to neighbours' edges (22 screen px); a tile touching nothing (or
  // overlapping) goes flush against the nearest one with >= 25% edge overlap.
  // Then shift everything so the mirror source (eDP-1) stays at 0,0.
  function endDrag(m, s) {
    const others = QuickModels.enabledMonitors(quickMonitorsRoot.mons).filter(o => o.name !== m.name).map(quickMonitorsRoot.box)
    const b = quickMonitorsRoot.box(m), th = Math.max(8, 22 / Math.max(0.0001, s))
    const xs = [0], ys = [0]
    for (const o of others) { xs.push(o.x, o.x + o.w, o.x - b.w, o.x + o.w - b.w); ys.push(o.y, o.y + o.h, o.y - b.h, o.y + o.h - b.h) }
    const snap = (v, list) => { const n = list.reduce((a, c) => Math.abs(c - v) < Math.abs(a - v) ? c : a); return Math.abs(n - v) <= th ? n : v }
    let x = snap(b.x, xs), y = snap(b.y, ys)
    // Edge contact without interior overlap.
    const touches = o => {
      const ox = Math.min(x + b.w, o.x + o.w) - Math.max(x, o.x), oy = Math.min(y + b.h, o.y + o.h) - Math.max(y, o.y)
      return ox >= 0 && oy >= 0 && !(ox > 0 && oy > 0)
    }
    if (others.length && !others.some(touches)) {
      const dist = o => Math.hypot(o.x + o.w / 2 - x - b.w / 2, o.y + o.h / 2 - y - b.h / 2)
      const n = others.slice().sort((a, c) => dist(a) - dist(c))[0]
      const dx = x + b.w / 2 - (n.x + n.w / 2), dy = y + b.h / 2 - (n.y + n.h / 2)
      if (Math.abs(dx) >= Math.abs(dy)) {
        const ov = Math.max(1, Math.min(b.h, n.h) * 0.25)
        x = dx >= 0 ? n.x + n.w : n.x - b.w
        y = Math.max(n.y - b.h + ov, Math.min(y, n.y + n.h - ov))
      } else {
        const ov = Math.max(1, Math.min(b.w, n.w) * 0.25)
        y = dy >= 0 ? n.y + n.h : n.y - b.h
        x = Math.max(n.x - b.w + ov, Math.min(x, n.x + n.w - ov))
      }
    }
    quickMonitorsRoot.dragTo(m, Math.round(x), Math.round(y))
    const main = quickMonitorsRoot.monitorPrimary(), o0 = main ? quickMonitorsRoot.pos(main) : { x: 0, y: 0 }
    const d = {}
    for (const mon of QuickModels.enabledMonitors(quickMonitorsRoot.mons)) {
      const q = quickMonitorsRoot.pos(mon), nx = q.x - o0.x, ny = q.y - o0.y
      if (nx !== (mon.x || 0) || ny !== (mon.y || 0)) d[mon.name] = { x: nx, y: ny }
    }
    quickMonitorsRoot.draft = d
  }
  function applyDraft() {
    const d = quickMonitorsRoot.draft
    const calls = Object.keys(d).map(n => "hl.monitor({ output = " + quickMonitorsRoot.luaString(n)
      + ", position = " + quickMonitorsRoot.luaString(d[n].x + "x" + d[n].y) + " })")
    const undo = Object.keys(d).map(n => { const m = quickMonitorsRoot.mons.find(x => x.name === n)
      return "hl.monitor({ output = " + quickMonitorsRoot.luaString(n) + ", position = " + quickMonitorsRoot.luaString((m.x || 0) + "x" + (m.y || 0)) + " })" })
    quickMonitorsRoot.draft = ({})
    if (!calls.length) return
    quickMonitorsRoot.applyRevertable(calls.join("\n"), "Arranging...")
    quickMonitorsRoot.revertLua = undo.join("\n")
    quickMonitorsRoot.keepPositions = d
  }

  // ---- Per-display enable/disable (guarded: never the last one) ----
  readonly property int enabledMonCount: QuickModels.enabledMonitors(quickMonitorsRoot.mons).length
  function toggleMonitor(m) {
    if (!m || !m.name) return
    if (!m.disabled && quickMonitorsRoot.enabledMonCount <= 1) {
      quickMonitorsRoot.monStatus = "Won't disable the last display"
      return
    }
    if (m.disabled) {
      const f = QuickModels.enableMonitorFields(m, quickMonitorsRoot.monSaved)
      quickMonitorsRoot.monStatus = "Enabling " + m.name + "..."
      monAction.command = ["hyprctl", "eval",
        "hl.monitor({ output = " + quickMonitorsRoot.luaString(m.name)
        + ", disabled = false"
        + ", mode = " + quickMonitorsRoot.luaString(f.mode)
        + ", position = " + quickMonitorsRoot.luaString(f.position)
        + ", scale = " + f.scale + " })"]
      monAction.running = true
      return
    }
    quickMonitorsRoot.monSaved = QuickModels.rememberEnabledMonitor(quickMonitorsRoot.monSaved, m)
    quickMonitorsRoot.keepLauncherOn(QuickModels.enabledMonitors(quickMonitorsRoot.mons).find(x => x.name !== m.name))
    quickMonitorsRoot.applyRevertable(
      "hl.monitor({ output = " + quickMonitorsRoot.luaString(m.name) + ", disabled = true })",
      "Disabling " + m.name + "...")
  }

  Process {
    id: monScan
    command: ["hyprctl", "monitors", "all", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        // Same JSON → keep the array: a new one rebuilds every preview box
        // (the 3 s poll made them blink out and spring back in).
        const raw = (text || "").trim() || "[]"
        if (raw === quickMonitorsRoot.monRaw) return
        quickMonitorsRoot.monRaw = raw
        try { quickMonitorsRoot.mons = JSON.parse(raw) } catch(_) { quickMonitorsRoot.mons = [] }
        let saved = quickMonitorsRoot.monSaved || {}
        for (const mon of (quickMonitorsRoot.mons || []))
          saved = QuickModels.rememberEnabledMonitor(saved, mon)
        quickMonitorsRoot.monSaved = saved
        quickMonitorsRoot.monVersion = (quickMonitorsRoot.monVersion + 1) % 1000
      }
    }
  }
  Process {
    id: monAction
    stdout: StdioCollector { id: monOut }
    stderr: StdioCollector { id: monErr }
    onExited: (code) => {
      const out = ((monOut.text || "") + (monErr.text || "")).trim()
      quickMonitorsRoot.monStatus = (code === 0 ? (out || "ok") : (out || ("fail " + code)))
      Qt.callLater(function(){ if (!monScan.running) monScan.running = true })
    }
  }
  Timer { interval: 900; id: monDelay; onTriggered: monScan.running = true }
  Timer {
    interval: 3000; running: root.quickMode && root.quickPaneKey === "monitors"; repeat: true; triggeredOnStart: true
    onTriggered: {
      if (!monScan.running) monScan.running = true
      if (!brightProc.running) brightProc.running = true
    }
  }

  Component.onCompleted: Qt.callLater(function(){ if (!monScan.running) monScan.running = true })


  // Segmented option pill: selected = solid primary, idle = hairline outline.
  component OptionPill: Rectangle {
    id: optPill
    property string label: ""
    property bool active: false
    signal tapped()
    implicitWidth: Math.max(44, optPillLbl.implicitWidth + 20)
    implicitHeight: 24
    radius: Style.menuRadiusFull
    color: optPill.active ? Style.m3primary
      : (optPillMa.pressed ? Style.m3containerHigh : optPillMa.containsMouse ? Style.m3stateHover : "transparent")
    border.width: optPill.active ? 0 : 1
    border.color: optPillMa.containsMouse ? Style.m3outline : Style.m3outlineVariant
    Behavior on color { ColorAnimation { duration: 90 } }
    Text {
      id: optPillLbl
      anchors.centerIn: parent
      text: optPill.label
      font.pixelSize: root.fontPx(9)
      font.family: root.uiSans
      font.weight: optPill.active ? Font.DemiBold : Font.Medium
      color: optPill.active ? Style.m3onPrimary : Style.m3onSurfaceVariant
    }
    MouseArea {
      id: optPillMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: optPill.tapped()
    }
  }

  // Header / footer action pill (Mirror / Extend / External / Rescan / Keep / Apply).
  component ActionPill: Rectangle {
    id: actPill
    property string label: ""
    property bool tonal: false
    signal tapped()
    implicitWidth: actPillLbl.implicitWidth + 26
    implicitHeight: 28
    radius: Style.menuRadiusFull
    color: actPill.tonal ? (actPillMa.containsMouse ? Qt.lighter(Style.m3primary, 1.1) : Style.m3primary)
      : (actPillMa.containsMouse ? Style.m3stateHover : "transparent")
    border.width: actPill.tonal ? 0 : 1
    border.color: actPillMa.containsMouse ? Style.m3outline : Style.m3outlineVariant
    Behavior on color { ColorAnimation { duration: 90 } }
    Text {
      id: actPillLbl
      anchors.centerIn: parent
      text: actPill.label
      font.pixelSize: root.fontPx(10)
      font.family: root.uiSans
      font.weight: Font.Medium
      color: actPill.tonal ? Style.m3onPrimary : Style.m3onSurface
    }
    MouseArea {
      id: actPillMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: actPill.tapped()
    }
  }

  // M3 switch: 34x18 track, 14 knob, primary when on. `locked` = last enabled display.
  component ToggleSwitch: Rectangle {
    id: sw
    property bool on: false
    property bool locked: false
    signal toggled()
    implicitWidth: 34; implicitHeight: 18
    radius: Style.menuRadiusFull
    color: sw.on ? Style.m3primary : Style.m3containerHigh
    border.width: sw.on ? 0 : 1
    border.color: Style.m3outline
    opacity: sw.locked ? 0.45 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Rectangle {
      x: sw.on ? sw.width - width - 2 : 2
      anchors.verticalCenter: parent.verticalCenter
      width: 14; height: 14; radius: 7
      color: sw.on ? Style.m3onPrimary : Style.m3outline
      Behavior on x { Menu.MenuAnim { effects: true } }
    }
    MouseArea {
      anchors.fill: parent
      anchors.margins: -4
      hoverEnabled: true
      cursorShape: sw.locked ? Qt.ArrowCursor : Qt.PointingHandCursor
      onClicked: if (!sw.locked) sw.toggled()
    }
  }

  // Settings row: label (+ hint) on the left, control on the right, hairline divider above.
  component SettingRow: Rectangle {
    id: setRow
    property string label: ""
    property string hint: ""
    default property alias control: setRowSlot.data
    Layout.fillWidth: true
    implicitHeight: Math.max(40, setRowSlot.childrenRect.height + 14, setRowText.implicitHeight + 14)
    color: setRowHover.hovered ? Style.menuRowHi : "transparent"
    HoverHandler { id: setRowHover }
    Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 16; anchors.rightMargin: 16; height: 1; color: Style.menuHairline }
    Column {
      id: setRowText
      anchors.left: parent.left; anchors.leftMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      width: root.fontPx(84)
      Text { text: setRow.label; color: Style.m3onSurface; font.pixelSize: root.fontPx(10); font.family: root.uiSans; font.weight: Font.Medium }
      Text { visible: text !== ""; text: setRow.hint; color: Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(8); font.family: root.uiSans }
    }
    Item {
      id: setRowSlot
      anchors.left: setRowText.right; anchors.right: parent.right; anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      height: childrenRect.height
    }
  }

  ColumnLayout {
    id: monLayout
    anchors.fill: parent; spacing: 10
    clip: true

    // Header: title + count, action pills.
    RowLayout {
      Layout.fillWidth: true; spacing: 8
      Text { text: "󰍹"; color: Style.m3primary; font.pixelSize: root.fontPx(14); font.family: root.uiFont }
      Text {
        text: "Displays"
        color: Style.m3onSurface; font.pixelSize: root.fontPx(14); font.family: root.uiSans; font.weight: Font.DemiBold
      }
      Rectangle {
        implicitWidth: countLbl.implicitWidth + 12; implicitHeight: 18; radius: 9
        color: Style.m3primaryContainer
        Text {
          id: countLbl; anchors.centerIn: parent
          text: QuickModels.enabledMonitors(quickMonitorsRoot.mons).length + "/" + (quickMonitorsRoot.mons || []).length
          color: Style.m3primary; font.pixelSize: root.fontPx(8); font.family: root.uiSans; font.weight: Font.DemiBold
        }
      }
      Item { Layout.fillWidth: true }
      ActionPill {
        label: quickMonitorsRoot.anyMirrored ? "Unmirror" : "Mirror"
        tonal: quickMonitorsRoot.anyMirrored
        onTapped: quickMonitorsRoot.anyMirrored ? quickMonitorsRoot.unmirrorMonitors() : quickMonitorsRoot.mirrorMonitors()
      }
      ActionPill { label: "Extend"; onTapped: quickMonitorsRoot.extendMonitors() }
      ActionPill { label: "External"; onTapped: quickMonitorsRoot.externalOnlyMonitors() }
      ActionPill { label: "Rescan"; onTapped: quickMonitorsRoot.rescanMonitors() }
    }

    // Arrangement canvas — uniform scale in logical coordinates fitted to 84%
    // of the frame. Drag a tile to re-arrange (snaps on release, Apply below).
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: root.launcherGeom.vizMin
      Layout.maximumHeight: root.launcherGeom.vizMax
      Layout.preferredHeight: root.launcherGeom.vizMax
      radius: Style.menuRadiusLg
      color: Style.m3container
      border.width: 1; border.color: Style.m3outlineVariant
      clip: true
      // Dot grid, like a design canvas.
      Canvas {
        id: dotGrid
        anchors.fill: parent
        readonly property color dot: Style.m3outlineVariant
        onDotChanged: requestPaint()
        onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
        onPaint: {
          const ctx = getContext("2d"); ctx.reset(); ctx.fillStyle = dotGrid.dot
          for (let x = 12; x < width; x += 18) for (let y = 12; y < height; y += 18) ctx.fillRect(x, y, 2, 2)
        }
      }
      Item {
        id: vizArea
        anchors.fill: parent; anchors.margins: 12
        // Boxes snap while the card is still opening/laying out; only later
        // topology changes (mirror, scale, toggle) glide.
        property bool animate: false
        Timer { interval: 700; running: vizArea.width > 0 && vizArea.height > 0; onTriggered: vizArea.animate = true }
        // Fitted to the draft layout; frozen while a drag is live so nothing
        // rescales under the pointer.
        property var frozen: null
        readonly property var liveGeom: {
          const mons = quickMonitorsRoot.mons || []
          let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
          for (const m of mons) {
            const p = quickMonitorsRoot.pos(m)
            minX = Math.min(minX, p.x); minY = Math.min(minY, p.y)
            maxX = Math.max(maxX, p.x + quickMonitorsRoot.monitorLogicalWidth(m))
            maxY = Math.max(maxY, p.y + quickMonitorsRoot.monitorLogicalHeight(m))
          }
          if (!mons.length) { minX = minY = 0; maxX = maxY = 1 }
          const spanX = Math.max(1, maxX - minX), spanY = Math.max(1, maxY - minY)
          // Uniform scale keeps logical aspect; 84% leaves room to drag; center leftover.
          const s = Math.min(width * 0.84 / spanX, height * 0.84 / spanY)
          return { s: s, minX: minX, minY: minY, ox: (width - spanX * s) / 2, oy: (height - spanY * s) / 2 }
        }
        readonly property var geom: vizArea.frozen || vizArea.liveGeom
        Text {
          visible: !(quickMonitorsRoot.mons || []).length
          anchors.centerIn: parent
          text: "Loading… rescan"
          color: Style.m3outline; font.pixelSize: root.fontPx(10); font.family: root.uiSans
        }
        Repeater {
          model: quickMonitorsRoot.mons || []
          delegate: Rectangle {
            id: vizMon
            required property var modelData
            readonly property bool sel: !!quickMonitorsRoot.focusedMon && quickMonitorsRoot.focusedMon.name === modelData.name
            readonly property bool off: !!modelData.disabled
            readonly property bool builtin: modelData.name === "eDP-1"
            readonly property bool mirrored: QuickModels.isMirroring(modelData)
            readonly property var p: quickMonitorsRoot.pos(modelData)
            readonly property real h: height
            x: vizArea.geom.ox + (vizMon.p.x - vizArea.geom.minX) * vizArea.geom.s + 1
            y: vizArea.geom.oy + (vizMon.p.y - vizArea.geom.minY) * vizArea.geom.s + 1
            width: Math.max(36, quickMonitorsRoot.monitorLogicalWidth(modelData) * vizArea.geom.s - 2)
            height: Math.max(28, quickMonitorsRoot.monitorLogicalHeight(modelData) * vizArea.geom.s - 2)
            z: vizDrag.active ? 2 : vizMon.sel ? 1 : 0
            radius: Style.menuRadiusMd
            color: Style.m3containerHigh
            opacity: vizMon.off ? 0.45 : 1
            Behavior on x { enabled: vizArea.animate && !vizDrag.active; Menu.MenuAnim {} }
            Behavior on y { enabled: vizArea.animate && !vizDrag.active; Menu.MenuAnim {} }
            Behavior on width { enabled: vizArea.animate; Menu.MenuAnim {} }
            Behavior on height { enabled: vizArea.animate; Menu.MenuAnim {} }
            // The live wallpaper as the "screen", dimmed so labels read on it.
            ClippingRectangle {
              anchors.fill: parent; anchors.margins: vizMon.sel ? 3 : 1
              radius: Math.max(0, vizMon.radius - anchors.margins)
              color: "transparent"
              visible: !vizMon.off && Wallpaper.WallpaperService.currentWallpaper !== ""
              // Cached picker thumbnail first (a 5K JPEG takes seconds to decode), original if missing.
              Image {
                readonly property string wall: Wallpaper.WallpaperService.currentWallpaper
                property bool full: false
                anchors.fill: parent
                source: !wall ? "" : full ? "file://" + wall : "file://" + WallThumbs.thumbPath(wall, Wallpaper.WallpaperService.thumbCacheDir)
                onWallChanged: full = false
                onStatusChanged: if (status === Image.Error && !full) full = true
                sourceSize.width: 480
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
              }
              Rectangle { anchors.fill: parent; color: Style.m3surface; opacity: vizMon.sel ? 0.35 : vizHover.hovered ? 0.45 : 0.6; Behavior on opacity { NumberAnimation { duration: 90 } } }
            }
            Rectangle {
              anchors.fill: parent; radius: parent.radius; color: "transparent"
              border.width: vizMon.sel ? 2 : 1
              border.color: vizMon.sel ? Style.m3primary : vizHover.hovered ? Style.m3outline : Style.m3outlineVariant
              Behavior on border.color { ColorAnimation { duration: 90 } }
            }
            // Centered label chip: name, logical size · scale.
            Rectangle {
              anchors.centerIn: parent
              width: Math.min(vizMon.width - 12, Math.max(vizName.implicitWidth, vizSub.implicitWidth) + 28)
              height: vizLbl.implicitHeight + 10
              radius: Style.menuRadiusMd
              color: Style.m3surface
              visible: vizMon.h >= 44
              Column {
                id: vizLbl
                anchors.centerIn: parent
                width: parent.width - 16
                spacing: 1
                Text {
                  id: vizName
                  width: parent.width; horizontalAlignment: Text.AlignHCenter
                  text: modelData.name || "mon"
                  color: Style.m3onSurface; font.family: root.uiSans; font.weight: Font.DemiBold
                  font.pixelSize: root.fontPx(vizMon.h >= 72 ? 12 : 10)
                  elide: Text.ElideRight
                }
                Text {
                  id: vizSub
                  width: parent.width; horizontalAlignment: Text.AlignHCenter
                  text: vizMon.off ? "OFF" : vizMon.mirrored ? "MIRROR ← " + modelData.mirrorOf
                    : Math.round(quickMonitorsRoot.monitorLogicalWidth(modelData)) + "×"
                      + Math.round(quickMonitorsRoot.monitorLogicalHeight(modelData)) + " · " + QuickModels.formatScale(modelData.scale || 1) + "×"
                  color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(9)
                  elide: Text.ElideRight
                }
              }
            }
            Text {
              visible: vizMon.h < 44
              anchors.centerIn: parent
              text: modelData.name || "mon"
              color: Style.m3onSurface; font.family: root.uiSans; font.weight: Font.DemiBold; font.pixelSize: root.fontPx(9)
            }
            // BUILT-IN badge (top-left) and active workspace (top-right).
            Rectangle {
              visible: vizMon.builtin && vizMon.h >= 72
              anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 8
              width: builtinLbl.implicitWidth + 12; height: 16; radius: 8
              color: Style.m3primary
              Text { id: builtinLbl; anchors.centerIn: parent; text: "BUILT-IN"; color: Style.m3onPrimary; font.pixelSize: root.fontPx(7); font.family: root.uiSans; font.weight: Font.Bold; font.letterSpacing: 1.2 }
            }
            Rectangle {
              visible: !vizMon.off && vizMon.h >= 72 && !!modelData.activeWorkspace
              anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
              width: wsLbl.implicitWidth + 12; height: 16; radius: 8
              color: Style.m3surface
              Text { id: wsLbl; anchors.centerIn: parent; text: "WS " + (modelData.activeWorkspace ? modelData.activeWorkspace.name : ""); color: Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(7); font.family: root.uiSans; font.weight: Font.Bold; font.letterSpacing: 1.2 }
            }
            HoverHandler { id: vizHover; cursorShape: vizDrag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor }
            TapHandler { onTapped: quickMonitorsRoot.selectedName = modelData.name }
            DragHandler {
              id: vizDrag
              target: null
              enabled: !vizMon.off && !vizMon.mirrored
              property point start
              onActiveChanged: {
                if (active) { vizArea.frozen = vizArea.liveGeom; quickMonitorsRoot.selectedName = modelData.name; start = Qt.point(vizMon.p.x, vizMon.p.y) }
                else { quickMonitorsRoot.endDrag(modelData, vizArea.geom.s); vizArea.frozen = null }
              }
              onTranslationChanged: if (active) quickMonitorsRoot.dragTo(modelData,
                start.x + translation.x / vizArea.geom.s, start.y + translation.y / vizArea.geom.s)
            }
          }
        }
      }
    }

    // Selected display: header + label | control rows.
    Rectangle {
      Layout.fillWidth: true
      visible: !!quickMonitorsRoot.focusedMon
      implicitHeight: dispCol.implicitHeight + 8
      radius: Style.menuRadiusLg
      color: Style.m3container
      clip: true
      ColumnLayout {
        id: dispCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.topMargin: 4
        spacing: 0
        readonly property var fm: quickMonitorsRoot.focusedMon
        RowLayout {
          Layout.fillWidth: true; Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.preferredHeight: 44
          spacing: 10
          Text {
            text: dispCol.fm && dispCol.fm.name === "eDP-1" ? "󰌢" : "󰍹"
            color: Style.m3primary; font.pixelSize: root.fontPx(14); font.family: root.uiFont
          }
          Column {
            Layout.fillWidth: true
            Text {
              width: parent.width
              text: dispCol.fm ? dispCol.fm.name + (dispCol.fm.name === "eDP-1" ? "  Built-in display" : (dispCol.fm.make ? "  " + dispCol.fm.make + " " + (dispCol.fm.model || "") : "")) : ""
              color: Style.m3onSurface; font.pixelSize: root.fontPx(11); font.family: root.uiSans; font.weight: Font.DemiBold; elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: dispCol.fm ? quickMonitorsRoot.monitorModeLabel(dispCol.fm) + " · " + QuickModels.formatScale(dispCol.fm.scale || 1) + "× · "
                + (dispCol.fm.x || 0) + "," + (dispCol.fm.y || 0) : ""
              color: Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(9); font.family: root.uiSans; elide: Text.ElideRight
            }
          }
          Text {
            text: dispCol.fm && dispCol.fm.disabled ? "Off" : "On"
            color: Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(10); font.family: root.uiSans
          }
          ToggleSwitch {
            on: !!dispCol.fm && !dispCol.fm.disabled
            locked: on && quickMonitorsRoot.enabledMonCount <= 1
            onToggled: quickMonitorsRoot.toggleMonitor(dispCol.fm)
          }
        }
        // Brightness: the built-in backlight only (brightnessctl).
        SettingRow {
          label: "Brightness"; hint: QuickModels.brightnessName(quickMonitorsRoot.brightness)
          visible: quickMonitorsRoot.brightness >= 0 && !!dispCol.fm && dispCol.fm.name === "eDP-1"
          RowLayout {
            width: parent.width; spacing: 12
            Menu.MenuSlider {
              Layout.fillWidth: true
              value: Math.max(0, quickMonitorsRoot.brightness) / 100
              onMoved: function(v) { quickMonitorsRoot.setBrightness(Math.round(v * 100)) }
            }
            Text {
              text: quickMonitorsRoot.brightness + "%"
              color: Style.m3onSurface; font.pixelSize: root.fontPx(10); font.family: root.uiSans; font.weight: Font.DemiBold
              Layout.preferredWidth: root.fontPx(30); horizontalAlignment: Text.AlignRight
            }
          }
        }
        // Scale pills are the Hyprland-legal values for this mode.
        Repeater {
          model: [
            { label: "Resolution", key: "res" },
            { label: "Scale", key: "scale", hint: "logical size" },
            { label: "Refresh", key: "hz" },
            { label: "Rotation", key: "rot" }
          ]
          delegate: SettingRow {
            id: optRow
            required property var modelData
            readonly property var opts: modelData.key === "scale" ? (quickMonitorsRoot.scaleValues || [])
              : modelData.key === "res" ? (quickMonitorsRoot.resolutionOpts || [])
              : modelData.key === "rot" ? [0, 1, 2, 3] : (quickMonitorsRoot.refreshOpts || [])
            label: modelData.label; hint: modelData.hint || ""
            // Rotation on externals only: a rotated eDP-1 breaks the bar's notch cutout.
            visible: modelData.key === "scale" || opts.length > 1
              && (modelData.key !== "rot" || (!!quickMonitorsRoot.focusedMon && quickMonitorsRoot.focusedMon.name !== "eDP-1"))
            Flow {
              width: parent.width; spacing: 6
              Repeater {
                model: optRow.opts
                delegate: OptionPill {
                  required property var modelData
                  required property int index
                  readonly property var fm: quickMonitorsRoot.focusedMon
                  readonly property string key: optRow.modelData.key
                  label: key === "scale" ? QuickModels.formatScale(fm ? QuickModels.cleanScale(modelData, fm.width, fm.height) : modelData) + "×"
                    : key === "res" ? modelData.label : key === "rot" ? (modelData * 90) + "°" : QuickModels.formatRefresh(modelData)
                  active: key === "scale" ? index === quickMonitorsRoot.activeScaleIdx
                    : key === "res" ? (!!fm && modelData.width === fm.width && modelData.height === fm.height)
                    : key === "rot" ? (!!fm && (fm.transform || 0) === modelData)
                    : (!!fm && QuickModels.sameRefresh(modelData, fm.refreshRate))
                  onTapped: {
                    if (key === "scale") quickMonitorsRoot.setScale(modelData)
                    else if (key === "res") quickMonitorsRoot.applyMode(modelData.width, modelData.height, modelData.best)
                    else if (key === "rot") quickMonitorsRoot.setRotation(modelData)
                    else quickMonitorsRoot.applyMode(fm.width, fm.height, modelData)
                  }
                }
              }
            }
          }
        }
      }
    }

    Item { Layout.fillHeight: true }

    // Status bar: pulsing dot while a change is pending (unapplied drag or
    // probation), status text, then Revert / Apply or Keep.
    RowLayout {
      id: statusBar
      Layout.fillWidth: true; Layout.preferredHeight: 30
      spacing: 10
      readonly property bool pending: quickMonitorsRoot.draftDirty || quickMonitorsRoot.revertLeft > 0
      Rectangle {
        id: pulseDot
        width: 8; height: 8; radius: 4
        color: statusBar.pending ? Style.m3primary : Style.m3outline
        SequentialAnimation on opacity {
          id: pulse
          running: statusBar.pending; loops: Animation.Infinite
          onRunningChanged: if (!running) pulseDot.opacity = 1
          NumberAnimation { to: 0.3; duration: 600 }
          NumberAnimation { to: 1; duration: 600 }
        }
      }
      Text {
        Layout.fillWidth: true
        readonly property bool bad: quickMonitorsRoot.monStatus.indexOf("fail") >= 0 || quickMonitorsRoot.monStatus.indexOf("No ") >= 0
        text: quickMonitorsRoot.draftDirty ? "Unapplied layout changes"
          : quickMonitorsRoot.revertLeft > 0 ? "Keep this layout? Reverting in " + quickMonitorsRoot.revertLeft + "s"
          : (quickMonitorsRoot.monStatus && quickMonitorsRoot.monStatus !== "ok" ? quickMonitorsRoot.monStatus : "Layout matches your displays · drag to arrange")
        color: bad ? Style.red : Style.m3onSurfaceVariant
        font.pixelSize: root.fontPx(9); font.family: root.uiSans; elide: Text.ElideRight
      }
      ActionPill {
        visible: quickMonitorsRoot.draftDirty || quickMonitorsRoot.revertLeft > 0
        label: "Revert"
        onTapped: quickMonitorsRoot.draftDirty ? (quickMonitorsRoot.draft = ({})) : quickMonitorsRoot.revertLayout("Reverted")
      }
      ActionPill {
        visible: quickMonitorsRoot.draftDirty || quickMonitorsRoot.revertLeft > 0
        tonal: true
        label: quickMonitorsRoot.draftDirty ? "Apply" : "Keep " + quickMonitorsRoot.revertLeft + "s"
        onTapped: quickMonitorsRoot.draftDirty ? quickMonitorsRoot.applyDraft() : quickMonitorsRoot.keepChange()
      }
    }
  }
}
