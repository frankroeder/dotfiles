export type Meta = {
  abbreviations: string[]
  comments: string[]
  optionalData: string[]
  wordClass: string[]
}

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

export type QueryParts = {
  sourceLanguage: string
  targetLanguage: string
  term: string
}

export declare const LANGS: Set<string>
export declare function parseQuery(query: string, defaults: { sourceLanguage: string; targetLanguage: string }): QueryParts
export declare function buildUrl(sourceLanguage: string, targetLanguage: string, term: string): string
export declare function copyLangFromUrl(finalUrl: string, fallback: string): string
export declare function parseHits(html: string, term: string, copyLang: string): Hit[]
export declare function strip(raw: string): string
export declare function metaText(meta: Meta | undefined): string
export declare function cacheGet(sourceLanguage: string, targetLanguage: string, term: string): Lookup | undefined
export declare function cachePut(sourceLanguage: string, targetLanguage: string, term: string, value: Lookup): void
