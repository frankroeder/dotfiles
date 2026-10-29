pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import "players.js" as PlayersJs

Singleton {
    id: root

    // Skip playerctld: it mirrors the active player under its own name.
    readonly property var list: Mpris.players.values.filter(p => !p.dbusName.endsWith(".playerctld"))

    // Player picked in the media popup (cycle()); wins while it exists.
    property var pinned: null
    // Last player seen playing: stays the shown one once everything paused.
    property var recent: null
    readonly property var playing: list.find(p => p.isPlaying) ?? null
    onPlayingChanged: if (playing) recent = playing

    // The best player to show (PlayersJs.pick)
    readonly property var active: PlayersJs.pick(list, pinned, recent)

    // dbusName → true for asahi-apple-music's browser, read from its command line (players.js).
    property var appleMusic: ({})
    Instantiator {
        model: root.list.filter(p => /\.chromium\.instance\d+$/.test(p.dbusName))
        delegate: FileView {
            required property var modelData
            path: "/proc/" + modelData.dbusName.replace(/.*\.instance/, "") + "/cmdline"
            printErrors: false
            onLoaded: {
                const m = Object.assign({}, root.appleMusic)
                m[modelData.dbusName] = PlayersJs.isAppleMusicCmdline(text())
                root.appleMusic = m
            }
        }
    }
    function name(p) { return !p ? "" : root.appleMusic[p.dbusName] ? "Apple Music" : p.identity || "Player" }

    readonly property bool hasPlayer: active !== null
    readonly property bool isPlaying: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""
    // Browsers often leave trackArtUrl empty but carry mpris:artUrl in the metadata.
    readonly property string artUrl: {
        const p = active
        if (!p) return ""
        return String(p.trackArtUrl || (p.metadata && p.metadata["mpris:artUrl"]) || "")
    }

    // MprisPlayer.position never notifies while playing: MediaCard ticks it while shown.

    // Track length in seconds, 0 = unknown (MediaCard: placeholder bar, no times). Chromium hands on the media
    // element's duration: INT64_MAX µs while it is Infinity, and for a gapless stream (Apple Music
    // web) the buffered end — growing every 10 s, the album's end once all of it is buffered — while
    // the position counts from the album start; a paused track shows no sign of it. So no length past
    // 1e6 s, and Chromium's only after it held still through 12 s of playback of the track and while
    // its clock restarted at the last track change (YouTube's seek bar shows after those 12 s).
    readonly property real length: {
        const p = active
        if (!p || !p.lengthSupported || p.length <= 0 || p.length >= 1e6) return 0
        return !chromium || (lengthHeld >= 12 && !clockRanOn) ? p.length : 0
    }
    // Strings: they notify only on a real change (`active` re-evaluates whenever any player's state does).
    readonly property string trackKey: active ? active.dbusName + "\n" + active.trackTitle + "\n" + active.trackArtist : ""
    readonly property bool chromium: !!active && active.dbusName.indexOf(".chromium.") >= 0
    property int lengthHeld: 0          // seconds of playback the length stayed put (Chromium)
    property bool clockRanOn: false     // the position kept counting across the last track change
    property string lastKey: ""
    onTrackKeyChanged: {
        lengthHeld = 0
        // A track change on the same player (not a switch, not the first sight): check its clock.
        const same = lastKey !== "" && lastKey.split("\n")[0] === trackKey.split("\n")[0]
        if (same) clockCheck.restart()
        else { clockCheck.stop(); clockRanOn = false }
        lastKey = trackKey
    }
    Timer {
        id: clockCheck
        interval: 5000
        onTriggered: root.clockRanOn = !!root.active && root.active.position >= 15
    }
    Timer {
        interval: 1000; repeat: true
        running: root.chromium && root.isPlaying && root.lengthHeld < 12
        onTriggered: root.lengthHeld++
    }
    Connections {
        target: root.active
        function onLengthChanged() { root.lengthHeld = 0 }
    }

    function playPause() { if (active?.canTogglePlaying) active.togglePlaying() }
    function next()      { if (active?.canGoNext)     active.next() }
    function cycle() {
        if (list.length < 2) return
        pinned = list[(list.indexOf(active) + 1) % list.length]
    }
}
