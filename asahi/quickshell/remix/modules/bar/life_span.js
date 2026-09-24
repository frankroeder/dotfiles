// 90-year life from a birth year. Each year starts on 1 January — the birthday
// itself is unknown. `today` is an argument; this file does not read the clock.

var LIFE_YEARS = 90

function decodeBirthYear(text) {
  if (text == null) return null
  var s = String(text).trim()
  if (!/^[0-9]{4}$/.test(s)) return null
  var n = parseInt(s, 10)
  if (!(n >= 1 && n <= 9999)) return null
  return n
}

function encodeBirthYear(year) {
  var n = asBirthYear(year)
  return n == null ? "" : String(n) + "\n"
}

// XDG state dir, else $HOME/.local/state — where a small persisted UI value belongs.
function birthStorePath(stateHome, home) {
  var root = String(stateHome == null ? "" : stateHome).trim().replace(/\/$/, "")
  if (!root) root = String(home == null ? "" : home).replace(/\/$/, "") + "/.local/state"
  return root + "/asahi/calendar-birth-year"
}

// A saved file wins, including an empty one (the year was cleared). BIRTH_YEAR is
// only used when that file is not there yet.
function resolveBirthYear(fileText, envText, filePresent) {
  if (filePresent) return decodeBirthYear(fileText)
  return decodeBirthYear(envText)
}

function asBirthYear(value) {
  if (typeof value === "number") {
    if (!isFinite(value) || Math.floor(value) !== value || value < 1 || value > 9999) return null
    return value
  }
  return decodeBirthYear(value)
}

function emptySpan() {
  return {
    set: false,
    birthYear: null,
    yearsLived: null,
    yearsLeft: null,
    percentLeft: null,
    cells: null
  }
}

function lifeSpan(birthYear, today) {
  var year = asBirthYear(birthYear)
  if (year == null) return emptySpan()
  if (!today || typeof today.getFullYear !== "function") return emptySpan()

  var y = today.getFullYear()
  var elapsed = y - year
  if (elapsed < 0) elapsed = 0
  if (elapsed > LIFE_YEARS) elapsed = LIFE_YEARS
  var before = y < year
  var cells = new Array(LIFE_YEARS)
  for (var i = 0; i < LIFE_YEARS; i++) {
    if (before) cells[i] = "left"
    else if (i < elapsed) cells[i] = "lived"
    else if (i === elapsed) cells[i] = "now"
    else cells[i] = "left"
  }
  var left = LIFE_YEARS - elapsed
  return {
    set: true,
    birthYear: year,
    yearsLived: elapsed,
    yearsLeft: left,
    percentLeft: Math.round(left / LIFE_YEARS * 100),
    cells: cells
  }
}
