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
        "life"   // sentinel — special-cased in the stack
    ]
    readonly property int shaderCount: shaderList.length
    readonly property int lifeIndex: 10

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

    Component.onCompleted: paletteFile.reload()

    IpcHandler {
        target: "saver"
        function start():  void { root.active = true; }
        function stop():   void { root.active = false; }
        function toggle(): void { root.active = !root.active; }
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
            if (root.elapsed >= root.cycleSec) {
                root.elapsed = 0;
                root.shaderIndex = (root.shaderIndex + 1) % root.shaderCount;
            }
        }
    }

    onActiveChanged: {
        if (active) {
            root.elapsed = 0;
            root.armedFor = 0;
        }
    }

    readonly property var focusScreen: {
        const mon = Hyprland.focusedMonitor;
        const screens = Quickshell.screens;
        if (!mon || screens.length === 0) return screens[0] ?? null;
        return screens.find(s => s.name === mon.name) ?? screens[0];
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
                    active: slotLoader.modelData !== "life"
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
                    live: true
                    smooth: false
                    hideSource: false
                    // Texture sized to grid so neighbour sampling lines up
                    // with cells regardless of window resolution.
                    textureSize: Qt.size(192, 108)
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

            onPressed: root.active = false
            onWheel: root.active = false
            onPositionChanged: (m) => {
                if (surf.lastX < 0) { surf.lastX = m.x; surf.lastY = m.y; return; }
                if (root.armedFor < 0.25) { surf.lastX = m.x; surf.lastY = m.y; return; }
                const dx = m.x - surf.lastX, dy = m.y - surf.lastY;
                if (dx * dx + dy * dy > 9) root.active = false;
            }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                if (root.armedFor < 0.25) { e.accepted = true; return; }
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
                root.active = false;
                e.accepted = true;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.active
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "screensaver"
            WlrLayershell.keyboardFocus: root.active && modelData === root.focusScreen
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            SaverSurface {}
        }
    }
}
