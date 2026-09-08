// Fastfetch small-logo parse for the Quick hub.
// QML: import "hub_logo.js" as HubLogo
// Node: require("./hub_logo.js")

function stripAnsi(text) {
  return String(text || "")
    .replace(/\u001b\[[0-9;?]*[A-Za-z]/g, "")
    .replace(/\u001b\][^\u0007\u001b]*(?:\u0007|\u001b\\)/g, "")
    .replace(/\u001b[PX^_][\s\S]*?(?:\u001b\\|\u0007)/g, "")
    .replace(/\u001b./g, "")
}

// Fedora_small shades the right edge with trailing "...." (sometimes ",,");
// those look like a hollow gap once the art sits in its own column, and they
// used to paint over the OS/Kernel labels. Keep the solid glyphs only.
function trimShade(line) {
  return String(line || "")
    .replace(/\.+[.,]*\s*$/g, "")
    .replace(/\s+$/g, "")
}

function leftShift(lines) {
  const list = lines || []
  let pad = Infinity
  for (let i = 0; i < list.length; i++) {
    const m = String(list[i] || "").match(/^(\s*)/)
    const n = m ? m[1].length : 0
    if (n < pad) pad = n
  }
  if (!isFinite(pad) || pad <= 0) return list
  return list.map(function (l) { return String(l).slice(pad) })
}

function parseLogo(text) {
  const lines = String(text || "").split(/\n/)
  const logo = []
  for (let i = 0; i < lines.length; i++) {
    let line = stripAnsi(lines[i]).replace(/\r/g, "")
    // Title is right-padded on the first art row (user@host), not logo @ glyphs.
    line = line.replace(/\s{2,}[A-Za-z0-9._-]+@[A-Za-z0-9._-]+\s*$/, "")
    const trimmed = line.replace(/^\s+|\s+$/g, "")
    if (/^-{3,}$/.test(trimmed)) break
    if (trimmed.length === 0) continue
    if (/^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$/.test(trimmed)) continue
    logo.push(trimShade(line))
  }
  // Shared leading indent is empty layout width — it used to push
  // contentWidth over the fact columns and paint through them.
  return leftShift(logo)
}

function logoText(text) {
  return parseLogo(text).join("\n")
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    stripAnsi: stripAnsi,
    trimShade: trimShade,
    leftShift: leftShift,
    parseLogo: parseLogo,
    logoText: logoText
  }
}
