import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../../../"
// Qualified sibling import: the launcher pane loads this file through a Loader, where qs never
// scanned this directory and a bare `WavySeekBar` is "not a type".
import "." as Components
import "../cava_bars.js" as CavaBars
import "../../../services" as Services

// Now-playing card (serpantinum's compact music card), shared by the bar's MediaPanel and the
// launcher's Media pane so both look alike: blurred art backdrop, vinyl disc, source pill, title /
// artist / album, wavy seek bar (+ times when the length is known), transport. Stacked for the popup (with a cava strip);
// `wide` puts disc, text + seek bar and transport in one row (the pane has its own Spectrum card).
Rectangle {
  id: card

  property bool wide: false
  // The owning window is shown: gates the position tick, the spinning disc and the wave.
  property bool live: true
  // Stacked strip: cava bars (the owner holds the shared cava) or a flat hairline.
  property bool cavaOn: false
  property real fontScale: 1
  readonly property var p: Services.Players.active
  readonly property real len: Services.Players.length
  readonly property bool hasLen: len > 0
  readonly property bool playing: Services.Players.isPlaying
  readonly property bool hasArt: Services.Players.artUrl !== ""
  // MprisPlayer.position re-estimates on read only: tick it while shown; hold a seek target 1 s
  // so the bar does not jump back before the player reports the new position.
  property real heldPos: -1
  readonly property real pos: card.heldPos >= 0 ? card.heldPos : (card.p ? card.p.position : 0)

  function px(n) { return Math.round(n * card.fontScale) }
  function fmtTime(s) {
    s = Math.max(0, Math.round(s || 0))
    const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = ("0" + (s % 60)).slice(-2)
    return h > 0 ? h + ":" + ("0" + m).slice(-2) + ":" + sec : m + ":" + sec
  }

  color: Style.m3surfaceSolid
  radius: Style.menuRadiusLg
  implicitHeight: body.implicitHeight + 36
  clip: true

  onLiveChanged: if (card.live && card.p) card.p.positionChanged()
  Timer {
    interval: 1000; repeat: true
    running: card.live && card.playing
    onTriggered: card.p.positionChanged()
  }
  Timer { id: seekHold; interval: 1000; onTriggered: card.heldPos = -1 }

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

  // Transport: shuffle · prev · play · next · loop (shuffle / loop only if the player has them).
  component Transport: RowLayout {
    spacing: card.px(card.wide ? 14 : 22)
    CtlBtn {
      icon: "󰒟"; size: card.px(32)
      visible: !!(card.p && card.p.shuffleSupported)
      active: !!(card.p && card.p.shuffle)
      available: !!(card.p && card.p.canControl)
      onClicked: card.p.shuffle = !card.p.shuffle
    }
    CtlBtn {
      icon: "󰒮"; size: card.px(36)
      available: !!(card.p && card.p.canGoPrevious)
      onClicked: card.p.previous()
    }
    CtlBtn {
      icon: card.playing ? "󰏤" : "󰐊"; size: card.px(52); primary: true
      available: !!(card.p && card.p.canTogglePlaying)
      onClicked: card.p.togglePlaying()
    }
    CtlBtn {
      icon: "󰒭"; size: card.px(36)
      available: !!(card.p && card.p.canGoNext)
      onClicked: card.p.next()
    }
    CtlBtn {
      icon: card.p && card.p.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"; size: card.px(32)
      visible: !!(card.p && card.p.loopSupported)
      active: !!(card.p && card.p.loopState !== MprisLoopState.None)
      available: !!(card.p && card.p.canControl)
      onClicked: card.p.loopState = card.p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
        : card.p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
    }
  }

  // Wavy seek bar + elapsed / length. Without a track length (Players.length) the bar stays as an
  // animated placeholder: no progress, no handle, no times.
  component Seek: ColumnLayout {
    spacing: 6
    Components.WavySeekBar {
      Layout.fillWidth: true
      indeterminate: !card.hasLen
      value: card.hasLen ? card.pos / card.len : 0
      playing: card.playing
      live: card.live
      seekable: !!(card.p && card.p.canSeek && card.p.positionSupported)
      color: Style.m3primary
      onSeek: (f) => {
        card.heldPos = f * card.len
        seekHold.restart()
        card.p.position = card.heldPos
      }
    }
    RowLayout {
      Layout.fillWidth: true
      visible: card.hasLen
      Text {
        text: card.fmtTime(card.pos)
        color: Style.m3onSurfaceVariant
        font.family: Style.menuSans; font.pixelSize: card.px(12); font.bold: true; font.features: { "tnum": 1 }
      }
      Item { Layout.fillWidth: true }
      Text {
        text: card.fmtTime(card.len)
        color: Style.m3onSurfaceVariant
        font.family: Style.menuSans; font.pixelSize: card.px(12); font.bold: true; font.features: { "tnum": 1 }
      }
    }
  }

  // Backdrop in a rounded clip: plain `clip` is rectangular, so the blur's square corners
  // showed past the card radius (visible on light themes).
  ClippingRectangle {
    anchors.fill: parent
    anchors.margins: card.border.width  // inside the card's outline, which it would paint over
    radius: card.radius - card.border.width
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
      visible: card.hasArt && backdrop.status === Image.Ready
      blurEnabled: true
      blur: 1.0
      blurMax: 64
      opacity: 0.9
    }
    // Reference wash: base at 0.55 / 0.72 / 0.90 top to bottom.
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.alpha(card.color, 0.55) }
        GradientStop { position: 0.5; color: Qt.alpha(card.color, 0.72) }
        GradientStop { position: 1.0; color: Qt.alpha(card.color, 0.90) }
      }
    }
  }

  ColumnLayout {
    id: body
    anchors.fill: parent
    anchors.margins: 18
    spacing: 12

    RowLayout {
      Layout.fillWidth: true
      spacing: card.px(16)

      // Vinyl disc (upstream MusicPopup): round cover in a record with grooves and an accent-ringed
      // label; one turn per 25 s while shown, paused (and shrunk to 0.9) when not playing; a soft
      // accent glow sits behind it while playing.
      Item {
        Layout.preferredWidth: disc.width + 14
        Layout.preferredHeight: disc.width + 14
        Layout.alignment: Qt.AlignVCenter
        Rectangle {
          anchors.centerIn: parent
          width: disc.width + 12; height: width; radius: width / 2
          color: Style.m3primary
          opacity: card.playing ? 0.35 : 0
          scale: disc.scale
          Behavior on opacity { NumberAnimation { duration: 500 } }
          layer.enabled: true
          layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
        }
        Rectangle {
          id: disc
          anchors.centerIn: parent
          width: card.px(110); height: width; radius: width / 2
          color: Style.surface1
          scale: card.playing ? 1.0 : 0.9
          Behavior on scale { SpringAnimation { spring: 5.2; damping: 0.35; mass: 0.75 } }
          NumberAnimation on rotation {
            from: 0; to: 360; duration: 25000
            loops: Animation.Infinite
            running: card.live && !!card.p
            paused: running && !card.playing
          }
          ClippingRectangle {
            anchors.fill: parent
            radius: width / 2
            color: Style.mantle
            Text {
              anchors.centerIn: parent
              visible: !card.hasArt
              text: "󰝚"
              color: Style.overlay1
              font.family: Style.fontFamily
              font.pixelSize: parent.width * 0.26
            }
            Image {
              anchors.fill: parent
              visible: card.hasArt
              source: Services.Players.artUrl
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              sourceSize: Qt.size(256, 256)
            }
            // Accent tint + grooves (alternating light / dark rings), as upstream.
            Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.alpha(Style.m3primary, 0.08); visible: card.hasArt }
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
          visible: !!card.p
          Layout.bottomMargin: 4
          implicitWidth: srcRow.implicitWidth + 16
          implicitHeight: card.px(22)
          radius: height / 2
          color: srcMa.containsMouse && many ? Style.m3containerHigh : Qt.alpha(Style.m3container, 0.8)
          Row {
            id: srcRow
            anchors.centerIn: parent
            spacing: 5
            Text {
              text: card.playing ? "󰐊" : "󰏤"
              color: card.playing ? Style.m3primary : Style.m3onSurfaceVariant
              font.family: Style.fontFamily; font.pixelSize: card.px(11)
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              textFormat: Text.PlainText
              text: (card.p ? card.p.identity || "Player" : "")
                + (parent.parent.many ? "  ·  " + (Services.Players.list.indexOf(card.p) + 1) + "/" + Services.Players.list.length : "")
              color: Style.m3onSurfaceVariant
              font.family: Style.menuSans; font.pixelSize: card.px(11); font.weight: Font.Medium
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              visible: parent.parent.many
              text: "󰑐"
              color: Style.m3onSurfaceVariant
              font.family: Style.fontFamily; font.pixelSize: card.px(11)
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
          textFormat: Text.PlainText
          text: card.p ? (card.p.trackTitle || "Unknown track") : "Nothing playing"
          color: Style.m3onSurface
          font.family: Style.menuSans; font.pixelSize: card.px(18); font.weight: Font.Bold
          wrapMode: Text.Wrap
          maximumLineCount: card.wide ? 1 : 2
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          visible: text !== ""
          textFormat: Text.PlainText
          text: card.p ? card.p.trackArtist || "" : "Start a player — its controls show up here"
          color: Style.m3onSurfaceVariant
          font.family: Style.menuSans; font.pixelSize: card.px(14); font.weight: Font.Medium
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          visible: text !== ""
          textFormat: Text.PlainText
          text: card.p ? card.p.trackAlbum || "" : ""
          color: Style.m3outline
          font.family: Style.menuSans; font.pixelSize: card.px(12)
          elide: Text.ElideRight
        }
        Seek { visible: card.wide; Layout.fillWidth: true; Layout.topMargin: 4 }
      }

      Transport { visible: card.wide; Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: card.px(8) }
    }

    Seek { visible: !card.wide; Layout.fillWidth: true }
    Transport { visible: !card.wide; Layout.alignment: Qt.AlignHCenter }

    // Cava strip: bars exist only while playing (see cavaOn), otherwise a flat hairline.
    Item {
      visible: !card.wide
      Layout.fillWidth: true
      Layout.preferredHeight: 22
      Row {
        anchors.fill: parent
        spacing: 3
        Repeater {
          model: card.cavaOn ? 24 : 0
          Rectangle {
            required property int index
            width: (parent.width - 23 * 3) / 24
            anchors.bottom: parent.bottom
            height: CavaBars.barHeight(Services.Cava.values[index] || 0, 22)
            radius: 1.5
            color: Qt.alpha(Style.m3primary, 0.55)
          }
        }
      }
      Rectangle {
        visible: !card.cavaOn
        anchors.bottom: parent.bottom
        width: parent.width; height: 2; radius: 1
        color: Style.menuSep
      }
    }
  }
}
