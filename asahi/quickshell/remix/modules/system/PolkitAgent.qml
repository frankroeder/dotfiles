import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "../menu" as Menu
import "../../"
import "touchid_model.js" as TouchModel

// Polkit authentication agent. Without one, GUI admin prompts (and pkexec) failed silently.
// One card on the focused screen: Enter submits, Esc cancels, a wrong password shakes and clears.
// Laid out like the lock screen: the Touch ID orb and its line over the password pill. PAM asks for the finger
// first (pam_fprintd, 3 tries / 30 s), then the password: until then the pill is off and the orb tells what happens.
Scope {
  id: root

  // shell.qml: the TouchIdPrompt. Its state also runs for our own verify (kind polkit, hidden in its card).
  property var touchId: null
  readonly property var touch: root.touchId && root.touchId.st.suppressed && root.touchId.st.info
    && root.touchId.st.info.kind === "polkit" ? root.touchId.st : TouchModel.initial()
  readonly property var touchView: {
    const v = TouchModel.view(root.touch)
    if (v.orb !== "off") return v
    return { orb: "off", tone: "", strong: "", hint: root.flow && root.flow.isResponseRequired ? "Type your password" : "" }
  }

  readonly property var flow: agent.flow
  property var authScreen: null
  onFlowChanged: if (flow) {
    const mon = Hyprland.focusedMonitor
    authScreen = (mon && Quickshell.screens.find(s => s.name === mon.name)) || Quickshell.screens[0] || null
  }
  property bool wrong: false

  PolkitAgent {
    id: agent
    path: "/org/asahi/PolkitAgent"
  }

  Connections {
    target: root.flow
    function onAuthenticationFailed() {
      root.wrong = true
      field.text = ""
      shake.restart()
      wrongTimer.restart()
    }
  }
  Timer { id: wrongTimer; interval: 1500; onTriggered: root.wrong = false }

  function submit() {
    if (!root.flow || !root.flow.isResponseRequired) return
    root.flow.submit(field.text)
    field.text = ""
  }

  readonly property bool shown: agent.isActive && root.flow !== null

  PanelWindow {
    id: card
    visible: root.shown || island.busy
    screen: root.authScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-polkit"
    onVisibleChanged: if (visible) { root.wrong = false; field.text = ""; field.forceActiveFocus() }

    Rectangle { anchors.fill: parent; color: Style.menuDim; opacity: island.grow }

    // Grows out of the notch (IslandCard) and folds back into it.
    IslandCard {
      id: island
      anchors.horizontalCenter: parent.horizontalCenter
      y: 0
      shown: root.shown
      screen: root.authScreen
      fullWidth: 440
      contentHeight: col.implicitHeight
      transform: Translate { id: shakeX }

      ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        ColumnLayout {
          spacing: 2
          Text {
            text: "Authentication required"
            color: Style.m3onSurface
            font.family: Style.menuSans
            font.pixelSize: 16
            font.weight: Font.DemiBold
          }
          Text {
            text: root.flow ? root.flow.actionId : ""
            color: Style.m3onSurfaceVariant
            font.family: Style.menuMono
            font.pixelSize: 10
            elide: Text.ElideMiddle
            Layout.maximumWidth: 396
          }
        }

        Text {
          Layout.fillWidth: true
          text: root.flow ? root.flow.message : ""
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          color: Style.m3onSurface
          font.family: Style.menuSans
          font.pixelSize: 13
        }

        TouchIdOrb {
          Layout.alignment: Qt.AlignHCenter
          Layout.topMargin: 10
          size: 58
          view: root.touchView
          live: card.visible
        }
        TouchIdLine {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredHeight: 16
          view: root.touchView
          live: card.visible
          pixelSize: 12
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 40
          radius: height / 2
          color: Style.m3container
          border.width: 1
          border.color: root.wrong ? Style.red : (field.activeFocus ? Style.menuSelBorder : "transparent")
          // Off until PAM asks for the password (Touch ID comes first).
          opacity: field.enabled ? 1 : 0.5
          Behavior on opacity { NumberAnimation { duration: 160 } }

          TextInput {
            id: field
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            verticalAlignment: TextInput.AlignVCenter
            enabled: !!root.flow && root.flow.isResponseRequired
            echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
            color: Style.m3onSurface
            font.family: Style.menuSans
            font.pixelSize: 14
            clip: true
            Keys.onReturnPressed: root.submit()
            Keys.onEnterPressed: root.submit()
            Keys.onEscapePressed: if (root.flow) root.flow.cancelAuthenticationRequest()
            Text {
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
              visible: !parent.text
              text: root.wrong ? "Wrong password" : (root.flow && root.flow.inputPrompt ? root.flow.inputPrompt.replace(/:\s*$/, "") : "Password")
              color: root.wrong ? Style.red : Style.m3onSurfaceVariant
              font: parent.font
            }
          }
        }

        // PAM's extra lines (lockout notices; its fingerprint hints only while the orb has nothing to say).
        Text {
          Layout.fillWidth: true
          visible: !!root.flow && root.flow.supplementaryMessage !== "" && root.touch.phase === "hidden"
          text: root.flow ? root.flow.supplementaryMessage : ""
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          color: root.flow && root.flow.supplementaryIsError ? Style.red : Style.m3onSurfaceVariant
          font.family: Style.menuSans
          font.pixelSize: 12
        }

        RowLayout {
          Layout.alignment: Qt.AlignRight
          spacing: 8
          Menu.MenuPill { label: "Cancel"; onClicked: if (root.flow) root.flow.cancelAuthenticationRequest() }
          Menu.MenuPill { icon: "󰄬"; label: "Authenticate"; selected: true; onClicked: root.submit() }
        }
      }
    }

    SequentialAnimation {
      id: shake
      NumberAnimation { target: shakeX; property: "x"; to: -10; duration: 50 }
      NumberAnimation { target: shakeX; property: "x"; to: 10; duration: 70 }
      NumberAnimation { target: shakeX; property: "x"; to: -6; duration: 60 }
      NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 50 }
    }
  }
}
