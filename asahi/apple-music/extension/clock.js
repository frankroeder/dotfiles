// MusicKit plays the queue as one MSE stream, so Chromium's MPRIS length is the buffered end and its
// position counts from the first track. The page's Media Session position state wins over the media
// element in Chromium: hand it MusicKit's per-track clock, and seek through MusicKit.
(function () {
  var ms = navigator.mediaSession
  var mk = null
  var sent = null   // last state handed to Chromium: { d, p, at, playing }

  function seekTo(details) {
    if (mk && details && details.seekTime >= 0) Promise.resolve(mk.seekToTime(details.seekTime)).then(sync, function () {})
  }

  function attach() {
    try { mk = window.MusicKit && window.MusicKit.getInstance() } catch (e) { mk = null }
    if (!mk) return false
    ;["playbackStateDidChange", "playbackDurationDidChange", "nowPlayingItemDidChange"].forEach(function (ev) {
      try { mk.addEventListener(ev, sync) } catch (e) {}
    })
    return true
  }

  function sync() {
    if (!mk && !attach()) return
    var d = Number(mk.currentPlaybackDuration), p = Number(mk.currentPlaybackTime), playing = !!mk.isPlaying
    if (!(d > 0) || !(p >= 0)) return
    p = Math.min(p, d)
    var now = Date.now() / 1000
    if (sent && sent.d === d && sent.playing === playing
        && Math.abs(sent.p + (sent.playing ? now - sent.at : 0) - p) < 1) return
    try {
      ms.playbackState = playing ? "playing" : "paused"
      ms.setPositionState({ duration: d, position: p, playbackRate: 1 })
      // The page may set its own handler on a track change; ours seeks the track, not the stream.
      ms.setActionHandler("seekto", seekTo)
      sent = { d: d, p: p, at: now, playing: playing }
    } catch (e) {}
  }

  setInterval(sync, 1000)
})()
