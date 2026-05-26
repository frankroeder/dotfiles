import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../../"

PanelWindow {
  id: root
  property bool shouldShow: false
  visible: shouldShow
  color: "transparent"
  anchors {
    top: true
    right: true
  }
  margins {
    top: 38
    right: 12
  }
  implicitWidth: 340
  implicitHeight: contentColumn.implicitHeight + 24
  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  property string currentText: ""
  property string currentTooltip: ""
  property var networks: []
  property bool isEnabled: true
  property string currentSsid: ""
  property bool isScanning: false
  property bool showPasswordPrompt: false
  property string pendingSsid: ""

  Process {
    id: scanProc
    command: ["bash", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto 2>/dev/null | head -12"]
    stdout: StdioCollector {
      onStreamFinished: {
        isScanning = false
        const lines = text.trim().split("\n").filter(l => l.length > 0)
        const list = []
        const seen = {}
        for (const line of lines) {
          const parts = line.split(":")
          if (parts.length >= 3) {
            const inUse = parts[0] === "*"
            const ssid = parts[1] || ""
            if (!ssid || seen[ssid]) continue
            seen[ssid] = true
            const signal = parseInt(parts[2]) || 0
            const security = parts[3] || ""
            // mark active if IN-USE or if it matches the currentSsid we already learned from status (before/during list creation)
            const isCurrent = inUse || (ssid === currentSsid)
            list.push({ ssid, signal, security, active: isCurrent })
            if (isCurrent) currentSsid = ssid
          }
        }
        const ai = list.findIndex(n => n.active)
        if (ai > 0) {
          const a = list.splice(ai, 1)[0]
          list.unshift(a)
        }
        root.networks = list
      }
    }
  }
  Process {
    id: statusProc
    command: ["bash", binDir + "/asahi-network"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(text.trim())
          root.currentText = d.text || ""
          root.currentTooltip = d.tooltip || ""
          // reliably determine the current connected SSID from the authoritative status script
          const m = (d.tooltip || "").match(/^Connected to (.+)$/m)
          if (m) root.currentSsid = m[1].trim()
        } catch (e) {}
      }
    }
  }
  Process {
    id: powerCheckProc
    command: ["nmcli", "radio", "wifi"]
    stdout: StdioCollector {
      onStreamFinished: { root.isEnabled = text.trim().indexOf("enabled") !== -1 }
    }
  }
  Process {
    id: savedCheckProc
    property string targetSsid: ""
    stdout: StdioCollector {
      onStreamFinished: {
        const saved = text.trim() === "saved"
        if (saved) {
          doConnect(savedCheckProc.targetSsid, null)
        } else {
          root.pendingSsid = savedCheckProc.targetSsid
          root.showPasswordPrompt = true
        }
      }
    }
  }
  function refresh() {
    statusProc.running = true
    powerCheckProc.running = true
    isScanning = true
    scanProc.running = true
  }
  function togglePower() {
    const tgt = isEnabled ? "off" : "on"
    Quickshell.execDetached(["nmcli", "radio", "wifi", tgt])
    isEnabled = !isEnabled
    delayedRefresh.start()
  }
  function doConnect(ssid, pass) {
    let args = ["nmcli", "dev", "wifi", "connect", ssid]
    if (pass && pass.length > 0) args = args.concat(["password", pass])
    Quickshell.execDetached(args)
    showPasswordPrompt = false
    shouldShow = false
  }
  Timer {
    id: delayedRefresh
    interval: 700
    repeat: false
    onTriggered: refresh()
  }
  Timer {
    interval: 15000
    running: shouldShow
    repeat: true
    onTriggered: refresh()
  }
  Component.onCompleted: refresh()

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: Style.surface
    border.color: Style.border
    border.width: 1
    ColumnLayout {
      id: contentColumn
      anchors.fill: parent
      anchors.margins: 14
      spacing: 10
      RowLayout {
        Layout.fillWidth: true
        Text { text: "󰖩"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: Style.blueAlt }
        Text { text: "Wi-Fi"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true; color: Style.text }
        Text {
          text: isEnabled ? (currentSsid || (currentTooltip ? currentTooltip.split("\n")[0] : "Ready") || "Ready") : "Disabled"
          color: isEnabled ? Style.blueAlt : Style.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; Layout.fillWidth: true; elide: Text.ElideRight
        }
        Item { Layout.fillWidth: true }
        MouseArea { width:24; height:24; cursorShape: Qt.PointingHandCursor; onClicked: refresh()
          Text { anchors.centerIn:parent; text:"󰑐"; font.family:"JetBrainsMono Nerd Font"; font.pixelSize:13; color:Style.textMuted }
        }
        Rectangle {
          width: 38; height: 20; radius: 10
          color: isEnabled ? Style.blueAlt : Qt.rgba(Style.surface.r, Style.surface.g, Style.surface.b, 0.35)  // dark Mocha overlay (was bright white tint)
          Behavior on color { ColorAnimation { duration: 150 } }
          Rectangle {
            width: 14; height: 14; radius: 7; color: Style.surface
            anchors.verticalCenter: parent.verticalCenter
            x: isEnabled ? 20 : 4
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
          }
          MouseArea { anchors.fill:parent; cursorShape: Qt.PointingHandCursor; onClicked: togglePower() }
        }
      }
      Rectangle {
        Layout.fillWidth: true; radius: 6; color: Qt.rgba(0,0,0,0.2); border.color: Style.border; border.width: 1
        implicitHeight: infoText.height + 14
        Text {
          id: infoText; anchors.centerIn: parent; anchors.margins: 8
          text: currentTooltip || "No connection"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: Style.text
          wrapMode: Text.Wrap; width: parent.width - 18
        }
      }
      Rectangle { Layout.fillWidth: true; height: 1; color: Style.border; opacity: 0.5 }
      RowLayout {
        Layout.fillWidth: true
        Text { text: "Available networks"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.bold: true; color: Style.textMuted }
        Text { visible: isScanning; text: " (scanning...)"; font.pixelSize: 10; color: Style.textMuted }
      }
      ColumnLayout {
        Layout.fillWidth: true; spacing: 2
        Repeater {
          model: root.networks
          delegate: Rectangle {
            Layout.fillWidth: true; height: 30; radius: 5
            // ── highlighted connected network (moved to top + stronger tint + border + bold SSID + primary "Connected") ──
            color: modelData.active
                   ? Qt.rgba(Style.blue.r, Style.blue.g, Style.blue.b, 0.22)
                   : (netMa.containsMouse ? Qt.rgba(Style.surface.r, Style.surface.g, Style.surface.b, 0.25) : "transparent")
            border.color: modelData.active ? Style.blueAlt : "transparent"
            border.width: modelData.active ? 1.5 : 0
            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 8
              Text {
                text: modelData.signal > 75 ? "󰤨" : (modelData.signal > 50 ? "󰤥" : (modelData.signal > 25 ? "󰤢" : "󰤟"))
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15
                color: modelData.active ? Style.blueAlt : Style.textMuted
              }
              ColumnLayout {
                spacing: -1; Layout.fillWidth: true
                Text {
                  text: modelData.ssid;
                  font.family: "JetBrainsMono Nerd Font";
                  font.pixelSize: 11;
                  font.bold: modelData.active
                  color: modelData.active ? Style.blueAlt : Style.text;
                  elide: Text.ElideRight;
                  Layout.fillWidth: true
                }
                Text {
                  text: modelData.active ? "Connected" : (modelData.security ? "Secure" : "Open")
                  font.family: "JetBrainsMono Nerd Font";
                  font.pixelSize: 9;
                  color: modelData.active ? Style.blueAlt : Style.textMuted
                }
              }
              Text { text: modelData.security ? "󰌾" : ""; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Style.textMuted }
              Text { text: modelData.signal + "%"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: Style.textMuted }
              MouseArea {
                visible: modelData.active; width: 18; height: 18
                onClicked: { Quickshell.execDetached(["nmcli", "con", "down", "id", modelData.ssid]); refresh() }
                Text { anchors.centerIn: parent; text: "󰅙"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Style.red }
              }
            }
            MouseArea {
              id: netMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: -1
              onClicked: {
                if (modelData.active) {
                  Quickshell.execDetached(["nmcli", "con", "down", "id", modelData.ssid])
                  refresh()
                  return
                }
                const sec = modelData.security || ""
                if (!sec) {
                  doConnect(modelData.ssid, null)
                } else {
                  savedCheckProc.targetSsid = modelData.ssid
                  savedCheckProc.command = ["bash", "-c", "nmcli -g NAME connection show | grep -Fx '" + modelData.ssid.replace(/'/g, "'\\''") + "' >/dev/null && echo saved || echo new"]
                  savedCheckProc.running = true
                }
              }
            }
          }
        }
        Text {
          visible: networks.length === 0
          text: isScanning ? "Scanning for networks..." : "No networks found (refresh)"
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: Style.textMuted; Layout.alignment: Qt.AlignHCenter
        }
      }
      Rectangle { Layout.fillWidth: true; height: 1; color: Style.border; opacity: 0.5 }
      MouseArea {
        Layout.fillWidth: true; height: 24; cursorShape: Qt.PointingHandCursor
        onClicked: { shouldShow = false; Quickshell.execDetached([binDir + "/asahi-network-menu"]) }
        Text { anchors.centerIn: parent; text: "Advanced Network Menu →"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: Style.blueAlt }
      }
    }
    Rectangle {
      anchors.fill: parent; radius: 12; color: Qt.rgba(0,0,0,0.78); visible: showPasswordPrompt; z: 20
      ColumnLayout {
        anchors.centerIn: parent; width: parent.width - 36; spacing: 10
        Text { text: "Connect to network"; color: Style.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; Layout.alignment: Qt.AlignHCenter }
        Text { text: pendingSsid; color: Style.blueAlt; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter; elide: Text.ElideRight }
        Rectangle {
          Layout.fillWidth: true; height: 34; radius: 6; color: Qt.rgba(Style.surface.r, Style.surface.g, Style.surface.b, 0.2); border.color: Style.border; border.width: 1
          TextInput {
            id: passInput; anchors.fill: parent; anchors.margins: 8; color: Style.text; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; echoMode: TextInput.Password; verticalAlignment: TextInput.AlignVCenter
            onAccepted: doConnect(pendingSsid, text)
          }
        }
        RowLayout {
          Layout.fillWidth: true; spacing: 8
          Rectangle { Layout.fillWidth: true; height: 30; radius: 6; color: Qt.rgba(Style.surface.r, Style.surface.g, Style.surface.b, 0.3)
            MouseArea { anchors.fill:parent; onClicked: showPasswordPrompt=false
              Text { anchors.centerIn:parent; text:"Cancel"; font.family:"JetBrainsMono Nerd Font"; font.pixelSize:11; color:Style.text }
            }
          }
          Rectangle { Layout.fillWidth: true; height: 30; radius: 6; color: Style.blueAlt
            MouseArea { anchors.fill:parent; onClicked: doConnect(pendingSsid, passInput.text)
              Text { anchors.centerIn:parent; text:"Connect"; font.family:"JetBrainsMono Nerd Font"; font.pixelSize:11; font.bold:true; color: Style.bg }
            }
          }
        }
      }
    }
  }
}
