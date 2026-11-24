// CPU/MEM click panel: tooltips, ps, sensor JSON.
// QML: import "../sys_panel.js" as Sys

function parseCpuTooltip(tooltip) {
  const text = String(tooltip || "")
  const load = text.match(/Load 1\/5\/15:\s+(\S+)\s+(\S+)\s+(\S+)/) || []
  const temp = Number((text.match(/Thermal\s+([0-9.]+)/) || [])[1])
  // PSI avg10 (asahi-cpu "Pressure cpu X% mem Y%"): NaN when the kernel has none.
  const psi = text.match(/Pressure cpu\s+([0-9.]+)%\s+mem\s+([0-9.]+)%/) || []
  return {
    psiCpu: psi[1] !== undefined ? Number(psi[1]) : NaN,
    psiMem: psi[2] !== undefined ? Number(psi[2]) : NaN,
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
  const zram = text.match(/Zram\s+[0-9.]+\s+GiB in\s+[0-9.]+\s+GiB\s+\(([0-9.]+)x\)/)
  return {
    zramRatio: zram ? zram[1] : "",
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

function hottest(sensors, n) {
  const list = (sensors || []).slice()
  list.sort(function (a, b) { return (b.value || 0) - (a.value || 0) })
  return list.slice(0, n == null ? 3 : n)
}

// hwmon labels like "temp1" say nothing; fall back to the chip name.
function sensorLabel(s) {
  const label = String((s && s.label) || "")
  if (label && !/^temp\d+$/i.test(label)) return label
  const name = String((s && s.name) || "")
  return ({ tas2764: "Speaker amp", nvme: "NVMe SSD" })[name] || name || label
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

// I/O tile (idea: Gren-95 SystemMonitor): system totals only, sampled while SysPanel is open.
// /proc/net/dev → bytes received / sent over physical links (wl*, en*, eth*): a VPN tunnel would count the same bytes twice.
function netTotals(text) {
  let rx = 0, tx = 0
  for (const line of String(text || "").split("\n")) {
    const m = line.match(/^\s*([^:\s]+):\s*(.*)$/)
    if (!m || !/^(wl|en|eth)/.test(m[1])) continue
    const f = m[2].trim().split(/\s+/).map(Number)
    rx += f[0] || 0
    tx += f[8] || 0
  }
  return { rx: rx, tx: tx }
}

// /proc/diskstats → bytes read / written by whole disks (nvme0n1, sda, mmcblk0; not their partitions), 512-byte sectors.
function diskTotals(text) {
  let rd = 0, wr = 0
  for (const line of String(text || "").split("\n")) {
    const f = line.trim().split(/\s+/)
    if (f.length < 10 || !/^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|mmcblk\d+)$/.test(f[2])) continue
    rd += (Number(f[5]) || 0) * 512
    wr += (Number(f[9]) || 0) * 512
  }
  return { rd: rd, wr: wr }
}

// Mirrored graph: `up` (download / read) above the midline, `down` (upload / write) below, one shared scale; sqrt so a
// trickle still shows next to a burst. Points normalised 0..1 (y 0.5 = midline).
function mirrorPoints(up, down) {
  const n = Math.min((up || []).length, (down || []).length)
  if (n < 2) return { up: [], down: [] }
  const max = Math.max(1, ...up.slice(-n), ...down.slice(-n))
  const pts = (h, sign) => h.slice(-n).map((v, i) => ({ x: i / (n - 1), y: 0.5 + sign * 0.5 * Math.sqrt(Math.max(0, v) / max) }))
  return { up: pts(up, -1), down: pts(down, 1) }
}

function fmtRate(bps) {
  const n = Math.max(0, Number(bps) || 0)
  if (n < 1024) return Math.round(n) + " B/s"
  if (n < 1048576) return (n / 1024).toFixed(n < 10240 ? 1 : 0) + " KB/s"
  return (n / 1048576).toFixed(1) + " MB/s"
}

// Heat bucket for a °C reading: 0 cool, 1 warm, 2 hot.
function heat(c) {
  const v = Number(c)
  return !isFinite(v) ? 0 : v >= 70 ? 2 : v >= 50 ? 1 : 0
}

// Heatpipe watts (SoC dissipation proxy): warm from 15 W, hot from 25 W.
function heatW(w) {
  const v = Number(w)
  return !isFinite(v) ? 0 : v >= 25 ? 2 : v >= 15 ? 1 : 0
}

function fanFraction(fan) {
  const rpm = Number(fan && fan.value)
  const min = Number(fan && fan.min)
  const max = Number(fan && fan.max)
  if (!isFinite(rpm) || !isFinite(min) || !isFinite(max) || max <= min) return 0
  return Math.max(0, Math.min(1, (rpm - min) / (max - min)))
}

// Per-core cells grouped by cluster (asahi-cpu `kind`: E = the lowest top clock, P = the rest), each with its mean
// percent; one unnamed group when the CPU is not hybrid.
function coreGroups(cores) {
  const all = cores || []
  const mean = cs => Math.round(cs.reduce((s, c) => s + (Number(c.percent) || 0), 0) / Math.max(1, cs.length))
  const e = all.filter(c => c.kind === "E")
  const p = all.filter(c => c.kind === "P")
  if (!e.length || !p.length) return [{ name: "", cores: all, avg: mean(all) }]
  return [{ name: "Efficiency", cores: e, avg: mean(e) }, { name: "Performance", cores: p, avg: mean(p) }]
}

function pressureClass(percent, warning, critical) {
  const v = Number(percent)
  if (!isFinite(v)) return "normal"
  if (v >= (critical == null ? 95 : critical)) return "critical"
  if (v >= (warning == null ? 80 : warning)) return "warning"
  return "normal"
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    parseCpuTooltip: parseCpuTooltip,
    parseMemTooltip: parseMemTooltip,
    parsePs: parsePs,
    hottest: hottest,
    sensorLabel: sensorLabel,
    sparkPoints: sparkPoints,
    netTotals: netTotals,
    diskTotals: diskTotals,
    mirrorPoints: mirrorPoints,
    fmtRate: fmtRate,
    heat: heat,
    heatW: heatW,
    fanFraction: fanFraction,
    coreGroups: coreGroups,
    pressureClass: pressureClass
  }
}
