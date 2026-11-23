.pragma library

// Low / critical battery cards (BatteryAlerts.qml; was asahi-battery-alertd). `next(state, pct, plugged, now)` →
// { state, card }: card = [title, body, timeout ms, urgency] or null. Low once at ≤ 20 %, critical at ≤ 10 % again every
// minute, and after an alert the charger gets one short low-urgency "Charging" card (the shell keeps one "Asahi
// Battery" card and never times a critical one out).
var LOW = 20
var CRITICAL = 10
var REPEAT_MS = 60000

function initial() { return { warned: false, criticalAt: 0 } }

function next(s, pct, plugged, now) {
  if (plugged || pct > LOW) {
    return { state: initial(), card: plugged && s.warned ? ["Charging · " + pct + "%", "", 4000, "low"] : null }
  }
  if (pct <= CRITICAL) {
    if (s.criticalAt > 0 && now - s.criticalAt < REPEAT_MS) return { state: s, card: null }
    return { state: { warned: true, criticalAt: now },
      card: ["Critical battery", "Battery at " + pct + "%. Connect charger.", 30000, "critical"] }
  }
  if (s.warned) return { state: s, card: null }
  return { state: { warned: true, criticalAt: s.criticalAt }, card: ["Low battery", "Battery at " + pct + "%.", 10000, "normal"] }
}

if (typeof module !== "undefined" && module.exports) module.exports = { next: next, initial: initial, LOW: LOW, CRITICAL: CRITICAL }
