// Temperature grouping → one-number-per-row display model for the Quick pane.
// QML: import "temp_display.js" as TempDisplay
// Node: require("./temp_display.js")

var GROUP_NAME_MAP = {
  macsmc_hwmon: "SMC Sensors",
  tas2764: "Speaker Amps",
  macsmc_battery: "Battery",
  nvme: "NVMe SSD"
}

function parseReading(line, unit) {
  const escaped = unit.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  const re = new RegExp("^\\s*(\\S+)\\s+(.+?)\\s+(-?\\d+(?:\\.\\d+)?) " + escaped + "\\s+(.+)$")
  const sm = String(line || "").match(re)
  if (!sm) return null
  return { name: sm[1], label: sm[2].trim(), value: Number(sm[3]), path: sm[4].trim() }
}

function parseTemperatures(out) {
  const sensors = []
  const power = []
  const fans = []
  let heatpipe = null
  let groupName = ""
  let groupPath = ""
  let groupKind = "temp"
  let last = null
  let summary = false
  const lines = String(out || "").split("\n")
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    // Trailing "Hottest:" / "Heatpipe:" blocks repeat a sensor on the next line.
    if (line.indexOf("Hottest:") === 0 || line.indexOf("Heatpipe:") === 0) { summary = true; continue }
    if (summary) continue
    const gm = line.match(/^>>> (.+?) \((.+)\)$/)
    if (gm) {
      const rawName = gm[1]
      groupKind = / power$/.test(rawName) ? "power" : / fans$/.test(rawName) ? "fans" : "temp"
      groupName = rawName.replace(/ (power|fans)$/, "")
      groupPath = gm[2]
      last = null
      continue
    }
    if (groupKind === "power") {
      const rec = parseReading(line, "W")
      if (rec) {
        last = {
          group: groupName, groupPath: groupPath, name: rec.name, label: rec.label,
          displayLabel: rec.label, value: rec.value, unit: "W", path: rec.path, desc: ""
        }
        power.push(last)
        if (/heatpipe/i.test(rec.label)) heatpipe = last
        continue
      }
    }
    if (groupKind === "fans") {
      const rec = parseReading(line, "RPM")
      if (rec) {
        last = {
          group: groupName, groupPath: groupPath, name: rec.name, label: rec.label,
          displayLabel: rec.label, value: rec.value, unit: "RPM", path: rec.path,
          desc: "", min: NaN, max: NaN
        }
        fans.push(last)
        continue
      }
      const bounds = String(line).match(/^\s+(\d+)\s*[–-]\s*(\d+)\s*RPM/)
      if (bounds && last && last.unit === "RPM") {
        last.min = Number(bounds[1])
        last.max = Number(bounds[2])
        continue
      }
    }
    const sm = line.match(/^\s*(\S+)\s+(.+?)\s+(-?\d+(?:\.\d+)?)°C\s+(.+)$/)
    if (sm) {
      const keyName = groupName || sm[1]
      const keyPath = groupPath || sm[4].trim().replace(/\/temp[^/]+$/, "")
      last = {
        group: keyName,
        groupPath: keyPath,
        groupKey: keyName + "|" + keyPath,
        name: sm[1],
        label: sm[2].trim(),
        displayLabel: sm[2].trim(),
        value: Number(sm[3]),
        path: sm[4].trim(),
        desc: ""
      }
      sensors.push(last)
      continue
    }
    const dm = line.match(/^\s{4}(.+)$/)
    if (dm && last) last.desc = dm[1].trim()
  }

  const groups = []
  for (let s = 0; s < sensors.length; s++) {
    const sensor = sensors[s]
    let g = null
    for (let gi = 0; gi < groups.length; gi++) {
      if (groups[gi].key === sensor.groupKey) {
        g = groups[gi]
        break
      }
    }
    if (!g) {
      g = { key: sensor.groupKey, name: sensor.group, path: sensor.groupPath, sensors: [], max: sensor.value }
      groups.push(g)
    }
    g.sensors.push(sensor)
    g.max = Math.max(g.max, sensor.value)
  }

  const sourceCounts = {}
  for (let gi = 0; gi < groups.length; gi++) {
    const n = groups[gi].name
    sourceCounts[n] = (sourceCounts[n] || 0) + 1
  }
  const sourceSeen = {}
  for (let gi = 0; gi < groups.length; gi++) {
    const g = groups[gi]
    const baseName = GROUP_NAME_MAP[g.name] || g.name
    sourceSeen[g.name] = (sourceSeen[g.name] || 0) + 1
    g.displayName = sourceCounts[g.name] > 1 ? (baseName + " " + sourceSeen[g.name]) : baseName
    const labelCounts = {}
    for (let si = 0; si < g.sensors.length; si++) {
      const lab = g.sensors[si].label
      labelCounts[lab] = (labelCounts[lab] || 0) + 1
    }
    const labelSeen = {}
    for (let si = 0; si < g.sensors.length; si++) {
      const s = g.sensors[si]
      labelSeen[s.label] = (labelSeen[s.label] || 0) + 1
      s.displayLabel = labelCounts[s.label] > 1 ? (s.label + " " + labelSeen[s.label]) : s.label
      s.groupDisplayName = g.displayName
    }
    let shared = null
    if (g.sensors.length > 0) {
      shared = g.sensors[0].desc || ""
      for (let si = 1; si < g.sensors.length; si++) {
        if ((g.sensors[si].desc || "") !== shared) {
          shared = null
          break
        }
      }
      if (shared === "") shared = null
    }
    g.sharedDesc = shared
    for (let si = 0; si < g.sensors.length; si++) g.sensors[si].sharedDesc = g.sharedDesc
  }
  groups.sort(function (a, b) { return b.max - a.max })

  let hottest = null
  for (let s = 0; s < sensors.length; s++) {
    if (!hottest || sensors[s].value > hottest.value) hottest = sensors[s]
  }
  return { sensors: sensors, groups: groups, hottest: hottest, power: power, fans: fans, heatpipe: heatpipe }
}

function tempDisplayRows(groups) {
  const rows = []
  const list = groups || []
  for (let gi = 0; gi < list.length; gi++) {
    const g = list[gi]
    const sensors = g.sensors || []
    if (sensors.length <= 1) {
      const s = sensors[0] || {}
      rows.push({
        kind: "item",
        title: g.displayName || g.name || s.displayLabel || s.label || "",
        value: s.value,
        desc: s.desc || "",
        path: s.path || "",
        sensors: []
      })
      continue
    }
    const children = []
    for (let si = 0; si < sensors.length; si++) {
      const s = sensors[si]
      children.push({
        kind: "item",
        title: s.displayLabel || s.label || "",
        value: s.value,
        desc: (si === 0 || !s.sharedDesc) ? (s.desc || "") : "",
        path: s.path || ""
      })
    }
    rows.push({
      kind: "group",
      title: g.displayName || g.name || "",
      value: null,
      desc: "",
      sensors: children
    })
  }
  return rows
}

function rowKey(row) {
  return String((row && (row.path || row.title)) || "")
}

function structureKey(rows) {
  const parts = []
  const list = rows || []
  for (let i = 0; i < list.length; i++) {
    const r = list[i]
    parts.push(r.kind || "", r.title || "", rowKey(r))
    const kids = r.sensors || []
    for (let j = 0; j < kids.length; j++) parts.push(rowKey(kids[j]), kids[j].title || "")
  }
  // ASCII delimiter: QML's JS import treats a NUL join as a non-function, and
  // TempPane then never applies the parse (hero stuck on "No sensors parsed").
  return parts.join("|")
}

function valuesMap(rows) {
  const m = {}
  const list = rows || []
  for (let i = 0; i < list.length; i++) {
    const r = list[i]
    if (r.value !== null && r.value !== undefined) m[rowKey(r)] = r.value
    const kids = r.sensors || []
    for (let j = 0; j < kids.length; j++) {
      if (kids[j].value !== null && kids[j].value !== undefined) m[rowKey(kids[j])] = kids[j].value
    }
  }
  return m
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    parseTemperatures: parseTemperatures,
    tempDisplayRows: tempDisplayRows,
    rowKey: rowKey,
    structureKey: structureKey,
    valuesMap: valuesMap,
    GROUP_NAME_MAP: GROUP_NAME_MAP
  }
}
