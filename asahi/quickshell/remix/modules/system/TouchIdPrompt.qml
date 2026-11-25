import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../../"
import "touchid_model.js" as Model

// Touch ID prompt (idea: omarchnix's touchid plugin): a card under the notch whenever something waits for a finger
// that has no prompt of its own — sudo / su in a terminal, aurora-fido (passkeys, ssh ecdsa-sk), fprintd-verify.
// It shows the lock screen's orb (TouchIdOrb) and its line (TouchIdLine): ready, reading, no match, not read, gave up,
// approved — animated here (the orb scans while reading, each result lands with a pop, the line rises in).
// The lock screen draws its own, and so does the polkit card (PolkitAgent reads `st` for its orb): suppressed here.
// Feed: asahi-touchid-monitor (fprintd's broadcast signals + who asked, guessed from processes); aurora-fidod's own
// "Touch ID" notification (its title names the site) is routed here by NotificationCenter instead of toasting.
// Click = focus the window that asked. State machine: touchid_model.js (touchid_model_test.js).
Scope {
  id: root

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  property var st: Model.initial()
  readonly property bool shown: Model.visible(root.st)
  readonly property var info: root.st.info || ({})
  property var promptScreen: null

  function focusedScreen() {
    const mon = Hyprland.focusedMonitor
    return mon ? (Quickshell.screens.find(s => s.name === mon.name) ?? Quickshell.screens[0]) : (Quickshell.screens[0] ?? null)
  }

  function feed(ev) {
    const was = root.shown
    root.st = Model.reduce(root.st, ev, Date.now())
    if (!was && root.shown) root.promptScreen = root.focusedScreen()
    // A QML Timer can fire a frame early (it runs on the animation clock): aim a little past `until`, or the state
    // outlived its time by a whole period (No match 2.8 s instead of 1.4, and the next touch showed no "Reading").
    if (root.st.until) {
      tick.interval = Math.max(16, root.st.until - Date.now() + 20)
      tick.restart()
    }
  }
  // NotificationCenter: aurora-fidod's note ("Touch ID to sign in to github.com") and its close.
  function fidoNote(title) { root.feed({ ev: "fidoNote", title: title }) }
  function fidoClosed() { root.feed({ ev: "fidoClosed" }) }

  Timer {
    id: tick
    onTriggered: root.feed({ ev: "tick" })
  }

  Process {
    id: monitor
    running: true
    command: ["setpriv", "--pdeathsig", "TERM", root.binDir + "/asahi-touchid-monitor"]
    stdout: SplitParser {
      onRead: data => {
        try { root.feed(JSON.parse(data)) } catch (e) {}
      }
    }
    onExited: { root.feed({ ev: "gone" }); restart.start() }
  }
  Timer { id: restart; interval: 5000; onTriggered: monitor.running = true }

  // Preview without a finger: qs -c remix ipc call touchid feed '{"ev":"start","kind":"sudo","title":"sudo",…}'
  IpcHandler {
    target: "touchid"
    function feed(json: string): void { try { root.feed(JSON.parse(json)) } catch (e) {} }
  }

  readonly property var view: Model.view(root.st)
  readonly property color tone: root.view.tone === "ok" ? Style.green : root.view.tone === "fail" ? Style.red
    : root.view.tone === "warn" ? Style.yellow : root.view.tone === "accent2" ? Style.vivid2 : Style.vivid

  PanelWindow {
    id: win
    visible: root.shown || linger.running
    screen: root.promptScreen
    focusable: false
    color: "transparent"
    // Normal + zone 0: just below the bar's exclusive zone (the notch floor), above windows.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-touchid"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true }
    margins { top: 8 }
    implicitWidth: 400
    implicitHeight: 74

    Timer { id: linger; interval: 180 }
    Connections { target: root; function onShownChanged() { if (!root.shown) linger.restart() } }

    Rectangle {
      id: card
      anchors.fill: parent
      radius: Style.menuRadiusLg
      color: Style.m3surfaceSolid
      border.color: Qt.alpha(root.tone, 0.55)
      border.width: Style.popupBorderWidth
      opacity: root.shown ? 1 : 0
      scale: root.shown ? 1 : 0.96
      Behavior on opacity { NumberAnimation { duration: 140 } }
      Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      Behavior on border.color { ColorAnimation { duration: 160 } }

      // It drops down out of the notch (and back up as it goes); a miss shakes it once, like macOS.
      transform: Translate {
        id: shake
        x: 0
        y: root.shown ? 0 : -12
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      }
      SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shake; property: "x"; to: -8; duration: 45 }
        NumberAnimation { target: shake; property: "x"; to: 8; duration: 70 }
        NumberAnimation { target: shake; property: "x"; to: -5; duration: 60 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
      }
      Connections {
        target: root
        // Once per miss: not again for the same phase (pam's next try marks it), nor when the last miss turns into
        // "type your password".
        property string was: "hidden"
        function onStChanged() {
          const now = root.st.phase
          if (now !== was && (now === "nomatch" || (now === "failed" && was !== "nomatch"))) shakeAnim.restart()
          was = now
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: root.info.address ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.info.address)
          Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + root.info.address + "\" })"])
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 16
        spacing: 14

        TouchIdOrb {
          size: 46
          view: root.view
          live: win.visible   // no per-frame work while hidden
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
              Layout.fillWidth: true
              textFormat: Text.PlainText
              text: root.info.title || "Touch ID"
              elide: Text.ElideRight
              color: Style.menuInk
              font.family: Style.menuSans
              font.pixelSize: 13
              font.weight: Font.DemiBold
            }
            Text {
              visible: !!root.info.app
              textFormat: Text.PlainText
              text: root.info.app || ""
              color: Style.menuInkDeep
              font.family: Style.menuSans
              font.pixelSize: 10
            }
          }
          Text {
            Layout.fillWidth: true
            visible: !!root.info.detail
            textFormat: Text.PlainText
            text: root.info.detail || ""
            elide: Text.ElideMiddle
            color: Style.menuInkDeep
            font.family: Style.fontData
            font.pixelSize: 10
          }
          TouchIdLine {
            view: root.view
            live: win.visible
          }
        }
      }
    }
  }
}
