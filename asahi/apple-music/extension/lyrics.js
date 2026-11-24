// Synced lyrics for the shell's media card. On a track change MusicKit's own API client (the page's developer and
// user tokens) fetches the song's TTML once; the parsed lines go out as one record per track (empty without lyrics):
// window.postMessage → relay.js (isolated world) → background.js → native host asahi-apple-music-lyrics → a JSON file.
(function () {
  // TTML clock values: "12.345", "1:02.345", "0:01:02.345" (an "s" suffix too) → seconds, null otherwise.
  function seconds(s) {
    s = String(s == null ? "" : s).trim().replace(/s$/, "")
    if (!/^\d+(:\d+){0,2}(\.\d+)?$/.test(s)) return null
    return Math.round(s.split(":").reduce(function (t, p) { return t * 60 + Number(p) }, 0) * 1000) / 1000
  }

  var ENT = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'" }
  function decode(s) {
    return s.replace(/&(#x[0-9a-f]+|#\d+|\w+);/gi, function (m, e) {
      if (e[0] === "#") return String.fromCodePoint(e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : Number(e.slice(1)))
      return ENT[e] !== undefined ? ENT[e] : m
    })
  }

  // One line per <p> (word-timed spans joined), sorted by start. Synced = every line has a begin time;
  // Apple's untimed TTML (itunes:timing="None") has none.
  function parse(ttml) {
    var lines = [], re = /<p\b([^>]*)>([\s\S]*?)<\/p>/g, m
    while ((m = re.exec(String(ttml || "")))) {
      var b = /\sbegin="([^"]*)"/.exec(m[1])
      var text = decode(m[2].replace(/<br\s*\/?>/g, " ").replace(/<[^>]*>/g, "")).replace(/\s+/g, " ").trim()
      if (text) lines.push({ t: b ? seconds(b[1]) : null, text: text })
    }
    var synced = lines.length > 0 && lines.every(function (l) { return l.t !== null })
    if (synced) lines.sort(function (a, b) { return a.t - b.t })
    return { synced: synced, lines: lines }
  }

  if (typeof window === "undefined") { module.exports = { seconds: seconds, parse: parse }; return }

  var mk = null
  var last = null   // track id of the last record

  // MusicKit v3: api.music(path) resolves to { data: <response body> }; a throw becomes a rejection.
  function lyrics(id, kind) {
    return Promise.resolve().then(function () {
      return mk.api.music("/v1/catalog/" + mk.storefrontId + "/songs/" + id + "/" + kind)
    }).then(function (r) {
      var a = r.data.data[0].attributes
      return parse(a.ttml || a.ttmlLocalizations)
    })
  }

  function check() {
    var item = mk.nowPlayingItem
    if (!item) return
    // Library songs carry their catalog id in playParams.
    var pp = item.playParams || (item.attributes && item.attributes.playParams) || {}
    var id = String(pp.catalogId || item.id || "")
    if (id === last) return
    last = id
    var rec = { trackId: id, title: item.title || "", artist: item.artistName || "", synced: false, lines: [] }
    function post(l) {
      if (id !== last) return   // a newer track won meanwhile
      if (l && l.lines.length) { rec.synced = l.synced; rec.lines = l.lines }
      window.postMessage({ asahiLyrics: rec }, location.origin)
    }
    if (!/^\d+$/.test(id) || (item.attributes && item.attributes.hasLyrics === false)) return post(null)
    lyrics(id, "lyrics").catch(function () { return lyrics(id, "syllable-lyrics") }).then(post, function () { post(null) })
  }

  var poll = setInterval(function () {
    try { mk = window.MusicKit && window.MusicKit.getInstance() } catch (e) { mk = null }
    if (!mk) return
    clearInterval(poll)
    mk.addEventListener("nowPlayingItemDidChange", check)
    check()
  }, 1000)
})()
