import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../../"

Scope {
  id: root

  property bool visible: false
  property var osdScreen: null
  property string icon: ""
  property string label: ""
  property string value: ""
  property real percent: 0
  property color accent: Style.blueAlt
  property string pending: ""

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  function focusedScreen() {
    const mon = Hyprland.focusedMonitor
    return mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
  }

  function show(kind, nextIcon, nextLabel, nextPercent, nextValue) {
    osdScreen = focusedScreen()
    icon = nextIcon
    label = nextLabel
    percent = Math.max(0, Math.min(100, Number(nextPercent) || 0))
    value = nextValue
    accent = kind === "volume" ? Style.green : (kind === "brightness" ? Style.orange : Style.blueAlt)
    visible = true
    hideTimer.restart()
  }

  function query(kind, command) {
    pending = kind
    osdProc.command = command
    osdProc.running = true
  }

  Timer {
    id: hideTimer
    interval: 1100
    onTriggered: root.visible = false
  }

  Process {
    id: osdProc
    stdout: StdioCollector {
      onStreamFinished: {
        const t = text.trim()
        if (root.pending === "volume" || root.pending === "mic") {
          let data = {}
          try {
            data = JSON.parse(t)
          } catch (_) {
            return
          }
          const muted = (data.class || []).includes("muted")
          const pct = data.percentage || 0
          if (root.pending === "volume") {
            root.show("volume", muted ? "󰖁" : "󰕾", "Volume", pct, muted ? "Muted" : pct + "%")
          } else {
            root.show("volume", muted ? "󰍭" : "󰍬", "Microphone", pct, muted ? "Muted" : pct + "%")
          }
        } else if (root.pending === "brightness") {
          root.show("brightness", "󰃠", "Brightness", Number(t) || 0, t + "%")
        } else if (root.pending === "keyboard") {
          root.show("brightness", "󰌌", "Keyboard", Number(t) || 0, t + "%")
        } else if (root.pending === "caps") {
          const on = t === "true"
          root.show("caps", on ? "󰪛" : "󰪚", "Caps Lock", on ? 100 : 0, on ? "On" : "Off")
        }
      }
    }
  }

  IpcHandler {
    target: "osd"
    function volume(): void { root.query("volume", ["bash", root.binDir + "/asahi-audio", "output"]) }
    function mic(): void { root.query("mic", ["bash", root.binDir + "/asahi-audio", "input"]) }
    function brightness(): void {
      root.query("brightness", ["bash", "-c", "brightnessctl -m | awk -F, '{gsub(/%/, \"\", $4); print $4}'"])
    }
    function keyboard(): void {
      root.query("keyboard", [
        "bash",
        "-c",
        "brightnessctl --device=kbd_backlight -m | awk -F, '{gsub(/%/, \"\", $4); print $4}'"
      ])
    }
    function caps(): void {
      root.query("caps", [
        "bash",
        "-c",
        "hyprctl devices -j | jq -r '[.keyboards[] | select(.main == true) | .capsLock][0] // [.keyboards[] | .capsLock][0] // false'"
      ])
    }
  }

  PanelWindow {
    id: osdWindow
    visible: root.visible
    focusable: false
    color: "transparent"
    screen: root.osdScreen
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    anchors { bottom: true }
    margins { bottom: 90 }
    implicitWidth: 320
    implicitHeight: 76

    Rectangle {
      anchors.fill: parent
      radius: 8
      color: Style.surface
      border.color: root.accent
      border.width: 1
      opacity: root.visible ? 1 : 0

      Behavior on opacity { NumberAnimation { duration: 120 } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Text {
          text: root.icon
          font.family: Style.fontFamily
          font.pixelSize: 28
          color: root.accent
          Layout.preferredWidth: 34
          horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 7

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: root.label
              font.family: Style.fontFamily
              font.pixelSize: 13
              font.bold: true
              color: Style.text
              Layout.fillWidth: true
            }
            Text {
              text: root.value
              font.family: Style.fontFamily
              font.pixelSize: 12
              color: Style.textMuted
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: Style.moduleBg
            clip: true

            Rectangle {
              width: parent.width * root.percent / 100
              height: parent.height
              radius: 4
              color: root.accent
              Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            }
          }
        }
      }
    }
  }
}
