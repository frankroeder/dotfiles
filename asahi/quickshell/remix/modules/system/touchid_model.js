// Touch ID prompt state for TouchIdPrompt.qml (also run by touchid_model_test.js under node).
// Events come from asahi-touchid-monitor (fprintd signals + who asked) and from aurora-fidod's "Touch ID"
// notification (its title names the site: "Touch ID to sign in to github.com"). Pure: state in, state out.
//
// phase: hidden | waiting | reading | match | nomatch | failed | ending
//   waiting  fprintd wants a finger (card breathes)      reading  finger on the sensor (solid)
//   match    green, then hidden                         nomatch  red, back to waiting (fprintd retries)
//   failed   red with a note, then hidden               ending   fprintd stopped waiting; a status may follow

var MATCH_MS = 900
var NOMATCH_MS = 1400
var FAILED_MS = 2400
var ENDING_MS = 450
// aurora-fidod notifies, then starts the verify: a note older than this belongs to an earlier request.
var FIDO_NOTE_MS = 5000

function initial() {
  return { phase: "hidden", suppressed: false, info: null, note: "", until: 0, fido: null }
}

function visible(s) {
  return s.phase !== "hidden"
}

function withPhase(s, phase, note, until) {
  return Object.assign({}, s, { phase: phase, note: note || "", until: until || 0 })
}

var RETRY = { "verify-retry-scan": 1, "verify-swipe-too-short": 1, "verify-finger-not-centered": 1,
  "verify-remove-and-retry": 1, "verify-too-fast": 1 }

function failNote(result) {
  if (result === "verify-no-match") return "No match · use your password"
  if (result === "verify-lockout") return "Too many attempts · use your password"
  if (result.indexOf("verify-password-required") === 0) return "Enter your password to enable Touch ID"
  return "Touch ID unavailable"
}

function reduce(s, ev, now) {
  if (!ev || !ev.ev) return s
  switch (ev.ev) {
    case "start": {
      if (ev.suppress) return Object.assign(initial(), { suppressed: true, fido: s.fido })
      var info = { kind: ev.kind || "other", title: String(ev.title || "Touch ID"), detail: String(ev.detail || ""),
        app: String(ev.app || ""), address: String(ev.address || "") }
      if (info.kind === "fido" && s.fido && now - s.fido.at <= FIDO_NOTE_MS) info.title = s.fido.title
      // A retry of the same request (aurora-fidod starts a new verify per touch) keeps its card.
      if (visible(s) && s.info && s.phase !== "ending" && s.info.kind === info.kind && s.info.title === info.title)
        return Object.assign({}, s, { phase: s.phase === "nomatch" ? s.phase : "waiting", suppressed: false })
      return Object.assign(withPhase(s, "waiting"), { suppressed: false, info: info })
    }
    case "present":
      if (s.suppressed) return s
      if (ev.value && (s.phase === "waiting" || s.phase === "ending")) return withPhase(s, "reading")
      if (!ev.value && s.phase === "reading") return withPhase(s, "waiting")
      return s
    case "status": {
      if (s.suppressed || !s.info) return s
      var r = String(ev.result || "")
      if (r === "verify-match") return withPhase(s, "match", "", now + MATCH_MS)
      if (RETRY[r]) return withPhase(s, "nomatch", "Not read · touch again", now + NOMATCH_MS)
      if (r === "verify-no-match" && !ev.done) return withPhase(s, "nomatch", "No match · try again", now + NOMATCH_MS)
      return withPhase(s, "failed", failNote(r), now + FAILED_MS)
    }
    case "needed":
      if (ev.value || s.suppressed) return s
      if (s.phase === "waiting" || s.phase === "reading") return withPhase(s, "ending", "", now + ENDING_MS)
      return s
    case "gone":
      return Object.assign(initial(), { fido: s.fido })
    case "fidoNote": {
      var fido = { title: String(ev.title || ""), at: now }
      var next = Object.assign({}, s, { fido: fido })
      if (visible(s) && s.info && s.info.kind === "fido")
        next.info = Object.assign({}, s.info, { title: fido.title })
      return next
    }
    case "fidoClosed":
      // aurora-fidod closes its note when the request ends (match, cancel, timeout): a waiting card goes.
      if (s.info && s.info.kind === "fido" && (s.phase === "waiting" || s.phase === "reading"))
        return withPhase(s, "ending", "", now + ENDING_MS)
      return s
    case "tick":
      if (!s.until || now < s.until) return s
      if (s.phase === "nomatch") return withPhase(s, "waiting")
      return Object.assign(initial(), { fido: s.fido })
  }
  return s
}
