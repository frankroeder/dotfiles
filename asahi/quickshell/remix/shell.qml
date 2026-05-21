import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "modules/bar/components" as BarComponents

PanelWindow {
  id: root

  // Theme
  property color colBg: "#1a1b26"
  property color colFg: "#a9b1d6"
  property color colMuted: "#444b6a"
  property color colCyan: "#0db9d7"
  property color colBlue: "#7aa2f7"
  property color colYellow: "#e0af68"
  property string fontFamily: "JetBrainsMono Nerd Font"
  property int fontSize: 16   // bigger symbols / text overall


  property string cpuText: ""
  property string cpuTooltip: ""

  property string memText: ""
  property string memTooltip: ""

  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: 36   // thicker bar, closer to waybar with 16px font + padding
  color: root.colBg

  // CPU script (usage + temperature)
  Process {
    id: cpuScriptProc
    command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-cpu"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          root.cpuText = data.text || "CPU --%"
          root.cpuTooltip = data.tooltip || ""
        } catch (e) {}
      }
    }
    Component.onCompleted: running = true
  }

  // Memory script (usage + history bars like CPU)
  Process {
    id: memScriptProc
    command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-memory"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          root.memText = data.text || "Mem --%"
          root.memTooltip = data.tooltip || ""
        } catch (e) {}
      }
    }
    Component.onCompleted: running = true
  }

  // Update your timer to run both processes
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
      cpuProc.running = true
      memProc.running = true
      cpuScriptProc.running = true
      memScriptProc.running = true
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: 6
    spacing: 10

    // Workspaces
    Repeater {
      model: 9
      Text {
        property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
        property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
        text: index + 1
        color: isActive ? root.colCyan : (ws ? root.colBlue : root.colMuted)
        font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
        MouseArea {
          anchors.fill: parent
          onClicked: Hyprland.dispatch("workspace " + (index + 1))
        }
      }
    }

    Item { Layout.fillWidth: true }

    // New widgets from remix (inspired by tripathiji1312 style)
    BarComponents.Volume {}
    BarComponents.Brightness {}
    BarComponents.Microphone {}
    BarComponents.SystemTray {}

    Rectangle { width: 1; height: 16; color: root.colMuted }

    // CPU — fixed width so the graph bar never changes the pill size (matches waybar #custom-cpu behavior)
    Rectangle {
      color: "#313244"   // surface0
      radius: 4
      implicitWidth: 168
      implicitHeight: 24

      Text {
        id: cpuDisplay
        anchors.centerIn: parent
        text: root.cpuText || "CPU --%"
        color: root.colYellow
        font { family: root.fontFamily; pixelSize: 14; bold: true }
      }

      MouseArea {
        id: cpuMa
        anchors.fill: parent
        hoverEnabled: true
      }
    }

    Rectangle { width: 1; height: 16; color: root.colMuted }

    // Memory — fixed width pill like CPU
    Rectangle {
      color: "#313244"
      radius: 4
      implicitWidth: 160
      implicitHeight: 24

      Text {
        id: memDisplay
        anchors.centerIn: parent
        text: root.memText || "Mem --%"
        color: root.colCyan
        font { family: root.fontFamily; pixelSize: 14; bold: true }
      }

      MouseArea {
        id: memMa
        anchors.fill: parent
        hoverEnabled: true
      }
    }

    BarComponents.Network {}
    BarComponents.Bluetooth {}

    BarComponents.Battery {}

    // Rectangle { width: 2; height: 16; color: root.colBg }

    // Clock - improved via reference Clock.qml inspiration
    BarComponents.Clock {}
  }

  // Custom tooltips sized to full multi-line content (PopupWindow + paintedHeight)
  BarComponents.TooltipWindow {
    id: cpuTip
    target: cpuDisplay
    text: root.cpuTooltip
    show: cpuMa.containsMouse
    maxWidth: 380
  }

  BarComponents.TooltipWindow {
    id: memTip
    target: memDisplay
    text: root.memTooltip
    show: memMa.containsMouse
    maxWidth: 380
  }
}
