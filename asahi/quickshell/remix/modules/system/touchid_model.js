// Touch ID prompt state for TouchIdPrompt.qml and the polkit card (also run by touchid_model_test.js under node).
// Events come from asahi-touchid-monitor (fprintd signals + who asked) and from aurora-fidod's "Touch ID"
// notification (its title names the site: "Touch ID to sign in to github.com"). Pure: state in, state out.
//
// phase: hidden | waiting | reading | match | nomatch | retry | failed | ending
//   waiting  fprintd wants a finger (orb breathes)        reading  a finger landed: until the result
//   match    green, then hidden                           nomatch  red; back to waiting if pam tries again
//   retry    amber: not read, back to waiting             failed   crossed fingerprint + why, then hidden
//   ending   fprintd stopped waiting; a status may follow
// fprintd (1.94.5 device.c): VerifyStatus goes out at once, the finger-present / finger-needed properties after it
// (PropertiesChanged from an idle); a no-match is always `done` and so is a cancelled verify (sudo's Ctrl+C);
// pam_fprintd starts a new verify (`start`) for each try. Some drivers drop "needed" once the finger is down.
// suppressed: something else draws this request (the lock screen, remix/lock.qml; polkit: the PolkitAgent card, which shows
// this state in its own orb). The notch card stays hidden (visible()); the state still runs.
// view(): the orb and its line, worded like the lock screen (remix/lock.qml).

var MATCH_MS = 900
var NOMATCH_MS = 1400
var FAILED_MS = 2400
var ENDING_MS = 450
// A read with no result (it takes about a second): stop showing it.
var READING_MS = 6000
// aurora-fidod notifies, then starts the verify: a note older than this belongs to an earlier request.
var FIDO_NOTE_MS = 5000

function initial() {
  // finger: fprintd's finger-present, whatever the phase; retried: pam started its next try after a miss.
  return { phase: "hidden", suppressed: false, info: null, note: "", tone: "", until: 0, fido: null, finger: false,
    retried: false }
}

function visible(s) {
  return s.phase !== "hidden" && !s.suppressed
}

function withPhase(s, phase, until, note, tone) {
  return Object.assign({}, s, { phase: phase, until: until || 0, note: note || "", tone: tone || "", retried: false })
}

var RETRY = { "verify-retry-scan": 1, "verify-swipe-too-short": 1, "verify-finger-not-centered": 1,
  "verify-remove-and-retry": 1, "verify-too-fast": 1 }

// Why Touch ID gave up: [note, tone] (fail = red, warn = amber).
function failure(result) {
  if (result === "verify-no-match") return ["No match", "fail"]
  if (result === "verify-lockout") return ["Touch ID locked", "fail"]
  if (result.indexOf("verify-password-required") === 0) return ["Password needed to re-enable Touch ID", "warn"]
  if (result === "verify-disconnected") return ["Touch ID disconnected", "warn"]
  return ["Touch ID unavailable", "warn"]
}

// orb = TouchIdOrb.phase; tone = accent | accent2 | ok | fail | warn; `strong` is the line's bold part in the tone,
// `hint` its muted rest.
function view(s) {
  switch (s.phase) {
    case "hidden": return { orb: "off", tone: "", strong: "", hint: "" }
    case "reading": return { orb: "reading", tone: "accent2", strong: "Reading", hint: "" }
    case "match": return { orb: "match", tone: "ok", strong: "Approved", hint: "" }
    case "nomatch": return { orb: "nomatch", tone: "fail", strong: "No match", hint: "touch again" }
    case "retry": return { orb: "retry", tone: "warn", strong: "Not read", hint: "touch again" }
    case "failed": return { orb: "failed", tone: s.tone || "warn", strong: s.note || "Touch ID unavailable",
      hint: "type your password" }
  }
  return { orb: "ready", tone: "accent", strong: "Touch ID ready", hint: "" }   // waiting, ending
}

function reduce(s, ev, now) {
  if (!ev || !ev.ev) return s
  switch (ev.ev) {
    case "start": {
      var info = { kind: ev.kind || "other", title: String(ev.title || "Touch ID"), detail: String(ev.detail || ""),
        app: String(ev.app || ""), address: String(ev.address || "") }
      if (info.kind === "fido" && s.fido && now - s.fido.at <= FIDO_NOTE_MS) info.title = s.fido.title
      // The next try of the same request (pam_fprintd and aurora-fidod start a new verify per try) keeps its miss.
      if (s.phase !== "hidden" && s.phase !== "ending" && s.info && s.info.kind === info.kind
          && s.info.title === info.title && s.suppressed === !!ev.suppress)
        return s.phase === "nomatch" || s.phase === "retry" ? Object.assign({}, s, { retried: true }) : withPhase(s, "waiting")
      return Object.assign(withPhase(s, "waiting"), { suppressed: !!ev.suppress, info: info, finger: false })
    }
    case "present": {
      // A lift does not end the read: the result follows it (fprintd sends no lift).
      var next = Object.assign({}, s, { finger: !!ev.value })
      if (ev.value && (s.phase === "waiting" || s.phase === "ending")) return withPhase(next, "reading", now + READING_MS)
      return next
    }
    case "status": {
      if (!s.info) return s
      var r = String(ev.result || "")
      if (r === "verify-match") return withPhase(s, "match", now + MATCH_MS)
      if (RETRY[r]) return withPhase(s, "retry", now + NOMATCH_MS)
      // A no-match with no finger down is a cancelled verify (sudo's Ctrl+C), not a miss.
      if (r === "verify-no-match")
        return s.finger || s.phase === "reading" ? withPhase(s, "nomatch", now + NOMATCH_MS) : withPhase(s, "ending", now + ENDING_MS)
      var why = failure(r)
      return withPhase(s, "failed", now + FAILED_MS, why[0], why[1])
    }
    case "needed":
      // fprintd stopped waiting for a finger: cancelled, or a result follows. During a read it means nothing: some
      // drivers drop "needed" as the finger lands (ending the card there hid it before every result).
      if (!ev.value && s.phase === "waiting") return withPhase(s, "ending", now + ENDING_MS)
      return s
    case "gone":
      return Object.assign(initial(), { fido: s.fido })
    case "fidoNote": {
      var fido = { title: String(ev.title || ""), at: now }
      var next = Object.assign({}, s, { fido: fido })
      if (s.phase !== "hidden" && s.info && s.info.kind === "fido")
        next.info = Object.assign({}, s.info, { title: fido.title })
      // aurora-fido >= 0.2: the Secure Enclave reads the finger, no fprintd verify (no "start"): the note opens the card.
      if (s.phase === "hidden")
        return Object.assign(withPhase(next, "waiting"), { suppressed: false,
          info: { kind: "fido", title: fido.title, detail: "Security key request", app: "", address: "" } })
      return next
    }
    case "fidoClosed":
      // aurora-fidod closes its note when the request ends (match, cancel, timeout): a waiting card goes.
      if (s.info && s.info.kind === "fido" && (s.phase === "waiting" || s.phase === "reading"))
        return withPhase(s, "ending", now + ENDING_MS)
      return s
    case "tick":
      if (!s.until || now < s.until) return s
      if (s.phase === "retry") return withPhase(s, "waiting")   // fprintd restarts a retry itself
      // After a miss: the next try, or that was the last one (pam_fprintd: 3) and the password comes.
      if (s.phase === "nomatch") return s.retried ? withPhase(s, "waiting") : withPhase(s, "failed", now + FAILED_MS, "No match", "fail")
      if (s.phase === "reading") return withPhase(s, "ending", now + ENDING_MS)
      return Object.assign(initial(), { fido: s.fido })
  }
  return s
}
