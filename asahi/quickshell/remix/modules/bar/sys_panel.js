// CPU/MEM click panel: parse asahi-cpu / asahi-memory tooltips, ps, df.
// QML: import "../sys_panel.js" as Sys

function parseCpuTooltip(tooltip) {
  const text = String(tooltip || "")
  const load = text.match(/Load 1\/5\/15:\s+(\S+)\s+(\S+)\s+(\S+)/) || []
  const temp = Number((text.match(/Thermal\s+([0-9.]+)/) || [])[1])
  return {
    load: load[1] ? (load[1] + " " + load[2] + " " + load[3]) : "",
    cores: (text.match(/Cores:\s+(\S+)/) || [])[1] || "",
    freq: (text.match(/Freq avg\s+([0-9.]+\s*GHz)/) || [])[1] || "",
    temp: isFinite(temp) ? temp : NaN
  }
}

function parseMemTooltip(tooltip) {
  const text = String(tooltip || "").replace(/\\n/g, "\n")
  const ram = text.match(/RAM\s+([0-9.]+)\/([0-9.]+)\s+GiB/)
  const swap = text.match(/Swap\s+([0-9.]+)\/([0-9.]+)\s+GiB/)
  return {
    ramUsed: ram ? ram[1] : "",
    ramTotal: ram ? ram[2] : "",
    swapUsed: swap ? swap[1] : "",
    swapTotal: swap ? swap[2] : ""
  }
}

// ps -eo pcpu,comm --sort=-pcpu → top n, skipping ps itself.
function parsePs(stdout, n) {
  const out = []
  const lines = String(stdout || "").split("\n")
  for (let i = 0; i < lines.length && out.length < (n || 5); i++) {
    const m = lines[i].match(/^\s*([0-9.]+)\s+(.+)$/)
    if (!m || m[2].trim() === "ps") continue
    out.push({ cpu: Number(m[1]), comm: m[2].trim() })
  }
  return out
}

// df -h / → "Filesystem Size Used Avail Use% Mounted on"
function parseDfRoot(stdout) {
  const parts = (String(stdout || "").trim().split("\n").pop() || "").split(/\s+/)
  const pct = Number(String(parts[4] || "").replace("%", ""))
  return { size: parts[1] || "", used: parts[2] || "", pct: parts.length >= 6 && isFinite(pct) ? pct : -1 }
}

function hottest(sensors, n) {
  const list = (sensors || []).slice()
  list.sort(function (a, b) { return (b.value || 0) - (a.value || 0) })
  return list.slice(0, n == null ? 3 : n)
}

// Normalised 0..1 polyline for a Canvas of any size.
function sparkPoints(history) {
  const h = history || []
  if (h.length < 2) return []
  const pts = []
  for (let i = 0; i < h.length; i++) {
    pts.push({ x: i / (h.length - 1), y: 1 - Math.max(0, Math.min(100, Number(h[i]) || 0)) / 100 })
  }
  return pts
}

// Heat bucket for a °C reading: 0 cool, 1 warm, 2 hot.
function heat(c) {
  const v = Number(c)
  return !isFinite(v) ? 0 : v >= 70 ? 2 : v >= 50 ? 1 : 0
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    parseCpuTooltip: parseCpuTooltip,
    parseMemTooltip: parseMemTooltip,
    parsePs: parsePs,
    parseDfRoot: parseDfRoot,
    hottest: hottest,
    sparkPoints: sparkPoints,
    heat: heat
  }
}
