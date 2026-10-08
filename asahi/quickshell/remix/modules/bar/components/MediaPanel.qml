import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../../../"
import "../BarModel.js" as BarModel
import "../cava_bars.js" as CavaBars
import "../../../services" as Services

// Media chip popup (serpantinum's compact music card): blurred art backdrop, cover + title /
// artist / album, player switch, wavy seek bar, transport, a small cava strip. Hangs under the
// chip, left-aligned to it. Esc / click outside closes.
PopupWindow {
  id: root

  property var barHost: null
  property bool panelOpen: false
  readonly property var p: Services.Players.active
  readonly property bool hasLen: !!(p && p.lengthSupported && p.length > 0)
  readonly property bool playing: Services.Players.isPlaying
  // MprisPlayer.position re-estimates on read only: tick it while shown; hold a seek target 1 s
  // so the bar does not jump back before the player reports the new position.
  property real heldPos: -1
  readonly property real pos: root.heldPos >= 0 ? root.heldPos : (root.p ? root.p.position : 0)

  visible: root.panelOpen && root.p !== null
  color: "transparent"
  anchor.edges: Edges.Bottom | Edges.Left
  anchor.gravity: Edges.Bottom | Edges.Right
  anchor.margins.bottom: -BarModel.popupDrop(root.barHost ? root.barHost.height : Style.barHeight, Style.barHeight)  // negative = below
  implicitWidth: 380
  implicitHeight: col.implicitHeight + 32

  function close() { if (root.barHost) root.barHost.mediaPanelOpen = false }
  function fmtTime(s) {
    s = Math.max(0, Math.round(s || 0))
    const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = ("0" + (s % 60)).slice(-2)
    return h > 0 ? h + ":" + ("0" + m).slice(-2) + ":" + sec : m + ":" + sec
  }

  onVisibleChanged: if (visible) { root.p.positionChanged(); openAnim.restart() }
  // Nothing left to show (player closed): drop the flag so the next track does not pop it open.
  onPChanged: if (!root.p) root.close()

  Timer {
    interval: 1000; repeat: true
    running: root.visible && root.playing
    onTriggered: root.p.positionChanged()
  }
  Timer { id: seekHold; interval: 1000; onTriggered: root.heldPos = -1 }

  // Shared cava only while the strip is on screen and something plays.
  readonly property bool cavaWanted: root.visible && root.playing
  onCavaWantedChanged: Services.Cava.hold(root, root.cavaWanted)
  Component.onDestruction: Services.Cava.hold(root, false)

  HyprlandFocusGrab {
    windows: [root, root.anchor.window]
    active: root.visible
    onCleared: root.close()
  }
  Shortcut {
    enabled: root.visible
    sequences: ["Escape"]
    context: Qt.ApplicationShortcut
    onActivated: root.close()
  }

  // Upstream IconButton look: surface0 rounded square; prev/next glyph subtext0 → text on hover,
  // play text → accent on hover. `active` (shuffle / loop on) tints the glyph.
  component CtlBtn: Rectangle {
    property string icon
    property int size: 32
    property bool primary: false
    property bool active: false
    property bool available: true
    signal clicked()
    implicitWidth: size; implicitHeight: size; radius: Style.radius
    color: btnMa.containsMouse ? Style.m3containerHigh : Style.m3container
    opacity: available ? 1 : 0.35
    Behavior on color { ColorAnimation { duration: 120 } }
    Text {
      anchors.centerIn: parent
      text: parent.icon
      color: parent.active ? Style.m3primary
        : parent.primary ? (btnMa.containsMouse ? Style.m3primary : Style.m3onSurface)
        : btnMa.containsMouse ? Style.m3onSurface : Style.m3onSurfaceVariant
      font.family: Style.fontFamily
      font.pixelSize: Math.round(parent.size * (parent.primary ? 0.42 : 0.38))
      Behavior on color { ColorAnimation { duration: 120 } }
    }
    MouseArea {
      id: btnMa
      anchors.fill: parent
      hoverEnabled: true
      enabled: parent.available
      cursorShape: Qt.PointingHandCursor
      onClicked: parent.clicked()
    }
  }

  Rectangle {
    id: card
    anchors.fill: parent
    radius: Style.menuRadiusLg
    color: Style.m3surfaceSolid
    border.color: Style.popupBorder
    border.width: Style.popupBorderWidth
    clip: true
    transformOrigin: Item.TopLeft

    ParallelAnimation {
      id: openAnim
      NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
      NumberAnimation { target: card; property: "scale"; from: 0.96; to: 1; duration: 260; easing.type: Easing.OutCubic }
    }

    // Backdrop in a rounded clip: plain `clip` is rectangular, so the blur's square corners
    // showed past the card radius (visible on light themes).
    ClippingRectangle {
      anchors.fill: parent
      anchors.margins: Style.popupBorderWidth  // inside the card's outline, which it would paint over
      radius: card.radius - Style.popupBorderWidth
      color: "transparent"
      // Backdrop: the cover, heavily blurred and washed with the surface so text stays legible.
      Image {
        id: backdrop
        anchors.fill: parent
        source: Services.Players.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(128, 128)
        visible: false
      }
      MultiEffect {
        anchors.fill: parent
        source: backdrop
        visible: Services.Players.artUrl !== "" && backdrop.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        opacity: 0.9
      }
      // Reference wash: base at 0.55 / 0.72 / 0.90 top to bottom.
      Rectangle {
        anchors.fill: parent
        gradient: Gradient {
          GradientStop { position: 0.0; color: Qt.alpha(Style.m3surfaceSolid, 0.55) }
          GradientStop { position: 0.5; color: Qt.alpha(Style.m3surfaceSolid, 0.72) }
          GradientStop { position: 1.0; color: Qt.alpha(Style.m3surfaceSolid, 0.90) }
        }
      }
    }

    ColumnLayout {
      id: col
      anchors.fill: parent
      anchors.margins: 16
      spacing: 10

      RowLayout {
        Layout.fillWidth: true
        spacing: 14

        // Vinyl disc (upstream MusicPopup): round cover in a record with grooves and an accent-ringed
        // label; one turn per 25 s while shown, paused (and shrunk to 0.9) when not playing; a soft
        // accent glow sits behind it while playing.
        Item {
          Layout.preferredWidth: 100
          Layout.preferredHeight: 100
          Rectangle {
            anchors.centerIn: parent
            width: disc.width + 12; height: width; radius: width / 2
            color: Style.m3primary
            opacity: root.playing ? 0.35 : 0
            scale: disc.scale
            Behavior on opacity { NumberAnimation { duration: 500 } }
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
          }
          Rectangle {
            id: disc
            anchors.centerIn: parent
            width: 88; height: 88; radius: width / 2
            color: Style.surface1
            scale: root.playing ? 1.0 : 0.9
            Behavior on scale { SpringAnimation { spring: 5.2; damping: 0.35; mass: 0.75 } }
            NumberAnimation on rotation {
              from: 0; to: 360; duration: 25000
              loops: Animation.Infinite
              running: root.visible
              paused: running && !root.playing
            }
            ClippingRectangle {
              anchors.fill: parent
              radius: width / 2
              color: Style.mantle
              Text {
                anchors.centerIn: parent
                visible: Services.Players.artUrl === ""
                text: "󰝚"
                color: Style.overlay1
                font.family: Style.fontFamily
                font.pixelSize: parent.width * 0.26
              }
              Image {
                anchors.fill: parent
                visible: Services.Players.artUrl !== ""
                source: Services.Players.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(256, 256)
              }
              // Accent tint + grooves (alternating light / dark rings), as upstream.
              Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.alpha(Style.m3primary, 0.08); visible: Services.Players.artUrl !== "" }
              Repeater {
                model: [0.92, 0.84, 0.76, 0.68, 0.60, 0.52, 0.44]
                Rectangle {
                  required property real modelData
                  required property int index
                  anchors.centerIn: parent
                  width: parent.width * modelData; height: width; radius: width / 2
                  color: "transparent"
                  border.width: 1
                  border.color: index % 2 === 0 ? "#ffffff" : "#000000"
                  opacity: index % 2 === 0 ? 0.035 : 0.06
                }
              }
            }
            // Label: crust disc with an accent ring, surface2 centre, black spindle hole.
            Rectangle {
              anchors.centerIn: parent
              width: parent.width * 0.28; height: width; radius: width / 2
              color: Style.crust
              opacity: 0.96
              border.width: 1.5
              border.color: Qt.alpha(Style.m3primary, 0.45)
              Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.68; height: width; radius: width / 2
                color: Style.surface2
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)
                Rectangle { anchors.centerIn: parent; width: parent.width * 0.38; height: width; radius: width / 2; color: "#0d0e15" }
              }
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 2

          // Source pill: player name; with 2+ players a click cycles (Players.pinned).
          Rectangle {
            readonly property bool many: Services.Players.list.length > 1
            Layout.bottomMargin: 4
            implicitWidth: srcRow.implicitWidth + 16
            implicitHeight: 20
            radius: 10
            color: srcMa.containsMouse && many ? Style.m3containerHigh : Qt.alpha(Style.m3container, 0.8)
            Row {
              id: srcRow
              anchors.centerIn: parent
              spacing: 5
              Text {
                text: root.playing ? "󰐊" : "󰏤"
                color: root.playing ? Style.m3primary : Style.m3onSurfaceVariant
                font.family: Style.fontFamily; font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: (root.p ? root.p.identity || "Player" : "")
                  + (parent.parent.many ? "  ·  " + (Services.Players.list.indexOf(root.p) + 1) + "/" + Services.Players.list.length : "")
                color: Style.m3onSurfaceVariant
                font.family: Style.menuSans; font.pixelSize: 10; font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                visible: parent.parent.many
                text: "󰑐"
                color: Style.m3onSurfaceVariant
                font.family: Style.fontFamily; font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
              }
            }
            MouseArea {
              id: srcMa
              anchors.fill: parent
              hoverEnabled: true
              enabled: parent.many
              cursorShape: Qt.PointingHandCursor
              onClicked: Services.Players.cycle()
            }
          }
          Text {
            Layout.fillWidth: true
            text: root.p ? (root.p.trackTitle || "Unknown track") : ""
            color: Style.m3onSurface
            font.family: Style.menuSans; font.pixelSize: 16; font.weight: Font.Bold
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.p ? root.p.trackArtist || "" : ""
            color: Style.m3onSurfaceVariant
            font.family: Style.menuSans; font.pixelSize: 12; font.weight: Font.Medium
            elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.p ? root.p.trackAlbum || "" : ""
            color: Style.m3outline
            font.family: Style.menuSans; font.pixelSize: 11
            elide: Text.ElideRight
          }
        }
      }

      WavySeekBar {
        Layout.fillWidth: true
        visible: root.hasLen
        value: root.hasLen ? root.pos / root.p.length : 0
        playing: root.playing
        live: root.visible
        seekable: !!(root.p && root.p.canSeek && root.p.positionSupported)
        color: Style.m3primary
        onSeek: (f) => {
          root.heldPos = f * root.p.length
          seekHold.restart()
          root.p.position = root.heldPos
        }
      }
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: -6
        visible: root.hasLen
        Text {
          text: root.fmtTime(root.pos)
          color: Style.m3onSurfaceVariant
          font.family: Style.menuSans; font.pixelSize: 11; font.bold: true; font.features: { "tnum": 1 }
        }
        Item { Layout.fillWidth: true }
        Text {
          text: root.fmtTime(root.hasLen ? root.p.length : 0)
          color: Style.m3onSurfaceVariant
          font.family: Style.menuSans; font.pixelSize: 11; font.bold: true; font.features: { "tnum": 1 }
        }
      }

      // Transport: shuffle · prev · play · next · loop (shuffle / loop only if the player has them).
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 18
        CtlBtn {
          icon: "󰒟"; size: 28
          visible: !!(root.p && root.p.shuffleSupported)
          active: !!(root.p && root.p.shuffle)
          available: !!(root.p && root.p.canControl)
          onClicked: root.p.shuffle = !root.p.shuffle
        }
        CtlBtn {
          icon: "󰒮"
          available: !!(root.p && root.p.canGoPrevious)
          onClicked: root.p.previous()
        }
        CtlBtn {
          icon: root.playing ? "󰏤" : "󰐊"; size: 43; primary: true
          available: !!(root.p && root.p.canTogglePlaying)
          onClicked: root.p.togglePlaying()
        }
        CtlBtn {
          icon: "󰒭"
          available: !!(root.p && root.p.canGoNext)
          onClicked: root.p.next()
        }
        CtlBtn {
          icon: root.p && root.p.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"; size: 28
          visible: !!(root.p && root.p.loopSupported)
          active: !!(root.p && root.p.loopState !== MprisLoopState.None)
          available: !!(root.p && root.p.canControl)
          onClicked: root.p.loopState = root.p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
            : root.p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
        }
      }

      // Cava strip: bars exist only while playing (see cavaWanted), otherwise a flat hairline.
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 18
        Row {
          anchors.fill: parent
          spacing: 3
          Repeater {
            model: root.cavaWanted ? 24 : 0
            Rectangle {
              required property int index
              width: (parent.width - 23 * 3) / 24
              anchors.bottom: parent.bottom
              height: CavaBars.barHeight(Services.Cava.values[index] || 0, 18)
              radius: 1.5
              color: Qt.alpha(Style.m3primary, 0.55)
            }
          }
        }
        Rectangle {
          visible: !root.cavaWanted
          anchors.bottom: parent.bottom
          width: parent.width; height: 2; radius: 1
          color: Style.menuSep
        }
      }
    }
  }
}
