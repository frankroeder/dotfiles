// Websearch engines from websearch.json (shared by QML + node tests).
// QML: import "websearch.js" as WebSearch
// Node: require("./websearch.js")

function resolveIcon(icon, iconBase) {
  const ic = String(icon || "").trim()
  const base = String(iconBase || "")
  if (!ic) return ""
  if (ic.indexOf("file://") === 0 || ic.charAt(0) === "/") return ic
  if (ic.indexOf(".") > 0) return base + ic
  return ic
}

function normalizeEngine(e, iconBase) {
  if (!e) return null
  const prefix = String(e.prefix || "").trim()
  const name = String(e.name || "").trim()
  const url = String(e.url || "").trim()
  if (!prefix || !name || !url) return null
  const out = {
    name: name,
    prefix: prefix,
    url: url,
    icon: resolveIcon(e.icon, iconBase)
  }
  if (e.description) out.description = String(e.description)
  return out
}

function parseConfig(text, iconBase) {
  const body = String(text || "").trim()
  if (!body) return null
  const data = JSON.parse(body)
  if (!data || !Array.isArray(data.engines) || data.engines.length === 0) return null
  const engines = []
  const seen = {}
  for (let i = 0; i < data.engines.length; i++) {
    const row = normalizeEngine(data.engines[i], iconBase)
    if (!row) continue
    const key = row.prefix.toLowerCase()
    if (seen[key]) continue
    seen[key] = true
    engines.push(row)
  }
  if (engines.length === 0) return null
  return {
    engines: engines,
    defaultSearchUrl: data.defaultSearchUrl ? String(data.defaultSearchUrl) : ""
  }
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    resolveIcon: resolveIcon,
    normalizeEngine: normalizeEngine,
    parseConfig: parseConfig
  }
}
