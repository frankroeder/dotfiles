import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick

import "modules/bar"
import "modules/system" as System
import "modules/wallpaper"
import "."

ShellRoot {
  id: shell

  property bool isRecording: false

  System.Osd { id: osd }
  System.DimOverlay { id: dimOverlay }
  System.NotificationCenter { id: notificationCenter }

  Process {
    id: recProbe
    command: ["pgrep", "-x", "wf-recorder"]
    onExited: function(code) { shell.isRecording = (code === 0) }
  }
  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!recProbe.running) recProbe.running = true
  }
  IpcHandler {
    target: "recording"
    function refresh(): void {
      if (!recProbe.running) recProbe.running = true
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
