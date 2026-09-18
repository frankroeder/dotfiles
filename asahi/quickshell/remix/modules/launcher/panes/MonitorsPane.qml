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
  property var monSaved: ({})
  property int monVersion: 0
  property string monStatus: ""

  function luaString(value) { return "\"" + String(value || "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"" }
  function monitorMode(m) {
    if (!m) return "preferred"
    const rr = m.refreshRate ? "@" + Number(m.refreshRate).toFixed(3) : ""
    return (m.width || 0) + "x" + (m.height || 0) + rr
  }
  // Enabled only: `monitors all -j` lists disabled outputs, and picking one as
  // the mirror source (clamshell'd eDP-1) points the live display at nothing.
  function monitorPrimary() {
    return QuickModels.mirrorSource(quickMonitorsRoot.mons) || (quickMonitorsRoot.mons || [])[0] || null
  }
  function monitorLogicalWidth(m) { return (m.width || 1920) / Math.max(0.25, m.scale || 1) }
  function monitorLogicalHeight(m) { return (m.height || 1080) / Math.max(0.25, m.scale || 1) }
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
  function extendMonitors() { quickMonitorsRoot.revertLayout("Reloading monitors...") }
  // Never leave zero outputs: the external must come up enabled (omitting
  // disabled = false leaves monitors.lua's off rule in place) before eDP-1 goes
  // dark, and its geometry comes from the saved snapshot, not "preferred".
  function externalOnlyMonitors() {
    const list = quickMonitorsRoot.mons || []
    const edp = list.find(m => m && m.name === "eDP-1")
    const external = QuickModels.enabledMonitors(list).find(m => m.name !== "eDP-1")
      || list.find(m => m && m.name !== "eDP-1")
    if (!external) { quickMonitorsRoot.monStatus = "No external"; return }
    if (!edp || edp.disabled) { quickMonitorsRoot.monStatus = "Already external only"; return }
    const f = QuickModels.enableMonitorFields(external, quickMonitorsRoot.monSaved)
    quickMonitorsRoot.keepLauncherOn(external)
    quickMonitorsRoot.applyRevertable(
      "hl.monitor({ output = " + quickMonitorsRoot.luaString(external.name)
      + ", disabled = false, mode = " + quickMonitorsRoot.luaString(f.mode)
      + ", position = " + quickMonitorsRoot.luaString(f.position)
      + ", scale = " + f.scale + " })\nhl.monitor({ output = \"eDP-1\", disabled = true })",
      "External only...")
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
    quickMonitorsRoot.monStatus = status
    Quickshell.execDetached(["hyprctl", "eval", lua])
    quickMonitorsRoot.revertLeft = 15
    revertTimer.restart()
    monDelay.restart()
  }
  function revertLayout(status) {
    quickMonitorsRoot.disarmRevert()
    quickMonitorsRoot.monStatus = status
    Quickshell.execDetached(["hyprctl", "reload"])
    monDelay.restart()
  }
  function disarmRevert() {
    quickMonitorsRoot.revertLeft = 0
    revertTimer.stop()
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
        try { quickMonitorsRoot.mons = JSON.parse((text || "").trim() || "[]") } catch(_) { quickMonitorsRoot.mons = [] }
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


  // Segmented option pill (M3 tonal chip): selected = secondaryContainer,
  // unselected = containerHigh so it stays visible inside a container card.
  component OptionPill: Rectangle {
    id: optPill
    property string label: ""
    property bool active: false
    signal tapped()
    implicitWidth: Math.max(44, optPillLbl.implicitWidth + 20)
    implicitHeight: 24
    radius: Style.menuRadiusFull
    color: optPill.active ? Style.m3secondaryContainer
      : (optPillMa.containsMouse ? Qt.lighter(Style.m3containerHigh, 1.15) : Style.m3containerHigh)
    Behavior on color { ColorAnimation { duration: 120 } }
    Text {
      id: optPillLbl
      anchors.centerIn: parent
      text: optPill.label
      font.pixelSize: root.fontPx(9)
      font.family: root.uiSans
      font.weight: optPill.active ? Font.DemiBold : Font.Normal
      color: optPill.active ? Style.m3onSurface : Style.m3onSurfaceVariant
    }
    MouseArea {
      id: optPillMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: optPill.tapped()
    }
  }

  // Header action pill (Mirror / Extend / External / Rescan).
  component ActionPill: Rectangle {
    id: actPill
    property string label: ""
    property bool tonal: false
    signal tapped()
    implicitWidth: actPillLbl.implicitWidth + 26
    implicitHeight: 28
    radius: Style.menuRadiusFull
    color: actPillMa.containsMouse ? Qt.lighter(actPill.tonal ? Style.m3primaryContainer : Style.m3containerHigh, 1.15)
      : (actPill.tonal ? Style.m3primaryContainer : Style.m3container)
    Behavior on color { ColorAnimation { duration: 120 } }
    Text {
      id: actPillLbl
      anchors.centerIn: parent
      text: actPill.label
      font.pixelSize: root.fontPx(10)
      font.family: root.uiSans
      font.weight: Font.Medium
      color: Style.m3onSurface
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

  ColumnLayout {
    id: monLayout
    anchors.fill: parent; spacing: 8
    clip: true

    // Header: count + status, action pills.
    RowLayout {
      Layout.fillWidth: true; spacing: 8
      Text { text: "󰍹"; color: Style.m3primary; font.pixelSize: root.fontPx(14); font.family: root.uiFont }
      Text {
        text: ((quickMonitorsRoot.mons || []).length || 0) + " displays"
        color: Style.m3onSurface; font.pixelSize: root.fontPx(13); font.family: root.uiSans; font.weight: Font.DemiBold
      }
      Text {
        text: "· " + (quickMonitorsRoot.monStatus || "Live layout")
        readonly property bool bad: quickMonitorsRoot.monStatus.indexOf("fail") >= 0 || quickMonitorsRoot.monStatus.indexOf("No ") >= 0
        color: bad ? Style.red : Style.m3onSurfaceVariant
        font.pixelSize: root.fontPx(10); font.family: root.uiSans; Layout.fillWidth: true; elide: Text.ElideRight
      }
      ActionPill {
        visible: quickMonitorsRoot.revertLeft > 0
        label: "Keep " + quickMonitorsRoot.revertLeft + "s"
        tonal: true
        onTapped: quickMonitorsRoot.disarmRevert()
      }
      ActionPill {
        label: quickMonitorsRoot.anyMirrored ? "Unmirror" : "Mirror"
        tonal: quickMonitorsRoot.anyMirrored
        onTapped: quickMonitorsRoot.anyMirrored ? quickMonitorsRoot.unmirrorMonitors() : quickMonitorsRoot.mirrorMonitors()
      }
      ActionPill { label: "Extend"; tonal: quickMonitorsRoot.enabledMonCount > 1; onTapped: quickMonitorsRoot.extendMonitors() }
      ActionPill { label: "External"; onTapped: quickMonitorsRoot.externalOnlyMonitors() }
      ActionPill { label: "Rescan"; onTapped: quickMonitorsRoot.rescanMonitors() }
    }

    // Brightness card (hidden when brightnessctl reports nothing).
    Rectangle {
      Layout.fillWidth: true
      visible: quickMonitorsRoot.brightness >= 0
      implicitHeight: brightRow.implicitHeight + 16
      radius: Style.menuRadiusLg
      color: Style.m3container
      RowLayout {
        id: brightRow
        anchors.fill: parent
        anchors.leftMargin: 14; anchors.rightMargin: 14
        spacing: 12
        Text { text: "󰃟"; color: Style.m3primary; font.pixelSize: root.fontPx(14); font.family: root.uiFont }
        Menu.MenuSlider {
          Layout.fillWidth: true
          value: Math.max(0, quickMonitorsRoot.brightness) / 100
          onMoved: function(v) { quickMonitorsRoot.setBrightness(Math.round(v * 100)) }
        }
        Text {
          text: quickMonitorsRoot.brightness + "%"
          color: Style.m3onSurface; font.pixelSize: root.fontPx(11); font.family: root.uiSans; font.weight: Font.DemiBold
          Layout.preferredWidth: root.fontPx(30)
          horizontalAlignment: Text.AlignRight
        }
        Text {
          text: QuickModels.brightnessName(quickMonitorsRoot.brightness)
          color: Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(10); font.family: root.uiSans
          elide: Text.ElideRight; Layout.maximumWidth: 110
        }
      }
    }

    // Selected display: name + On switch, then Scale / Resolution / Refresh
    // segmented rows. Scale pills are the Hyprland-legal values for this mode.
    Rectangle {
      Layout.fillWidth: true
      visible: !!quickMonitorsRoot.focusedMon
      implicitHeight: dispCol.implicitHeight + 20
      radius: Style.menuPanelRadius
      color: Style.m3container
      ColumnLayout {
        id: dispCol
        anchors.fill: parent
        anchors.margins: 10
        anchors.leftMargin: 16; anchors.rightMargin: 16
        spacing: 4
        RowLayout {
          Layout.fillWidth: true; spacing: 10
          Text {
            text: quickMonitorsRoot.focusedMon ? quickMonitorsRoot.focusedMon.name : ""
            color: Style.m3onSurface; font.pixelSize: root.fontPx(12); font.family: root.uiSans; font.weight: Font.DemiBold
          }
          Text {
            Layout.fillWidth: true
            text: quickMonitorsRoot.focusedMon ? quickMonitorsRoot.monitorMode(quickMonitorsRoot.focusedMon) : ""
            color: Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(10); font.family: root.uiSans; elide: Text.ElideRight
          }
          Text {
            text: quickMonitorsRoot.focusedMon && quickMonitorsRoot.focusedMon.disabled ? "Off" : "On"
            color: Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(10); font.family: root.uiSans
          }
          ToggleSwitch {
            on: !!quickMonitorsRoot.focusedMon && !quickMonitorsRoot.focusedMon.disabled
            locked: on && quickMonitorsRoot.enabledMonCount <= 1
            onToggled: quickMonitorsRoot.toggleMonitor(quickMonitorsRoot.focusedMon)
          }
        }
        Repeater {
          model: [
            { label: "Scale", key: "scale" },
            { label: "Resolution", key: "res" },
            { label: "Refresh", key: "hz" }
          ]
          delegate: RowLayout {
            id: optRow
            required property var modelData
            readonly property var opts: modelData.key === "scale" ? (quickMonitorsRoot.scaleValues || [])
              : modelData.key === "res" ? (quickMonitorsRoot.resolutionOpts || []) : (quickMonitorsRoot.refreshOpts || [])
            Layout.fillWidth: true; spacing: 8
            visible: modelData.key === "scale" || opts.length > 1
            Text {
              text: modelData.label; Layout.preferredWidth: root.fontPx(52); Layout.alignment: Qt.AlignTop; topPadding: 4
              color: Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(10); font.family: root.uiSans
            }
            Flow {
              Layout.fillWidth: true; spacing: 6
              Repeater {
                model: opts
                delegate: OptionPill {
                  required property var modelData
                  required property int index
                  readonly property var fm: quickMonitorsRoot.focusedMon
                  readonly property string key: optRow.modelData.key
                  label: key === "scale" ? QuickModels.formatScale(fm ? QuickModels.cleanScale(modelData, fm.width, fm.height) : modelData) + "×"
                    : key === "res" ? modelData.label : QuickModels.formatRefresh(modelData)
                  active: key === "scale" ? index === quickMonitorsRoot.activeScaleIdx
                    : key === "res" ? (!!fm && modelData.width === fm.width && modelData.height === fm.height)
                    : (!!fm && QuickModels.sameRefresh(modelData, fm.refreshRate))
                  onTapped: {
                    if (key === "scale") quickMonitorsRoot.setScale(modelData)
                    else if (key === "res") quickMonitorsRoot.applyMode(modelData.width, modelData.height, modelData.best)
                    else quickMonitorsRoot.applyMode(fm.width, fm.height, modelData)
                  }
                }
              }
            }
          }
        }
      }
    }

    // Layout preview — uniform scale in logical coordinates, height capped so
    // the list stays visible. Label density follows box height so text never clips.
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: root.launcherGeom.vizMin
      Layout.maximumHeight: root.launcherGeom.vizMax
      Layout.preferredHeight: LauncherGeom.monitorsVizHeight(quickMonitorsRoot.height, root.launcherGeom)
      radius: Style.menuRadiusLg
      color: Style.m3container
      Item {
        id: vizArea
        anchors.fill: parent; anchors.margins: 12
        readonly property var geom: {
          const _ = quickMonitorsRoot.monVersion
          const mons = quickMonitorsRoot.mons || []
          let minX = 0, minY = 0, maxX = 0, maxY = 0
          for (const m of mons) {
            minX = Math.min(minX, m.x || 0); minY = Math.min(minY, m.y || 0)
            maxX = Math.max(maxX, (m.x || 0) + quickMonitorsRoot.monitorLogicalWidth(m))
            maxY = Math.max(maxY, (m.y || 0) + quickMonitorsRoot.monitorLogicalHeight(m))
          }
          const spanX = Math.max(1, maxX - minX), spanY = Math.max(1, maxY - minY)
          // Uniform scale keeps logical aspect; center leftover.
          const s = Math.min(width / spanX, height / spanY)
          return { s: s, minX: minX, minY: minY, ox: (width - spanX * s) / 2, oy: (height - spanY * s) / 2 }
        }
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
            readonly property real h: height
            x: vizArea.geom.ox + ((modelData.x || 0) - vizArea.geom.minX) * vizArea.geom.s + 1
            y: vizArea.geom.oy + ((modelData.y || 0) - vizArea.geom.minY) * vizArea.geom.s + 1
            width: Math.max(2, quickMonitorsRoot.monitorLogicalWidth(modelData) * vizArea.geom.s - 2)
            height: Math.max(2, quickMonitorsRoot.monitorLogicalHeight(modelData) * vizArea.geom.s - 2)
            radius: Style.menuRadiusMd
            color: vizMon.sel ? Style.m3primaryContainer : (vizMonMa.containsMouse ? Qt.lighter(Style.m3containerHigh, 1.1) : Style.m3containerHigh)
            border.width: vizMon.sel ? 2 : 1
            border.color: vizMon.sel ? Style.m3primary : Style.m3outlineVariant
            opacity: modelData.disabled ? 0.45 : 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on x { Menu.MenuAnim {} }
            Behavior on y { Menu.MenuAnim {} }
            Behavior on width { Menu.MenuAnim {} }
            Behavior on height { Menu.MenuAnim {} }
            Column {
              anchors.left: parent.left; anchors.top: parent.top
              anchors.margins: Math.max(4, Math.min(10, vizMon.width * 0.04))
              width: vizMon.width - 2 * anchors.margins
              spacing: 2
              Text {
                width: parent.width
                text: modelData.name || "mon"
                color: Style.m3onSurface; font.family: root.uiSans; font.weight: Font.DemiBold
                font.pixelSize: root.fontPx(vizMon.h >= 72 ? 12 : vizMon.h >= 44 ? 10 : 9)
                elide: Text.ElideRight
              }
              Text {
                visible: vizMon.h >= 44
                width: parent.width
                text: Math.round(quickMonitorsRoot.monitorLogicalWidth(modelData)) + "×"
                  + Math.round(quickMonitorsRoot.monitorLogicalHeight(modelData)) + " · " + QuickModels.formatScale(modelData.scale || 1) + "×"
                color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(9)
                elide: Text.ElideRight
              }
              Text {
                visible: vizMon.h >= 72
                width: parent.width
                text: (modelData.x || 0) + "," + (modelData.y || 0)
                color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(9)
                elide: Text.ElideRight
              }
            }
            MouseArea {
              id: vizMonMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: quickMonitorsRoot.selectedName = modelData.name
            }
          }
        }
      }
    }
    Text {
      Layout.fillWidth: true
      text: "Mirror sources eDP-1 when on · Unmirror/Extend reload monitors.lua · Keep holds a change"
      color: Style.m3outline; font.pixelSize: root.fontPx(9); font.family: root.uiSans
      horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
    }

    // Display list — content-sized (capped) so leftover height feeds the preview, not a gap.
    Flickable {
      Layout.fillWidth: true
      Layout.fillHeight: false
      Layout.preferredHeight: Math.min(Math.max(monList.height, root.launcherGeom.minList), root.launcherGeom.monListMax)
      Layout.maximumHeight: Math.min(Math.max(monList.height, root.launcherGeom.minList), root.launcherGeom.monListMax)
      Layout.minimumHeight: root.launcherGeom.minList
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      contentHeight: monList.height
      ScrollBar.vertical: Menu.MenuScrollBar {}
      Column { id: monList; width: parent.width; spacing: 0
        Repeater {
          model: quickMonitorsRoot.mons || []
          delegate: Rectangle {
            id: monRow
            required property var modelData
            readonly property bool sel: !!quickMonitorsRoot.focusedMon && quickMonitorsRoot.focusedMon.name === modelData.name
            readonly property bool isOff: !!modelData.disabled
            width: parent.width; height: 42
            radius: Style.menuRadiusMd
            color: monRow.sel ? Style.m3container : (monRowMa.containsMouse ? Style.m3stateHover : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }
            MouseArea { id: monRowMa; anchors.fill: parent; hoverEnabled: true; onClicked: quickMonitorsRoot.selectedName = modelData.name }
            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 14; spacing: 12
              Text {
                text: modelData.name === "eDP-1" ? "󰌢" : "󰍹"
                color: monRow.sel ? Style.m3primary : Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(15); font.family: root.uiFont
              }
              ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text {
                  Layout.fillWidth: true
                  text: (modelData.name || "?") + (modelData.mirrorOf && modelData.mirrorOf !== "none" ? " mirrors " + modelData.mirrorOf : "")
                  color: monRow.isOff ? Style.m3onSurfaceVariant : Style.m3onSurface
                  font.pixelSize: root.fontPx(11); font.family: root.uiSans; elide: Text.ElideRight
                  font.weight: monRow.sel ? Font.DemiBold : Font.Medium
                }
                Text {
                  Layout.fillWidth: true
                  text: quickMonitorsRoot.monitorMode(modelData) + " · " + QuickModels.formatScale(modelData.scale || 1) + "× · "
                    + (modelData.x || 0) + "," + (modelData.y || 0)
                  color: Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(9); font.family: root.uiSans; elide: Text.ElideRight
                }
              }
              Text {
                text: monRow.isOff ? "Off" : "On"
                color: Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(9); font.family: root.uiSans
              }
              // Enable/disable this display (guarded against the last one).
              ToggleSwitch {
                on: !monRow.isOff
                locked: on && quickMonitorsRoot.enabledMonCount <= 1
                onToggled: quickMonitorsRoot.toggleMonitor(modelData)
              }
            }
          }
        }
      }
    }
  }
}
