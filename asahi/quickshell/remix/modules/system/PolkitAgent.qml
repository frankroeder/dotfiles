import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "../menu" as Menu
import "../../"

// Polkit authentication agent. Without one, GUI admin prompts (and pkexec) failed silently.
// One card on the focused screen: Enter submits, Esc cancels, a wrong password shakes and clears.
Scope {
  id: root

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

  PanelWindow {
    id: win
    visible: agent.isActive && root.flow !== null
    screen: root.authScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-polkit"
    onVisibleChanged: if (visible) { root.wrong = false; field.text = ""; field.forceActiveFocus() }

    Rectangle { anchors.fill: parent; color: Style.menuDim }

    Menu.MenuCard {
      id: card
      anchors.centerIn: parent
      width: 440
      height: col.implicitHeight + 2 * cardMargin
      cardMargin: 22
      transform: Translate { id: shakeX }

      ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        RowLayout {
          spacing: 12
          Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: Style.menuRadiusMd
            color: Style.m3primaryContainer
            Text { anchors.centerIn: parent; text: "󰌾"; color: Style.m3primary; font.family: Style.menuMono; font.pixelSize: 20 }
          }
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
              Layout.maximumWidth: 330
            }
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

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 40
          radius: height / 2
          color: Style.m3container
          border.width: 1
          border.color: root.wrong ? Style.red : (field.activeFocus ? Style.menuSelBorder : "transparent")

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

        // PAM's extra lines (fingerprint hints, lockout notices).
        Text {
          Layout.fillWidth: true
          visible: !!root.flow && root.flow.supplementaryMessage !== ""
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
