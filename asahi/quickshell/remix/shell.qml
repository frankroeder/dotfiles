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

  System.Osd { id: osd }
  System.NotificationCenter { id: notificationCenter }

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
      }
    }
  }

  Loader {
    id: launcherLoader
    source: "modules/launcher/LauncherWindow.qml"
    active: true
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
