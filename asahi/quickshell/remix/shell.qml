import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick

import "modules/bar"
import "modules/system" as System
import "modules/wallpaper"
import "services" as Services
import "."

ShellRoot {
  id: shell

  readonly property bool isRecording: Services.Recorder.running
  property bool calendarOpen: false
  // Launcher is the topmost layer: bar popups close so none float over it or hold Esc.
  readonly property bool launcherOpen: launcherLoader.item ? launcherLoader.item.shouldShow : false
  onLauncherOpenChanged: if (launcherOpen) {
    shell.calendarOpen = false
    Services.Recorder.panelOpen = false
  }

  System.Osd { id: osd }
  System.DimOverlay { id: dimOverlay }
  System.NotificationCenter { id: notificationCenter }
  System.PkgManager {}

  // Bound in hypr/conf.d/bindings.lua as hl.dsp.global("quickshell:recorder-panel").
  GlobalShortcut {
    appid: "quickshell"
    name: "recorder-panel"
    description: "Toggle screen recorder panel"
    onPressed: Services.Recorder.panelOpen = !Services.Recorder.panelOpen
  }

  IpcHandler {
    target: "recording"
    function refresh(): void { Services.Recorder.refresh() }
    function panel(): void { Services.Recorder.panelOpen = !Services.Recorder.panelOpen }
    function toggle(): void { Services.Recorder.panelOpen = !Services.Recorder.panelOpen }
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
      implicitHeight: Math.max(44, barContent.notchFloor)
      exclusiveZone: Math.max(44, barContent.notchFloor)
      color: barContent.barBackground
      surfaceFormat.opaque: true

      WlrLayershell.namespace: "asahi-bar"
      WlrLayershell.layer: WlrLayer.Top

      BarHost {
        id: barContent
        anchors.fill: parent
        barScreen: modelData
        notificationCenter: notificationCenter
        isRecording: shell.isRecording
        calendarOpen: shell.calendarOpen
        launcherOpen: shell.launcherOpen
        onCalendarToggle: shell.calendarOpen = !shell.calendarOpen
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
}
