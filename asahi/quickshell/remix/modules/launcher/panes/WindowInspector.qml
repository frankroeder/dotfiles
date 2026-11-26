import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "../../menu" as Menu
import "../../../"

// Windows mode (`,`) side card (idea: caelestia windowinfo): the highlighted window as a still capture (one frame per
// selection, never live), its state and process, and the window actions of bindings.lua aimed at this window (not the
// focused one): float / pin / center / pseudo / opaque, maximize / fullscreen / in the tile, PiP and pop, group, move to a
// workspace or display, screenshot, a new window of the app, close and kill (twice). `root` is the LauncherWindow,
// `address` the row's window (Quickshell's form: no 0x).
Item {
  id: wi
  property var root
  property string address: ""
  readonly property var tl: {
    wi.root.winVersion
    return (Hyprland.toplevels.values || []).find(t => t.address === wi.address) || null
  }
  readonly property var ipc: wi.tl ? (wi.tl.lastIpcObject || {}) : ({})
  readonly property string cls: (wi.tl && wi.tl.wayland && wi.tl.wayland.appId) || wi.ipc.class || ""
  readonly property var de: wi.cls ? DesktopEntries.heuristicLookup(wi.cls) : null
  readonly property bool floating: !!wi.ipc.floating
  readonly property int fs: wi.ipc.fullscreen || 0               // 0 none · 1 maximized · 2 fullscreen
  readonly property int fsClient: wi.ipc.fullscreenClient || 0   // 2 with fs 0 = fullscreen inside its tile
  readonly property int groupSize: (wi.ipc.grouped || []).length
  readonly property var tags: (wi.ipc.tags || []).map(t => String(t).replace(/\*$/, ""))
  property var proc: ({})                                       // ps: rss (KiB), etimes (s), args
  property string armed: ""                                     // "close" / "kill": waits for the second click
  onAddressChanged: { wi.armed = ""; wi.proc = ({}); wi.regrabbed = false; grab.restart(); procRead.restart() }

  function lua(fn, extra) { return "hl.dsp." + fn + "({ " + (extra ? extra + ", " : "") + "window = \"address:0x" + wi.address + "\" })" }
  // Dispatches in order (one shell, one hyprctl each): float first, then size / center (a resize in the same call still
  // saw a tiled window: asahi-window-gesture).
  function act(...luas) {
    Quickshell.execDetached(["sh", "-c", "for d; do hyprctl dispatch \"$d\" >/dev/null; done", "sh"].concat(luas))
    wi.root.refreshWindowsSoon()
    grab.restart()
  }
  // Float like asahi-window-gesture: 60 % of its display, centred (a tiled window floated at its tile size, often huge).
  function floatToggle() {
    if (wi.floating) { wi.act(wi.lua("window.float", "action = \"disable\"")); return }
    const m = wi.tl && wi.tl.monitor
    const w = m ? Math.round(m.width / (m.scale || 1) * 0.6) : 960, h = m ? Math.round(m.height / (m.scale || 1) * 0.6) : 600
    wi.act(wi.lua("window.float", "action = \"enable\""), wi.lua("window.resize", "x = " + w + ", y = " + h + ", relative = false"),
      wi.lua("window.center"))
  }
  // Scripts that work on the focused window (Pop, PiP): focus it, then run them; the launcher goes first. The focus
  // waits for its unmap (as focusWindowAfterClose): the leaving exclusive layer hands focus back to the old window.
  function viaFocus(script) {
    const focus = "hl.dsp.focus({ window = \"address:0x" + wi.address + "\" })"
    wi.root.closeLauncher()
    const wait = (Style.menuAnimOutMs + 80) / 1000
    Quickshell.execDetached(["sh", "-c", "sleep " + wait + "; hyprctl dispatch \"$1\" >/dev/null; sleep 0.15; exec \"$2\" \"${@:3}\"",
      "sh", focus].concat(script))
  }
  // The usual screenshot (asahi-cmd-screenshot: saved, copied, the Open / Annotate card) of this window's rectangle,
  // once the launcher is gone; only while the window is on screen (grim reads the screen).
  function screenshot() {
    if (!wi.ipc.visible || !wi.ipc.at || !wi.ipc.size) return
    const g = wi.ipc.at[0] + "," + wi.ipc.at[1] + " " + wi.ipc.size[0] + "x" + wi.ipc.size[1]
    wi.root.closeLauncher()
    Quickshell.execDetached(["sh", "-c", "sleep " + (Style.menuAnimOutMs / 1000 + 0.15) + "; ASAHI_SHOT_GEOMETRY=\"$1\" exec \"$2\" windows", "sh",
      g, wi.root.binDir + "/asahi-cmd-screenshot"])
  }
  function copy(text) {
    if (!text) return
    Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", String(text)])
    if (wi.root.osd && wi.root.osd.toast) wi.root.osd.toast("󰆏", "Copied", String(text).slice(0, 40), 1200)
  }
  function twice(what, luaCall) {
    if (wi.armed !== what) { wi.armed = what; disarm.restart(); return }
    wi.armed = ""
    wi.act(luaCall)
  }
  Timer { id: disarm; interval: 3000; onTriggered: wi.armed = "" }

  function fmtAge(s) {
    s = Number(s) || 0
    return s >= 86400 ? Math.floor(s / 86400) + " d " + Math.floor(s % 86400 / 3600) + " h"
      : s >= 3600 ? Math.floor(s / 3600) + " h " + Math.floor(s % 3600 / 60) + " min" : Math.max(1, Math.floor(s / 60)) + " min"
  }

  // One still per selection (and after an action): a live capture would redraw at the window's frame rate. A failed frame
  // drops the view's context (Quickshell 0.2.1), and only a new source makes another: captureFrame then just warned
  // ("no recording context is ready") and the preview stayed the icon. No frame yet: re-set the source, once a selection.
  readonly property var src: wi.tl && wi.tl.wayland ? wi.tl.wayland : null
  property bool regrabbed: false
  Timer {
    id: grab; interval: 120
    onTriggered: {
      if (!shot.captureSource) return
      if (shot.hasContent) shot.captureFrame()
      else if (!wi.regrabbed) {
        wi.regrabbed = true
        shot.captureSource = null
        shot.captureSource = Qt.binding(() => wi.src)
      }
    }
  }
  // Its process, once per selection: resident memory, age, command line.
  Timer { id: procRead; interval: 150; onTriggered: if (wi.ipc.pid > 0 && !procProc.running) procProc.running = true }
  Process {
    id: procProc
    command: ["ps", "-o", "rss=,etimes=,args=", "-p", String(wi.ipc.pid || 0)]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = /^\s*(\d+)\s+(\d+)\s+(.*)$/.exec(text.trim())
        wi.proc = m ? { rss: Number(m[1]), etimes: Number(m[2]), args: m[3] } : ({})
      }
    }
  }

  component Caption: Menu.MenuCaption { font.pixelSize: wi.root.fontPx(8) }
  // A fact row; a click copies the value.
  component Fact: Item {
    id: fact
    property string label: ""
    property string value: ""
    property bool mono: true
    Layout.fillWidth: true
    implicitHeight: factRow.implicitHeight + 4
    visible: value !== ""
    Rectangle { anchors.fill: parent; radius: Style.radiusSm; color: factMa.containsMouse ? Style.m3stateHover : "transparent" }
    RowLayout {
      id: factRow
      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 4; rightMargin: 4 }
      spacing: 10
      Text {
        text: fact.label
        Layout.preferredWidth: wi.root.fontPx(10) * 6.5
        color: Style.m3onSurfaceVariant; font.family: wi.root.uiSans; font.pixelSize: wi.root.fontPx(10)
      }
      Text {
        Layout.fillWidth: true
        text: fact.value
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Style.m3onSurface; font.family: fact.mono ? Style.fontData : wi.root.uiSans; font.pixelSize: wi.root.fontPx(10)
      }
    }
    MouseArea { id: factMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wi.copy(fact.value) }
  }
  component Act: Menu.MenuPill { fontScale: wi.root.uiFontScale; opacity: enabled ? 1 : 0.4 }
  property string hint: ""
  component Btn: Menu.MenuIconBtn {
    id: btn
    fontScale: wi.root.uiFontScale
    iconPx: 15
    opacity: enabled ? 1 : 0.4
    readonly property string tip: ({ "󰁔": "Focus", "󰹑": "Screenshot (saved + copied)", "󰪵": "New window of this app", "󰅖": "Close", "󰚌": "Kill (force quit)" })[btn.icon] || ""
    HoverHandler { onHoveredChanged: wi.hint = hovered ? btn.tip : (wi.hint === btn.tip ? "" : wi.hint) }
  }
  component StateChip: Menu.MenuChip { fontScale: wi.root.uiFontScale }

  Flickable {
    id: flick
    anchors.fill: parent
    visible: !!wi.tl
    clip: true
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: Menu.MenuScrollBar { id: bar }
    Menu.MenuEdgeFade { parent: flick; surface: Style.m3surface; atTop: true; gutter: bar.width }
    Menu.MenuEdgeFade { parent: flick; surface: Style.m3surface; gutter: bar.width }

    ColumnLayout {
      id: col
      width: flick.width - (bar.overflow ? bar.implicitWidth + 4 : 0)
      spacing: 8

      // The capture, letterboxed to the window's aspect.
      ClippingRectangle {
        id: frame   // children sit in its content item: `parent` there is not this
        readonly property real aspect: (wi.ipc.size && wi.ipc.size[1] > 0) ? wi.ipc.size[0] / wi.ipc.size[1] : 16 / 10
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(width / aspect, wi.height * 0.26)
        radius: Style.menuRadiusLg
        color: Style.m3container
        ScreencopyView {
          id: shot
          anchors.centerIn: parent
          width: Math.min(frame.width, frame.height * frame.aspect)
          height: width / frame.aspect
          captureSource: wi.src
          live: false
          onCaptureSourceChanged: grab.restart()
        }
        // No frame (a client that won't share): the app icon.
        Image {
          anchors.centerIn: parent
          visible: !shot.hasContent
          width: 64; height: 64
          sourceSize: Qt.size(128, 128)
          source: wi.de && wi.de.icon ? wi.root.resolveIconUrl(wi.de.icon) : ""
        }
      }

      // Title + the window's own actions (icons: Focus, Screenshot, New window, Close, Kill — the last two take a second
      // click within 3 s, red while armed).
      RowLayout {
        Layout.fillWidth: true
        spacing: 4
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text {
            Layout.fillWidth: true
            text: wi.tl ? (wi.tl.title || wi.cls) : ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Style.m3onSurface; font.family: wi.root.uiSans; font.pixelSize: wi.root.fontPx(13); font.weight: Font.DemiBold
          }
          // The app; while an icon is under the pointer what it does, while Close / Kill is armed the question (in place:
          // no line comes and goes).
          Text {
            Layout.fillWidth: true
            text: wi.armed === "close" ? "Close again to confirm" : wi.armed === "kill" ? "Kill again: the app stops without saving"
              : wi.hint !== "" ? wi.hint : (wi.de ? wi.de.name + "  ·  " : "") + wi.cls
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: wi.armed !== "" ? Style.red : wi.hint !== "" ? Style.m3primary : Style.m3onSurfaceVariant
            font.family: wi.root.uiSans; font.pixelSize: wi.root.fontPx(10)
          }
        }
        Btn { icon: "󰁔"; onClicked: wi.root.focusWindowAfterClose(wi.address) }
        Btn { icon: "󰹑"; enabled: !!wi.ipc.visible; onClicked: wi.screenshot() }
        Btn { icon: "󰪵"; enabled: !!wi.de; onClicked: { wi.root.closeLauncher(); wi.root.launchDesktopEntry(wi.de) } }
        Btn {
          icon: "󰅖"; tone: wi.armed === "close" ? Style.red : Style.m3onSurfaceVariant; hot: Style.red
          bg: wi.armed === "close" ? Style.panelDangerBg : "transparent"
          onClicked: wi.twice("close", wi.lua("window.close"))
        }
        Btn {
          icon: "󰚌"; tone: wi.armed === "kill" ? Style.red : Style.m3onSurfaceVariant; hot: Style.red
          bg: wi.armed === "kill" ? Style.panelDangerBg : "transparent"
          onClicked: wi.twice("kill", wi.lua("window.kill"))
        }
      }
      Flow {
        Layout.fillWidth: true
        spacing: 6
        StateChip { label: wi.floating ? "Floating" : "Tiled"; icon: wi.floating ? "󰖲" : "󰕰" }
        StateChip { visible: wi.fs > 0 || wi.fsClient > 0; label: wi.fs === 2 ? "Fullscreen" : wi.fs === 1 ? "Maximized" : "Fullscreen in tile"; icon: "󰊓" }
        StateChip { visible: !!wi.ipc.pinned; label: "Pinned"; icon: "󰐃" }
        StateChip { visible: wi.groupSize > 0; label: "Group of " + wi.groupSize; icon: "󰓩" }
        StateChip { visible: !!wi.ipc.inhibitingIdle; label: "Keeps awake"; icon: "󰅶"; bg: Qt.alpha(Style.yellow, 0.2) }
        StateChip { visible: !!wi.ipc.contentType && wi.ipc.contentType !== "none"; label: String(wi.ipc.contentType); icon: "󰕧" }
        StateChip { visible: !!wi.ipc.xwayland; label: "XWayland"; icon: "󰕵"; bg: Qt.alpha(Style.orange, 0.2) }
        Repeater { model: wi.tags; StateChip { required property var modelData; label: "#" + modelData; icon: "󰓹" } }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Fact {
          label: "Where"
          value: "ws " + (wi.ipc.workspace ? wi.ipc.workspace.name : "?") + " · " + (wi.tl && wi.tl.monitor ? wi.tl.monitor.name : "")
            + (wi.ipc.size ? "  ·  " + wi.ipc.size[0] + "×" + wi.ipc.size[1] + " at " + wi.ipc.at[0] + "," + wi.ipc.at[1] : "")
        }
        Fact {
          label: "Process"
          value: !wi.ipc.pid ? "" : "pid " + wi.ipc.pid + (wi.proc.rss ? "  ·  " + wi.root.prettyBytes(wi.proc.rss * 1024) : "")
            + (wi.proc.etimes ? "  ·  up " + wi.fmtAge(wi.proc.etimes) : "")
        }
        Fact { label: "Command"; value: wi.proc.args || (wi.ipc.pid ? " " : "") }   // laid out while ps runs (rows bounced)
      }

      Caption { text: "Layout" }
      Flow {
        Layout.fillWidth: true
        spacing: 6
        Act { icon: "󰖲"; label: wi.floating ? "Tile" : "Float"; onClicked: wi.floatToggle() }
        Act { icon: "󰐃"; label: wi.ipc.pinned ? "Unpin" : "Pin"; enabled: wi.floating; onClicked: wi.act(wi.lua("window.pin", "action = \"toggle\"")) }
        Act { icon: "󰘞"; label: "Center"; enabled: wi.floating; onClicked: wi.act(wi.lua("window.center")) }
        Act { icon: "󰗆"; label: "Pseudo"; enabled: !wi.floating; onClicked: wi.act(wi.lua("window.pseudo")) }
        Act { icon: "󰽗"; label: "Opaque"; onClicked: wi.act(wi.lua("window.set_prop", "prop = \"opaque\", value = \"toggle\"")) }
        Act { icon: "󰓩"; label: wi.groupSize > 0 ? "Ungroup" : "Group"; onClicked: wi.act(wi.lua("group.toggle")) }
        Act { visible: wi.groupSize > 1; icon: "󰓪"; label: "Leave group"; onClicked: wi.act(wi.lua("window.move", "out_of_group = true")) }
      }
      Caption { text: "Fill" }
      Flow {
        Layout.fillWidth: true
        spacing: 6
        Act { icon: "󰖯"; label: "Maximize"; selected: wi.fs === 1; onClicked: wi.act(wi.lua("window.fullscreen", "mode = \"maximized\"")) }
        Act { icon: "󰊓"; label: "Fullscreen"; selected: wi.fs === 2; onClicked: wi.act(wi.lua("window.fullscreen")) }
        Act {
          icon: "󰘖"; label: "In tile"; selected: wi.fs === 0 && wi.fsClient === 2
          onClicked: wi.act(wi.lua("window.fullscreen_state", "internal = 0, client = " + (wi.fsClient === 2 ? 0 : 2)))
        }
        Act { icon: "󰊔"; label: "PiP"; onClicked: wi.viaFocus([wi.root.binDir + "/asahi-window-gesture", "pip"]) }
        Act { icon: "󰁌"; label: "Pop"; onClicked: wi.viaFocus([wi.root.binDir + "/asahi-window-pop"]) }
      }
      // Move: any workspace (1–5 external, 6–10 built-in; monitors.lua) or another display.
      Caption { text: "Move to" }
      Flow {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
          model: 10
          Menu.MenuChip {
            required property int index
            readonly property int ws: index + 1
            readonly property bool here: !!wi.ipc.workspace && wi.ipc.workspace.id === ws
            label: String(ws)
            clickable: !here
            fixedWidth: wi.root.fontPx(10) * 2.6
            bg: here ? Style.m3primaryContainer : Style.m3container
            fg: here ? Style.m3primary : Style.m3onSurface
            fontScale: wi.root.uiFontScale
            onClicked: wi.act(wi.lua("window.move", "workspace = " + ws + ", follow = false"))
          }
        }
        Repeater {
          model: (Hyprland.monitors.values || []).filter(m => !(wi.tl && wi.tl.monitor && wi.tl.monitor.name === m.name))
          Menu.MenuChip {
            required property var modelData
            icon: "󰍹"; label: modelData.name
            clickable: true
            fontScale: wi.root.uiFontScale
            onClicked: wi.act(wi.lua("window.move", "monitor = \"" + modelData.name + "\""))
          }
        }
      }

    }
  }

  Menu.MenuEmptyState {
    anchors.centerIn: parent
    visible: !wi.tl
    fontScale: wi.root.uiFontScale
    glyph: "󰖯"
    tint: Style.m3primary
    title: "No window selected"
    detail: "Pick a window on the left"
  }
}
