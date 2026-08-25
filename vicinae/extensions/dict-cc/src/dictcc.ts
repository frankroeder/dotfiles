// Thin host wrapper around the shared core (dictcc-core.mjs): only the
// fetch-based transport lives here. Parsing, query handling, and the LRU
// cache are shared with the Asahi quickshell launcher.
import { buildUrl, cacheGet, cachePut, copyLangFromUrl, parseHits, parseQuery } from "./dictcc-core.mjs"
import type { Lookup } from "./dictcc-core.mjs"

export type { Hit, Lookup, Meta } from "./dictcc-core.mjs"
export { metaText, strip } from "./dictcc-core.mjs"

export type Prefs = {
  sourceLanguage: string
  targetLanguage: string
}

export function peekCache(query: string, prefs: Prefs) {
  const { sourceLanguage, targetLanguage, term } = parseQuery(query, prefs)
  if (!term) return undefined
  return cacheGet(sourceLanguage, targetLanguage, term)
}

export async function lookup(query: string, prefs: Prefs, signal?: AbortSignal): Promise<Lookup> {
  const { sourceLanguage, targetLanguage, term } = parseQuery(query, prefs)
  if (!term) return { items: [], url: "", copyLang: targetLanguage }
  const cached = cacheGet(sourceLanguage, targetLanguage, term)
  if (cached) return cached

  const url = buildUrl(sourceLanguage, targetLanguage, term)
  const timeout = AbortSignal.timeout(8000)
  const res = await fetch(url, {
    signal: signal ? AbortSignal.any([signal, timeout]) : timeout,
    headers: { "User-Agent": "Mozilla/5.0", Accept: "text/html" },
    redirect: "follow",
  })
  if (!res.ok) throw new Error(`dict.cc ${res.status}`)
  const html = await res.text()
  const finalUrl = res.url || url
  const copyLang = copyLangFromUrl(finalUrl, targetLanguage)
  const result: Lookup = { items: parseHits(html, term, copyLang), url: finalUrl, copyLang }
  cachePut(sourceLanguage, targetLanguage, term, result)
  return result
}
