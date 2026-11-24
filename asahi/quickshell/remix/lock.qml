import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "modules/system" as System
import "modules/menu" as Menu

// Session lock, the only locker (2026-11-20 his pick over hyprlock, which is gone since 2026-11-22; logic after
// shell-ninja/hyprconf), laid out like the old hyprlock screen — hostname under the cutout, at the bottom
// [uptime / battery] [Touch ID orb over the password] [clock / date] — with the orb's live states, a "●" password
// echo, a shake on a wrong password, a rise-in and the lift-off before the session unlocks. Nothing attaches to the
// notch (his call: the island card was rejected). Run by asahi-lock (`qs -p <this file>`), never by the shell.
// PAM from LOCK_PAM_DIR (asahi/quickshell/lockpam): `fingerprint` (pam_fprintd, re-armed until 3 no-matches) beside
// `password` (pam_unix). "Unlocked, exiting!" on stderr: asahi-lock's guard and the wallpaper intro key on it. LOCK_DEMO=1: no PAM, states over IPC (screenshots only);
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
  property bool fpRestarted: false      // fprintd restarted once this lock (a wedged reader)
  property bool fpReached: false        // this attempt reached the reader (it asked for a finger)
  property int fpFails: 0               // attempts in a row that never reached it (no reader, claim refused)
  property bool fpGaveUp: false         // 3 no-matches / MaxTries: password only for this lock
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
  // Success: tell asahi-lock, let the check land and the UI drop out, lift the lock off the desktop, let the session go.
  function unlock() {
    if (lock.phase === "ok") return
    lock.phase = "ok"
    lock.touch = { orb: "match", tone: "ok", strong: "Unlocked", hint: "" }
    console.warn("Unlocked, exiting!")
    if (fpPam.active) fpPam.abort()
    if (lock.blanked) Quickshell.execDetached([lock.dpms, "on"])   // Touch ID in the dark: light up for the desktop
    lock.xray(true)
    liftOff.start()
  }

  // Lift-off (2026-11-22, his pick of the unlock ideas): the wallpaper fades and grows a little, showing the real
  // desktop under it (windows, bar, the intro's first frame = this wallpaper). Hyprland's misc:session_lock_xray draws
  // the workspaces under a lock surface; it goes on only after PAM said yes (nothing is drawn under the lock before)
  // and off again at release and at every lock's start (one left on must not carry into the next lock).
  property real lift: 0
  function xray(on) { Quickshell.execDetached(["hyprctl", "eval", "hl.config({ misc = { session_lock_xray = " + on + " } })"]) }
  Component.onCompleted: { lock.xray(false); lock.startFingerprint() }
  SequentialAnimation {
    id: liftOff
    PauseAnimation { duration: 250 }                 // the orb's check lands
    ScriptAction { script: lock.shown = false }      // the UI drops out (exit curve, 180 ms)
    PauseAnimation { duration: 80 }
    NumberAnimation { target: lock; property: "lift"; to: 1; duration: 380; easing.type: Easing.InOutCubic }
    ScriptAction { script: sessionLock.locked = false }
  }

  // Displays off 30 s after the last key / pointer motion on the lock (omarchy quattro; a manual lock stayed lit until
  // hypridle's step, 150 / 300 s). A key or a motion lights them again (Hyprland key_press / mouse_move_enables_dpms);
  // hypridle's later steps (off, suspend) run as before. asahi-dpms touches only outputs in the other state.
  readonly property string dpms: Quickshell.env("HOME") + "/.dotfiles/asahi/bin/asahi-dpms"
  property bool blanked: false
  IdleMonitor {
    enabled: !lock.demo && lock.phase !== "ok"
    timeout: Number(Quickshell.env("LOCK_BLANK_S")) || 30
    respectInhibitors: false   // a video's idle inhibitor must not keep a locked screen lit
    onIsIdleChanged: {
      lock.blanked = isIdle
      if (isIdle) Quickshell.execDetached([lock.dpms, "off"])
      else lock.wakeFingerprint()
    }
  }

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

  // Touch ID: one long verify (pam_fprintd timeout 600 s), re-armed when it runs out; 3 no-matches or Aurora's
  // lockout end it for this lock. After omarchy quattro's lock: an attempt that never reached the reader (fprintd
  // drops it while the lid is shut, a refused claim) backs off 5, 10, 20, 40 s instead of retrying every 5 s all lock
  // long; the end of the blank (key / motion), a key, or a display arriving (lid open while docked) tries again at
  // once. No pause while the displays are off (tried 2026-11-23: a lid-open wake lights the panel without input, so
  // Touch ID stayed off until a key).
  function startFingerprint() {
    if (lock.demo || lock.phase === "ok" || lock.fpGaveUp || fpPam.active) return
    lock.fpReached = false
    fpPam.start()
  }
  function wakeFingerprint() {
    if (lock.fpGaveUp || fpPam.active) return
    lock.fpFails = 0
    fpRetry.stop()
    lock.startFingerprint()
  }
  Connections { target: Quickshell; function onScreensChanged() { lock.wakeFingerprint() } }
  PamContext {
    id: fpPam
    configDirectory: lock.pamDir
    config: "fingerprint"
    onMessageChanged: {
      const m = String(message || "").toLowerCase()
      // Aurora's SEP lockout (pam_fprintd: "Too many failed fingerprint attempts. Use your password." / "Your password
      // is required to enable / use Touch ID."): only the password ends it (pam_aurora_touchid in lockpam/password).
      if (m.indexOf("too many failed") >= 0 || m.indexOf("password is required") >= 0) {
        lock.fpGaveUp = true
        lock.touch = { orb: "failed", tone: "fail", strong: m.indexOf("too many") >= 0 ? "Touch ID locked" : "Password needed for Touch ID",
          hint: "type your password" }
      } else if (m.indexOf("failed to match") >= 0) {
        lock.fpReached = true
        lock.fpMisses++
        lock.touch = { orb: "nomatch", tone: "fail", strong: "No match", hint: lock.fpMisses >= 2 ? "last try" : "touch again" }
      } else if (m.indexOf("place") >= 0 || m.indexOf("swipe") >= 0) {
        lock.fpReached = true
        lock.touch = { orb: "ready", tone: "accent", strong: "Touch ID ready", hint: "or type your password" }
      }
    }
    onCompleted: result => {
      if (result === PamResult.Success) { lock.unlock(); return }
      if (lock.phase === "ok" || lock.fpGaveUp) return
      if (lock.fpMisses >= 3 || result === PamResult.MaxTries) {   // pam_fprintd's own count is final too
        lock.fpGaveUp = true
        lock.touch = { orb: "failed", tone: "warn", strong: "Too many tries", hint: "type your password" }
        return
      }
      if (lock.fpReached) {   // the verify ran out waiting for a finger: re-arm at once
        lock.fpFails = 0
        fpRetry.interval = 1000
      } else {
        lock.fpFails++
        fpRetry.interval = Math.min(40000, 5000 * Math.pow(2, lock.fpFails - 1))
        lock.touch = { orb: "failed", tone: "warn", strong: "Touch ID unavailable", hint: "type your password" }
        // A wedged fprintd (reader left open after a suspend mid-verify: every claim fails) only clears on a restart
        // (polkit rule 49-asahi-fprintd-restart); once per lock: PamContext claims afresh on the next try.
        if (!lock.fpRestarted && !lock.demo) {
          lock.fpRestarted = true
          Quickshell.execDetached(["systemctl", "--no-ask-password", "--no-block", "restart", "fprintd.service"])
        }
      }
      fpRetry.restart()
    }
  }
  Timer { id: fpRetry; interval: 5000; onTriggered: lock.startFingerprint() }

  IpcHandler {
    target: "lock"
    enabled: lock.demo   // states for screenshots; never in a real lock
    function state(p: string): void {
      if (p === "typing") { lock.pw = "hunter22"; lock.phase = "typing" }
      else if (p === "reading") lock.touch = { orb: "reading", tone: "accent2", strong: "Reading", hint: "" }
      else if (p === "wrong") { lock.pw = "x"; lock.failed() }
      else if (p === "unlock") lock.unlock()
      else if (p === "caps") lock.capsOn = !lock.capsOn
      else { lock.phase = "idle"; lock.pw = "" }
    }
  }
  IpcHandler {
    target: "locktest"
    enabled: Quickshell.env("LOCK_IPC_SUBMIT") === "1" && !lock.demo
    function submit(pw: string): void { lock.pw = pw; lock.submit() }
  }

  // Seconds tick only on the lock: one label, once a second.
  SystemClock { id: clock; precision: SystemClock.Seconds }
  readonly property string themeDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/asahi-theme"
  FileView { id: uptimeFile; path: "/proc/uptime" }
  Timer { interval: 60000; running: true; repeat: true; onTriggered: uptimeFile.reload() }
  readonly property string uptime: {
    const s = Math.floor(Number(String(uptimeFile.text() || "0").split(" ")[0]) || 0)
    const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
    return d > 0 ? "up " + d + "d " + h + "h" : h > 0 ? "up " + h + "h " + String(m).padStart(2, "0") + "m" : "up " + m + "m"
  }
  // Caps Lock (the CAPS tag) from the keyboards' LEDs, read on each key press, never polled; the layout from
  // Hyprland's main keyboard, once per lock.
  property var capsLeds: []
  property bool capsOn: false
  property string layout: ""
  Process {
    running: true
    command: ["sh", "-c", "for d in /sys/class/leds/*::capslock; do [ -r \"$d/brightness\" ] && echo \"$d/brightness\"; done"]
    stdout: StdioCollector { onStreamFinished: { lock.capsLeds = text.split("\n").filter(l => l !== ""); capsCheck.restart() } }
  }
  Instantiator {
    id: capsFiles
    model: lock.capsLeds
    delegate: FileView { required property string modelData; path: modelData; blockLoading: true }
  }
  // The LED follows the key a moment later: look after the press, not during it.
  Timer {
    id: capsCheck
    interval: 40
    onTriggered: {
      let on = false
      for (let i = 0; i < capsFiles.count; i++) {
        const f = capsFiles.objectAt(i)
        f.reload()
        if (Number(String(f.text()).trim()) > 0) on = true
      }
      lock.capsOn = on
    }
  }
  Process {
    running: true
    command: ["hyprctl", "devices", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const kbs = JSON.parse(text).keyboards || []
          const main = kbs.find(k => k.main) || kbs[0]
          lock.layout = main ? String(main.layout || "").split(",")[0] : ""
        } catch (e) {}
      }
    }
  }
  readonly property var battery: UPower.displayDevice
  readonly property string batteryText: !lock.battery || !lock.battery.ready ? ""
    : Math.round(lock.battery.percentage * 100) + "% · " + (lock.battery.state === UPowerDeviceState.Charging ? "Charging"
      : lock.battery.state === UPowerDeviceState.FullyCharged ? "Full"
      : lock.battery.state === UPowerDeviceState.PendingCharge ? "Holding" : "On battery")

  WlSessionLock {
    id: sessionLock
    locked: true
    onLockedChanged: if (!locked) { lock.xray(false); Qt.quit() }
    // The compositor confirmed the lock (every output covered): asahi-lock waits for this line, else the lock never
    // engaged (qs stays up after a QML load error, with no lock: fail-open) and it retries.
    onSecureStateChanged: if (secure) console.warn("Session locked")

    WlSessionLockSurface {
      id: surf
      color: Qt.rgba(0, 0, 0, 1 - lock.lift)
      readonly property real enter: lock.shown ? 1 : 0
      property real reveal: 0
      Behavior on reveal { Menu.MenuAnim { exit: !lock.shown } }
      onEnterChanged: reveal = enter
      Component.onCompleted: reveal = enter

      // The sharp wallpaper (no blur on the lock: his pick) and the scheme's two fades (asahi-autotheme).
      Image {
        anchors.fill: parent
        source: "file://" + (Quickshell.env("LOCK_WALL") || Quickshell.env("HOME") + "/.local/state/asahi/lock-screen")
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        opacity: 1 - lock.lift
        scale: 1 + 0.03 * lock.lift
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

        // Left: uptime / battery, centred 416 px left of the middle.
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
            breathe: false   // results still pop; a waiting loop would redraw every output all lock long
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
            Text {   // layout, the left-hand "de"
              anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
              visible: lock.layout !== ""
              text: lock.layout
              color: Style.m3onSurfaceVariant
              font.family: Style.fontMono; font.pixelSize: 13
            }
            Text {   // CAPS tag opposite it, only while Caps Lock is on
              anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
              visible: lock.capsOn
              text: "CAPS"
              color: Style.yellow
              font.family: Style.fontMono; font.pixelSize: 12; font.weight: Font.Bold
            }
            Text {
              anchors.centerIn: parent
              visible: lock.pw === "" || lock.phase === "checking"
              text: lock.phase === "checking" ? "Checking…"
                : lock.pw === "" ? (lock.phase === "wrong" ? "Wrong password · " + lock.wrong : "Password")
                : "●".repeat(Math.min(lock.pw.length, 24))
              color: lock.pw === "" || lock.phase === "checking" ? (lock.phase === "wrong" ? Style.red : Style.m3onSurfaceVariant) : Style.m3onSurface
              font.family: lock.pw === "" || lock.phase === "checking" ? Style.fontUi : Style.fontMono
              font.pixelSize: lock.pw === "" || lock.phase === "checking" ? 15 : 16
              font.letterSpacing: lock.pw === "" || lock.phase === "checking" ? 0 : 3
            }
            // Typed characters pop in one by one (caelestia InputField, end-4 PasswordChars): each dot springs 0 → 1
            // and cools from the accent to ink; deleting drops the last at once. Runs per key press only.
            Row {
              anchors.centerIn: parent
              visible: lock.pw !== "" && lock.phase !== "checking"
              spacing: 8
              Repeater {
                model: 24   // fixed slots: a count model rebuilt every dot on each key (all popped again)
                Rectangle {
                  id: dot
                  required property int index
                  visible: index < lock.pw.length
                  anchors.verticalCenter: parent.verticalCenter
                  width: 10; height: 10; radius: 5
                  color: Style.m3onSurface
                  onVisibleChanged: if (visible && !Style.reduceMotion) pop.restart()
                  ParallelAnimation {
                    id: pop
                    NumberAnimation { target: dot; property: "scale"; from: 0; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                    ColorAnimation { target: dot; property: "color"; from: Style.vivid; to: Style.m3onSurface; duration: 900 }
                  }
                }
              }
            }
          }
        }

        // Right: hours bold, seconds in the accent, the date under it.
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
          capsCheck.restart()
          if (fpRetry.running && lock.fpFails > 1) lock.wakeFingerprint()   // someone is here: skip a long backoff (once)
          if (lock.phase === "ok" || lock.phase === "checking") return
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) lock.submit()
          else if (event.key === Qt.Key_Escape) lock.pw = ""
          else if (event.key === Qt.Key_Backspace) lock.pw = Array.from(lock.pw).slice(0, -1).join("")   // whole code points
          // Printable text only: Delete, Tab and Ctrl combos carry control characters (a silent wrong password).
          else if (/^[^\x00-\x1f\x7f]+$/.test(event.text)) { lock.pw += event.text; lock.phase = "typing" }
          event.accepted = true
        }
      }
    }
  }
}
