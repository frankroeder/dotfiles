pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // Skip playerctld: it mirrors the active player under its own name.
    readonly property var list: Mpris.players.values.filter(p => !p.dbusName.endsWith(".playerctld"))

    // Player picked in the media popup (cycle()); wins while it exists.
    property var pinned: null

    // The best player to show: the pinned one, else one that is playing
    property var active: {
        if (pinned && list.indexOf(pinned) >= 0) return pinned
        for (let i = 0; i < list.length; i++) {
            if (list[i]?.isPlaying) return list[i]
        }
        return list[0] ?? null
    }

    readonly property bool hasPlayer: active !== null
    readonly property bool isPlaying: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""
    readonly property real progress: active && active.length > 0 ? active.position / active.length : 0
    // Browsers often leave trackArtUrl empty but carry mpris:artUrl in the metadata.
    readonly property string artUrl: {
        const p = active
        if (!p) return ""
        return String(p.trackArtUrl || (p.metadata && p.metadata["mpris:artUrl"]) || "")
    }

    // MprisPlayer.position is computed on read but never notifies while playing: emit
    // positionChanged so bound progress bars re-read it.
    Timer {
        interval: 2000
        repeat: true
        running: root.isPlaying
        onTriggered: root.active.positionChanged()
    }

    function playPause() { if (active?.canTogglePlaying) active.togglePlaying() }
    function next()      { if (active?.canGoNext)     active.next() }
    function previous()  { if (active?.canGoPrevious) active.previous() }
    function cycle() {
        if (list.length < 2) return
        pinned = list[(list.indexOf(active) + 1) % list.length]
    }
}
