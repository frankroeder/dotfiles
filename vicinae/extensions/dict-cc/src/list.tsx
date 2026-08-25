import { useEffect, useState } from "react"
import { Action, ActionPanel, Clipboard, getPreferenceValues, getSelectedText, List } from "@vicinae/api"
import { lookup, metaText, peekCache, type Hit, type Prefs } from "./dictcc"

const DEBOUNCE_MS = 150

function accessory(hit: Hit) {
  const text = metaText(hit.meta)
  return text ? [{ text }] : []
}

export function TranslationsList({ from }: { from?: "clipboard" | "selection" }) {
  const prefs = getPreferenceValues<Prefs>()
  const sourceLanguage = prefs.sourceLanguage || "de"
  const targetLanguage = prefs.targetLanguage || "en"
  const [searchText, setSearchText] = useState("")
  const [items, setItems] = useState<Hit[]>([])
  const [url, setUrl] = useState("")
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState("")
  const [seeded, setSeeded] = useState(!from)

  useEffect(() => {
    if (!from) return
    let cancelled = false
    ;(async () => {
      const raw =
        from === "clipboard" ? ((await Clipboard.readText()) ?? "") : ((await getSelectedText().catch(() => "")) ?? "")
      if (cancelled) return
      setSearchText(raw.trim().split(/\r?\n/, 1)[0].slice(0, 80))
      setSeeded(true)
    })()
    return () => {
      cancelled = true
    }
  }, [from])

  useEffect(() => {
    if (!seeded) return
    const term = searchText.trim()
    if (!term) {
      setItems([])
      setUrl("")
      setError("")
      setLoading(false)
      return
    }
    const prefs = { sourceLanguage, targetLanguage }
    const cached = peekCache(term, prefs)
    if (cached) {
      setItems(cached.items)
      setUrl(cached.url)
      setError("")
      setLoading(false)
      return
    }
    const ac = new AbortController()
    const timer = setTimeout(() => {
      setLoading(true)
      lookup(term, prefs, ac.signal)
        .then((r) => {
          setItems(r.items)
          setUrl(r.url)
          setError("")
        })
        .catch((e) => {
          if (e?.name === "AbortError") return
          setItems([])
          setUrl("")
          setError("dict.cc lookup failed")
        })
        .finally(() => {
          if (!ac.signal.aborted) setLoading(false)
        })
    }, DEBOUNCE_MS)
    return () => {
      clearTimeout(timer)
      ac.abort()
    }
  }, [searchText, seeded, sourceLanguage, targetLanguage])

  const empty = !searchText.trim()
  return (
    <List
      isLoading={loading || !seeded}
      filtering={false}
      searchText={from ? searchText : undefined}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder="term, or 'en de house'"
    >
      <List.EmptyView
        title={empty ? "Translate with dict.cc" : loading ? "Looking up…" : error || "No translations"}
        description={empty ? "Type a word · en de term for a language pair" : searchText.trim()}
      />
      <List.Section title="Results" subtitle={items.length ? `${items.length}` : undefined}>
        {items.map((hit, i) => (
          <List.Item
            key={`${hit.source}-${hit.target}-${i}`}
            title={hit.target}
            subtitle={hit.source}
            accessories={accessory(hit)}
            actions={
              <ActionPanel>
                <Action.CopyToClipboard title="Copy Translation" content={hit.copy} />
                <Action.CopyToClipboard title="Copy Source" content={hit.source} />
                <Action.Paste title="Paste Translation" content={hit.copy} />
                {url ? <Action.OpenInBrowser title="Open on dict.cc" url={url} /> : null}
              </ActionPanel>
            }
          />
        ))}
      </List.Section>
    </List>
  )
}
