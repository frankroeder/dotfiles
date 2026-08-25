// Shared dict.cc core used by BOTH launchers:
//   - vicinae extension (macOS): imported from src/dictcc.ts, bundled by vici.
//   - quickshell launcher (Asahi): imported directly by LauncherWindow.qml via
//     the symlink asahi/quickshell/remix/modules/launcher/dictcc-core.mjs.
// Keep this file dependency-free and conservative ES2018: quickshell's QML JS
// engine has no fetch/AbortSignal, and RegExp.matchAll support is not a given.
// Transport (fetch vs XMLHttpRequest) lives in each host.

export const LANGS = new Set([
  "sq", "bs", "bg", "hr", "cs", "da", "nl", "en", "eo", "fi", "fr", "de", "el", "hu", "is", "it", "la", "no",
  "pl", "pt", "ro", "ru", "sr", "sk", "es", "sv", "tr",
])

const BRACKETS = [
  ["<([^<>]*)>", "abbreviations"],
  ["\\[([^\\[\\]]*)\\]", "comments"],
  ["\\(([^()]*)\\)", "optionalData"],
  ["\\{([^{}]*)\\}", "wordClass"],
]

const MAX_ITEMS = 50
const CACHE_MAX = 32
const cache = new Map()

function cacheKey(sourceLanguage, targetLanguage, term) {
  return sourceLanguage + ":" + targetLanguage + ":" + term.toLowerCase()
}

export function cacheGet(sourceLanguage, targetLanguage, term) {
  return cache.get(cacheKey(sourceLanguage, targetLanguage, term))
}

export function cachePut(sourceLanguage, targetLanguage, term, value) {
  cache.set(cacheKey(sourceLanguage, targetLanguage, term), value)
  if (cache.size <= CACHE_MAX) return
  const first = cache.keys().next().value
  if (first) cache.delete(first)
}

function matches(pattern, raw) {
  const re = new RegExp(pattern, "g")
  const out = []
  let m
  while ((m = re.exec(raw)) !== null) out.push(m[1])
  return out
}

function decode(value) {
  return value
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&#(\d+);/g, function (_, n) { return String.fromCharCode(Number(n)) })
    .replace(/\s+/g, " ")
    .trim()
}

function meta(raw) {
  const out = {}
  for (const pair of BRACKETS) out[pair[1]] = matches(pair[0], raw)
  return out
}

export function metaText(m) {
  if (!m) return ""
  const parts = []
  const groups = [m.wordClass, m.abbreviations, m.comments, m.optionalData]
  for (const group of groups) {
    for (const part of group || []) if (part) parts.push(part)
  }
  return parts.join(" · ")
}

export function strip(raw) {
  let text = raw
  for (const pair of BRACKETS) text = text.replace(new RegExp(pair[0], "g"), "")
  return text.replace(/\d/g, "").replace(/\s+/g, " ").trim()
}

export function parseQuery(query, defaults) {
  const parts = query.trim().split(/\s+/)
  if (parts.length > 2 && LANGS.has(parts[0]) && LANGS.has(parts[1]) && parts[0] !== parts[1]) {
    return { sourceLanguage: parts[0], targetLanguage: parts[1], term: parts.slice(2).join(" ") }
  }
  return { sourceLanguage: defaults.sourceLanguage, targetLanguage: defaults.targetLanguage, term: query.trim() }
}

export function buildUrl(sourceLanguage, targetLanguage, term) {
  return "https://m.dict.cc/" + sourceLanguage + targetLanguage + "/?s=" + encodeURIComponent(term)
}

// dict.cc redirects deen queries to a direction-specific page; for DE/EN that
// final URL names the input language, which fixes the copy-side language.
export function copyLangFromUrl(finalUrl, fallback) {
  if (/\/deutsch-englisch\//.test(finalUrl || "")) return "en"
  if (/\/englisch-deutsch\//.test(finalUrl || "")) return "de"
  return fallback
}

export function parseHits(html, term, copyLang) {
  const re = /<td class="srtd([23])"[^>]*data-term="([^"]*)"/g
  const left = []
  const right = []
  let m
  while ((m = re.exec(html)) !== null) {
    const value = decode(m[2])
    if (!value) continue
    if (m[1] === "2") left.push(value)
    else right.push(value)
  }
  const n = Math.min(left.length, right.length)
  if (n === 0) return []

  // dict.cc column order depends on the detected input language; the column
  // that echoes the query term more often is the source side.
  const q = term.toLowerCase()
  let leftHits = 0
  let rightHits = 0
  for (let i = 0; i < n; i++) {
    if (left[i].toLowerCase().indexOf(q) !== -1) leftHits++
    if (right[i].toLowerCase().indexOf(q) !== -1) rightHits++
  }
  const sourceOnRight = rightHits > leftHits

  const items = []
  const seen = new Set()
  for (let i = 0; i < n; i++) {
    const sourceRaw = sourceOnRight ? right[i] : left[i]
    const targetRaw = sourceOnRight ? left[i] : right[i]
    const key = sourceRaw + "\u0000" + targetRaw
    if (seen.has(key)) continue
    seen.add(key)
    const copy = strip(targetRaw)
    if (!copy) continue
    const srcMeta = meta(sourceRaw)
    const dstMeta = meta(targetRaw)
    dstMeta.wordClass = srcMeta.wordClass.concat(dstMeta.wordClass)
    items.push({
      source: strip(sourceRaw) || sourceRaw,
      target: copy,
      copy: copy,
      copyLang: copyLang,
      meta: dstMeta,
    })
    if (items.length >= MAX_ITEMS) break
  }
  return items
}
