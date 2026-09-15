// ASCII cava frame ("v;v;...;v\n", ascii_max_range=100, 24 bars) → bar values for the media chip.
// QML: import "../cava_bars.js" as CavaBars

function parseFrame(line) {
  const parts = String(line || "").trim().split(";")
  const vs = []
  for (let i = 0; i < 24; i++) vs.push(Math.max(0, Math.min(100, parseInt(parts[i], 10) || 0)))
  return vs
}

function barHeight(value, maxH) {
  return Math.max(2, maxH * Math.max(0, Math.min(100, Number(value) || 0)) / 100)
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { parseFrame: parseFrame, barHeight: barHeight }
}
