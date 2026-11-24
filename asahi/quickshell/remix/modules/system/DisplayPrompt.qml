import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.VectorImage
import "../menu" as Menu
import "../../"

// New-display prompt (idea: snes19xx/surface-dots lib/MonitorPrompt.qml). `asahi-hdmi added` calls `display plugged
// <name>` once per plug (never for a reload's re-enable). Unknown screen: four tiles on the built-in display —
// Extend · Mirror · Laptop only · External only (1–4, ←/→ + Enter, click; Esc keeps what is live). A pick applies at
// once (`asahi-hdmi mode`) on a 10 s Keep / Revert probation like the Monitors pane (silence or Revert = Extend); Keep
// remembers it (`asahi-hdmi remember`: monitor-layout.json, keyed by the EDID description = make + model + serial).
// Known screen: its mode is applied and a 5 s card says "<model> · Mirror  change ▸" (click: the tiles again).
Scope {
  id: root

  property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"   // a harness points it at a copy
  property string phase: ""          // "" · toast (known screen) · ask (tiles) · confirm (on probation)
  property string look: "ask"        // the phase the card draws, kept through its exit
  property string output: ""         // HDMI-A-1 / DP-n
  property string label: ""          // EDID model
  property string current: "extend"  // live mode of `output` (asahi-hdmi added sets up extend)
  property string picked: ""         // on probation, or the toast's mode
  property bool fresh: true          // never chosen for this screen
  property int sel: 0
  property int left: 0
  property string status: ""         // asahi-hdmi's refusal
  property var queue: []             // a dock's second output waits for the first card
  property bool busy: false
  property string after: ""          // mode to run once the running one is done

  readonly property var modes: [
    { key: "extend", label: "Extend", hint: "One desktop", icon: "extend.svg" },
    { key: "mirror", label: "Mirror", hint: "Same picture", icon: "mirror.svg" },
    { key: "laptop", label: "Laptop only", hint: "External off", icon: "laptop.svg" },
    { key: "external", label: "External only", hint: "Built-in off", icon: "external.svg" }
  ]
  function modeLabel(k) { const m = root.modes.find(x => x.key === k); return m ? m.label : k }
  readonly property bool asking: root.phase === "ask" || root.phase === "confirm"

  // The built-in display, unless it is off (external only, clamshell): then the new one.
  readonly property var cardScreen: Quickshell.screens.find(s => s.name === "eDP-1")
    ?? Quickshell.screens.find(s => s.name === root.output) ?? Quickshell.screens[0] ?? null

  function plugged(name) {
    if (root.asking || root.busy || recall.running) {
      if (root.queue.indexOf(name) < 0) root.queue = root.queue.concat([name])
      return
    }
    recall.command = [root.binDir + "/asahi-hdmi", "recall", name]
    recall.running = true
  }
  function unplugged(name) {
    root.queue = root.queue.filter(n => n !== name)
    if (root.output === name && root.phase !== "") { root.after = ""; root.close() }
  }
  function next() {
    if (!root.queue.length || root.asking || root.busy) return
    const n = root.queue[0]
    root.queue = root.queue.slice(1)
    root.plugged(n)
  }
  function recalled(text) {
    let r = null
    try { r = JSON.parse(text) } catch (e) { return root.next() }   // gone again before the recall
    root.output = r.name
    root.label = r.label || r.name
    root.status = ""
    root.current = "extend"
    root.fresh = !root.modes.some(m => m.key === r.mode)
    if (root.fresh) return root.ask()
    if (r.mode !== "extend") root.run(r.mode)
    root.picked = r.mode
    root.show("toast")
    toastTimer.restart()
  }

  function show(p) {
    const was = root.phase !== ""
    root.phase = p
    root.look = p
    if (!was) { popOut.stop(); slideOut.stop(); popIn.restart(); slideIn.restart() }
    if (root.asking) { idle.restart(); keys.forceActiveFocus() }
  }
  function close() {
    countdown.stop(); toastTimer.stop(); idle.stop()
    if (root.phase === "") return
    root.phase = ""
    popIn.stop(); slideIn.stop(); popOut.restart(); slideOut.restart()
    Qt.callLater(root.next)
  }
  function ask() {
    toastTimer.stop()
    root.sel = Math.max(0, root.modes.findIndex(m => m.key === root.current))
    root.show("ask")
  }

  // One asahi-hdmi mode at a time; a second waits in `after` (revert during an apply, the step through extend).
  function run(k) {
    if (root.busy) { root.after = k; return }
    root.busy = true
    modeProc.want = k
    modeProc.command = [root.binDir + "/asahi-hdmi", "mode", root.output, k]
    modeProc.running = true
  }
  function applied(ok, err) {
    root.busy = false
    if (!ok) {
      root.after = ""
      root.status = String(err || "").trim().split("\n").pop() || "asahi-hdmi failed"
      if (root.phase === "confirm") { countdown.stop(); root.show("ask") }   // nothing to keep: pick again
      return
    }
    root.current = modeProc.want
    if (root.after) { const k = root.after; root.after = ""; return root.run(k) }
    if (root.phase === "confirm" && root.current === root.picked) countdown.restart()
    Qt.callLater(root.next)
  }
  function remember(k) { Quickshell.execDetached([root.binDir + "/asahi-hdmi", "remember", root.output, k]) }

  function pick(i) {
    const k = root.modes[i].key
    root.sel = i
    root.status = ""
    // Live already, or extend (the safe state): no probation.
    if (k === root.current || k === "extend") {
      if (k !== root.current) root.run(k)
      root.remember(k)
      return root.close()
    }
    root.picked = k
    if (root.current !== "extend") root.run("extend")   // asahi-hdmi takes the other modes one step from extend
    root.run(k)
    root.left = 10
    root.show("confirm")
  }
  function keep() {
    if (root.busy) return
    root.remember(root.picked)
    root.close()
  }
  function revert(timedOut) {
    countdown.stop()
    root.after = ""
    root.run("extend")
    if (timedOut) root.close()
    else root.show("ask")
  }

  Timer { id: toastTimer; interval: 5000; onTriggered: root.close() }
  Timer {
    id: countdown
    interval: 1000; repeat: true
    onTriggered: { root.left -= 1; if (root.left <= 0) root.revert(true) }
  }
  // Exclusive keyboard: an unnoticed card (lid half shut, other desk) must not hold the keys forever. Esc semantics.
  Timer { id: idle; interval: 30000; onTriggered: if (root.phase === "ask") root.close() }

  Process {
    id: recall
    stdout: StdioCollector { onStreamFinished: root.recalled(text) }
  }
  Process {
    id: modeProc
    property string want: ""
    stderr: StdioCollector { id: modeErr }
    onExited: code => root.applied(code === 0, modeErr.text)
  }

  // `asahi-hdmi added` / `removed`; by hand: qs -c remix ipc call display plugged DP-1
  IpcHandler {
    target: "display"
    function plugged(name: string): void { root.plugged(name) }
    function unplugged(name: string): void { root.unplugged(name) }
  }

  Menu.MenuPopIn { id: popIn; target: card }
  Menu.MenuPopOut { id: popOut; target: card }
  Menu.MenuAnim { id: slideIn; target: slide; property: "y"; from: 16; to: 0 }
  Menu.MenuAnim { id: slideOut; target: slide; property: "y"; to: 16; exit: true }

  // Mode tile: the Monitors pane's pictogram (white + alpha, tinted), label, hint, the key as a keycap.
  component ModeTile: Rectangle {
    id: tile
    required property var modelData
    required property int index
    readonly property bool on: root.sel === tile.index
    readonly property color fg: tile.on ? Style.m3onPrimary : Style.m3onSurface
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: tileCol.implicitHeight + 28
    radius: tileMa.pressed && !Style.reduceMotion ? Style.menuRadiusSm : Style.menuRadiusMd
    color: tile.on ? Style.m3primary : Style.m3container
    border.width: tile.on ? 0 : 1
    border.color: tileMa.containsMouse ? Style.m3outline : Style.m3outlineVariant
    scale: tileMa.pressed && !Style.reduceMotion ? 0.97 : 1
    Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
    Behavior on radius { NumberAnimation { duration: Style.menuStateMs; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Style.menuStateMs; easing.type: Easing.OutCubic } }
    Rectangle {
      anchors.fill: parent
      radius: parent.radius
      color: tileMa.pressed ? Style.m3statePress : Style.m3stateHover
      opacity: tileMa.containsMouse || tileMa.pressed ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: Style.menuStateMs } }
    }
    Rectangle {
      x: 7; y: 7
      width: 16; height: 16
      radius: 4
      color: tile.on ? Qt.alpha(Style.m3onPrimary, 0.14) : Style.m3containerHigh
      border.width: tile.on ? 0 : 1
      border.color: Style.menuHairline
      Text {
        anchors.centerIn: parent
        text: String(tile.index + 1)
        color: tile.fg
        opacity: 0.8
        font.family: Style.fontData; font.pixelSize: 10; font.weight: Font.DemiBold
      }
    }
    ColumnLayout {
      id: tileCol
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: 3
      spacing: 3
      VectorImage {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 72
        Layout.preferredHeight: 30
        Layout.bottomMargin: 4
        source: "../launcher/panes/icons/" + tile.modelData.icon
        fillMode: VectorImage.PreserveAspectFit
        preferredRendererType: VectorImage.CurveRenderer
        layer.enabled: true
        layer.effect: MultiEffect { colorization: 1; colorizationColor: tile.fg }
      }
      Text {
        Layout.alignment: Qt.AlignHCenter
        text: tile.modelData.label
        color: tile.fg
        font.family: Style.menuSans; font.pixelSize: Style.typeBody; font.weight: Font.DemiBold
      }
      Text {
        Layout.alignment: Qt.AlignHCenter
        text: tile.modelData.hint
        color: tile.fg
        opacity: 0.7
        font.family: Style.menuSans; font.pixelSize: Style.typeCaption
      }
    }
    MouseArea {
      id: tileMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: { root.sel = tile.index; idle.restart() }
      onClicked: root.pick(tile.index)
    }
  }

  PanelWindow {
    id: win
    visible: root.phase !== "" || popOut.running
    screen: root.cardScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-display"
    // The tiles take the keys; the toast never steals them.
    WlrLayershell.keyboardFocus: root.asking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { bottom: true }
    margins { bottom: 56 }
    implicitWidth: card.width
    implicitHeight: card.height + 16   // the slide's room
    // External only takes eDP-1 away mid-probation: the card moves to the external, keys follow.
    onScreenChanged: if (root.asking) Qt.callLater(() => keys.forceActiveFocus())

    Item {
      id: keys
      anchors.fill: parent
      focus: true
      Keys.onPressed: event => {
        const k = event.key
        idle.restart()
        if (root.phase === "ask") {
          if (k >= Qt.Key_1 && k <= Qt.Key_4) root.pick(k - Qt.Key_1)
          else if (k === Qt.Key_Left || k === Qt.Key_Up || k === Qt.Key_Backtab) root.sel = (root.sel + 3) % 4
          else if (k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_Tab) root.sel = (root.sel + 1) % 4
          else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.pick(root.sel)
          else if (k === Qt.Key_Escape) root.close()
          else return
        } else if (root.phase === "confirm") {
          if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.keep()
          else if (k === Qt.Key_Escape) root.revert(false)
          else return
        } else return
        event.accepted = true
      }
    }

    Rectangle {
      id: card
      width: root.look === "toast" ? toastRow.implicitWidth + 28 : 520
      height: (root.look === "toast" ? toastRow.implicitHeight : root.look === "ask" ? askCol.implicitHeight
        : confirmCol.implicitHeight) + 28
      radius: Style.menuRadiusLg
      color: Style.m3surfaceSolid
      border.width: Style.popupBorderWidth
      border.color: Style.popupBorder
      transformOrigin: Item.Bottom
      transform: Translate { id: slide }

      // Known screen: "<model> · <mode>  change ▸". Hover holds it; click opens the tiles.
      RowLayout {
        id: toastRow
        visible: root.look === "toast"
        x: 14; y: 14
        spacing: 10
        Menu.MenuGlyphTile { glyph: "󰍹" }
        ColumnLayout {
          spacing: 1
          Text {
            Layout.maximumWidth: 320
            text: root.label + " · " + root.modeLabel(root.picked)
            textFormat: Text.PlainText   // EDID model
            elide: Text.ElideRight
            color: Style.menuInk
            font.family: Style.menuSans; font.pixelSize: Style.typeLead; font.weight: Font.DemiBold
          }
          Text {
            visible: root.status !== ""
            text: root.status
            textFormat: Text.PlainText
            color: Style.red
            font.family: Style.menuSans; font.pixelSize: Style.typeCaption
          }
        }
        Text {
          Layout.leftMargin: 8
          text: "change ▸"
          color: Style.m3primary
          font.family: Style.menuSans; font.pixelSize: Style.typeBody; font.weight: Font.DemiBold
        }
      }
      MouseArea {
        anchors.fill: parent
        visible: root.look === "toast"
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: toastTimer.stop()
        onExited: if (root.phase === "toast") toastTimer.restart()
        onClicked: root.ask()
      }

      // Unknown screen (or change ▸): the four tiles.
      ColumnLayout {
        id: askCol
        visible: root.look === "ask"
        x: 16; y: 14
        width: card.width - 32
        spacing: 12
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Menu.MenuGlyphTile { glyph: "󰍹" }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              text: root.fresh ? "New display" : "Display mode"
              color: Style.menuInk
              font.family: Style.menuSans; font.pixelSize: Style.typeTitle; font.weight: Font.DemiBold
            }
            Text {
              Layout.fillWidth: true
              text: root.label
              textFormat: Text.PlainText   // EDID model
              elide: Text.ElideRight
              color: Style.menuInkDeep
              font.family: Style.menuSans; font.pixelSize: Style.typeBody
            }
          }
          Text {
            text: "Esc keeps " + root.modeLabel(root.current)
            color: Style.menuInkMuted
            font.family: Style.menuSans; font.pixelSize: Style.typeCaption
          }
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Repeater {
            model: root.modes
            delegate: ModeTile {}
          }
        }
        Text {
          Layout.fillWidth: true
          visible: root.status !== ""
          text: root.status
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Style.red
          font.family: Style.menuSans; font.pixelSize: Style.typeCaption
        }
      }

      // Picked: Keep / Revert, reverting to Extend when the countdown runs out.
      ColumnLayout {
        id: confirmCol
        visible: root.look === "confirm"
        x: 16; y: 14
        width: card.width - 32
        spacing: 12
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Menu.MenuGlyphTile { glyph: "󰍹" }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              text: "Keep " + root.modeLabel(root.picked) + "?"
              color: Style.menuInk
              font.family: Style.menuSans; font.pixelSize: Style.typeTitle; font.weight: Font.DemiBold
            }
            Text {
              Layout.fillWidth: true
              text: root.busy ? "Applying on " + root.label + "…"
                : "Back to Extend in " + root.left + " s · Enter keeps, Esc reverts"
              textFormat: Text.PlainText   // EDID model
              elide: Text.ElideRight
              color: Style.menuInkDeep
              font.family: Style.menuSans; font.pixelSize: Style.typeBody; font.features: Style.fontTabular
            }
          }
          Menu.MenuPill { label: "Revert"; onClicked: root.revert(false) }
          Menu.MenuPill {
            label: root.busy ? "Keep" : "Keep " + root.left + "s"
            bg: Style.m3primary; fg: Style.m3onPrimary
            opacity: root.busy ? 0.5 : 1
            onClicked: root.keep()
          }
        }
        // Drains with the countdown.
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 3
          radius: 1.5
          color: Style.m3container
          Rectangle {
            width: parent.width * Math.max(0, root.left) / 10
            height: parent.height
            radius: parent.radius
            color: Style.m3primary
            Behavior on width { enabled: countdown.running; NumberAnimation { duration: 1000 } }
          }
        }
      }
    }
  }
}
