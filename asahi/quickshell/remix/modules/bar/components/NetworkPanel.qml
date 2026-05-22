import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Inline Network Panel (for future popupHost inside a proper Bar)
// Same UI as the PopupWindow version

FocusScope {
  id: root

  property bool shouldShow: false
  signal closeRequested()

  implicitWidth: 340
  implicitHeight: contentColumn.implicitHeight + 24

  readonly property color cSurface: "#1e1e2e"
  readonly property color cBorder: "#45475a"
  readonly property color cText: "#cdd6f4"
  readonly property color cSub: "#a6adc8"
  readonly property color cPrimary: "#89b4fa"

  property string currentText: ""
  property string currentTooltip: ""
  property var networks: []

  // Enhanced (synced with Popup)
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
            list.push({ ssid, signal, security, active: inUse })
            if (inUse) currentSsid = ssid
          }
        }
        // put the connected network first so the highlight is obvious
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
    command: ["bash", "/home/froeder/.dotfiles/asahi/bin/asahi-waybar-network"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(text.trim())
          root.currentText = d.text || ""
          root.currentTooltip = d.tooltip || ""
        } catch (e) {}
      }
    }
  }

  Process {
    id: powerCheckProc
    command: ["nmcli", "radio", "wifi"]
    stdout: StdioCollector { onStreamFinished: { root.isEnabled = text.trim().indexOf("enabled") !== -1 } }
  }

  Process {
    id: savedCheckProc
    property string targetSsid: ""
    stdout: StdioCollector {
      onStreamFinished: {
        const saved = text.trim() === "saved"
        if (saved) doConnect(savedCheckProc.targetSsid, null)
        else { root.pendingSsid = savedCheckProc.targetSsid; root.showPasswordPrompt = true }
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
    if (pass && pass.length) args = args.concat(["password", pass])
    Quickshell.execDetached(args)
    showPasswordPrompt = false
    closeRequested()
  }

  Timer { id: delayedRefresh; interval: 700; repeat: false; onTriggered: refresh() }
  Timer { interval: 15000; running: root.shouldShow || true; repeat: true; onTriggered: refresh() }

  Component.onCompleted: refresh()

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: cSurface
    border.color: cBorder
    border.width: 1

    ColumnLayout {
      id: contentColumn
      anchors.fill: parent
      anchors.margins: 14
      spacing: 10

      // Header + switch
      RowLayout {
        Layout.fillWidth: true
        Text { text: "󰖩"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: cPrimary }
        Text { text: "Network"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; font.bold: true; color: cText }
        Text {
          text: isEnabled ? (currentSsid || (currentTooltip ? currentTooltip.split("\n")[0] : "Ready") || "Ready") : "Disabled"
          color: isEnabled ? cPrimary : cSub; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; Layout.fillWidth: true; elide: Text.ElideRight
        }
        Item { Layout.fillWidth: true }
        MouseArea { width:22; height:22; cursorShape: Qt.PointingHandCursor; onClicked: refresh()
          Text { anchors.centerIn:parent; text:"󰑐"; font.family:"JetBrainsMono Nerd Font"; font.pixelSize:12; color:cSub }
        }
        Rectangle {
          width: 36; height: 18; radius: 9
          color: isEnabled ? cPrimary : Qt.rgba(1,1,1,0.12)
          Behavior on color { ColorAnimation { duration: 150 } }
          Rectangle {
            width: 12; height: 12; radius: 6; color: "#1e1e2e"
            anchors.verticalCenter: parent.verticalCenter
            x: isEnabled ? 20 : 4
            Behavior on x { NumberAnimation { duration: 160 } }
          }
          MouseArea { anchors.fill:parent; cursorShape: Qt.PointingHandCursor; onClicked: togglePower() }
        }
      }

      Rectangle {
        Layout.fillWidth: true; radius: 6; color: Qt.rgba(0,0,0,0.2); border.color: cBorder; border.width: 1
        Text {
          anchors.centerIn: parent; anchors.margins: 7
          text: currentTooltip || "No connection info"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: cText
          wrapMode: Text.Wrap; width: parent.width - 18
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.5 }

      RowLayout {
        Layout.fillWidth: true
        Text { text: "Available networks"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.bold: true; color: cSub }
        Text { visible: isScanning; text: "(scan)"; font.pixelSize: 9; color: cSub }
      }

      ColumnLayout {
        Layout.fillWidth: true; spacing: 2
        Repeater {
          model: root.networks
          delegate: Rectangle {
            Layout.fillWidth: true; height: 28; radius: 4
            color: modelData.active ? Qt.rgba(0.25,0.55,0.35,0.25) : (netMa.containsMouse ? Qt.rgba(1,1,1,0.05) : "transparent")
            RowLayout {
              anchors.fill: parent; anchors.leftMargin: 5; anchors.rightMargin: 5; spacing: 6
              Text {
                text: modelData.signal > 75 ? "󰤨" : (modelData.signal > 50 ? "󰤥" : (modelData.signal > 25 ? "󰤢" : "󰤟"))
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: modelData.active ? cPrimary : cSub
              }
              ColumnLayout {
                spacing: -1; Layout.fillWidth: true
                Text { text: modelData.ssid; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: modelData.active ? cPrimary : cText; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: modelData.active ? "Connected" : (modelData.security ? "Secure" : "Open"); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 8; color: cSub }
              }
              Text { text: modelData.security ? "󰌾" : ""; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.2) }
              Text { text: modelData.signal+"%"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: cSub }
              MouseArea {
                visible: modelData.active; width:16; height:16
                onClicked: { Quickshell.execDetached(["nmcli","con","down","id",modelData.ssid]); refresh() }
                Text { anchors.centerIn:parent; text:"󰅙"; font.family:"JetBrainsMono Nerd Font"; font.pixelSize:13; color:"#f38ba8" }
              }
            }
            MouseArea {
              id: netMa; anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; z:-1
              onClicked: {
                if (modelData.active) {
                  Quickshell.execDetached(["nmcli", "con", "down", "id", modelData.ssid])
                  refresh()
                  return
                }
                if (!modelData.security) { doConnect(modelData.ssid, null) }
                else {
                  savedCheckProc.targetSsid = modelData.ssid
                  savedCheckProc.command = ["bash","-c","nmcli -g NAME connection show | grep -Fx '"+modelData.ssid.replace(/'/g,"'\\''")+"' >/dev/null && echo saved || echo new"]
                  savedCheckProc.running = true
                }
              }
            }
          }
        }
        Text {
          visible: networks.length===0
          text: isScanning ? "Scanning..." : "No networks"
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: cSub; Layout.alignment: Qt.AlignHCenter
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: cBorder; opacity: 0.5 }

      MouseArea {
        Layout.fillWidth: true; height: 22; cursorShape: Qt.PointingHandCursor
        onClicked: { closeRequested(); Quickshell.execDetached(["/home/froeder/.dotfiles/asahi/bin/asahi-network-menu"]) }
        Text { anchors.centerIn:parent; text: "Advanced Network Menu →"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: cPrimary }
      }
    }

    // Prompt overlay (embedded safe)
    Rectangle {
      anchors.fill: parent; radius: 12; color: Qt.rgba(0,0,0,0.78); visible: showPasswordPrompt; z: 10
      ColumnLayout {
        anchors.centerIn: parent; width: parent.width-30; spacing: 8
        Text { text: "Connect to "+pendingSsid; color: cText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold:true; Layout.alignment: Qt.AlignHCenter }
        Rectangle {
          Layout.fillWidth: true; height: 30; radius: 5; color: Qt.rgba(1,1,1,0.05); border.color: cBorder
          TextInput {
            id: passInput; anchors.fill:parent; anchors.margins:6; color: cText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; echoMode: TextInput.Password; verticalAlignment: TextInput.AlignVCenter
            onAccepted: doConnect(pendingSsid, text)
          }
        }
        RowLayout {
          Layout.fillWidth: true; spacing: 6
          Rectangle { Layout.fillWidth:true; height:26; radius:5; color: Qt.rgba(1,1,1,0.1)
            MouseArea { anchors.fill:parent; onClicked: showPasswordPrompt=false
              Text { anchors.centerIn:parent; text:"Cancel"; font.family:"JetBrainsMono Nerd Font"; font.pixelSize:10; color:cText }
            }
          }
          Rectangle { Layout.fillWidth:true; height:26; radius:5; color: cPrimary
            MouseArea { anchors.fill:parent; onClicked: doConnect(pendingSsid, passInput.text)
              Text { anchors.centerIn:parent; text:"Connect"; font.family:"JetBrainsMono Nerd Font"; font.pixelSize:10; font.bold:true; color:"#1e1e2e" }
            }
          }
        }
      }
    }
  }
}
