// node asahi/apple-music/clock_test.js — extension/clock.js against a fake MusicKit + Media Session.
const assert = require("assert")
const fs = require("fs")
const path = require("path")
const vm = require("vm")

const src = fs.readFileSync(path.join(__dirname, "extension", "clock.js"), "utf8")
let now = 1000000
let tick = null
const sets = []
const handlers = {}
const session = {
  playbackState: "none",
  setPositionState(s) {
    if (!(s.duration >= 0) || s.position > s.duration || !s.playbackRate) throw new TypeError("bad state")
    sets.push(Object.assign({ state: this.playbackState }, s))
  },
  setActionHandler(name, fn) { handlers[name] = fn }
}
const listeners = {}
const seeks = []
const mk = {
  currentPlaybackDuration: 0, currentPlaybackTime: 0, isPlaying: false,
  addEventListener(ev, fn) { listeners[ev] = fn },
  seekToTime(t) { seeks.push(t); this.currentPlaybackTime = t; return Promise.resolve() }
}
const win = {}
const ctx = vm.createContext({
  navigator: { mediaSession: session }, window: win, Promise,
  Date: { now: () => now }, setInterval: (fn) => { tick = fn }
})
vm.runInContext(src, ctx)
const step = (s) => { now += (s || 1) * 1000; tick() }
const last = () => sets[sets.length - 1]

step()
assert.strictEqual(sets.length, 0, "no MusicKit yet")
win.MusicKit = { getInstance: () => mk }
step()
assert.strictEqual(sets.length, 0, "no track")
assert.deepStrictEqual(Object.keys(listeners).sort(), ["nowPlayingItemDidChange", "playbackDurationDidChange", "playbackStateDidChange"])

Object.assign(mk, { currentPlaybackDuration: 200, currentPlaybackTime: 10, isPlaying: true })
step()
assert.deepStrictEqual(last(), { state: "playing", duration: 200, position: 10, playbackRate: 1 })
assert.strictEqual(typeof handlers.seekto, "function")

mk.currentPlaybackTime = 11.2
step()
assert.strictEqual(sets.length, 1, "on schedule: nothing to hand on")

mk.currentPlaybackTime = 80
step()
assert.strictEqual(last().position, 80, "a jump is handed on")

mk.isPlaying = false
listeners.playbackStateDidChange()
assert.strictEqual(last().state, "paused", "pause via event")
const n = sets.length
step(5)
assert.strictEqual(sets.length, n, "paused clock stands still")

Object.assign(mk, { currentPlaybackDuration: 180, currentPlaybackTime: 0, isPlaying: true })
listeners.nowPlayingItemDidChange()
assert.deepStrictEqual(last(), { state: "playing", duration: 180, position: 0, playbackRate: 1 }, "next track")

mk.currentPlaybackTime = 181
step()
assert.strictEqual(last().position, 180, "position clamped to the length")

handlers.seekto({ seekTime: 42 })
assert.deepStrictEqual(seeks, [42], "MPRIS seek goes through MusicKit")
handlers.seekto({})
assert.strictEqual(seeks.length, 1, "seek without a time is ignored")

console.log("clock_test: ok")
