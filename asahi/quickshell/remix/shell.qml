import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

import "modules/bar"
import "modules/system" as System
import "modules/wallpaper"
import "modules/writing" as Writing
import "services" as Services

ShellRoot {
  id: shell

  property bool calendarOpen: false
  // Launcher is the topmost layer: bar popups close so none float over it or hold Esc.
  readonly property bool launcherOpen: launcherLoader.item ? launcherLoader.item.shouldShow : false
  onLauncherOpenChanged: if (launcherOpen) {
    shell.calendarOpen = false
    // Its focus grab would keep the launcher's keyboard input.
    notifCenter.historyVisible = false
  }
  // Calendar and notification sheet are one-at-a-time.
  onCalendarOpenChanged: if (calendarOpen) notifCenter.historyVisible = false
  Connections {
    target: notifCenter
    function onHistoryVisibleChanged() { if (notifCenter.historyVisible) shell.calendarOpen = false }
  }

  System.Osd { id: osd }
  System.DimOverlay {}
  System.NotificationCenter { id: notifCenter }
  System.PkgManager { id: pkgManager }
  // Answers polkit (GUI admin prompts, pkexec); nothing did before.
  System.PolkitAgent {}

  // Bound in hypr/conf.d/bindings.lua as hl.dsp.global("quickshell:recorder-panel").
  GlobalShortcut {
    appid: "quickshell"
    name: "recorder-panel"
    description: "Toggle screen recorder panel"
    onPressed: shell.recPanelRequested()
  }

  IpcHandler {
    target: "recording"
    function refresh(): void { Services.Recorder.refresh() }
    function panel(): void { shell.recPanelRequested() }
    function toggle(): void { shell.recPanelRequested() }
  }

  // `qs ipc call media panel` / Super+Alt+R: the media / recorder popup on the focused screen's bar
  // (BarHost.requestPanel). Signals, not counters: a bar created later (display plug) replayed a counter.
  signal mediaPanelRequested()
  signal recPanelRequested()
  IpcHandler {
    target: "media"
    function panel(): void { shell.mediaPanelRequested() }
  }

  IpcHandler {
    target: "calendar"
    function toggle(): void {
      shell.calendarOpen = !shell.calendarOpen
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      anchors.top: true
      anchors.left: true
      anchors.right: true
      implicitHeight: barContent.notchFloor
      exclusiveZone: barContent.notchFloor
      color: barContent.barBackground
      surfaceFormat.opaque: true

      WlrLayershell.namespace: "asahi-bar"
      WlrLayershell.layer: WlrLayer.Top

      BarHost {
        id: barContent
        anchors.fill: parent
        barScreen: modelData
        notificationCenter: notifCenter
        calendarOpen: shell.calendarOpen
        launcherOpen: shell.launcherOpen
        onCalendarToggle: shell.calendarOpen = !shell.calendarOpen
        onQuickRequested: key => {
          if (key === "updates") { pkgManager.toggle(2); return }
          const l = launcherLoader.item
          if (l && l.openQuick) l.openQuick(key)
        }
        Connections {
          target: shell
          function onMediaPanelRequested() { barContent.requestPanel("media") }
          function onRecPanelRequested() { barContent.requestPanel("rec") }
        }
      }
    }
  }

  Loader {
    id: launcherLoader
    source: "modules/launcher/LauncherWindow.qml"
    active: true
    onLoaded: item.osd = osd
  }

  IpcHandler {
    target: "launcher"
    function toggle() {
      const l = launcherLoader.item
      if (!l) return
      if (l.shouldShow) {
        if (l.closeLauncher) l.closeLauncher()
        else l.shouldShow = false
      } else {
        if (l.openLauncher) l.openLauncher()
        else l.shouldShow = true
      }
    }
    function files(query: string) {
      const l = launcherLoader.item
      if (l && l.openFileSearch) l.openFileSearch(query || "")
    }
    function openCategory(cat: string) {
      const l = launcherLoader.item
      if (!l) return
      if (l.openCategory) l.openCategory(cat || "")
      else if (l.openLauncher) l.openLauncher()
    }
    function quick(key: string) {
      const l = launcherLoader.item
      if (!l) return
      if (l.openQuick) l.openQuick(key || "hub")
    }
  }

  WallpaperManager {}
  Writing.WritingTools {}
}
