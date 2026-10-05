pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // Skip playerctld: it mirrors the active player under its own name.
    readonly property var list: Mpris.players.values.filter(p => !p.dbusName.endsWith(".playerctld"))

    // The best player to show: prefer one that is playing
    property var active: {
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
}
