const LANGS = new Set([
  "sq", "bs", "bg", "hr", "cs", "da", "nl", "en", "eo", "fi", "fr", "de", "el", "hu", "is", "it", "la", "no",
  "pl", "pt", "ro", "ru", "sr", "sk", "es", "sv", "tr",
])

export type Meta = {
  abbreviations: string[]
  comments: string[]
  optionalData: string[]
  wordClass: string[]
}

const BRACKETS: [() => RegExp, keyof Meta][] = [
  [() => /<([^<>]*)>/g, "abbreviations"],
  [() => /\[([^[\]]*)\]/g, "comments"],
  [() => /\(([^()]*)\)/g, "optionalData"],
  [() => /\{([^{}]*)\}/g, "wordClass"],
]

export type Hit = {
  source: string
  target: string
  copy: string
  copyLang: string
  meta: Meta
}

export type Lookup = {
  items: Hit[]
  url: string
  copyLang: string
}

export type Prefs = {
  sourceLanguage: string
  targetLanguage: string
}

const MAX_ITEMS = 50
const CACHE_MAX = 32
const cache = new Map<string, Lookup>()

function cacheKey(term: string, sourceLanguage: string, targetLanguage: string) {
  return `${sourceLanguage}:${targetLanguage}:${term.toLowerCase()}`
}

function remember(key: string, value: Lookup) {
  cache.set(key, value)
  if (cache.size <= CACHE_MAX) return
  const first = cache.keys().next().value
  if (first) cache.delete(first)
}

export function peekCache(query: string, prefs: Prefs) {
  const { sourceLanguage, targetLanguage, term } = parseQuery(query, prefs)
  if (!term) return undefined
  return cache.get(cacheKey(term, sourceLanguage, targetLanguage))
}

function decode(value: string) {
  return value
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/\s+/g, " ")
    .trim()
}

function meta(raw: string): Meta {
  const out: Meta = { abbreviations: [], comments: [], optionalData: [], wordClass: [] }
  for (const [re, key] of BRACKETS) out[key] = Array.from(raw.matchAll(re()), (m) => m[1])
  return out
}

export function strip(raw: string) {
  let text = raw
  for (const [re] of BRACKETS) text = text.replace(re(), "")
  return text.replace(/\d/g, "").replace(/\s+/g, " ").trim()
}

export function parseQuery(query: string, prefs: Prefs) {
  const parts = query.trim().split(/\s+/)
  if (parts.length > 2 && LANGS.has(parts[0]) && LANGS.has(parts[1]) && parts[0] !== parts[1]) {
    return { sourceLanguage: parts[0], targetLanguage: parts[1], term: parts.slice(2).join(" ") }
  }
  return { sourceLanguage: prefs.sourceLanguage, targetLanguage: prefs.targetLanguage, term: query.trim() }
}

export function parseHits(html: string, term: string, targetLanguage: string): Hit[] {
  const re = /<td class="srtd([23])"[^>]*data-term="([^"]*)"/g
  const left: string[] = []
  const right: string[] = []
  for (const m of html.matchAll(re)) {
    const value = decode(m[2])
    if (!value) continue
    if (m[1] === "2") left.push(value)
    else right.push(value)
  }
  const n = Math.min(left.length, right.length)
  if (n === 0) return []

  const q = term.toLowerCase()
  let leftHits = 0
  let rightHits = 0
  for (let i = 0; i < n; i++) {
    if (left[i].toLowerCase().includes(q)) leftHits++
    if (right[i].toLowerCase().includes(q)) rightHits++
  }
  const sourceOnRight = rightHits > leftHits

  const items: Hit[] = []
  const seen = new Set<string>()
  for (let i = 0; i < n; i++) {
    const sourceRaw = sourceOnRight ? right[i] : left[i]
    const targetRaw = sourceOnRight ? left[i] : right[i]
    const key = `${sourceRaw}\0${targetRaw}`
    if (seen.has(key)) continue
    seen.add(key)
    const copy = strip(targetRaw)
    if (!copy) continue
    const srcMeta = meta(sourceRaw)
    const dstMeta = meta(targetRaw)
    items.push({
      source: strip(sourceRaw) || sourceRaw,
      target: copy,
      copy,
      copyLang: targetLanguage,
      meta: {
        ...dstMeta,
        wordClass: [...srcMeta.wordClass, ...dstMeta.wordClass],
      },
    })
    if (items.length >= MAX_ITEMS) break
  }
  return items
}

export async function lookup(query: string, prefs: Prefs, signal?: AbortSignal): Promise<Lookup> {
  const { sourceLanguage, targetLanguage, term } = parseQuery(query, prefs)
  if (!term) return { items: [], url: "", copyLang: targetLanguage }
  const key = cacheKey(term, sourceLanguage, targetLanguage)
  const cached = cache.get(key)
  if (cached) return cached

  const url = `https://m.dict.cc/${sourceLanguage}${targetLanguage}/?s=${encodeURIComponent(term)}`
  const timeout = AbortSignal.timeout(8000)
  const res = await fetch(url, {
    signal: signal ? AbortSignal.any([signal, timeout]) : timeout,
    headers: { "User-Agent": "Mozilla/5.0", Accept: "text/html" },
    redirect: "follow",
  })
  if (!res.ok) throw new Error(`dict.cc ${res.status}`)
  const html = await res.text()
  const finalUrl = res.url || url
  const copyLang = /\/deutsch-englisch\//.test(finalUrl)
    ? "en"
    : /\/englisch-deutsch\//.test(finalUrl)
      ? "de"
      : targetLanguage
  const result = { items: parseHits(html, term, copyLang), url: finalUrl, copyLang }
  remember(key, result)
  return result
}
