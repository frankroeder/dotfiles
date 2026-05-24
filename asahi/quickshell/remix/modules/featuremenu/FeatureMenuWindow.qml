import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import "../../"
import "../wallpaper" as WallpaperModule

pragma ComponentBehavior: Bound

Scope {
  id: root

  property bool shouldShow: false
  property var featureScreen: null
  property string mode: "hub"  // hub | wallpaper | screenshots | media | wifi | bluetooth | power
  property string pendingConfirm: ""

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  readonly property string shotDir: Quickshell.env("HOME") + "/screenshots"

  // Live wifi status for overview tile
  property string wifiLabel: "WiFi"
  Process {
    id: wifiProc
    command: [binDir + "/asahi-network"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const d = JSON.parse(text.trim())
          root.wifiLabel = (d.text || "WiFi").replace(/<[^>]*>/g, "")
        } catch (_) {}
      }
    }
  }
  Timer { interval: 7000; running: shouldShow; repeat: true; onTriggered: wifiProc.running = true }

  // Sidebar live telemetry data
  property int sidebarCpu: 0
  property int sidebarMem: 0
  property int sidebarBat: 100
  property string sidebarBatStatus: "Discharging"

  Process {
    id: sidebarProc
    command: [
      "sh", "-c",
      "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' ; " +
      "free | grep Mem | awk '{print $3/$2 * 100}' ; " +
      "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 100 ; " +
      "cat /sys/class/power_supply/BAT0/status 2>/dev/null || cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo 'Full'"
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const lines = text.trim().split("\n")
          if (lines.length >= 4) {
            root.sidebarCpu = Math.round(parseFloat(lines[0]) || 0)
            root.sidebarMem = Math.round(parseFloat(lines[1]) || 0)
            root.sidebarBat = Math.round(parseFloat(lines[2]) || 100)
            root.sidebarBatStatus = lines[3].trim()
          }
        } catch (_) {}
      }
    }
  }
  Timer {
    interval: 3000; running: shouldShow; repeat: true; triggeredOnStart: true
    onTriggered: sidebarProc.running = true
  }

  // Embedded wifi (native, no popup)
  property var wifiNetworks: []
  function scanWifi() {
    wifiListProc.running = true
  }
  Process {
    id: wifiListProc
    command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "auto"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n").filter(l => l)
        const out = []
        const seen = {}
        for (const line of lines) {
          const p = line.split(":")
          if (p.length < 3) continue
          const ssid = p[1] || ""
          if (!ssid || seen[ssid]) continue
          seen[ssid] = true
          out.push({ ssid, signal: parseInt(p[2])||0, sec: p[3]||"", active: p[0]==="*" })
        }
        root.wifiNetworks = out.slice(0, 12)
      }
    }
  }

  // Media mode state (players via Mpris, audio via wpctl, cava viz)
  property var cavaValues: []
  property bool cavaRunning: false

  // Active MPRIS player (playing preferred)
  readonly property var activePlayer: {
    const list = Mpris.players && Mpris.players.values ? Mpris.players.values : []
    for (let i = 0; i < list.length; i++) if (list[i] && list[i].isPlaying) return list[i]
    return list.length > 0 ? list[0] : null
  }
  function enterMedia() {
    startCavaIfNeeded()
    pollAudioDefaults()
  }
  function startCavaIfNeeded() {
    if (cavaRunning) return
    cavaRunning = true
    Quickshell.execDetached([
      "sh", "-c",
      "pkill -x cava 2>/dev/null; mkdir -p ~/.config/cava; " +
      "cat > ~/.config/cava/config << 'EOC'\n[general]\nbars=24\nframerate=30\nsensitivity=180\n[input]\nmethod=pulse\n[output]\nmethod=raw\nraw_target=/tmp/quickshell_cava\ndata_format=ascii\nascii_max_range=100\nEOC\n" +
      "rm -f /tmp/quickshell_cava; nohup cava -p ~/.config/cava/config > /dev/null 2>&1 & disown"
    ])
    cavaWatcher.path = ""
    Qt.callLater(function(){ cavaWatcher.path = "/tmp/quickshell_cava" })
  }
  function stopCava() {
    if (!cavaRunning) return
    cavaRunning = false
    Quickshell.execDetached(["pkill", "-x", "cava"])
  }
  FileView {
    id: cavaWatcher
    watchChanges: true
    onTextChanged: {
      const line = (text() || "").trim()
      if (!line) return
      const parts = line.split(";")
      const vals = []
      for (let i=0; i<parts.length && i<24; i++) {
        const v = parseInt(parts[i]) || 0
        vals.push(Math.max(0, Math.min(100, v)))
      }
      while (vals.length < 24) vals.push(0)
      root.cavaValues = vals
    }
  }

  // Simple default sink/source volume (wpctl based, like asahi-audio)
  property string defaultSinkVol: "—"
  property string defaultSourceVol: "—"
  function pollAudioDefaults() {
    audioPollProc.command = [
      "sh", "-c",
      "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2*100}' ; " +
      "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk '{print $2*100}'"
    ]
    audioPollProc.running = true
  }
  Process {
    id: audioPollProc
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n")
        root.defaultSinkVol = lines[0] ? (Math.round(parseFloat(lines[0])) + "%") : "—"
        root.defaultSourceVol = lines[1] ? (Math.round(parseFloat(lines[1])) + "%") : "—"
      }
    }
  }
  function volAdjust(target, delta) {
    Quickshell.execDetached(["wpctl", "set-volume", target, (delta > 0 ? "+" : "") + "5%"])
    Qt.callLater(pollAudioDefaults)
  }

  // Screenshots
  property var shots: []
  property string copiedShot: ""
  Timer { id: copyClear; interval: 1200; onTriggered: copiedShot = "" }

  function scanShots() {
    shotScan.command = ["sh", "-c", "find \"" + shotDir + "\" -maxdepth 1 -type f -name 'screenshot-*.png' 2>/dev/null | sort -r | head -16"]
    shotScan.running = true
  }
  Process {
    id: shotScan
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n").filter(l => l.length > 0)
        root.shots = lines.map(p => ({ path: p, label: p.split("/").pop().replace("screenshot-", "").replace(".png", "") }))
      }
    }
  }

  function copyShot(p) {
    if (!p) return
    copiedShot = p
    copyClear.restart()
    Quickshell.execDetached(["sh", "-c", "wl-copy < \"$1\" && notify-send -a screenshot -t 900 'Copied' \"$(basename \"$1\")\"", "sh", p])
  }
  function openShot(p) { if (p) Quickshell.execDetached(["xdg-open", p]) }
  function capture(kind) {
    Quickshell.execDetached([binDir + "/asahi-cmd-screenshot", kind || "smart"])
    Qt.callLater(function() { Qt.callLater(scanShots) })
  }

  // Wallpaper Picker search & preview properties
  property string wallpaperSearchText: ""
  property string wallpaperPreviewPath: ""
  property var filteredWallpapers: {
    const q = wallpaperSearchText.toLowerCase()
    if (q === "") return WallpaperModule.WallpaperService.wallpapers
    return WallpaperModule.WallpaperService.wallpapers.filter(p => {
      const name = p.split("/").pop().toLowerCase()
      return name.includes(q)
    })
  }

  function openFeature() {
    const mon = Hyprland.focusedMonitor
    featureScreen = mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
    shouldShow = true
    mode = "hub"
    pendingConfirm = ""
    wifiProc.running = true
    scanShots()
  }
  function closeFeature() {
    shouldShow = false
    mode = "hub"
    pendingConfirm = ""
    stopCava()
  }

  // Power actions
  function doLock() { Quickshell.execDetached(["loginctl", "lock-session"]); closeFeature() }
  function doSuspend() { Quickshell.execDetached(["sh", "-c", "loginctl lock-session && systemctl suspend"]); closeFeature() }
  function doReboot() {
    if (pendingConfirm === "reboot") { Quickshell.execDetached(["systemctl", "reboot"]); closeFeature() }
    else pendingConfirm = "reboot"
  }
  function doShutdown() {
    if (pendingConfirm === "shutdown") { Quickshell.execDetached(["systemctl", "poweroff"]); closeFeature() }
    else pendingConfirm = "shutdown"
  }
  function cancelConfirm() { pendingConfirm = "" }

  // Reload helpers
  function toggleScratch() { Quickshell.execDetached(["hyprctl", "dispatch", "togglespecialworkspace", "scratch"]); closeFeature() }
  function reloadBar() { Quickshell.execDetached([binDir + "/asahi-restart-app", "quickshell", "-c", "remix"]); closeFeature() }
  function reloadHyprland() { Quickshell.execDetached([binDir + "/asahi-reload-hyprland"]); closeFeature() }
  function restartHyprpaper() { Quickshell.execDetached([binDir + "/asahi-restart-app", "hyprpaper"]); closeFeature() }
  function restartHypridle() { Quickshell.execDetached([binDir + "/asahi-restart-app", "hypridle"]); closeFeature() }

  PanelWindow {
    id: panel
    visible: root.shouldShow
    focusable: true
    color: "transparent"
    screen: root.featureScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-feature"
    exclusionMode: ExclusionMode.Ignore

    anchors { top: true; bottom: true; left: true; right: true }

    // Backdrop overlay
    MouseArea {
      anchors.fill: parent
      onClicked: root.closeFeature()
      Rectangle { anchors.fill: parent; color: Style.bgOverlay || "#88000000" }
    }

    // Centered console box
    Rectangle {
      id: box
      anchors.centerIn: parent
      width: 920
      height: 600
      radius: 16
      color: Style.bgBase || Style.surface || "#1e1e2e"
      border.color: Style.bgBorder || Style.border || "#45475a"
      border.width: 1

      MouseArea { anchors.fill: parent; onClicked: event => event.accepted = true }

      Keys.onEscapePressed: {
        if (root.wallpaperPreviewPath !== "") {
          root.wallpaperPreviewPath = ""
        } else if (root.mode !== "hub") {
          root.mode = "hub"
          root.pendingConfirm = ""
        } else {
          root.closeFeature()
        }
      }
      focus: true

      RowLayout {
        anchors.fill: parent
        spacing: 0

        // LEFT NAVIGATION SIDEBAR
        Rectangle {
          id: sidebar
          Layout.preferredWidth: 220
          Layout.fillHeight: true
          color: Style.crust || "#11111b"
          topLeftRadius: 16
          bottomLeftRadius: 16

          // Right border divider
          Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Style.border || "#45475a"
          }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // User Profile slot
            RowLayout {
              spacing: 10
              Layout.fillWidth: true
              
              Rectangle {
                width: 38
                height: 38
                radius: 19
                color: Style.moduleBg || "#313244"
                Text {
                  anchors.centerIn: parent
                  text: ""
                  font.pixelSize: 20
                  color: Style.blue || "#89b4fa"
                }
              }
              Column {
                Text {
                  text: "froeder"
                  color: Style.text || "#cdd6f4"
                  font.pixelSize: 13
                  font.bold: true
                  font.family: "JetBrainsMono Nerd Font"
                }
                Text {
                  text: "@asahi"
                  color: Style.textMuted || "#a6adc8"
                  font.pixelSize: 10
                  font.family: "JetBrainsMono Nerd Font"
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Style.border || "#45475a"
              opacity: 0.4
            }

            // Navigation menu list
            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: 4

              Repeater {
                model: [
                  { key: "hub", icon: "󰕮", label: "Dashboard" },
                  { key: "wallpaper", icon: "󰸉", label: "Wallpapers" },
                  { key: "screenshots", icon: "󰹑", label: "Screenshots" },
                  { key: "media", icon: "󰝚", label: "Media & Sound" },
                  { key: "wifi", icon: "󰤨", label: "Wi-Fi" },
                  { key: "bluetooth", icon: "󰂯", label: "Bluetooth" },
                  { key: "power", icon: "󰐥", label: "Power" }
                ]
                delegate: Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  height: 34
                  radius: 8
                  color: root.mode === modelData.key ? (Style.moduleBg || "#313244") : (navMa.containsMouse ? (Style.hoverBg || "#45475a") : "transparent")
                  
                  Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    radius: 1.5
                    color: Style.blue || "#89b4fa"
                    visible: root.mode === modelData.key
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10
                    
                    Text {
                      text: modelData.icon
                      font.pixelSize: 14
                      color: root.mode === modelData.key ? (Style.blue || "#89b4fa") : (Style.textMuted || "#a6adc8")
                      font.family: "JetBrainsMono Nerd Font"
                      Layout.preferredWidth: 18
                      horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                      text: modelData.label
                      font.pixelSize: 11
                      font.bold: root.mode === modelData.key
                      color: root.mode === modelData.key ? (Style.text || "#cdd6f4") : (Style.textAlt || "#bac2de")
                      font.family: "JetBrainsMono Nerd Font"
                    }
                  }

                  MouseArea {
                    id: navMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.mode = modelData.key
                      root.pendingConfirm = ""
                      if (modelData.key === "screenshots") root.scanShots()
                      else if (modelData.key === "wifi") root.scanWifi()
                      else if (modelData.key === "media") root.enterMedia()
                    }
                  }
                }
              }
              Item { Layout.fillHeight: true }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Style.border || "#45475a"
              opacity: 0.4
            }

            // Quick stats telemetry in sidebar
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 8

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                  Text { text: "CPU Load"; font.pixelSize: 10; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
                  Item { Layout.fillWidth: true }
                  Text { text: root.sidebarCpu + "%"; font.pixelSize: 10; color: Style.orange || "#fab387"; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                }
                Rectangle {
                  Layout.fillWidth: true; height: 5; radius: 2.5; color: Style.moduleBg || "#313244"
                  Rectangle { width: parent.width * root.sidebarCpu / 100; height: parent.height; radius: 2.5; color: Style.orange || "#fab387" }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                  Text { text: "Memory"; font.pixelSize: 10; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
                  Item { Layout.fillWidth: true }
                  Text { text: root.sidebarMem + "%"; font.pixelSize: 10; color: Style.lavender || "#b4befe"; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                }
                Rectangle {
                  Layout.fillWidth: true; height: 5; radius: 2.5; color: Style.moduleBg || "#313244"
                  Rectangle { width: parent.width * root.sidebarMem / 100; height: parent.height; radius: 2.5; color: Style.lavender || "#b4befe" }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                  Text { text: "Battery"; font.pixelSize: 10; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
                  Item { Layout.fillWidth: true }
                  Text { text: root.sidebarBat + "%"; font.pixelSize: 10; color: Style.green || "#a6e3a1"; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                }
                Rectangle {
                  Layout.fillWidth: true; height: 5; radius: 2.5; color: Style.moduleBg || "#313244"
                  Rectangle { width: parent.width * root.sidebarBat / 100; height: parent.height; radius: 2.5; color: root.sidebarBatStatus === "Charging" ? Style.yellow : (root.sidebarBat < 20 ? Style.red : Style.green) }
                }
              }
            }
          }
        }

        // RIGHT MAIN CONTENT PANE
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Style.base || "#1e1e2e"
          topRightRadius: 16
          bottomRightRadius: 16

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header Row
            RowLayout {
              Layout.fillWidth: true
              
              Text {
                text: {
                  if (root.mode === "hub") return "󰕮  Dashboard"
                  if (root.mode === "wallpaper") return "󰸉  Wallpapers"
                  if (root.mode === "screenshots") return "󰹑  Screenshots Gallery"
                  if (root.mode === "media") return "󰝚  Media & Sound"
                  if (root.mode === "wifi") return "󰤨  Wi-Fi Networks"
                  if (root.mode === "bluetooth") return "󰂯  Bluetooth Devices"
                  if (root.mode === "power") return "󰐥  Power Actions"
                  return "Features"
                }
                color: Style.blue || "#89b4fa"
                font.pixelSize: 16
                font.family: "JetBrainsMono Nerd Font"
                font.bold: true
              }
              
              Item { Layout.fillWidth: true }

              Text {
                visible: root.mode === "screenshots" && root.shots.length
                text: root.shots.length + " recent"
                color: Style.textMuted
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
              }
              
              Rectangle {
                visible: root.mode !== "hub"
                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                color: "transparent"
                Text { anchors.centerIn: parent; text: "←"; color: Style.textMuted; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.mode = "hub"; root.pendingConfirm = "" } }
              }

              Rectangle {
                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                color: "transparent"
                Text { anchors.centerIn: parent; text: "󰅖"; color: Style.textMuted; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closeFeature() }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: Style.border || "#45475a"
              opacity: 0.3
            }

            // DYNAMIC VIEWS CONTAINER
            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              // ----------------------------------------------------
              // DASHBOARD VIEW (HUB)
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "hub"
                spacing: 12

                RowLayout {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  spacing: 12

                  // Left column: System telemetry status
                  Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1.2
                    radius: 12
                    color: Style.moduleBg || "#313244"
                    border.color: Style.border || "#45475a"
                    border.width: 1
                    
                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 14
                      spacing: 10
                      
                      Text {
                        text: "󰌢  System Information"
                        color: Style.blue
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                      }
                      
                      GridLayout {
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 12
                        Layout.fillWidth: true
                        
                        Text { text: "OS:"; color: Style.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font" }
                        Text { text: "Fedora Asahi Linux"; color: Style.text; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; font.bold: true }

                        Text { text: "Kernel:"; color: Style.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font" }
                        Text { text: "6.x-asahi"; color: Style.text; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font" }

                        Text { text: "Shell:"; color: Style.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font" }
                        Text { text: "Quickshell Remix"; color: Style.text; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font" }

                        Text { text: "Compositor:"; color: Style.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font" }
                        Text { text: "Hyprland"; color: Style.text; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font" }
                      }

                      Item { Layout.fillHeight: true }

                      // Sub-dashboard stats
                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: 2
                          RowLayout {
                            Text { text: "CPU usage"; font.pixelSize: 10; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                            Item { Layout.fillWidth: true }
                            Text { text: root.sidebarCpu + "%"; font.pixelSize: 10; color: Style.orange; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                          }
                          Rectangle {
                            Layout.fillWidth: true; height: 6; radius: 3; color: Style.surface || "#313244"
                            Rectangle { width: parent.width * root.sidebarCpu / 100; height: parent.height; radius: 3; color: Style.orange || "#fab387" }
                          }
                        }

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: 2
                          RowLayout {
                            Text { text: "Memory usage"; font.pixelSize: 10; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                            Item { Layout.fillWidth: true }
                            Text { text: root.sidebarMem + "%"; font.pixelSize: 10; color: Style.lavender; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                          }
                          Rectangle {
                            Layout.fillWidth: true; height: 6; radius: 3; color: Style.surface || "#313244"
                            Rectangle { width: parent.width * root.sidebarMem / 100; height: parent.height; radius: 3; color: Style.lavender || "#b4befe" }
                          }
                        }
                      }
                    }
                  }

                  // Right column: Now playing and wallpaper preview
                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    // Mini Now playing
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      radius: 12
                      color: Style.moduleBg || "#313244"
                      border.color: Style.border || "#45475a"
                      border.width: 1
                      
                      ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8
                        
                        Text {
                          text: "󰎈  Now Playing"
                          color: Style.blue
                          font.pixelSize: 13
                          font.bold: true
                          font.family: "JetBrainsMono Nerd Font"
                        }
                        
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: 10
                          
                          Rectangle {
                            width: 36
                            height: 36
                            radius: 8
                            color: Style.surface || "#1e1e2e"
                            Text {
                              anchors.centerIn: parent
                              text: "󰎆"
                              font.pixelSize: 18
                              color: Style.green
                            }
                          }

                          ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                              text: {
                                const p = root.activePlayer
                                if (!p) return "No media playing"
                                return p.trackTitle || "Unknown Track"
                              }
                              color: Style.text
                              font.pixelSize: 12
                              font.bold: true
                              font.family: "JetBrainsMono Nerd Font"
                              elide: Text.ElideRight
                              Layout.fillWidth: true
                            }
                            Text {
                              text: {
                                const p = root.activePlayer
                                if (!p) return "System Player"
                                return p.trackArtist || "Unknown Artist"
                              }
                              color: Style.textMuted
                              font.pixelSize: 10
                              font.family: "JetBrainsMono Nerd Font"
                              elide: Text.ElideRight
                              Layout.fillWidth: true
                            }
                          }
                        }

                        // Compact playback controls
                        RowLayout {
                          Layout.alignment: Qt.AlignHCenter
                          spacing: 16
                          
                          MouseArea {
                            width: 24; height: 24; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              const p = root.activePlayer
                              if (p && p.canGoPrevious) p.previous()
                            }
                            Text { anchors.centerIn: parent; text: "󰒮"; font.pixelSize: 18; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
                          }
                          
                          Rectangle {
                            width: 32; height: 32; radius: 16
                            color: Style.green
                            opacity: 0.15
                            
                            Text {
                              anchors.centerIn: parent
                              text: {
                                const p = root.activePlayer
                                return (p && p.isPlaying) ? "󰏤" : "󰐊"
                              }
                              font.pixelSize: 16
                              color: Style.green
                              font.family: "JetBrainsMono Nerd Font"
                            }
                            MouseArea {
                              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                              onClicked: {
                                const p = root.activePlayer
                                if (p && p.canTogglePlaying) p.togglePlaying()
                              }
                            }
                          }

                          MouseArea {
                            width: 24; height: 24; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              const p = root.activePlayer
                              if (p && p.canGoNext) p.next()
                            }
                            Text { anchors.centerIn: parent; text: "󰒭"; font.pixelSize: 18; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
                          }
                        }
                      }
                    }

                    // Mini Wallpaper Preview
                    Rectangle {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      radius: 12
                      clip: true
                      color: Style.moduleBg || "#313244"
                      border.color: Style.border || "#45475a"
                      border.width: 1
                      
                      Image {
                        anchors.fill: parent
                        source: WallpaperModule.WallpaperService.currentWallpaper ? "file://" + WallpaperModule.WallpaperService.currentWallpaper : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: 0.8
                        
                        Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0,0.4) }
                      }
                      
                      ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4
                        
                        Text {
                          text: "󰸉  Active Wallpaper"
                          color: "#ffffff"
                          font.pixelSize: 12
                          font.bold: true
                          font.family: "JetBrainsMono Nerd Font"
                          style: Text.Outline; styleColor: "#000000"
                        }
                        Item { Layout.fillHeight: true }
                        Text {
                          text: WallpaperModule.WallpaperService.currentWallpaper ? WallpaperModule.WallpaperService.currentWallpaper.split("/").pop() : "No wallpaper active"
                          color: "#cdd6f4"
                          font.pixelSize: 10
                          font.bold: true
                          font.family: "JetBrainsMono Nerd Font"
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                          style: Text.Outline; styleColor: "#000000"
                        }
                      }
                      
                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.mode = "wallpaper"
                      }
                    }
                  }
                }

                // Recent Screenshots strip
                Item {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 74
                  visible: root.shots.length > 0
                  
                  ColumnLayout {
                    anchors.fill: parent
                    spacing: 4
                    RowLayout {
                      Layout.fillWidth: true
                      Text { text: "󰹑  Recent Screenshots"; color: Style.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                      Item { Layout.fillWidth: true }
                      Text {
                        text: "view all →"
                        color: Style.blue
                        font.pixelSize: 10
                        font.family: "JetBrainsMono Nerd Font"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.mode = "screenshots" }
                      }
                    }
                    Row {
                      spacing: 8
                      Repeater {
                        model: root.shots.slice(0, 4)
                        delegate: Rectangle {
                          required property var modelData
                          width: 106; height: 50; radius: 8; clip: true
                          color: Style.surface || "#313244"
                          border.color: root.copiedShot === modelData.path ? Style.green : (dashShotMa.containsMouse ? Style.blue : "transparent")
                          border.width: 1
                          
                          Image { anchors.fill: parent; anchors.margins: 1; source: "file://" + modelData.path; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(150, 90) }
                          
                          Rectangle { anchors.fill: parent; color: Qt.rgba(0.4, 0.8, 0.5, 0.35); visible: root.copiedShot === modelData.path; Text { anchors.centerIn: parent; text: "COPIED"; color: "#cdd6f4"; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"; font.bold: true } }
                          
                          MouseArea {
                            id: dashShotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (e) => { if (e.button === Qt.RightButton) root.openShot(modelData.path); else root.copyShot(modelData.path) }
                          }
                        }
                      }
                    }
                  }
                }

                // Bottom row: reload tools
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8
                  Repeater {
                    model: [
                      { icon: "󱂬", label: "Scratch", act: () => root.toggleScratch() },
                      { icon: "󰑓", label: "Hypr", act: () => root.reloadHyprland() },
                      { icon: "󰑐", label: "QS Remix", act: () => root.reloadBar() },
                      { icon: "󰑓", label: "Paper", act: () => root.restartHyprpaper() },
                      { icon: "󰑓", label: "Idle", act: () => root.restartHypridle() },
                      { icon: "󰌾", label: "Lock", act: () => root.doLock() }
                    ]
                    delegate: Rectangle {
                      required property var modelData
                      Layout.fillWidth: true; height: 32; radius: 8
                      color: Style.surface || "#313244"
                      border.color: reloadMa.containsMouse ? Style.blue : Style.border || "transparent"
                      border.width: 1
                      
                      Row { anchors.centerIn: parent; spacing: 6; Text { text: modelData.icon; font.pixelSize: 13; color: Style.blue; font.family: "JetBrainsMono Nerd Font" } Text { text: modelData.label; font.pixelSize: 11; color: Style.text; font.family: "JetBrainsMono Nerd Font" } }
                      MouseArea { id: reloadMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.act() }
                    }
                  }
                }
              }

              // ----------------------------------------------------
              // WALLPAPER SELECTION VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "wallpaper"
                spacing: 10

                Rectangle {
                  Layout.fillWidth: true
                  height: 36
                  radius: 8
                  color: Style.surface || "#313244"
                  border.color: searchInput.activeFocus ? Style.blue : Style.border || "#45475a"
                  border.width: 1

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    TextInput {
                      id: searchInput
                      Layout.fillWidth: true
                      Layout.alignment: Qt.AlignVCenter
                      color: Style.text || "#cdd6f4"
                      font.pixelSize: 13
                      font.family: "JetBrainsMono Nerd Font"
                      clip: true
                      selectByMouse: true
                      onTextChanged: root.wallpaperSearchText = text
                    }

                    Text {
                      text: "Search wallpapers..."
                      color: Style.textMuted || "#a6adc8"
                      font.pixelSize: 13
                      font.family: "JetBrainsMono Nerd Font"
                      visible: searchInput.text === "" && !searchInput.activeFocus
                    }
                  }
                }

                GridView {
                  id: wallpaperGrid
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  cellWidth: Math.floor(width / 3)
                  cellHeight: cellWidth * 0.6 + 6
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  model: root.filteredWallpapers

                  delegate: Item {
                    required property string modelData
                    required property int index
                    width: wallpaperGrid.cellWidth
                    height: wallpaperGrid.cellHeight

                    Rectangle {
                      anchors.fill: parent
                      anchors.margins: 4
                      radius: 8
                      color: Style.surface || "#313244"
                      border.color: WallpaperModule.WallpaperService.currentWallpaper === modelData ? Style.green : (wallGridMa.containsMouse ? Style.blue : Style.border || "transparent")
                      border.width: WallpaperModule.WallpaperService.currentWallpaper === modelData ? 2 : 1
                      clip: true

                      Image {
                        anchors.fill: parent
                        anchors.margins: WallpaperModule.WallpaperService.currentWallpaper === modelData ? 2 : 1
                        source: "file://" + modelData
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 200
                        sourceSize.height: 120
                        asynchronous: true

                        Rectangle {
                          anchors.fill: parent
                          color: Style.surface
                          visible: parent.status !== Image.Ready
                          Text { anchors.centerIn: parent; text: "󰋩"; color: Style.textMuted; font.pixelSize: 22 }
                        }
                      }

                      Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 20
                        color: Qt.rgba(0, 0, 0, 0.6)
                        Text { anchors.centerIn: parent; text: modelData.split("/").pop(); color: "#ffffff"; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideMiddle; width: parent.width - 6; horizontalAlignment: Text.AlignHCenter }
                      }

                      Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 18; height: 18; radius: 9
                        color: Style.green
                        visible: WallpaperModule.WallpaperService.currentWallpaper === modelData
                        Text { anchors.centerIn: parent; text: "✓"; color: Style.bg || "#1e1e2e"; font.pixelSize: 11; font.bold: true }
                      }

                      MouseArea {
                        id: wallGridMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (e) => {
                          if (e.button === Qt.RightButton) {
                            root.wallpaperPreviewPath = modelData
                          } else {
                            WallpaperModule.WallpaperService.setWallpaper(modelData)
                          }
                        }
                      }
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 12
                  Text { text: "Left-click: apply • Right-click: widescreen preview"; color: Style.textMuted; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                  Item { Layout.fillWidth: true }
                  Text { text: WallpaperModule.WallpaperService.wallpapers.length + " wallpapers"; color: Style.textMuted; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                }
              }

              // ----------------------------------------------------
              // SCREENSHOTS VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "screenshots"
                spacing: 8
                
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8
                  
                  Repeater {
                    model: [
                      { label: "󰄄  Region", k: "region" },
                      { label: "󰹑  Fullscreen", k: "fullscreen" }
                    ]
                    delegate: Rectangle {
                      required property var modelData
                      width: 110; height: 28; radius: 8
                      color: Style.moduleBg || "#313244"
                      border.color: ca.containsMouse ? Style.green : "transparent"
                      border.width: 1
                      Text { anchors.centerIn: parent; text: modelData.label; font.pixelSize: 11; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                      MouseArea { id: ca; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.capture(modelData.k) }
                    }
                  }
                  Item { Layout.fillWidth: true }
                  Text { text: "Click to copy • Right-click to open"; color: Style.textMuted; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                }

                GridView {
                  id: shotGrid
                  Layout.fillWidth: true; Layout.fillHeight: true
                  cellWidth: Math.floor(width / 3)
                  cellHeight: cellWidth * 0.6 + 6
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  model: root.shots

                  delegate: Item {
                    required property var modelData
                    required property int index
                    width: shotGrid.cellWidth
                    height: shotGrid.cellHeight

                    Rectangle {
                      anchors.fill: parent
                      anchors.margins: 4
                      radius: 8; clip: true
                      color: Style.surface || "#313244"
                      border.color: root.copiedShot === modelData.path ? Style.green : (hma.containsMouse ? Style.blue : Style.border || "transparent")
                      border.width: root.copiedShot === modelData.path ? 2 : 1
                      
                      Image {
                        anchors.fill: parent; anchors.margins: 1
                        source: "file://" + modelData.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 200
                        sourceSize.height: 120
                      }
                      
                      Rectangle {
                        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 18; color: Qt.rgba(0,0,0,0.55)
                        Text { anchors.centerIn: parent; text: modelData.label; color: "#ffffff"; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight; width: parent.width-6; horizontalAlignment: Text.AlignHCenter }
                      }

                      Rectangle {
                        anchors.fill: parent; anchors.margins: 1; radius: 6; color: Qt.rgba(0.4,0.8,0.5,0.32); visible: root.copiedShot === modelData.path
                        Text { anchors.centerIn: parent; text: "COPIED"; color: "#ffffff"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                      }

                      MouseArea {
                        id: hma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (e) => { if (e.button === Qt.RightButton) root.openShot(modelData.path); else root.copyShot(modelData.path) }
                      }
                    }
                  }
                }
                Text { visible: root.shots.length === 0; text: "No screenshots in ~/screenshots"; color: Style.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; Layout.alignment: Qt.AlignHCenter }
              }

              // ----------------------------------------------------
              // MEDIA & AUDIO VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "media"
                spacing: 12

                // Players Control Panel
                Rectangle {
                  Layout.fillWidth: true
                  radius: 12
                  color: Style.moduleBg || "#313244"
                  border.color: Style.border || "#45475a"
                  border.width: 1
                  Layout.preferredHeight: 90

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: "󰎈  Now Playing Status"; color: Style.blue; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; font.bold: true }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10

                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                          text: {
                            const p = root.activePlayer
                            if (!p) return "No active media player"
                            return (p.trackArtist || "Unknown Artist") + " — " + (p.trackTitle || "Unknown Track")
                          }
                          color: Style.text
                          font.pixelSize: 12
                          font.bold: true
                          font.family: "JetBrainsMono Nerd Font"
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }
                      }

                      // Controls
                      RowLayout {
                        spacing: 14
                        MouseArea {
                          width: 22; height: 22; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            const p = root.activePlayer
                            if (p && p.canGoPrevious) p.previous()
                          }
                          Text { text: "󰒮"; font.pixelSize: 16; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                        }
                        
                        Rectangle {
                          width: 28; height: 28; radius: 14
                          color: Style.green
                          opacity: 0.2
                          Text {
                            anchors.centerIn: parent
                            text: {
                              const p = root.activePlayer
                              return (p && p.isPlaying) ? "󰏤" : "󰐊"
                            }
                            font.pixelSize: 15; color: Style.green; font.family: "JetBrainsMono Nerd Font"
                          }
                          MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              const p = root.activePlayer
                              if (p && p.canTogglePlaying) p.togglePlaying()
                            }
                          }
                        }

                        MouseArea {
                          width: 22; height: 22; cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            const p = root.activePlayer
                            if (p && p.canGoNext) p.next()
                          }
                          Text { text: "󰒭"; font.pixelSize: 16; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                        }
                      }
                    }
                  }
                }

                // Volume Controls
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 12
                  
                  // Output Vol
                  Rectangle {
                    Layout.fillWidth: true; height: 44; radius: 10; color: Style.moduleBg || "#313244"
                    border.color: Style.border || "#45475a"; border.width: 1
                    
                    RowLayout {
                      anchors.fill: parent; anchors.margins: 10
                      Text { text: "󰕾  Speakers"; font.pixelSize: 11; color: Style.text; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                      Item { Layout.fillWidth: true }
                      Text { text: root.defaultSinkVol; font.pixelSize: 11; color: Style.blue; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                      
                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.surface
                        Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 12; color: Style.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volAdjust("@DEFAULT_AUDIO_SINK@", -5) }
                      }
                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.surface
                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 12; color: Style.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volAdjust("@DEFAULT_AUDIO_SINK@", 5) }
                      }
                    }
                  }

                  // Mic Vol
                  Rectangle {
                    Layout.fillWidth: true; height: 44; radius: 10; color: Style.moduleBg || "#313244"
                    border.color: Style.border || "#45475a"; border.width: 1
                    
                    RowLayout {
                      anchors.fill: parent; anchors.margins: 10
                      Text { text: "󰍬  Microphone"; font.pixelSize: 11; color: Style.text; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                      Item { Layout.fillWidth: true }
                      Text { text: root.defaultSourceVol; font.pixelSize: 11; color: Style.blue; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                      
                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.surface
                        Text { anchors.centerIn: parent; text: "−"; font.pixelSize: 12; color: Style.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volAdjust("@DEFAULT_AUDIO_SOURCE@", -5) }
                      }
                      Rectangle {
                        width: 20; height: 20; radius: 4; color: Style.surface
                        Text { anchors.centerIn: parent; text: "+"; font.pixelSize: 12; color: Style.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volAdjust("@DEFAULT_AUDIO_SOURCE@", 5) }
                      }
                    }
                  }
                }

                // Cava Spectrum visualization
                Rectangle {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  radius: 12
                  color: Style.moduleBg || "#313244"
                  border.color: Style.border || "#45475a"
                  border.width: 1
                  
                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    
                    Text { text: "󰎈  Live Cava Audio Spectrum"; color: Style.textMuted; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                    
                    Item {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      
                      Row {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4
                        
                        Repeater {
                          model: 24
                          delegate: Rectangle {
                            required property int index
                            width: (parent.width - 23 * 4) / 24
                            height: root.cavaValues && root.cavaValues.length > index ? Math.max(3, (root.cavaValues[index] || 0) / 100 * parent.height) : 3
                            color: Style.green || "#a6e3a1"
                            radius: 2
                            anchors.bottom: parent.bottom
                            Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                          }
                        }
                      }
                    }
                  }
                }
              }

              // ----------------------------------------------------
              // WI-FI VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "wifi"
                spacing: 10

                RowLayout {
                  Layout.fillWidth: true
                  Text { text: "󰤨 Connected: " + root.wifiLabel; color: Style.green; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; font.bold: true }
                  Item { Layout.fillWidth: true }
                  Rectangle {
                    width: 70; height: 24; radius: 6; color: Style.moduleBg || "#313244"
                    border.color: Style.border; border.width: 1
                    Text { anchors.centerIn: parent; text: "Scan"; font.pixelSize: 10; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.scanWifi() }
                  }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Style.border; opacity: 0.4 }

                Flickable {
                  Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                  contentHeight: wifiCol.height
                  boundsBehavior: Flickable.StopAtBounds
                  Column {
                    id: wifiCol; width: parent.width; spacing: 4
                    Repeater {
                      model: root.wifiNetworks
                      delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 32; radius: 6
                        color: h.containsMouse ? Style.moduleBg : "transparent"
                        
                        RowLayout {
                          anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                          Text { text: modelData.active ? "󰤨" : "󰤯"; font.pixelSize: 14; color: modelData.active ? Style.green : Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
                          Text { text: modelData.ssid; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 11; color: Style.text; font.family: "JetBrainsMono Nerd Font"; font.bold: modelData.active }
                          Text { text: modelData.sec ? "󰌾" : ""; font.pixelSize: 11; color: Style.textMuted }
                          Text { text: modelData.signal + "%"; font.pixelSize: 10; color: Style.textAlt; font.family: "JetBrainsMono Nerd Font" }
                        }
                        
                        MouseArea {
                          id: h; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                          onClicked: Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", modelData.ssid])
                        }
                      }
                    }
                  }
                }
                Text { visible: root.wifiNetworks.length === 0; text: "No networks found. Tap Scan."; color: Style.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; Layout.alignment: Qt.AlignHCenter }
              }

              // ----------------------------------------------------
              // BLUETOOTH VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "bluetooth"
                spacing: 10

                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    text: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "Bluetooth Radio: Active" : "Bluetooth Radio: Disabled")
                    color: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? Style.green : Style.textMuted)
                    font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; font.bold: true
                  }
                  Item { Layout.fillWidth: true }
                  Rectangle {
                    width: 70; height: 24; radius: 6; color: Style.moduleBg || "#313244"
                    border.color: Style.border; border.width: 1
                    Text { anchors.centerIn: parent; text: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "Turn Off" : "Turn On"); font.pixelSize: 10; color: Style.text; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled }
                    }
                  }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Style.border; opacity: 0.4 }

                Flickable {
                  Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                  contentHeight: btCol.height
                  boundsBehavior: Flickable.StopAtBounds
                  Column {
                    id: btCol; width: parent.width; spacing: 4
                    Repeater {
                      model: Bluetooth.devices ? Bluetooth.devices.values : []
                      delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 36; radius: 6
                        color: bth.containsMouse ? Style.moduleBg : "transparent"
                        
                        RowLayout {
                          anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                          Text { text: modelData.connected ? "󰂱" : "󰂯"; font.pixelSize: 14; color: modelData.connected ? Style.green : Style.textMuted }
                          
                          ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text { text: modelData.name || modelData.alias || modelData.address; font.pixelSize: 11; color: Style.text; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight; font.bold: modelData.connected }
                            Text { text: modelData.batteryAvailable ? ("Battery: " + modelData.battery + "%") : (modelData.paired ? "Paired" : "Nearby Device"); font.pixelSize: 9; color: Style.textMuted; font.family: "JetBrainsMono Nerd Font" }
                          }
                          
                          Rectangle {
                            width: 64; height: 20; radius: 4
                            color: Style.surface
                            border.color: Style.border; border.width: 1
                            Text { anchors.centerIn: parent; text: modelData.connected ? "disc" : (modelData.paired ? "conn" : "pair"); font.pixelSize: 9; color: Style.blue; font.family: "JetBrainsMono Nerd Font" }
                            MouseArea {
                              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                              onClicked: { if (modelData.connected) modelData.disconnect(); else if (modelData.paired) modelData.connect(); else modelData.pair() }
                            }
                          }
                        }
                        MouseArea { id: bth; anchors.fill: parent; hoverEnabled: true }
                      }
                    }
                  }
                }
                Text { visible: (!Bluetooth.devices || Bluetooth.devices.values.length === 0); text: "No devices found"; color: Style.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; Layout.alignment: Qt.AlignHCenter }
              }

              // ----------------------------------------------------
              // POWER VIEW
              // ----------------------------------------------------
              ColumnLayout {
                anchors.fill: parent
                visible: root.mode === "power"
                spacing: 12

                Text { text: root.pendingConfirm ? "Confirm action: " + root.pendingConfirm + "?" : "Select Power Action"; color: Style.textMuted; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; Layout.alignment: Qt.AlignHCenter }
                
                GridLayout {
                  Layout.fillWidth: true
                  columns: 2
                  rowSpacing: 12
                  columnSpacing: 12
                  Repeater {
                    model: [
                      { icon: "󰌾", label: "Lock Session", act: () => root.doLock(), danger: false },
                      { icon: "󰒲", label: "Suspend", act: () => root.doSuspend(), danger: false },
                      { icon: "󰑓", label: "Reboot System", act: () => root.doReboot(), danger: true },
                      { icon: "󰐥", label: "Shutdown Power", act: () => root.doShutdown(), danger: true }
                    ]
                    delegate: Rectangle {
                      required property var modelData
                      Layout.fillWidth: true; height: 50; radius: 10
                      color: modelData.danger ? (Style.red ? Qt.rgba(0.95,0.55,0.65,0.1) : "#2a1e1e") : (Style.moduleBg || "#313244")
                      border.color: pma.containsMouse ? (modelData.danger ? Style.red : Style.blue) : Style.border || "transparent"
                      border.width: 1
                      
                      Row { anchors.centerIn: parent; spacing: 8; Text { text: modelData.icon; font.pixelSize: 20; color: modelData.danger ? Style.red : Style.blue; font.family: "JetBrainsMono Nerd Font" } Text { text: modelData.label; font.pixelSize: 12; color: Style.text; font.family: "JetBrainsMono Nerd Font"; font.bold: true } }
                      MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.act() }
                    }
                  }
                }

                RowLayout {
                  visible: !!root.pendingConfirm
                  Layout.alignment: Qt.AlignHCenter
                  spacing: 12
                  
                  Rectangle { width: 90; height: 30; radius: 6; color: Style.green ? Qt.rgba(0.6,0.8,0.5,0.2) : "#1e2a1e"
                    Text { anchors.centerIn: parent; text: "Confirm"; color: Style.green; font.pixelSize: 12; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.pendingConfirm === "reboot") root.doReboot(); else if (root.pendingConfirm === "shutdown") root.doShutdown() } }
                  }
                  Rectangle { width: 90; height: 30; radius: 6; color: Style.surface || "#313244"
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Style.textMuted; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cancelConfirm() }
                  }
                }
              }
            }
          }
        }
      }
    }

    // WIDESCREEN WALLPAPER PICKER PREVIEW OVERLAY
    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.85)
      visible: root.wallpaperPreviewPath !== ""
      radius: 16
      
      MouseArea { anchors.fill: parent; onClicked: root.wallpaperPreviewPath = "" }

      Image {
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: parent.height * 0.8
        source: root.wallpaperPreviewPath !== "" ? "file://" + root.wallpaperPreviewPath : ""
        fillMode: Image.PreserveAspectFit
        asynchronous: true
      }

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 30
        width: applyRow.width + 36
        height: 40
        radius: 20
        color: Style.blue || "#89b4fa"

        RowLayout {
          id: applyRow
          anchors.centerIn: parent
          spacing: 10
          Text { text: "✓"; color: Style.crust || "#11111b"; font.pixelSize: 14; font.bold: true }
          Text { text: "Apply Wallpaper"; color: Style.crust || "#11111b"; font.pixelSize: 12; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            WallpaperModule.WallpaperService.setWallpaper(root.wallpaperPreviewPath)
            root.wallpaperPreviewPath = ""
          }
        }
      }
      
      Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        text: "Press ESC or click anywhere to exit preview"; color: Style.textMuted; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
      }
    }
  }
}
