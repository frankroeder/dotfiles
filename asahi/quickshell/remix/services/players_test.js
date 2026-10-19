// node asahi/quickshell/remix/services/players_test.js
const assert = require("assert")
const P = require("./players.js")

const argv = (...a) => a.join("\0") + "\0"
const bin = "/usr/lib64/chromium-browser/chromium-browser"
// Chromium's own /proc cmdline: one space-joined string.
assert.ok(P.isAppleMusicCmdline([bin, "--enable-features=WebRTCPipeWireCapturer",
  "--user-data-dir=/home/u/.local/share/asahi-apple-music", "--app=https://music.apple.com/"].join(" ")))
assert.ok(P.isAppleMusicCmdline([bin, "--user-data-dir=/home/u/.local/share/asahi-apple-music"].join(" ")))
assert.ok(!P.isAppleMusicCmdline([bin, "--user-data-dir=/home/u/apple-music-old", "--app=x"].join(" ")))
assert.ok(P.isAppleMusicCmdline(argv(bin, "--enable-features=WebRTCPipeWireCapturer",
  "--user-data-dir=/home/u/.local/share/asahi-apple-music", "--app=https://music.apple.com/")))
assert.ok(P.isAppleMusicCmdline(argv(bin, "--user-data-dir=/home/u/.local/share/omarchy-apple-music/")))
assert.ok(!P.isAppleMusicCmdline(argv(bin, "--enable-sync")), "main browser")
assert.ok(!P.isAppleMusicCmdline(argv(bin, "--app=https://music.apple.com/")), "app window of the main profile")
assert.ok(!P.isAppleMusicCmdline(argv(bin, "--user-data-dir=/home/u/apple-music-old")))
assert.ok(!P.isAppleMusicCmdline(argv(bin, "--foo=--user-data-dir=/x/apple-music")))
assert.ok(!P.isAppleMusicCmdline(""))
assert.ok(!P.isAppleMusicCmdline(undefined))

const pl = (name, isPlaying, trackTitle) => ({ name, isPlaying, trackTitle })
const quiet = pl("chromium", false, "")
const yt = pl("firefox", false, "Video")
const am = pl("apple", false, "Song")
const playing = pl("mpv", true, "Clip")

assert.strictEqual(P.pick([], null, null), null)
assert.strictEqual(P.pick([quiet, yt], null, null), yt, "skips the trackless player")
assert.strictEqual(P.pick([quiet], null, null), quiet, "only a trackless one")
assert.strictEqual(P.pick([quiet, yt, am, playing], null, null), playing, "playing wins")
assert.strictEqual(P.pick([quiet, yt, am], null, am), am, "last seen playing")
assert.strictEqual(P.pick([quiet, yt, am, playing], null, am), playing, "playing beats recent")
assert.strictEqual(P.pick([quiet, yt], null, am), yt, "recent gone")
assert.strictEqual(P.pick([quiet, yt], null, quiet), yt, "recent lost its track")
assert.strictEqual(P.pick([quiet, yt, playing], yt, am), yt, "pinned wins")
assert.strictEqual(P.pick([quiet, playing], yt, null), playing, "pinned gone")

console.log("players_test: ok")
