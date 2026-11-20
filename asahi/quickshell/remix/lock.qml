import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "modules/system" as System
import "modules/menu" as Menu

// Session lock (2026-11-20, his pick over hyprlock; logic after shell-ninja/hyprconf): hyprlock's layout — hostname
// under the cutout, at the bottom [uptime / battery] [Touch ID orb over the password] [clock / date] — with the
// orb's live states, a "●" password echo, a shake on a wrong password, a rise-in and a drop-out before the session
// unlocks. Nothing attaches to the notch (his call: the island card was rejected). Run by asahi-lock (`locker` =
// quickshell), never by the shell: `qs -n -p <this file>`.
// PAM from LOCK_PAM_DIR (asahi/quickshell/lockpam): `fingerprint` (pam_fprintd, re-armed until 3 no-matches) beside
// `password` (pam_unix), like hyprlock's fprintd claim + password PAM. "Unlocked, exiting!" on stderr = hyprlock's line:
// asahi-lock's guard and the wallpaper intro key on it. LOCK_DEMO=1: no PAM, states over IPC (screenshots only);
// LOCK_IPC_SUBMIT=1: an IPC `submit` for tests (still PAM: it cannot unlock without the password).
ShellRoot {
  id: lock

  readonly property bool demo: Quickshell.env("LOCK_DEMO") === "1"
  readonly property string pamDir: Quickshell.env("LOCK_PAM_DIR") || (Quickshell.env("HOME") + "/.dotfiles/asahi/quickshell/lockpam")
  property bool shown: false             // the UI's entrance / exit; the lock itself holds until `released`
  property string phase: "idle"          // idle | typing | checking | wrong | ok
  property string pw: ""
  property int wrong: 0
  property int fpMisses: 0
  property var touch: ({ orb: "ready", tone: "accent", strong: "Touch ID ready", hint: "or type your password" })

  Timer { interval: 40; running: true; onTriggered: lock.shown = true }   // rise in once mapped

  function submit() {
    if (lock.pw === "" || lock.phase === "checking" || lock.phase === "ok") return
    lock.phase = "checking"
    if (lock.demo) return
    pwPam.start()
  }
  function failed() {
    lock.wrong++
    lock.pw = ""
    lock.phase = "wrong"
  }
  // Success: tell asahi-lock, let the UI drop out, then let the session go.
  function unlock() {
    if (lock.phase === "ok") return
    lock.phase = "ok"
    lock.touch = { orb: "match", tone: "ok", strong: "Unlocked", hint: "" }
    console.warn("Unlocked, exiting!")
    if (fpPam.active) fpPam.abort()
    foldTimer.start()
  }
  Timer { id: foldTimer; interval: 150; onTriggered: lock.shown = false }
  Timer { id: releaseTimer; interval: 220; running: !lock.shown && lock.phase === "ok"; onTriggered: sessionLock.locked = false }

  PamContext {
    id: pwPam
    configDirectory: lock.pamDir
    config: "password"
    onResponseRequiredChanged: if (responseRequired) respond(lock.pw)
    onCompleted: result => {
      if (result === PamResult.Success) lock.unlock()
      else lock.failed()
    }
  }

  // Touch ID: one long verify, re-armed after a timeout / suspend / lid close (fprintd drops the reader while the lid
  // is shut: retries every 5 s until it is back); 3 no-matches end it for this lock.
  PamContext {
    id: fpPam
    configDirectory: lock.pamDir
    config: "fingerprint"
    onMessageChanged: {
      const m = String(message || "").toLowerCase()
      if (m.indexOf("failed to match") >= 0) {
        lock.fpMisses++
        lock.touch = { orb: "nomatch", tone: "fail", strong: "No match", hint: lock.fpMisses >= 2 ? "last try" : "touch again" }
      } else if (m.indexOf("place") >= 0 || m.indexOf("swipe") >= 0) {
        lock.touch = { orb: "ready", tone: "accent", strong: "Touch ID ready", hint: "or type your password" }
      }
    }
    onCompleted: result => {
      if (result === PamResult.Success) { lock.unlock(); return }
      if (lock.phase === "ok") return
      if (lock.fpMisses >= 3) {
        lock.touch = { orb: "failed", tone: "warn", strong: "Too many tries", hint: "type your password" }
        return
      }
      lock.touch = { orb: "failed", tone: "warn", strong: "Touch ID unavailable", hint: "type your password" }
      fpRetry.restart()
    }
  }
  Timer { id: fpRetry; interval: 5000; onTriggered: if (!lock.demo && lock.phase !== "ok" && !fpPam.active) fpPam.start() }
  Component.onCompleted: if (!lock.demo) fpPam.start()

  IpcHandler {
    target: "lock"
    enabled: lock.demo   // states for screenshots; never in a real lock
    function state(p: string): void {
      if (p === "typing") { lock.pw = "hunter22"; lock.phase = "typing" }
      else if (p === "reading") lock.touch = { orb: "reading", tone: "accent2", strong: "Reading", hint: "" }
      else if (p === "wrong") { lock.pw = "x"; lock.failed() }
      else if (p === "unlock") lock.unlock()
      else { lock.phase = "idle"; lock.pw = "" }
    }
  }
  IpcHandler {
    target: "locktest"
    enabled: Quickshell.env("LOCK_IPC_SUBMIT") === "1" && !lock.demo
    function submit(pw: string): void { lock.pw = pw; lock.submit() }
  }

  // Seconds tick only on the lock (hyprlock did the same): one label, once a second.
  SystemClock { id: clock; precision: SystemClock.Seconds }
  readonly property string themeDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/asahi-theme"
  FileView { id: uptimeFile; path: "/proc/uptime" }
  Timer { interval: 60000; running: true; repeat: true; onTriggered: uptimeFile.reload() }
  readonly property string uptime: {
    const s = Math.floor(Number(String(uptimeFile.text() || "0").split(" ")[0]) || 0)
    const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
    return d > 0 ? "up " + d + "d " + h + "h" : h > 0 ? "up " + h + "h " + String(m).padStart(2, "0") + "m" : "up " + m + "m"
  }
  readonly property var battery: UPower.displayDevice
  readonly property string batteryText: !lock.battery || !lock.battery.ready ? ""
    : Math.round(lock.battery.percentage * 100) + "% · " + (lock.battery.state === UPowerDeviceState.Charging ? "Charging"
      : lock.battery.state === UPowerDeviceState.FullyCharged ? "Full"
      : lock.battery.state === UPowerDeviceState.PendingCharge ? "Holding" : "On battery")

  WlSessionLock {
    id: sessionLock
    locked: true
    onLockedChanged: if (!locked) Qt.quit()

    WlSessionLockSurface {
      id: surf
      color: "black"
      readonly property real enter: lock.shown ? 1 : 0
      property real reveal: 0
      Behavior on reveal { Menu.MenuAnim { exit: !lock.shown } }
      onEnterChanged: reveal = enter
      Component.onCompleted: reveal = enter

      // The sharp wallpaper (no blur on the lock: his pick) and the scheme's two fades (asahi-autotheme), as hyprlock.
      Image {
        anchors.fill: parent
        source: "file://" + (Quickshell.env("LOCK_WALL") || Quickshell.env("HOME") + "/.local/state/asahi/lock-screen")
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
      }
      Image {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.round(parent.height * 0.32)
        source: "file://" + lock.themeDir + "/lock-fade-bottom.png"
        fillMode: Image.Stretch
        opacity: surf.reveal
      }
      Image {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: Math.round(parent.height * 0.13)
        source: "file://" + lock.themeDir + "/lock-fade-top.png"
        fillMode: Image.Stretch
        opacity: surf.reveal
      }

      // Hostname under the cutout (rows the notch covers + air), plain text: nothing hangs off the notch.
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: (String(surf.screen?.name || "").indexOf("eDP") === 0 ? 37 : 0) + 22
        text: String(hostFile.text() || "").trim()
        color: Style.m3onSurface
        opacity: surf.reveal
        font.family: Style.fontMono; font.pixelSize: 17
      }
      FileView { id: hostFile; path: "/etc/hostname" }

      // Bottom: rises in (the shared spring), drops out on unlock (the exit curve).
      Item {
        id: bottomRow
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 46 }
        height: centre.implicitHeight
        opacity: surf.reveal
        transform: Translate { y: (1 - surf.reveal) * 24 }

        // Left: uptime / battery, centred 416 px left of the middle (hyprlock's row).
        Column {
          anchors { horizontalCenter: parent.horizontalCenter; horizontalCenterOffset: -416; bottom: parent.bottom; bottomMargin: 4 }
          spacing: 6
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: lock.uptime
            color: Style.m3onSurface
            font.family: Style.fontMono; font.pixelSize: 19
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            text: lock.batteryText
            color: Style.m3onSurfaceVariant
            font.family: Style.fontMono; font.pixelSize: 15
          }
        }

        // Centre: the Touch ID orb and its line over the password pill.
        ColumnLayout {
          id: centre
          anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
          width: 416
          spacing: 10
          transform: Translate { id: shakeX }

          System.TouchIdOrb {
            Layout.alignment: Qt.AlignHCenter
            size: 64
            view: lock.touch
            live: surf.reveal > 0.5
          }
          System.TouchIdLine {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 16
            view: lock.touch
            live: surf.reveal > 0.5
            pixelSize: 12
          }
          // Password pill: a "●" echo with air between the dots, accent rim while typing, red after a miss.
          Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 6
            implicitHeight: 56
            radius: height / 2
            color: Style.m3surfaceSolid
            border.width: lock.phase === "idle" ? 1.5 : 2
            border.color: lock.phase === "wrong" ? Style.red : lock.phase === "ok" ? Style.green
              : lock.pw !== "" ? Style.vivid : Qt.alpha(Style.vivid, 0.55)
            Behavior on border.color { ColorAnimation { duration: Style.menuStateMs } }
            Text {
              anchors.centerIn: parent
              text: lock.phase === "checking" ? "Checking…"
                : lock.pw === "" ? (lock.phase === "wrong" ? "Wrong password · " + lock.wrong : "Password")
                : "●".repeat(Math.min(lock.pw.length, 24))
              color: lock.pw === "" || lock.phase === "checking" ? (lock.phase === "wrong" ? Style.red : Style.m3onSurfaceVariant) : Style.m3onSurface
              font.family: lock.pw === "" || lock.phase === "checking" ? Style.fontUi : Style.fontMono
              font.pixelSize: lock.pw === "" || lock.phase === "checking" ? 15 : 16
              font.letterSpacing: lock.pw === "" || lock.phase === "checking" ? 0 : 3
            }
          }
        }

        // Right: hours bold, seconds in the accent (hyprlock's clock), the date under it.
        Column {
          anchors { horizontalCenter: parent.horizontalCenter; horizontalCenterOffset: 416; bottom: parent.bottom; bottomMargin: 4 }
          spacing: 4
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.StyledText
            text: "<b>" + Qt.formatTime(clock.date, "HH:mm") + "</b><font color='" + Style.vivid + "'>:" + Qt.formatTime(clock.date, "ss") + "</font>"
            color: Style.m3onSurface
            font.family: Style.fontMono; font.pixelSize: 30
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.date, "dddd  ·  d MMMM")
            color: Style.m3onSurfaceVariant
            font.family: Style.fontMono; font.pixelSize: 15
          }
        }
      }

      // hyprconf's wrong-password shake: −14 / 14 / −8 / 8 / 0, 40 ms each.
      SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeX; property: "x"; to: -14; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: 14; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: -8; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: 8; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 40; easing.type: Easing.OutQuad }
      }
      Connections { target: lock; function onWrongChanged() { shake.restart() } }

      Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
          if (lock.phase === "ok" || lock.phase === "checking") return
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) lock.submit()
          else if (event.key === Qt.Key_Escape) lock.pw = ""
          else if (event.key === Qt.Key_Backspace) lock.pw = lock.pw.slice(0, -1)
          else if (event.text !== "") { lock.pw += event.text; lock.phase = "typing" }
          event.accepted = true
        }
      }
    }
  }
}
