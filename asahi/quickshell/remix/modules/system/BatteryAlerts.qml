import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "battery_alerts.js" as Alerts

// Low / critical battery cards (idea: caelestia's BatteryMonitor). Was asahi-battery-alertd, a bash loop waking every
// 30 s to read sysfs; this follows UPower's own change signals, which the bar's battery chip already listens to: no
// wakeups of its own. Cards via notify-send as before (NotificationCenter's "Asahi Battery" rules: one card at a time,
// shown under Do Not Disturb). The critical repeat timer runs only while critical on battery.
Scope {
  id: root

  readonly property var dev: UPower.displayDevice
  readonly property int pct: dev.ready ? Math.round(dev.percentage * 100) : 100
  readonly property bool plugged: !UPower.onBattery
  property var alertState: Alerts.initial()

  function check() {
    if (!root.dev.ready) return
    const r = Alerts.next(root.alertState, root.pct, root.plugged, Date.now())
    root.alertState = r.state
    if (r.card) Quickshell.execDetached(["notify-send", "-a", "Asahi Battery", "-u", r.card[3], "-t", String(r.card[2]),
      "-i", "battery-alert", r.card[0], r.card[1]])
  }
  onPctChanged: root.check()
  // The charger's chime (macOS MagSafe feel; ideas: Ryoku, end-4). UPower's first readings after a start only set the
  // baseline: chimes from 3 s on (on AC at start nothing changes, so a flag set by a change left the first unplug silent).
  property bool seenPlug: false
  onPluggedChanged: {
    root.check()
    if (root.dev.ready && root.seenPlug)
      Quickshell.execDetached(["paplay", "/usr/share/sounds/freedesktop/stereo/" + (root.plugged ? "power-plug" : "power-unplug") + ".oga"])
  }
  Timer { interval: 3000; running: root.dev.ready; onTriggered: root.seenPlug = true }

  Timer {
    interval: 60000
    repeat: true
    running: !root.plugged && root.pct <= Alerts.CRITICAL
    onTriggered: root.check()
  }
}
