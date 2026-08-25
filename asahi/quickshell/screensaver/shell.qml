import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

// Abstract shader screensaver. Four fragment programs (plasma, fluid,
// voronoi, kaleidoscope) cycle on a ~22 s timer with a soft cross-fade.
// Each shader takes the live Asahi palette as uniforms, so swapping
// `Asahi theme update <name>` recolours the saver mid-flight without
// restart.
//
// Activation: IPC only. Bind your preferred trigger to e.g.
//   qs -c screensaver ipc call saver toggle
// Dismiss: any mouse move, click, or key press.
ShellRoot {
    id: root

    // ---------- Theme ----------
    readonly property string colorsPath: Quickshell.env("HOME") + "/.config/quickshell/asahi/theme/colors.toml"
    readonly property string themeNamePath: Quickshell.env("HOME") + "/.config/quickshell/asahi/theme.name"

    property color paper:  "#181616"
    property color ink:    "#c5c9c5"
    property color accent: "#5d799b"
    property color seal:   "#c4746e"

    // ---------- State ----------
    property bool active: false
    property bool panelVisible: false
    property int  shaderIndex: 0

    // Adding a shader = one entry here + drop its .qsb in shaders/.
    // Index order is what the IPC `pick N` and 1..9 hotkeys map onto.
    // Each entry is one fragment-shader slot. Most are plain
    // ShaderEffects; the `life` entry uses a recursive ShaderEffectSource
    // for cell-state feedback and is handled by a separate sub-tree
    // (see lifeContainer below). The list still controls draw order,
    // index assignment, and crossfade.
    readonly property var shaderList: [
        "shaders/plasma.frag.qsb",
        "shaders/fluid.frag.qsb",
        "shaders/crt.frag.qsb",
        "shaders/matrix.frag.qsb",
        "shaders/hexdump.frag.qsb",
        "shaders/buffer.frag.qsb",
        "shaders/invaders.frag.qsb",
        "shaders/fire.frag.qsb",
        "shaders/terminal.frag.qsb",
        "shaders/mrrobot.frag.qsb",
        "life",  // sentinel — special-cased in the stack
        "ascii"  // sentinel — omarchy-style logo text effects (asciiContainer)
    ]
    readonly property int shaderCount: shaderList.length
    readonly property int lifeIndex: 10
    readonly property int asciiIndex: 11

    // Indices that paint with premultiplied alpha and want the desktop
    // visible behind them — the paper backdrop fades out while one of
    // these is on top.
    readonly property var transparentIndices: [2]   // crt
    readonly property bool transparentActive:
        transparentIndices.indexOf(root.shaderIndex) >= 0

    // Auto-cycle cadence. 22s reads as "look at this", longer than that
    // and a fixed viewer notices the pattern repeating.
    readonly property real cycleSec: 22.0
    readonly property real fadeMs:   1600

    function parseColors(text) {
        const re = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]+)"/;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(re);
            if (!m) continue;
            const k = m[1], v = m[2];
            if (k === "background")      root.paper  = v;
            else if (k === "foreground") root.ink    = v;
            else if (k === "color4")     root.accent = v;
            else if (k === "color1")     root.seal   = v;
            else if (k === "accent")     root.accent = v;
        }
    }

    // Asahi theme updates the palette via atomic rm+mv on theme set, which
    // races inotify on the file itself. Watch the sibling theme.name
    // Reload palette when theme.name changes.
    FileView {
        id: paletteFile
        path: root.colorsPath
        onLoaded: root.parseColors(paletteFile.text())
    }
    FileView {
        id: themeMarker
        path: root.themeNamePath
        watchChanges: true
        onFileChanged: { reload(); paletteFile.reload(); }
    }

    // ---------- ASCII branding (omarchy-style saver scene) ----------
    // The logo the ascii scene animates. Regenerate with:
    //   fastfetch --logo asahi --structure none --pipe | sed 's/\x1b\[[0-9;]*m//g'
    readonly property string logoPath: Quickshell.env("HOME") + "/.config/quickshell/screensaver/logo.txt"
    property var logoLines: ["A S A H I"]
    FileView {
        id: logoFile
        path: root.logoPath
        onLoaded: {
            let lines = logoFile.text().split("\n")
            while (lines.length > 0 && lines[lines.length - 1].trim() === "") lines.pop()
            if (lines.length > 0) root.logoLines = lines
        }
    }

    Component.onCompleted: { paletteFile.reload(); logoFile.reload(); }

    function setActive(on: bool): void {
        if (root.active === on && root.panelVisible === on)
            return;
        if (!on) {
            root.active = false;
            Qt.callLater(() => { if (!root.active) root.panelVisible = false; });
            return;
        }
        root.panelVisible = true;
        Qt.callLater(() => { if (root.panelVisible) root.active = true; });
    }

    IpcHandler {
        target: "saver"
        function start():  void { Qt.callLater(() => root.setActive(true)); }
        function stop():   void { root.setActive(false); }
        function toggle(): void { Qt.callLater(() => root.setActive(!root.active)); }
        function next():   void {
            root.shaderIndex = (root.shaderIndex + 1) % root.shaderCount;
            root.elapsed = 0;
        }
        function pick(i: int): void {
            const n = ((i % root.shaderCount) + root.shaderCount) % root.shaderCount;
            root.shaderIndex = n;
            root.elapsed = 0;
        }
    }

    // Shared across every output.
    property real elapsed: 0
    property real armedFor: 0

    Timer {
        id: tick
        interval: 16
        repeat: true
        running: root.active
        onTriggered: {
            root.elapsed += 0.016;
            root.armedFor += 0.016;
            // The ascii scene holds twice as long: it is the omarchy-style
            // headliner and runs several random effects back to back.
            const slot = root.shaderIndex === root.asciiIndex ? root.cycleSec * 2 : root.cycleSec;
            if (root.elapsed >= slot) {
                root.elapsed = 0;
                root.shaderIndex = (root.shaderIndex + 1) % root.shaderCount;
            }
        }
    }

    property string focusScreenName: ""

    onActiveChanged: {
        if (active) {
            const mon = Hyprland.focusedMonitor;
            const screens = Quickshell.screens;
            if (!mon || screens.length === 0)
                root.focusScreenName = screens.length ? screens[0].name : "";
            else
                root.focusScreenName = mon.name;
            // Open on the omarchy-style logo scene, then cycle into shaders.
            root.shaderIndex = root.asciiIndex;
            root.elapsed = 0;
            root.armedFor = 0;
        } else {
            root.focusScreenName = "";
        }
    }

    component SaverSurface : Item {
        id: surf
        anchors.fill: parent

        property real lastX: -1
        property real lastY: -1

        // Baseline paper so the very first frame (and any micro-gap in
        // the cross-fade) shows a themed background, not black. Fades out
        // when a transparent shader is on top so the desktop shows
        // through. The fade is matched to the shader cross-fade so the
        // backdrop hand-off lands at the same beat.
        Rectangle {
            anchors.fill: parent
            color: root.paper
            opacity: root.transparentActive ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: root.fadeMs; easing.type: Easing.InOutQuad } }
        }

        // Shader stack, cross-faded by opacity. Every entry in shaderList
        // gets one ShaderEffect; only the active one is at opacity 1, the
        // others fade in/out around it. They all run every frame even at
        // opacity 0 — fine for a screensaver, nothing else is competing
        // for GPU. The `life` sentinel entry is handled by lifeContainer
        // below instead of the Repeater (it needs feedback wiring).
        Item {
            id: stack
            anchors.fill: parent

            Repeater {
                model: root.shaderList
                delegate: Loader {
                    id: slotLoader
                    required property int index
                    required property string modelData
                    anchors.fill: parent
                    active: root.active && slotLoader.modelData.indexOf("shaders/") === 0
                    sourceComponent: ShaderEffect {
                        anchors.fill: parent
                        opacity: root.shaderIndex === slotLoader.index ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: root.fadeMs; easing.type: Easing.InOutQuad } }
                        property real  iTime: root.elapsed
                        property size  iResolution: Qt.size(width, height)
                        property color colPaper:  root.paper
                        property color colInk:    root.ink
                        property color colAccent: root.accent
                        property color colSeal:   root.seal
                        fragmentShader: slotLoader.modelData
                    }
                }
            }

            // Conway's Life: needs the previous frame as a texture so we
            // wire ShaderEffectSource with recursive: true. The simulation
            // and the display happen in the same ShaderEffect — alpha
            // encodes cell state, RGB carries the visible colour, and
            // gridSize tells the shader how to sample 8 neighbours.
            Item {
                id: lifeContainer
                anchors.fill: parent
                opacity: root.shaderIndex === root.lifeIndex ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.fadeMs; easing.type: Easing.InOutQuad } }

                ShaderEffect {
                    id: lifeEffect
                    anchors.fill: parent
                    property real  iTime: root.elapsed
                    property size  iResolution: Qt.size(width, height)
                    property color colPaper:  root.paper
                    property color colInk:    root.ink
                    property color colAccent: root.accent
                    property color colSeal:   root.seal
                    property size  gridSize: Qt.size(192, 108)
                    property real  seedSec: 28.0
                    property variant prev: lifeSource
                    fragmentShader: "shaders/life.frag.qsb"
                }
                ShaderEffectSource {
                    id: lifeSource
                    sourceItem: lifeEffect
                    recursive: true
                    live: root.active
                    smooth: false
                    hideSource: false
                    // Texture sized to grid so neighbour sampling lines up
                    // with cells regardless of window resolution.
                    textureSize: Qt.size(192, 108)
                }
            }

            // omarchy screensaver port: the ASCII logo animated by a random
            // terminal-text effect (their ttfx saver), re-rolled every few
            // seconds while the scene is up. Two text layers per row: base
            // (ink) carries settled characters, hot (accent) carries the
            // moving/unresolved ones.
            Item {
                id: asciiContainer
                anchors.fill: parent
                opacity: root.shaderIndex === root.asciiIndex ? 1 : 0
                visible: opacity > 0.001
                Behavior on opacity { NumberAnimation { duration: root.fadeMs; easing.type: Easing.InOutQuad } }

                readonly property int rows: root.logoLines.length
                readonly property int cols: {
                    let m = 1
                    for (let i = 0; i < root.logoLines.length; i++)
                        m = Math.max(m, root.logoLines[i].length)
                    return m
                }
                // The family MUST be an installed monospace face. Qt
                // silently substitutes proportional Noto Sans for unknown
                // families ("JetBrainsMono Nerd Font" is not installed
                // here), which shreds column alignment — wide Ms made the
                // logo look melted. Same trap as the launcher's fastfetch
                // logo. The advance is probed, not assumed.
                readonly property string monoFamily: "Noto Sans Mono"
                TextMetrics {
                    id: cellProbe
                    font.family: asciiContainer.monoFamily
                    font.pixelSize: 100
                    text: "M"
                }
                readonly property real advRatio: cellProbe.advanceWidth > 0 ? cellProbe.advanceWidth / 100 : 0.6

                // Terminals stack lines at the font's natural ~1.33 em;
                // anything flatter squashes the logo vertically. The logo
                // fills at most ~60% of either screen axis.
                readonly property real lineFactor: 1.33
                readonly property real cellPx: Math.max(10, Math.min(
                    width * 0.62 / (cols * advRatio),
                    height * 0.6 / (rows * lineFactor)))

                property string kind: "decrypt"
                property real t: 0
                property real dur: 6
                property int seed: 1
                property var baseLines: []
                property var hotLines: []

                readonly property var kinds: ["typewriter", "decrypt", "rain", "beams", "slide", "expand"]
                readonly property string glyphs: "!<>-_\\/[]{}=+*^?#$%&@abcdefghikmnopqrstuvwxyz0123456789"

                // Deterministic per-(seed, n) hash → [0, 1). Stable across
                // ticks so every character keeps its own timing/jitter.
                function rnd(n) {
                    let x = Math.imul(n + 1, 2654435761) ^ Math.imul(asciiContainer.seed, 40503)
                    x = Math.imul(x ^ (x >>> 13), 1274126177)
                    x ^= x >>> 16
                    return (x >>> 0) / 4294967296
                }
                function randGlyph(n) {
                    return glyphs.charAt(Math.floor(rnd(n) * glyphs.length))
                }

                function restart() {
                    seed = Math.floor(Math.random() * 2147483647) || 1
                    let next = kinds[Math.floor(Math.random() * kinds.length)]
                    if (next === kind) next = kinds[(kinds.indexOf(next) + 1) % kinds.length]
                    kind = next
                    dur = kind === "typewriter" || kind === "decrypt" ? 7 : 5.5
                    t = 0
                    step()
                }

                function step() {
                    const lines = root.logoLines
                    const R = rows, C = cols, time = t, k = kind
                    const B = [], H = []
                    for (let r = 0; r < R; r++) {
                        B.push(new Array(C).fill(" "))
                        H.push(new Array(C).fill(" "))
                    }
                    const flicker = Math.floor(time * 12) * 7919
                    if (k === "typewriter") {
                        const frontier = time / (dur - 0.8) * R * C
                        for (let r = 0; r < R; r++) {
                            const line = lines[r]
                            for (let c = 0; c < line.length; c++) {
                                if (r * C + c < frontier) B[r][c] = line[c]
                            }
                        }
                        const fr = Math.floor(frontier / C), fc = Math.floor(frontier % C)
                        if (fr < R) H[fr][Math.min(fc, C - 1)] = "\u2588"
                    } else if (k === "decrypt") {
                        for (let r = 0; r < R; r++) {
                            const line = lines[r]
                            for (let c = 0; c < line.length; c++) {
                                if (line[c] === " ") continue
                                const idx = r * C + c
                                const resolve = 0.6 + rnd(idx) * (dur - 1.8)
                                if (time >= resolve) B[r][c] = line[c]
                                else H[r][c] = randGlyph(idx + flicker)
                            }
                        }
                    } else if (k === "rain") {
                        const speed = R / (dur * 0.4)
                        for (let r = 0; r < R; r++) {
                            const line = lines[r]
                            for (let c = 0; c < line.length; c++) {
                                if (line[c] === " ") continue
                                const idx = r * C + c
                                const cur = Math.floor((time - rnd(idx) * dur * 0.45) * speed)
                                if (cur < 0) continue
                                if (cur >= r) B[r][c] = line[c]
                                else H[cur][c] = line[c]
                            }
                        }
                    } else if (k === "beams") {
                        const sweep = time / (dur * 0.8) * (R + 4) - 2
                        for (let r = 0; r < R; r++) {
                            const line = lines[r]
                            for (let c = 0; c < line.length; c++) {
                                if (line[c] === " ") continue
                                if (r < sweep - 1.5) B[r][c] = line[c]
                                else if (r < sweep + 1.5) H[r][c] = randGlyph(r * C + c + flicker)
                            }
                        }
                    } else if (k === "slide") {
                        const speed = (C * 1.6) / (dur * 0.7)
                        for (let r = 0; r < R; r++) {
                            const line = lines[r]
                            const shift = Math.max(0, Math.floor(C + 4 - (time - r * 0.08) * speed))
                            for (let c = 0; c < line.length; c++) {
                                if (line[c] === " ") continue
                                if (shift === 0) { B[r][c] = line[c]; continue }
                                // Even rows enter from the right, odd from the left.
                                const at = r % 2 === 0 ? c + shift : c - shift
                                if (at >= 0 && at < C) H[r][at] = line[c]
                            }
                        }
                    } else { // expand
                        const cy = (R - 1) / 2, cx = (C - 1) / 2
                        const maxd = cx * 0.55 + cy * 1.4
                        const reach = time / (dur * 0.8) * (maxd + 1.5)
                        for (let r = 0; r < R; r++) {
                            const line = lines[r]
                            for (let c = 0; c < line.length; c++) {
                                if (line[c] === " ") continue
                                const d = Math.abs(c - cx) * 0.55 + Math.abs(r - cy) * 1.4
                                if (d < reach - 1.2) B[r][c] = line[c]
                                else if (d < reach + 1.2) H[r][c] = randGlyph(r * C + c + flicker)
                            }
                        }
                    }
                    const bases = [], hots = []
                    for (let r = 0; r < R; r++) { bases.push(B[r].join("")); hots.push(H[r].join("")) }
                    baseLines = bases
                    hotLines = hots
                }

                onVisibleChanged: if (visible) restart()

                Timer {
                    interval: 33
                    repeat: true
                    running: asciiContainer.visible && root.active
                    onTriggered: {
                        asciiContainer.t += 0.033
                        if (asciiContainer.t > asciiContainer.dur + 2.6) asciiContainer.restart()
                        else asciiContainer.step()
                    }
                }

                // Two overlaid multi-line texts (settled ink + moving
                // accent) with a FIXED line height. Per-row Items squeezed
                // lines below the font's natural height and distorted the
                // logo; a single Text with fixed line spacing keeps the
                // terminal aspect exactly, and both layers stay aligned.
                Item {
                    anchors.centerIn: parent
                    width: asciiContainer.cols * asciiContainer.cellPx * asciiContainer.advRatio
                    height: asciiContainer.rows * asciiContainer.cellPx * asciiContainer.lineFactor
                    Text {
                        anchors.fill: parent
                        text: asciiContainer.baseLines.join("\n")
                        textFormat: Text.PlainText
                        color: root.ink
                        font.family: asciiContainer.monoFamily
                        font.pixelSize: asciiContainer.cellPx
                        lineHeight: asciiContainer.cellPx * asciiContainer.lineFactor
                        lineHeightMode: Text.FixedHeight
                    }
                    Text {
                        anchors.fill: parent
                        text: asciiContainer.hotLines.join("\n")
                        textFormat: Text.PlainText
                        color: root.accent
                        font.family: asciiContainer.monoFamily
                        font.pixelSize: asciiContainer.cellPx
                        lineHeight: asciiContainer.cellPx * asciiContainer.lineFactor
                        lineHeightMode: Text.FixedHeight
                    }
                }
            }
        }

        // Thin theme strip across the bottom — like a slide footer. Pure
        // QML, sits on top of the shader. Looks intentional; also reassures
        // you the theme parser actually grabbed real colours.
        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 36
            spacing: 14
            opacity: 0.55
            Rectangle { width: 36; height: 3; color: root.paper;  radius: 1 }
            Rectangle { width: 36; height: 3; color: root.ink;    radius: 1 }
            Rectangle { width: 36; height: 3; color: root.accent; radius: 1 }
            Rectangle { width: 36; height: 3; color: root.seal;   radius: 1 }
        }

        // ---------- Dismissal ----------
        // Any real input → close. Position-change has to ignore the first
        // event (the cursor's resting position when the overlay maps) and
        // the small jitter on map; armedFor adds a 250 ms grace.
        MouseArea {
            id: dismissArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onPressed: root.setActive(false)
            onWheel: root.setActive(false)
            onPositionChanged: (m) => {
                if (surf.lastX < 0) { surf.lastX = m.x; surf.lastY = m.y; return; }
                if (root.armedFor < 0.25) { surf.lastX = m.x; surf.lastY = m.y; return; }
                const dx = m.x - surf.lastX, dy = m.y - surf.lastY;
                if (dx * dx + dy * dy > 9) root.setActive(false);
            }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                if (root.armedFor < 0.25) { e.accepted = true; return; }
                if (e.key === Qt.Key_0) {
                    root.shaderIndex = root.asciiIndex;
                    root.elapsed = 0;
                    e.accepted = true;
                    return;
                }
                const maxKey = Qt.Key_1 + Math.min(root.shaderCount, 9) - 1;
                if (e.key >= Qt.Key_1 && e.key <= maxKey) {
                    root.shaderIndex = e.key - Qt.Key_1;
                    root.elapsed = 0;
                    e.accepted = true;
                    return;
                }
                if (e.key === Qt.Key_Right || e.key === Qt.Key_L || e.key === Qt.Key_Space
                    || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) {
                    root.shaderIndex = (root.shaderIndex + 1) % root.shaderCount;
                    root.elapsed = 0;
                    e.accepted = true;
                    return;
                }
                if (e.key === Qt.Key_Left || e.key === Qt.Key_H || e.key === Qt.Key_Backtab
                    || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier))) {
                    root.shaderIndex = (root.shaderIndex - 1 + root.shaderCount) % root.shaderCount;
                    root.elapsed = 0;
                    e.accepted = true;
                    return;
                }
                root.setActive(false);
                e.accepted = true;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.panelVisible
            focusable: root.active && modelData.name === root.focusScreenName
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "screensaver"
            WlrLayershell.keyboardFocus: root.active && modelData.name === root.focusScreenName
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            Loader {
                anchors.fill: parent
                active: root.active
                sourceComponent: SaverSurface {}
            }
        }
    }
}
