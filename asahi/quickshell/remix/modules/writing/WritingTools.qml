import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import "../menu" as Menu
import "writing_diff.js" as Diff
import "../../"

// Writing Tools (macOS-style): selected text → small picker at the cursor
// (Proofread / Rewrite / Concise) → the card morphs into original (top) vs
// suggestion (bottom) with a word diff → Replace / Copy / Retry / Decline.
// Backend: asahi/bin/asahi-writing-tools (capture, run, replace).
// The card never takes keyboard focus (QtQuick fields drop their selection on focus loss): its
// keys are the Hyprland submap "writing" (bindings.lua), entered while open.
Scope {
  id: root

  property bool open: false
  property string phase: "pick" // pick | result
  property var cap: ({})
  property string mode: ""
  property string output: ""
  property bool busy: false
  property string error: ""
  property var ops: []
  property string suggestion: ""
  property int pickIndex: 0
  property var cardScreen: null
  // Off while the card is first placed, so it does not fly in from 0,0.
  property bool morph: false
  // One Process per run; a stale run (retry, mode switch, close) is ignored by generation.
  property int gen: 0
  property var runProc: null

  readonly property string bin: Quickshell.env("HOME") + "/.dotfiles/asahi/bin/asahi-writing-tools"
  readonly property var modes: [
    { key: "proofread", label: "Proofread", icon: "󰓆", hint: "Fix spelling and grammar" },
    { key: "rewrite", label: "Rewrite", icon: "󰏫", hint: "Clearer wording, same meaning" },
    { key: "concise", label: "Concise", icon: "󰆐", hint: "Same points, fewer words" },
  ]
  readonly property string original: cap.text || ""
  readonly property bool hasText: original.trim() !== ""
  // Replace pastes over the live selection: a terminal has none, and a truncated capture would drop
  // the rest of it.
  readonly property bool canReplace: !!cap.address && !cap.terminal && !cap.truncated
  readonly property bool done: phase === "result" && !busy && error === "" && suggestion !== ""
  readonly property string appName: {
    const c = (cap.class || "").split(".").pop()
    return c ? c.charAt(0).toUpperCase() + c.slice(1) : ""
  }
  readonly property int wordCount: original.trim() === "" ? 0 : original.trim().split(/\s+/).length

  // The screen under the cursor (where the selection was made).
  function screenAt(c) {
    return Quickshell.screens.find(s => c.x >= s.x && c.x < s.x + s.width && c.y >= s.y && c.y < s.y + s.height) ?? Quickshell.screens[0]
  }

  function toggle() {
    if (root.open) root.close()
    else if (!captureProc.running) captureProc.running = true
  }

  function show(data) {
    root.cap = data
    root.phase = "pick"
    root.pickIndex = 0
    root.mode = ""
    root.output = root.suggestion = root.error = ""
    root.ops = []
    root.morph = false
    root.cardScreen = root.screenAt(data.cursor || { x: -1, y: -1 })
    root.open = true
    Hyprland.dispatch('hl.dsp.submap("writing")')
    Qt.callLater(() => { root.morph = true })
  }

  function stopRun() {
    root.gen++
    if (root.runProc) root.runProc.running = false
    root.runProc = null
  }

  function close() {
    root.stopRun()
    root.busy = false
    root.open = false
    Hyprland.dispatch('hl.dsp.submap("reset")')
  }

  // Submap keys (quickshell:writing-<name>).
  function key(k) {
    if (!root.open) return
    if (k === "escape") return root.close()
    const num = ["1", "2", "3"].indexOf(k)
    if (num >= 0) return root.start(root.modes[num].key)
    if (root.phase === "pick") {
      if (k === "down") root.pickIndex = (root.pickIndex + 1) % root.modes.length
      else if (k === "up") root.pickIndex = (root.pickIndex + root.modes.length - 1) % root.modes.length
      else if (k === "enter") root.start(root.modes[root.pickIndex].key)
      return
    }
    if (k === "enter") root.canReplace ? root.replace() : root.copyAll()
    else if (k === "retry" && !root.busy) root.start(root.mode)
    // A selection in the suggestion copies just that and keeps the card; else copy all and close.
    else if (k === "copy") sugPane.edit.selectedText !== "" ? root.copy(sugPane.edit.selectedText) : root.copyAll()
  }

  function start(key) {
    if (!root.hasText) return
    root.mode = key
    root.phase = "result"
    root.output = root.suggestion = root.error = ""
    root.ops = []
    root.busy = true
    root.stopRun()
    const p = runComp.createObject(root, { gen: root.gen, command: [root.bin, "run", key, root.original] })
    root.runProc = p
    p.running = true
  }

  function onLine(line) {
    let ev
    try { ev = JSON.parse(line) } catch (e) { return }
    if (ev.delta !== undefined) root.output += ev.delta
    else if (ev.error) root.error = ev.error
    else if (ev.stop === "refusal") root.error = "The model declined this text."
  }

  function finish() {
    root.busy = false
    if (root.error === "" && root.output.trim() === "") root.error = "No response (network or API error)."
    if (root.error !== "") return
    root.suggestion = Diff.fitOutput(root.original, root.output)
    root.ops = Diff.diff(root.original, root.suggestion)
  }

  function copy(text) {
    Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", text])
  }

  function copyAll() {
    if (!root.done) return
    root.copy(root.suggestion)
    root.close()
  }

  function replace() {
    if (!root.done || !root.canReplace) return
    Quickshell.execDetached([root.bin, "replace", root.cap.address, root.suggestion])
    root.close()
  }

  Process {
    id: captureProc
    command: [root.bin, "capture"]
    stdout: StdioCollector {
      onStreamFinished: {
        let data = {}
        try { data = JSON.parse(text) } catch (e) {}
        root.show(data)
      }
    }
  }

  Component {
    id: runComp
    Process {
      id: proc
      property int gen: 0
      stdout: SplitParser { onRead: line => { if (proc.gen === root.gen) root.onLine(line) } }
      onExited: {
        if (proc.gen === root.gen) { root.runProc = null; root.finish() }
        proc.destroy()
      }
    }
  }

  // Bound in hypr/conf.d/bindings.lua as hl.dsp.global("quickshell:writing-tools").
  GlobalShortcut {
    appid: "quickshell"
    name: "writing-tools"
    description: "Writing tools for the selected text"
    onPressed: root.toggle()
  }

  Instantiator {
    model: ["1", "2", "3", "up", "down", "enter", "retry", "copy", "escape"]
    GlobalShortcut {
      required property string modelData
      appid: "quickshell"
      name: "writing-" + modelData
      description: "Writing tools card key " + modelData
      onPressed: root.key(modelData)
    }
  }

  // A reload while open must not leave the submap (and its keys) active.
  Component.onDestruction: if (root.open) Hyprland.dispatch('hl.dsp.submap("reset")')

  // Footer / mode pill.
  component Pill: Rectangle {
    id: pill
    property string icon: ""
    property string label: ""
    property string keyHint: ""
    property bool primary: false
    property bool active: false
    signal clicked()
    implicitWidth: pillRow.implicitWidth + 26
    implicitHeight: 34
    radius: height / 2
    opacity: enabled ? 1 : 0.4
    color: primary ? (pillMa.containsMouse ? Qt.lighter(Style.m3primary, 1.08) : Style.m3primary)
      : active ? Style.m3primaryContainer
      : pillMa.containsMouse ? Style.m3containerHigh : Style.m3container
    border.width: active ? 1 : 0
    border.color: Style.menuSelBorder
    Behavior on color { ColorAnimation { duration: 120 } }
    Row {
      id: pillRow
      anchors.centerIn: parent
      spacing: 7
      Text {
        visible: pill.icon !== ""
        text: pill.icon
        color: pill.primary ? Style.m3onPrimary : pill.active ? Style.m3primary : Style.m3onSurface
        font.family: Style.menuMono; font.pixelSize: 15
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: pill.label
        color: pill.primary ? Style.m3onPrimary : Style.m3onSurface
        font.family: Style.menuSans; font.pixelSize: 13; font.weight: Font.DemiBold
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        visible: pill.keyHint !== ""
        text: pill.keyHint
        color: pill.primary ? Qt.alpha(Style.m3onPrimary, 0.7) : Style.m3onSurfaceVariant
        font.family: Style.menuSans; font.pixelSize: 11
        anchors.verticalCenter: parent.verticalCenter
      }
    }
    MouseArea {
      id: pillMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pill.clicked()
    }
  }

  // Scrollable read-only rich text (diff colours), selectable for copying.
  component Pane: Rectangle {
    id: pane
    property alias edit: paneEdit
    property string label: ""
    property string body: ""
    property bool rich: false
    property color ink: Style.m3onSurface
    property real maxHeight: 200
    readonly property real wantHeight: Math.min(paneEdit.implicitHeight + 20, maxHeight)
    radius: Style.menuRadiusMd
    color: Style.menuCardBg
    clip: true
    Flickable {
      id: flick
      anchors.fill: parent
      anchors.margins: 10
      contentHeight: paneEdit.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      TextEdit {
        id: paneEdit
        width: flick.width - 10 // fixed gutter: a bar-dependent width loops through contentHeight
        readOnly: true
        persistentSelection: true // the card never has keyboard focus
        wrapMode: TextEdit.Wrap
        textFormat: pane.rich ? TextEdit.RichText : TextEdit.PlainText
        text: pane.body
        color: pane.ink
        selectionColor: Style.menuSelFill
        selectedTextColor: Style.m3onSurface
        font.family: Style.menuSans
        font.pixelSize: 14
        // Own drag-select instead of selectByMouse: Qt's mouse selection claims the primary
        // selection, and GTK apps then drop the very selection Replace pastes over.
        MouseArea {
          property int anchor: 0
          anchors.fill: parent
          cursorShape: Qt.IBeamCursor
          preventStealing: true
          onPressed: mouse => { anchor = paneEdit.positionAt(mouse.x, mouse.y); paneEdit.select(anchor, anchor) }
          onPositionChanged: mouse => paneEdit.select(anchor, paneEdit.positionAt(mouse.x, mouse.y))
          onDoubleClicked: mouse => { paneEdit.cursorPosition = paneEdit.positionAt(mouse.x, mouse.y); paneEdit.selectWord() }
        }
      }
      Menu.MenuScrollBar { id: bar; parent: flick; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom }
      ScrollBar.vertical: bar
    }
  }

  PanelWindow {
    id: win
    visible: root.open
    screen: root.cardScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-writing"
    anchors { top: true; bottom: true; left: true; right: true }

    readonly property real margin: 24
    // Anchor = the cursor (usually where the selection was made); pickX/pickY clamp it on screen.
    readonly property real ax: (root.cap.cursor?.x ?? 0) - (root.cardScreen?.x ?? 0)
    readonly property real ay: (root.cap.cursor?.y ?? 0) - (root.cardScreen?.y ?? 0)
    readonly property real pickW: 340
    readonly property real pickH: picker.implicitHeight + 32
    readonly property real pickX: Math.max(margin, Math.min(ax + 8, width - pickW - margin))
    readonly property real pickY: Math.max(margin, Math.min(ay + 16, height - pickH - margin))
    readonly property real resW: Math.min(760, width - 2 * margin)
    readonly property real resChrome: result.chromeHeight + 36
    readonly property real paneMax: Math.max(80, (height * 0.8 - resChrome) / 2)
    readonly property real resH: resChrome + origPane.wantHeight + sugPane.wantHeight
    readonly property real resX: Math.max(margin, Math.min(pickX + pickW / 2 - resW / 2, width - resW - margin))
    readonly property real resY: Math.max(margin, Math.min(pickY, height - resH - margin))

    Item {
      anchors.fill: parent

      // Click outside = decline.
      MouseArea { anchors.fill: parent; onClicked: root.close() }

      Item {
        id: card
        readonly property bool big: root.phase === "result"
        x: big ? win.resX : win.pickX
        y: big ? win.resY : win.pickY
        width: big ? win.resW : win.pickW
        height: big ? win.resH : win.pickH
        Behavior on x { enabled: root.morph; Menu.MenuAnim {} }
        Behavior on y { enabled: root.morph; Menu.MenuAnim {} }
        Behavior on width { enabled: root.morph; Menu.MenuAnim {} }
        Behavior on height { enabled: root.morph; Menu.MenuAnim {} }

        // Pop in from the cursor corner.
        transformOrigin: Item.TopLeft
        scale: root.open ? 1 : 0.94
        opacity: root.open ? 1 : 0
        Behavior on scale { Menu.MenuAnim {} }
        Behavior on opacity { Menu.MenuAnim { effects: true } }

        Rectangle {
          id: shadowSrc
          anchors.fill: parent
          anchors.topMargin: 6
          radius: body.radius
          color: Style.m3shadow
          visible: false
        }
        MultiEffect { source: shadowSrc; anchors.fill: shadowSrc; blurEnabled: true; blur: 1.0; blurMax: 32 }

        Rectangle {
          id: body
          anchors.fill: parent
          radius: card.big ? Style.menuPanelRadius : 20
          Behavior on radius { Menu.MenuAnim {} }
          color: Style.m3surfaceSolid
          border.color: Style.popupBorder
          border.width: Style.popupBorderWidth
          clip: true
          MouseArea { anchors.fill: parent; onClicked: mouse => mouse.accepted = true }

          // ── Picker ──
          ColumnLayout {
            id: picker
            x: 16; y: 16
            width: win.pickW - 32
            spacing: 10
            opacity: card.big ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { Menu.MenuAnim { effects: true } }

            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              Rectangle {
                width: 32; height: 32; radius: Style.menuRadiusMd
                color: Style.m3primaryContainer
                Text { anchors.centerIn: parent; text: "󰙴"; color: Style.m3primary; font.family: Style.menuMono; font.pixelSize: 17 }
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { text: "Writing Tools"; color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: 15; font.weight: Font.DemiBold }
                Text {
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                  color: Style.m3onSurfaceVariant
                  font.family: Style.menuSans; font.pixelSize: 12
                  text: !root.hasText ? "Select some text first"
                    : root.wordCount + (root.wordCount === 1 ? " word" : " words")
                      + (root.appName ? " · " + root.appName : "")
                      + (root.cap.truncated ? " · truncated" : "")
                }
              }
            }

            Text {
              Layout.fillWidth: true
              visible: root.hasText
              text: root.original.trim().replace(/\s+/g, " ")
              color: Style.m3onSurfaceVariant
              font.family: Style.menuSans; font.pixelSize: 13; font.italic: true
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Repeater {
              model: root.modes
              Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: root.pickIndex === index
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Style.menuRadiusMd
                opacity: root.hasText ? 1 : 0.4
                color: sel ? Style.menuSelFill : rowMa.containsMouse ? Style.m3stateHover : "transparent"
                border.width: sel ? 1 : 0
                border.color: Style.menuSelBorder
                Behavior on color { ColorAnimation { duration: 120 } }
                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 12; anchors.rightMargin: 12
                  spacing: 12
                  Text { text: row.modelData.icon; color: row.sel ? Style.m3primary : Style.m3onSurface; font.family: Style.menuMono; font.pixelSize: 18 }
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text { text: row.modelData.label; color: Style.m3onSurface; font.family: Style.menuSans; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { text: row.modelData.hint; color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: 12 }
                  }
                  Text { text: String(row.index + 1); color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: 12 }
                }
                MouseArea {
                  id: rowMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: root.hasText ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onEntered: root.pickIndex = row.index
                  onClicked: root.start(row.modelData.key)
                }
              }
            }
          }

          // ── Result ──
          ColumnLayout {
            id: result
            readonly property real chromeHeight: header.implicitHeight + origLabel.implicitHeight + sugLabel.implicitHeight
              + footer.implicitHeight + 5 * spacing
            x: 18; y: 18
            width: win.resW - 36
            height: card.height - 36
            spacing: 10
            opacity: card.big ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { Menu.MenuAnim { effects: true } }

            RowLayout {
              id: header
              Layout.fillWidth: true
              spacing: 6
              Repeater {
                model: root.modes
                Pill {
                  required property var modelData
                  icon: modelData.icon
                  label: modelData.label
                  active: root.mode === modelData.key
                  onClicked: root.start(modelData.key)
                }
              }
              Item { Layout.fillWidth: true }
              Text {
                id: status
                Layout.maximumWidth: 260
                elide: Text.ElideRight
                font.family: Style.menuSans; font.pixelSize: 12
                color: root.error !== "" ? Style.red : Style.m3onSurfaceVariant
                text: root.error !== "" ? "Failed"
                  : root.busy ? "Thinking…"
                  : root.ops.length === 0 ? ""
                  : Diff.changes(root.ops) === 0 ? "No changes" : Diff.changes(root.ops) + (Diff.changes(root.ops) === 1 ? " change" : " changes")
                SequentialAnimation on opacity {
                  running: root.busy && root.open
                  loops: Animation.Infinite
                  alwaysRunToEnd: true
                  NumberAnimation { to: 0.45; duration: 600; easing.type: Easing.InOutSine }
                  NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                }
              }
            }

            Text { id: origLabel; text: "ORIGINAL"; color: Style.m3onSurfaceVariant; font.family: Style.menuSans; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1 }
            Pane {
              id: origPane
              Layout.fillWidth: true
              Layout.preferredHeight: wantHeight
              maxHeight: win.paneMax
              ink: Style.m3onSurfaceVariant
              rich: root.ops.length > 0
              body: root.ops.length > 0 ? Diff.html(root.ops, "old", root.diffColors) : root.original
            }

            Text { id: sugLabel; text: "SUGGESTION"; color: Style.m3primary; font.family: Style.menuSans; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 1 }
            Pane {
              id: sugPane
              Layout.fillWidth: true
              Layout.preferredHeight: wantHeight
              maxHeight: win.paneMax
              rich: root.ops.length > 0
              body: root.ops.length > 0 ? Diff.html(root.ops, "new", root.diffColors)
                : root.error !== "" ? root.error : root.output + (root.busy ? " ▍" : "")
              ink: root.error !== "" ? Style.red : Style.m3onSurface
            }

            RowLayout {
              id: footer
              Layout.fillWidth: true
              spacing: 8
              Pill { icon: "󰑐"; label: "Retry"; keyHint: "R"; enabled: !root.busy && root.mode !== ""; onClicked: root.start(root.mode) }
              Item { Layout.fillWidth: true }
              Pill { icon: "󰅖"; label: "Decline"; keyHint: "Esc"; onClicked: root.close() }
              Pill { icon: "󰆏"; label: "Copy"; keyHint: root.canReplace ? "^C" : "⏎"; enabled: root.done; primary: !root.canReplace; onClicked: root.copyAll() }
              Pill { visible: root.canReplace; icon: "󰄬"; label: "Replace"; keyHint: "⏎"; enabled: root.done; primary: true; onClicked: root.replace() }
            }
          }
        }
      }
    }
  }

  // Opaque blends (Qt rich text has no alpha): diff marks on the card colour.
  // …Bg tints a changed word, …Mark the changed characters inside it (or a whole new/removed word).
  readonly property var diffColors: ({
    del: Style.red.toString(),
    delBg: Qt.tint(Style.m3surfaceSolid, Qt.alpha(Style.red, 0.10)).toString(),
    delMark: Qt.tint(Style.m3surfaceSolid, Qt.alpha(Style.red, 0.34)).toString(),
    ins: Style.m3onSurface.toString(),
    insBg: Qt.tint(Style.m3surfaceSolid, Qt.alpha(Style.green, 0.16)).toString(),
    insMark: Qt.tint(Style.m3surfaceSolid, Qt.alpha(Style.green, 0.45)).toString(),
  })
}
