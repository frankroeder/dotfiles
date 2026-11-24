// node asahi/apple-music/lyrics_test.js — extension/lyrics.js (TTML parser, then the fetch against a fake MusicKit)
// and the shell's line lookup (quickshell/remix/services/lyrics.js).
const assert = require("assert")
const fs = require("fs")
const path = require("path")
const vm = require("vm")

const L = require("./extension/lyrics.js")
const { indexAt } = require("../quickshell/remix/services/lyrics.js")

assert.strictEqual(L.seconds("12.345"), 12.345)
assert.strictEqual(L.seconds("1:02.345"), 62.345)
assert.strictEqual(L.seconds("0:01:02.345"), 62.345)
assert.strictEqual(L.seconds("01:00:00"), 3600)
assert.strictEqual(L.seconds("7"), 7)
assert.strictEqual(L.seconds("4.5s"), 4.5)
assert.strictEqual(L.seconds(""), null)
assert.strictEqual(L.seconds("abc"), null)
assert.strictEqual(L.seconds(undefined), null)

// Line-timed, as the catalog's /lyrics sends it (head metadata, divs per song part, entities, a <br/>).
const lineTtml = `<tt xmlns="http://www.w3.org/ns/ttml" xmlns:itunes="http://music.apple.com/lyric-ttml-internal"
 xmlns:ttm="http://www.w3.org/ns/ttml#metadata" itunes:timing="Line" xml:lang="en"><head><metadata>
<iTunesMetadata xmlns="http://music.apple.com/lyric-ttml-internal" leadingSilence="0.420"><songwriters>
<songwriter>A Writer</songwriter></songwriters></iTunesMetadata></metadata></head><body dur="3:31.200">
<div begin="12.345" end="1:02.500" itunes:songPart="Verse">
<p begin="12.345" end="15.100" itunes:key="L1" ttm:agent="v1">Rock &amp; roll &#39;til dawn</p>
<p begin="15.1" end="1:02.5" itunes:key="L2" ttm:agent="v1">Second<br/>line</p></div>
<div begin="1:05.000" end="0:01:20.000"><p begin="0:01:05.000" end="0:01:20.000" itunes:key="L3">Third &lt;3 &#x2665;</p>
<p begin="1:30.000" end="1:31.000" itunes:key="L4">   </p></div></body></tt>`
assert.deepStrictEqual(L.parse(lineTtml), { synced: true, lines: [
  { t: 12.345, text: "Rock & roll 'til dawn" }, { t: 15.1, text: "Second line" }, { t: 65, text: "Third <3 ♥" }
] }, "line-timed; empty lines dropped")

// Word-timed (syllable-lyrics): spans joined as written.
const wordTtml = `<tt itunes:timing="Word"><body><div><p begin="1:00.000" end="1:02.000"><span begin="1:00.000" end="1:00.400">Beau</span>` +
  `<span begin="1:00.400" end="1:00.900">tiful</span> <span begin="1:01.000" end="1:02.000">day</span></p>` +
  `<p begin="50.000" end="52.000"><span begin="50.0" end="52.0">Earlier</span></p></div></body></tt>`
assert.deepStrictEqual(L.parse(wordTtml), { synced: true, lines: [{ t: 50, text: "Earlier" }, { t: 60, text: "Beautiful day" }] },
  "word-timed, sorted by start")

// Untimed lyrics: plain lines, not synced.
assert.deepStrictEqual(L.parse(`<tt itunes:timing="None"><body><div><p>First</p><p>Second</p></div></body></tt>`),
  { synced: false, lines: [{ t: null, text: "First" }, { t: null, text: "Second" }] })
assert.deepStrictEqual(L.parse(""), { synced: false, lines: [] })
assert.deepStrictEqual(L.parse(undefined), { synced: false, lines: [] })

// Shell lookup: the last line started at or before the position.
const lines = L.parse(lineTtml).lines
assert.strictEqual(indexAt(lines, 0), -1, "before the first line")
assert.strictEqual(indexAt(lines, 12.345), 0, "on the first start")
assert.strictEqual(indexAt(lines, 15), 0)
assert.strictEqual(indexAt(lines, 15.1), 1)
assert.strictEqual(indexAt(lines, 64.9), 1)
assert.strictEqual(indexAt(lines, 1000), 2, "past the end: the last line")
assert.strictEqual(indexAt([], 5), -1)
assert.strictEqual(indexAt(undefined, 5), -1)
const many = Array.from({ length: 101 }, (_, i) => ({ t: i * 2 }))
for (let s = -1; s < 205; s += 0.5) assert.strictEqual(indexAt(many, s), Math.min(100, Math.floor(s / 2)), "binary search at " + s)

// The page side: one record per track change, fetched through MusicKit's API client.
const src = fs.readFileSync(path.join(__dirname, "extension", "lyrics.js"), "utf8")
let poll = null
const posts = []
const calls = []
const responses = {}    // path → ttml, or an Error to reject with
const mk = {
  storefrontId: "de",
  nowPlayingItem: null,
  listeners: {},
  addEventListener(ev, fn) { this.listeners[ev] = fn },
  api: {
    music(p) {
      calls.push(p)
      const r = responses[p]
      if (r === undefined) return Promise.reject(new Error("404"))
      return r instanceof Error ? Promise.reject(r) : Promise.resolve({ data: { data: [{ attributes: { ttml: r } }] } })
    }
  }
}
const win = { postMessage(msg, origin) { posts.push({ msg: JSON.parse(JSON.stringify(msg)), origin }) } }
vm.runInContext(src, vm.createContext({ window: win, location: { origin: "https://music.apple.com" }, setInterval: (fn) => { poll = fn; return 1 },
  clearInterval: () => { poll = null } }))
const flush = () => new Promise((r) => setTimeout(r, 0))
const change = async (item) => { mk.nowPlayingItem = item; mk.listeners.nowPlayingItemDidChange(); await flush() }
const last = () => posts[posts.length - 1].msg.asahiLyrics

;(async () => {
  poll()
  assert.ok(poll, "keeps polling until MusicKit shows up")
  win.MusicKit = { getInstance: () => mk }
  mk.nowPlayingItem = { id: "111", title: "Song A", artistName: "Band", attributes: { hasLyrics: true } }
  responses["/v1/catalog/de/songs/111/lyrics"] = lineTtml
  poll()
  assert.strictEqual(poll, null, "polling stops once attached")
  assert.strictEqual(typeof mk.listeners.nowPlayingItemDidChange, "function")
  await flush()
  assert.deepStrictEqual(calls, ["/v1/catalog/de/songs/111/lyrics"], "the playing track at attach time")
  assert.strictEqual(posts.length, 1)
  assert.strictEqual(posts[0].origin, "https://music.apple.com")
  assert.deepStrictEqual(last(), { trackId: "111", title: "Song A", artist: "Band", synced: true, lines })

  mk.listeners.nowPlayingItemDidChange()
  await flush()
  assert.strictEqual(calls.length, 1, "once per track")
  assert.strictEqual(posts.length, 1)

  // A library song: the catalog id from playParams; /lyrics fails, syllable-lyrics answers.
  responses["/v1/catalog/de/songs/222/lyrics"] = new Error("404")
  responses["/v1/catalog/de/songs/222/syllable-lyrics"] = wordTtml
  await change({ id: "i.AbC", title: "Song B", artistName: "Band", playParams: { id: "i.AbC", catalogId: "222", isLibrary: true } })
  assert.deepStrictEqual(calls.slice(1), ["/v1/catalog/de/songs/222/lyrics", "/v1/catalog/de/songs/222/syllable-lyrics"])
  assert.strictEqual(last().trackId, "222")
  assert.strictEqual(last().lines[1].text, "Beautiful day")

  // No lyrics: an empty record (the card says so), fetched only when the catalog does not rule it out.
  await change({ id: "333", title: "Instrumental", artistName: "Band", attributes: { hasLyrics: false } })
  assert.strictEqual(calls.length, 3, "hasLyrics false: no fetch")
  assert.deepStrictEqual(last(), { trackId: "333", title: "Instrumental", artist: "Band", synced: false, lines: [] })
  await change({ id: "i.upload", title: "Own upload", artistName: "Me", playParams: { id: "i.upload", isLibrary: true } })
  assert.strictEqual(calls.length, 3, "no catalog id: no fetch")
  assert.deepStrictEqual(last().lines, [])
  await change({ id: "444", title: "Gone", artistName: "Band" })
  assert.deepStrictEqual(calls.slice(3), ["/v1/catalog/de/songs/444/lyrics", "/v1/catalog/de/songs/444/syllable-lyrics"])
  assert.deepStrictEqual(last(), { trackId: "444", title: "Gone", artist: "Band", synced: false, lines: [] }, "both fail: empty")

  // A slow answer for a track already skipped is dropped.
  let answer = null
  mk.api.music = (p) => { calls.push(p); return new Promise((r) => { answer = r }) }
  mk.nowPlayingItem = { id: "555", title: "Skipped", artistName: "Band" }
  mk.listeners.nowPlayingItemDidChange()
  await flush()
  const n = posts.length
  mk.api.music = () => Promise.reject(new Error("404"))
  await change({ id: "666", title: "Next", artistName: "Band" })
  answer({ data: { data: [{ attributes: { ttml: lineTtml } }] } })
  await flush()
  assert.strictEqual(posts.length, n + 1, "only the newer track's record")
  assert.strictEqual(last().trackId, "666")

  // An API client that throws (other MusicKit build) gives an empty record, not an exception.
  mk.api = {}
  await change({ id: "777", title: "Odd", artistName: "Band" })
  assert.strictEqual(last().trackId, "777")

  console.log("lyrics_test: ok")
})().catch((e) => { console.error(e); process.exit(1) })
