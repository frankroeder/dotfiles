import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"

RowLayout {
  id: root

  property var notificationCenter: null
  property bool isRecording: false
  property bool updatesAvailable: false
  property bool stayAwake: false
  property bool nightLightOn: false
  property int nightLightTemp: 6500
  property var barHost: null
  readonly property bool solidBar: barHost !== null && barHost !== undefined

  readonly property string stayAwakePath: Quickshell.env("HOME") + "/.local/state/asahi/stay-awake"
  readonly property string nightLightStatePath: Quickshell.env("HOME") + "/.local/state/asahi/nightlight.json"
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"

  spacing: solidBar ? 2 : 6

  function refreshStayAwake() {
    if (!stayAwakeProc.running) stayAwakeProc.running = true
  }

  function refreshNightLight() {
    if (!nightLightProc.running) nightLightProc.running = true
  }

  function toggleNightLight() {
    Quickshell.execDetached(["bash", binDir + "/asahi-nightlight", "toggle"])
    nightLightRefresh.restart()
  }

  function toggleStayAwake() {
    if (root.stayAwake)
      Quickshell.execDetached(["rm", "-f", root.stayAwakePath])
    else
      Quickshell.execDetached(["bash", "-lc", "mkdir -p \"$HOME/.local/state/asahi\" && touch \"$HOME/.local/state/asahi/stay-awake\""])
    stayAwakeRefresh.restart()
  }

  Process {
    id: nightLightProc
    command: ["bash", root.binDir + "/asahi-nightlight", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text.trim())
          root.nightLightOn = !!data.on
          root.nightLightTemp = data.temperature || 6500
        } catch (e) {
          root.nightLightOn = false
        }
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshNightLight()
  }

  Timer {
    id: nightLightRefresh
    interval: 400
    onTriggered: root.refreshNightLight()
  }

  Process {
    id: stayAwakeProc
    command: ["test", "-e", root.stayAwakePath]
    onExited: code => { root.stayAwake = (code === 0) }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshStayAwake()
  }

  Timer {
    id: stayAwakeRefresh
    interval: 250
    onTriggered: root.refreshStayAwake()
  }

  SystemTray {}

  Rectangle {
    id: stayAwakeChip
    width: solidBar ? stayAwakeGlyph.implicitWidth + 10 : 30
    height: solidBar ? Style.barHeight : 30
    radius: solidBar ? 0 : Style.radius
    color: solidBar
      ? (stayAwakeMouse.containsMouse ? Style.barStripHover : "transparent")
      : (stayAwakeMouse.containsMouse ? Style.panelWarningBg : Style.barBg)
    border.width: solidBar ? 0 : 1
    border.color: root.stayAwake ? Style.yellow : (stayAwakeMouse.containsMouse ? Style.barHoverBorder : Style.barBorder)
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    Text {
      id: stayAwakeGlyph
      anchors.centerIn: parent
      text: "󰅶"
      font.family: Style.fontFamily
      font.pixelSize: solidBar ? Style.barFontIcon : 15
      color: root.stayAwake ? Style.yellow : (solidBar && barHost ? barHost.barForeground : Style.textMuted)
    }

    MouseArea {
      id: stayAwakeMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggleStayAwake()
    }

    TooltipWindow { target: stayAwakeChip; text: root.stayAwake ? "Stay awake (idle lock off)" : "Allow idle lock"; show: stayAwakeMouse.containsMouse }
  }

  Rectangle {
    id: nightChip
    width: solidBar ? 28 : 26
    height: solidBar ? Style.barHeight : 26
    radius: solidBar ? 0 : Style.radius
    color: solidBar
      ? (nightMouse.containsMouse ? Style.barStripHover : "transparent")
      : (nightMouse.containsMouse ? Style.panelWarningBg : Style.barBg)
    border.width: solidBar ? 0 : 1
    border.color: root.nightLightOn ? Style.orange : (solidBar ? "transparent" : Style.barBorder)
    visible: true

    Text {
      anchors.centerIn: parent
      text: root.nightLightOn ? "󰽥" : "󰖔"
      font.family: Style.fontFamily
      font.pixelSize: solidBar ? Style.barFontIcon : 15
      color: root.nightLightOn ? Style.orange : (solidBar && barHost ? barHost.barForeground : Style.textMuted)
    }

    MouseArea {
      id: nightMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggleNightLight()
    }

    TooltipWindow {
      target: nightChip
      text: root.nightLightOn ? ("Night light " + root.nightLightTemp + "K") : "Night light off"
      show: nightMouse.containsMouse
    }
  }

  Rectangle {
    id: recChip
    width: recRow.implicitWidth + (solidBar ? 8 : 12)
    height: solidBar ? Style.barHeight : 26
    radius: solidBar ? 0 : Style.radius
    color: solidBar
      ? (recMouse.containsMouse ? Style.barStripHover : "transparent")
      : (recMouse.containsMouse ? Style.panelDangerBg : Style.barBg)
    border.width: solidBar ? 0 : 1
    border.color: solidBar ? "transparent" : (recMouse.containsMouse ? Style.red : Style.barBorder)
    visible: root.isRecording
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    RowLayout {
      id: recRow
      anchors.centerIn: parent
      spacing: 5
      Text { text: "󰑋"; font.family: Style.fontFamily; font.pixelSize: 12; color: Style.red }
      Text { text: "REC"; font.family: Style.fontFamily; font.pixelSize: 10; font.bold: true; color: Style.red }
    }

    MouseArea {
      id: recMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: Quickshell.execDetached([root.binDir + "/asahi-cmd-record", "stop"])
    }
    TooltipWindow { target: recChip; text: "Recording — click to stop"; show: recMouse.containsMouse }
  }

  Rectangle {
    id: updateChip
    width: solidBar ? 28 : 26
    height: solidBar ? Style.barHeight : 26
    radius: solidBar ? 0 : Style.radius
    color: solidBar
      ? (updateMouse.containsMouse ? Style.barStripHover : "transparent")
      : (updateMouse.containsMouse ? Style.panelWarningBg : Style.barBg)
    border.width: solidBar ? 0 : 1
    border.color: solidBar ? "transparent" : (updateMouse.containsMouse ? Style.orange : Style.barBorder)
    visible: root.updatesAvailable
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    Text {
      anchors.centerIn: parent
      text: "󰚰"
      font.family: Style.fontFamily
      font.pixelSize: solidBar ? Style.barFontIcon : 15
      color: Style.orange
    }

    MouseArea { id: updateMouse; anchors.fill: parent; hoverEnabled: true }
    TooltipWindow { target: updateChip; text: "Package updates available"; show: updateMouse.containsMouse }
  }

  Rectangle {
    width: notifRow.implicitWidth + (solidBar ? 8 : 12)
    height: solidBar ? Style.barHeight : 26
    radius: solidBar ? 0 : Style.radius
    border.width: solidBar ? 0 : 1
    border.color: solidBar ? "transparent" : Style.barBorder
    scale: solidBar ? 1.0 : (notifMouse.containsMouse ? 1.018 : 1.0)
    color: solidBar
      ? (notifMouse.containsMouse ? Style.barStripHover : "transparent")
      : (notifMouse.containsMouse ? Style.barHoverBg : Style.barBg)
    visible: root.notificationCenter !== null

    RowLayout {
      id: notifRow
      anchors.centerIn: parent
      spacing: 5

      Text {
        text: root.notificationCenter && root.notificationCenter.dndEnabled ? "󰂛" : "󰂚"
        font.family: Style.fontFamily
        font.pixelSize: solidBar ? Style.barFontIcon : 15
        color: root.notificationCenter && root.notificationCenter.dndEnabled ? Style.yellow : Style.blueAlt
      }

      Text {
        text: root.notificationCenter ? root.notificationCenter.historyCount : 0
        font.family: Style.fontFamily
        font.pixelSize: 11
        color: Style.textMuted
        visible: root.notificationCenter && root.notificationCenter.historyCount > 0
      }
    }

    MouseArea {
      id: notifMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onClicked: (mouse) => {
        if (!root.notificationCenter) return
        if (mouse.button === Qt.RightButton) root.notificationCenter.toggleDnd()
        else root.notificationCenter.toggleHistory()
      }
    }
  }
}
