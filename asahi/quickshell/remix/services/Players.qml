pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    readonly property var list: Mpris.players.values

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

    function playPause() { if (active?.canTogglePlaying) active.togglePlaying() }
    function next()      { if (active?.canGoNext)     active.next() }
    function previous()  { if (active?.canGoPrevious) active.previous() }
}
