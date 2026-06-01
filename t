[1mdiff --git a/asahi/bin/asahi-network b/asahi/bin/asahi-network[m
[1mindex cf26944..b90df80 100755[m
[1m--- a/asahi/bin/asahi-network[m
[1m+++ b/asahi/bin/asahi-network[m
[36m@@ -33,8 +33,9 @@[m [mif [ -z "$line" ]; then[m
     --arg text "󰤮" \[m
     --arg tooltip "Disconnected" \[m
     --arg class "disconnected" \[m
[32m+[m[32m    --arg device "" \[m
     --argjson percentage 0 \[m
[31m-    '{text:$text, tooltip:$tooltip, class:$class, percentage:$percentage}'[m
[32m+[m[32m    '{text:$text, tooltip:$tooltip, class:$class, device:$device, percentage:$percentage}'[m
   exit 0[m
 fi[m
 [m
[36m@@ -75,5 +76,6 @@[m [mjq -cn \[m
   --arg text "$text" \[m
   --arg tooltip "$tooltip" \[m
   --arg class "$class" \[m
[32m+[m[32m  --arg device "$dev" \[m
   --argjson percentage "${pct:-0}" \[m
[31m-  '{text:$text, tooltip:$tooltip, class:$class, percentage:$percentage}'[m
[32m+[m[32m  '{text:$text, tooltip:$tooltip, class:$class, device:$device, percentage:$percentage}'[m
[1mdiff --git a/asahi/hypr/hyprlock.conf b/asahi/hypr/hyprlock.conf[m
[1mindex a9df677..7402e3e 100644[m
[1m--- a/asahi/hypr/hyprlock.conf[m
[1m+++ b/asahi/hypr/hyprlock.conf[m
[36m@@ -1,24 +1,88 @@[m
[32m+[m[32m$font = Cascadia Mono NF[m
[32m+[m
[32m+[m[32mgeneral {[m
[32m+[m[32m  hide_cursor = true[m
[32m+[m[32m  ignore_empty_input = true[m
[32m+[m[32m  immediate_render = true[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mauth {[m
[32m+[m[32m  pam:enabled = true[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32manimations {[m
[32m+[m[32m  enabled = true[m
[32m+[m[32m  bezier = linear, 1, 1, 0, 0[m
[32m+[m[32m  animation = fadeIn, 1, 5, linear[m
[32m+[m[32m  animation = fadeOut, 1, 5, linear[m
[32m+[m[32m  animation = inputFieldDots, 1, 2, linear[m
[32m+[m[32m}[m
[32m+[m
 background {[m
   monitor =[m
[31m-  path = ~/Pictures/wallpaper/rocket_launch.jpg[m
[32m+[m[32m  path = ~/Pictures/wallpaper/blackhole.jpg[m
   color = rgb(1e1e2e)[m
 }[m
 [m
[32m+[m[32mlabel {[m
[32m+[m[32m  monitor =[m
[32m+[m[32m  text = $TIME[m
[32m+[m[32m  color = rgb(f5c2e7)[m
[32m+[m[32m  font_size = 84[m
[32m+[m[32m  font_family = $font[m
[32m+[m[32m  shadow_passes = 2[m
[32m+[m[32m  shadow_size = 4[m
[32m+[m[32m  shadow_color = rgba(11111bcc)[m
[32m+[m[32m  position = 0, 125[m
[32m+[m[32m  halign = center[m
[32m+[m[32m  valign = center[m
[32m+[m[32m  zindex = 1[m
[32m+[m[32m}[m
[32m+[m
[32m+[m[32mlabel {[m
[32m+[m[32m  monitor =[m
[32m+[m[32m  text = cmd[update:60000] date +"%A, %d %B %Y"[m
[32m+[m[32m  color = rgb(7f849c)[m
[32m+[m[32m  font_size = 24[m
[32m+[m[32m  font_family = $font[m
[32m+[m[32m  position = 0, 60[m
[32m+[m[32m  halign = center[m
[32m+[m[32m  valign = center[m
[32m+[m[32m  zindex = 1[m
[32m+[m[32m}[m
[32m+[m
 input-field {[m
   monitor =[m
[31m-  outline_thickness = 8[m
[31m-  outer_color = rgb(89b4fa)[m
[31m-  inner_color = rgb(313244)[m
[32m+[m[32m  size = 22%, 5%[m
[32m+[m[32m  outline_thickness = 4[m
[32m+[m[32m  inner_color = rgba(0, 0, 0, 0.0)[m
[32m+[m[32m  outer_color = rgba(f5c2e7ee) rgba(cba6f7ee) 45deg[m
[32m+[m[32m  check_color = rgba(a6e3a1ee) rgba(94e2d5ee) 120deg[m
[32m+[m[32m  fail_color = rgba(f38ba8ee) rgba(eb6f92ee) 40deg[m
   font_color = rgb(cdd6f4)[m
[32m+[m[32m  font_family = $font[m
   fade_on_empty = false[m
[31m-  position = 0, -80[m
[32m+[m[32m  rounding = 15[m
[32m+[m[32m  placeholder_text = Enter password...[m
[32m+[m[32m  fail_text = $PAMFAIL[m
[32m+[m[32m  dots_spacing = 0.3[m
[32m+[m[32m  shadow_passes = 2[m
[32m+[m[32m  shadow_size = 4[m
[32m+[m[32m  shadow_color = rgba(11111bcc)[m
[32m+[m[32m  position = 0, -45[m
[32m+[m[32m  halign = center[m
[32m+[m[32m  valign = center[m
[32m+[m[32m  zindex = 1[m
 }[m
 [m
 label {[m
   monitor =[m
[31m-  text = cmd[update:1000] date +'%H:%M'[m
[31m-  color = rgb(cdd6f4)[m
[31m-  font_size = 84[m
[31m-  font_family = Cascadia Mono NF[m
[31m-  position = 0, 80[m
[32m+[m[32m  text = Locked for $USER[m
[32m+[m[32m  color = rgb(a6adc8)[m
[32m+[m[32m  font_size = 16[m
[32m+[m[32m  font_family = $font[m
[32m+[m[32m  position = 0, -115[m
[32m+[m[32m  halign = center[m
[32m+[m[32m  valign = center[m
[32m+[m[32m  zindex = 1[m
 }[m
[1mdiff --git a/asahi/quickshell/remix/modules/bar/components/Network.qml b/asahi/quickshell/remix/modules/bar/components/Network.qml[m
[1mindex 41d0362..e81d905 100644[m
[1m--- a/asahi/quickshell/remix/modules/bar/components/Network.qml[m
[1m+++ b/asahi/quickshell/remix/modules/bar/components/Network.qml[m
[36m@@ -20,6 +20,62 @@[m [mRectangle {[m
     property string icon: "󰤨"[m
     property string text: "WiFi"[m
     property string tooltip: ""[m
[32m+[m[32m    property string device: ""[m
[32m+[m[32m    property real rxSpeed: 0[m
[32m+[m[32m    property real txSpeed: 0[m
[32m+[m[32m    property real previousRxBytes: -1[m
[32m+[m[32m    property real previousTxBytes: -1[m
[32m+[m[32m    property real previousSampleMs: 0[m
[32m+[m
[32m+[m[32m    function formatSpeed(bytes) {[m
[32m+[m[32m        let unit = "K"[m
[32m+[m[32m        let value = bytes / 1024[m
[32m+[m[32m        if (value >= 1024) {[m
[32m+[m[32m            unit = "M"[m
[32m+[m[32m            value /= 1024[m
[32m+[m[32m        }[m
[32m+[m[32m        if (value >= 1024) {[m
[32m+[m[32m            unit = "G"[m
[32m+[m[32m            value /= 1024[m
[32m+[m[32m        }[m
[32m+[m[32m        return Math.min(999, Math.round(value)).toString().padStart(3, "0") + " " + unit[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    function refreshSpeed() {[m
[32m+[m[32m        if (root.device === "" || speedProc.running) return[m
[32m+[m[32m        speedProc.command = [[m
[32m+[m[32m            "cat",[m
[32m+[m[32m            "/sys/class/net/" + root.device + "/statistics/rx_bytes",[m
[32m+[m[32m            "/sys/class/net/" + root.device + "/statistics/tx_bytes"[m
[32m+[m[32m        ][m
[32m+[m[32m        speedProc.running = true[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    function updateSpeed(text) {[m
[32m+[m[32m        const values = text.trim().split(/\s+/)[m
[32m+[m[32m        if (values.length < 2) return[m
[32m+[m
[32m+[m[32m        const now = Date.now()[m
[32m+[m[32m        const rxBytes = Number(values[0])[m
[32m+[m[32m        const txBytes = Number(values[1])[m
[32m+[m[32m        const seconds = (now - root.previousSampleMs) / 1000[m
[32m+[m
[32m+[m[32m        if (root.previousSampleMs > 0 && seconds > 0) {[m
[32m+[m[32m            root.rxSpeed = Math.max(0, (rxBytes - root.previousRxBytes) / seconds)[m
[32m+[m[32m            root.txSpeed = Math.max(0, (txBytes - root.previousTxBytes) / seconds)[m
[32m+[m[32m        }[m
[32m+[m
[32m+[m[32m        root.previousRxBytes = rxBytes[m
[32m+[m[32m        root.previousTxBytes = txBytes[m
[32m+[m[32m        root.previousSampleMs = now[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    onDeviceChanged: {[m
[32m+[m[32m        root.rxSpeed = 0[m
[32m+[m[32m        root.txSpeed = 0[m
[32m+[m[32m        root.previousSampleMs = 0[m
[32m+[m[32m        root.refreshSpeed()[m
[32m+[m[32m    }[m
 [m
     RowLayout {[m
         id: content[m
[36m@@ -29,9 +85,27 @@[m [mRectangle {[m
         Text {[m
             text: root.text[m
             font.family: "JetBrainsMono Nerd Font"[m
[31m-            font.pixelSize: 30[m
[32m+[m[32m            font.pixelSize: 32[m
             color: Style.blueAlt[m
         }[m
[32m+[m
[32m+[m[32m        Column {[m
[32m+[m[32m            spacing: -4[m
[32m+[m
[32m+[m[32m            Text {[m
[32m+[m[32m                text: "↑ " + root.formatSpeed(root.txSpeed)[m
[32m+[m[32m                font.family: Style.fontFamily[m
[32m+[m[32m                font.pixelSize: 11[m
[32m+[m[32m                color: root.txSpeed >= 1024 ? Style.green : Style.textMuted[m
[32m+[m[32m            }[m
[32m+[m
[32m+[m[32m            Text {[m
[32m+[m[32m                text: "↓ " + root.formatSpeed(root.rxSpeed)[m
[32m+[m[32m                font.family: Style.fontFamily[m
[32m+[m[32m                font.pixelSize: 11[m
[32m+[m[32m                color: root.rxSpeed >= 1024 ? Style.blueAlt : Style.textMuted[m
[32m+[m[32m            }[m
[32m+[m[32m        }[m
     }[m
 [m
     Process {[m
[36m@@ -43,11 +117,20 @@[m [mRectangle {[m
                     const data = JSON.parse(text.trim())[m
                     root.text = data.text || "󰤮"[m
                     root.tooltip = data.tooltip || ""[m
[32m+[m[32m                    root.device = data.device || ""[m
                 } catch (e) {}[m
             }[m
         }[m
     }[m
 [m
[32m+[m[32m    Process {[m
[32m+[m[32m        id: speedProc[m
[32m+[m[32m        command: ["true"][m
[32m+[m[32m        stdout: StdioCollector {[m
[32m+[m[32m            onStreamFinished: root.updateSpeed(text)[m
[32m+[m[32m        }[m
[32m+[m[32m    }[m
[32m+[m
     Timer {[m
         interval: 5000[m
         running: true[m
[36m@@ -55,7 +138,17 @@[m [mRectangle {[m
         onTriggered: netProc.running = true[m
     }[m
 [m
[31m-    Component.onCompleted: netProc.running = true[m
[32m+[m[32m    Timer {[m
[32m+[m[32m        interval: 1000[m
[32m+[m[32m        running: true[m
[32m+[m[32m        repeat: true[m
[32m+[m[32m        onTriggered: root.refreshSpeed()[m
[32m+[m[32m    }[m
[32m+[m
[32m+[m[32m    Component.onCompleted: {[m
[32m+[m[32m        netProc.running = true[m
[32m+[m[32m        root.refreshSpeed()[m
[32m+[m[32m    }[m
 [m
     MouseArea {[m
         id: ma[m
[36m@@ -66,7 +159,7 @@[m [mRectangle {[m
 [m
     TooltipWindow {[m
         target: root[m
[31m-        text: root.tooltip[m
[32m+[m[32m        text: root.tooltip + "\nUpload: " + root.formatSpeed(root.txSpeed) + "/s\nDownload: " + root.formatSpeed(root.rxSpeed) + "/s"[m
         show: ma.containsMouse[m
         maxWidth: 380[m
     }[m
[1mdiff --git a/asahi/quickshell/remix/modules/launcher/LauncherWindow.qml b/asahi/quickshell/remix/modules/launcher/LauncherWindow.qml[m
[1mindex d00cc59..8fa6d03 100644[m
[1m--- a/asahi/quickshell/remix/modules/launcher/LauncherWindow.qml[m
[1m+++ b/asahi/quickshell/remix/modules/launcher/LauncherWindow.qml[m
[36m@@ -26,6 +26,11 @@[m [mScope {[m
   property string dictRunningTerm: ""[m
   property string dictCopyLang: ""[m
   property var dictItems: [][m
[32m+[m[32m  property int fileVersion: 0[m
[32m+[m[32m  property string fileStatus: ""[m
[32m+[m[32m  property string filePendingTerm: ""[m
[32m+[m[32m  property string fileRunningTerm: ""[m
[32m+[m[32m  property var fileItems: [][m
 [m
   readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"[m
   readonly property string dictIcon: "file://" + Quickshell.env("HOME") + "/.dotfiles/asahi/quickshell/remix/assets/dict-cc.png"[m
[36m@@ -38,6 +43,7 @@[m [mScope {[m
     if (q.startsWith("=")) return "Calculator"[m
     if (q.startsWith("!")) return "Web Search"[m
     if (q.startsWith("@")) return "Documentation"[m
[32m+[m[32m    if (root.fileTerm(q) !== null) return "File Search"[m
     if (root.dictTerm(q)) return "Dictionary"[m
     return "Applications"[m
   }[m
[36m@@ -46,6 +52,14 @@[m [mScope {[m
     const c = root.resultCount[m
     const s = c !== 1 ? "s" : ""[m
     const qq = root.query.trim()[m
[32m+[m[32m    if (root.fileTerm(qq) !== null) {[m
[32m+[m[32m      if (root.fileStatus === "loading") return "Searching files..."[m
[32m+[m[32m      if (root.fileStatus === "error") return "fd search failed"[m
[32m+[m[32m      if (root.fileStatus === "prompt") return "Type after > to search ~"[m
[32m+[m[32m      if (root.fileStatus === "no-results") return "No files found"[m
[32m+[m[32m      const count = root.fileItems.length[m
[32m+[m[32m      return count + (count === 200 ? "+" : "") + " match" + (count !== 1 ? "es" : "") + " · Enter opens"[m
[32m+[m[32m    }[m
     if (root.dictTerm(qq)) {[m
       if (root.dictStatus === "loading") return "Loading dict.cc"[m
       if (root.dictStatus === "error") return "dict.cc lookup failed"[m
[36m@@ -64,6 +78,7 @@[m [mScope {[m
     }[m
   }[m
   onDictVersionChanged: root.resetDictSelection()[m
[32m+[m[32m  onFileVersionChanged: root.resetFileSelection()[m
 [m
   function launchCurrent() {[m
     let entry = null[m
[36m@@ -85,6 +100,11 @@[m [mScope {[m
     Qt.callLater(() => { if (searchInput) searchInput.forceActiveFocus() })[m
   }[m
 [m
[32m+[m[32m  function openFileSearch(term) {[m
[32m+[m[32m    root.openLauncher()[m
[32m+[m[32m    searchInput.text = ">" + (term || "")[m
[32m+[m[32m  }[m
[32m+[m
   function closeLauncher() {[m
     shouldShow = false[m
   }[m
[36m@@ -120,6 +140,8 @@[m [mScope {[m
     } else if (entry.special === "dict") {[m
       const copy = entry.copy || ""[m
       if (copy) Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", copy])[m
[32m+[m[32m    } else if (entry.special === "file" && entry.path) {[m
[32m+[m[32m      Quickshell.execDetached(["xdg-open", entry.path])[m
     } else if ((entry.special === "web" || entry.special === "doc") && entry.url) {[m
       let u = entry.url[m
       if (u.includes("%TERM%")) u = u.replace("%TERM%", "")[m
[36m@@ -138,6 +160,164 @@[m [mScope {[m
     return m ? m[1].trim() : ""[m
   }[m
 [m
[32m+[m[32m  function fileTerm(q) {[m
[32m+[m[32m    const value = (q || "").trim()[m
[32m+[m[32m    return value.startsWith(">") ? value.substring(1).trim() : null[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  function resetFileSelection() {[m
[32m+[m[32m    if (!resultsList || fileTerm(root.query) === null) return[m
[32m+[m[32m    resultsList.currentIndex = 0[m
[32m+[m[32m    resultsList.positionViewAtBeginning()[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  function scheduleFileLookup() {[m
[32m+[m[32m    const term = fileTerm(root.query)[m
[32m+[m[32m    fileDebounce.stop()[m
[32m+[m[32m    if (term === null) {[m
[32m+[m[32m      root.filePendingTerm = ""[m
[32m+[m[32m      root.fileStatus = ""[m
[32m+[m[32m      root.fileItems = [][m
[32m+[m[32m      root.fileVersion++[m
[32m+[m[32m      return[m
[32m+[m[32m    }[m
[32m+[m[32m    root.filePendingTerm = term[m
[32m+[m[32m    if (!term) {[m
[32m+[m[32m      root.fileStatus = "prompt"[m
[32m+[m[32m      root.fileItems = [][m
[32m+[m[32m      root.fileVersion++[m
[32m+[m[32m      return[m
[32m+[m[32m    }[m
[32m+[m[32m    root.fileStatus = "loading"[m
[32m+[m[32m    root.fileVersion++[m
[32m+[m[32m    fileDebounce.restart()[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  function startFileLookup() {[m
[32m+[m[32m    const term = root.filePendingTerm[m
[32m+[m[32m    if (!term || fileProc.running) return[m
[32m+[m[32m    root.fileRunningTerm = term[m
[32m+[m[32m    root.fileStatus = "loading"[m
[32m+[m[32m    root.fileVersion++[m
[32m+[m[32m    fileProc.command = [[m
[32m+[m[32m      "fd",[m
[32m+[m[32m      "--type", "f",[m
[32m+[m[32m      "--type", "d",[m
[32m+[m[32m      "--max-results", "200",[m
[32m+[m[32m      "--absolute-path",[m
[32m+[m[32m      "--color", "never",[m
[32m+[m[32m      "--fixed-strings",[m
[32m+[m[32m      "--", term, Quickshell.env("HOME")[m
[32m+[m[32m    ][m
[32m+[m[32m    fileProc.running = true[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  function finishFileLookup(exitCode, stdoutText, stderrText) {[m
[32m+[m[32m    const term = root.fileRunningTerm[m
[32m+[m[32m    if (term === root.filePendingTerm && term === fileTerm(root.query)) {[m
[32m+[m[32m      if (exitCode !== 0) {[m
[32m+[m[32m        root.fileStatus = "error"[m
[32m+[m[32m        root.fileItems = [{[m
[32m+[m[32m          id: "file-error",[m
[32m+[m[32m          name: "File search failed",[m
[32m+[m[32m          comment: stderrText.trim() || ("fd exited " + exitCode),[m
[32m+[m[32m          icon: "",[m
[32m+[m[32m          glyph: "󰅙",[m
[32m+[m[32m          special: "noop"[m
[32m+[m[32m        }][m
[32m+[m[32m      } else {[m
[32m+[m[32m        const paths = stdoutText.split("\n").filter(line => line.length > 0)[m
[32m+[m[32m        root.fileItems = root.sortFileResults(paths.map(root.formatFileResult), term)[m
[32m+[m[32m        root.fileStatus = root.fileItems.length > 0 ? "ready" : "no-results"[m
[32m+[m[32m      }[m
[32m+[m[32m      root.fileVersion++[m
[32m+[m[32m    }[m
[32m+[m[32m    if (root.filePendingTerm && root.filePendingTerm !== term) fileDebounce.restart()[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  function getFileResults(q) {[m
[32m+[m[32m    const term = fileTerm(q)[m
[32m+[m[32m    if (term === null) return null[m
[32m+[m[32m    if (!term) {[m
[32m+[m[32m      return [{ id: "file-prompt", name: "Search files and folders", comment: "Type > followed by a filename", icon: "", glyph: "󰍉", special: "noop" }][m
[32m+[m[32m    }[m
[32m+[m[32m    if (root.fileStatus === "loading") {[m
[32m+[m[32m      return [{ id: "file-loading", name: "Searching " + term, comment: "Searching ~ with fd", icon: "", glyph: "󰍉", special: "noop" }][m
[32m+[m[32m    }[m
[32m+[m[32m    if (root.fileStatus === "error") return root.fileItems[m
[32m+[m[32m    if (root.fileItems.length === 0) {[m
[32m+[m[32m      return [{ id: "file-empty", name: "No files found", comment: term, icon: "", glyph: "󰍉", special: "noop" }][m
[32m+[m[32m    }[m
[32m+[m[32m    return root.fileItems[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  function formatFileResult(rawPath) {[m
[32m+[m[32m    const isDirectory = rawPath.length > 1 && rawPath.endsWith("/")[m
[32m+[m[32m    const path = isDirectory ? rawPath.substring(0, rawPath.length - 1) : rawPath[m
[32m+[m[32m    const parts = path.split("/")[m
[32m+[m[32m    const name = parts.pop() || path[m
[32m+[m[32m    const parent = parts.join("/") || "/"[m
[32m+[m[32m    return {[m
[32m+[m[32m      id: "file-" + path,[m
[32m+[m[32m      name: name,[m
[32m+[m[32m      comment: root.displayFilePath(parent),[m
[32m+[m[32m      accessory: isDirectory ? "DIR" : "",[m
[32m+[m[32m      icon: "",[m
[32m+[m[32m      glyph: root.fileGlyph(name, isDirectory),[m
[32m+[m[32m      special: "file",[m
[32m+[m[32m      path: path,[m
[32m+[m[32m      isDirectory: isDirectory[m
[32m+[m[32m    }[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  function displayFilePath(path) {[m
[32m+[m[32m    const home = Quickshell.env("HOME")[m
[32m+[m[32m    if (path === home) return "~"[m
[32m+[m[32m    return path.startsWith(home + "/") ? "~" + path.substring(home.length) : path[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  function sortFileResults(items, term) {[m
[32m+[m[32m    const query = term.toLowerCase()[m
[32m+[m[32m    return items.sort((a, b) => {[m
[32m+[m[32m      const ar = root.fileRank(a.name.toLowerCase(), query)[m
[32m+[m[32m      const br = root.fileRank(b.name.toLowerCase(), query)[m
[32m+[m[32m      if (ar !== br) return ar - br[m
[32m+[m[32m      if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1[m
[32m+[m[32m      if (a.name.toLowerCase() !== b.name.toLowerCase()) return a.name.toLowerCase().localeCompare(b.name.toLowerCase())[m
[32m+[m[32m      return a.path.length - b.path.length[m
[32m+[m[32m    })[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  function fileRank(name, query) {[m
[32m+[m[32m    if (name === query) return 0[m
[32m+[m[32m    if (name.startsWith(query)) return 1[m
[32m+[m[32m    if (name.includes(query)) return 2[m
[32m+[m[32m    return 3[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  function fileGlyph(name, isDirectory) {[m
[32m+[m[32m    if (isDirectory) return "󰉋"[m
[32m+[m[32m    const ext = name.includes(".") ? name.split(".").pop().toLowerCase() : ""[m
[32m+[m[32m    if (["jpg", "jpeg", "png", "gif", "svg", "webp", "bmp", "ico"].includes(ext)) return "󰋩"[m
[32m+[m[32m    if (["mp3", "wav", "flac", "ogg", "m4a", "aac"].includes(ext)) return "󰎆"[m
[32m+[m[32m    if (["mp4", "mkv", "avi", "mov", "webm"].includes(ext)) return "󰎁"[m
[32m+[m[32m    if (["zip", "tar", "gz", "bz2", "xz", "7z", "rar"].includes(ext)) return "󰀼"[m
[32m+[m[32m    return "󰈔"[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Timer {[m
[32m+[m[32m    id: fileDebounce[m
[32m+[m[32m    interval: 250[m
[32m+[m[32m    onTriggered: root.startFileLookup()[m
[32m+[m[32m  }[m
[32m+[m
[32m+[m[32m  Process {[m
[32m+[m[32m    id: fileProc[m
[32m+[m[32m    stdout: StdioCollector { id: fileStdout }[m
[32m+[m[32m    stderr: StdioCollector { id: fileStderr }[m
[32m+[m[32m    onExited: code => root.finishFileLookup(code, fileStdout.text, fileStderr.text)[m
[32m+[m[32m  }[m
[32m+[m
   function resetDictSelection() {[m
     if (!resultsList || !dictTerm(root.query)) return[m
     resultsList.currentIndex = 0[m
[36m@@ -298,6 +478,8 @@[m [mScope {[m
   function getSpecialResults(qq) {[m
     const q = (qq || "").trim()[m
     if (!q) return null[m
[32m+[m[32m    const fileResults = getFileResults(q)[m
[32m+[m[32m    if (fileResults) return fileResults[m
     const dictResults = getDictResults(q)[m
     if (dictResults) return dictResults[m
     if (q.startsWith("=")) {[m
[36m@@ -387,6 +569,7 @@[m [mScope {[m
     values: {[m
       root.deVersion[m
       root.dictVersion[m
[32m+[m[32m      root.fileVersion[m
       root.webVersion[m
       const specials = root.getSpecialResults(root.query)[m
       if (specials && specials.length > 0) return specials[m
[36m@@ -521,6 +704,7 @@[m [mScope {[m
               onTextChanged: {[m
                 root.query = text[m
                 root.scheduleDictLookup()[m
[32m+[m[32m                root.scheduleFileLookup()[m
                 if (resultsList) resultsList.currentIndex = 0[m
               }[m
 [m
[36m@@ -632,7 +816,7 @@[m [mScope {[m
                 // Fallback letter icon[m
                 Text {[m
                   anchors.centerIn: parent[m
[31m-                  text: (delegateRoot.modelData.name ?? "?").charAt(0).toUpperCase()[m
[32m+[m[32m                  text: delegateRoot.modelData.glyph ?? (delegateRoot.modelData.name ?? "?").charAt(0).toUpperCase()[m
                   color: root.theme.accentPrimary[m
                   font.pixelSize: 16[m
                   font.family: "Hack Nerd Font"[m
[36m@@ -763,7 +947,7 @@[m [mScope {[m
           }[m
 [m
           Text {[m
[31m-            text: "=:calc  !:kagi  @:docs  dict:translate"[m
[32m+[m[32m            text: "=:calc  !:kagi  @:docs  dict:translate  >:files"[m
             color: Style.text[m
             font.pixelSize: 10[m
             font.family: "Hack Nerd Font"[m
[1mdiff --git a/asahi/quickshell/remix/shell.qml b/asahi/quickshell/remix/shell.qml[m
[1mindex f7b7d84..942e96a 100644[m
[1m--- a/asahi/quickshell/remix/shell.qml[m
[1m+++ b/asahi/quickshell/remix/shell.qml[m
[36m@@ -514,6 +514,10 @@[m [mVariants {[m
           else l.shouldShow = true[m
         }[m
       }[m
[32m+[m[32m      function files(query: string) {[m
[32m+[m[32m        const l = launcherLoader.item[m
[32m+[m[32m        if (l && l.openFileSearch) l.openFileSearch(query || "")[m
[32m+[m[32m      }[m
     }[m
 [m
     Loader {[m
