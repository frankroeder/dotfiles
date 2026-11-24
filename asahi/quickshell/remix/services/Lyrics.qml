pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "lyrics.js" as LyricsJs

// Synced lyrics from the Apple Music app: its extension (asahi/apple-music/extension/lyrics.js) fetches them once per
// track and the native host asahi-apple-music-lyrics writes one record, watched here (no polling). Only the record of
// the track the active player shows counts, and only for the Apple Music player.
Singleton {
  id: root

  // {trackId, title, artist, synced, lines: [{t, text}]}; null until the app sent its first one.
  property var rec: null
  // MediaCard strip on / off: one word in ~/.local/state/asahi/media-lyrics (on | off; missing = on).
  property bool enabled: true
  function setEnabled(on) { root.enabled = on; flagFile.setText(on ? "on\n" : "off\n") }

  readonly property bool appleMusic: !!Players.active && !!Players.appleMusic[Players.active.dbusName]
  // The app is set up for lyrics (MediaCard shows the toggle).
  readonly property bool available: root.appleMusic && root.rec !== null
  // MusicKit fills the Media Session from the same item, so title and artist match the MPRIS ones.
  readonly property bool current: root.available && root.rec.title === Players.title && root.rec.artist === Players.artist
  readonly property var lines: root.current ? root.rec.lines || [] : []
  readonly property bool synced: root.current && root.rec.synced === true && root.lines.length > 0
  // MediaCard's strip: kept while a new track's record is on its way (no jump between tracks), gone for a track
  // without lyrics (its record has no lines).
  readonly property bool shown: root.available && root.enabled && !(root.current && !root.lines.length)
  function indexAt(s) { return LyricsJs.indexAt(root.lines, s) }

  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/asahi-apple-music-lyrics.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.rec = JSON.parse(text()) } catch (e) {} }
  }
  FileView {
    id: flagFile
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/asahi/media-lyrics"
    printErrors: false
    onLoaded: root.enabled = flagFile.text().trim() !== "off"
  }
}
