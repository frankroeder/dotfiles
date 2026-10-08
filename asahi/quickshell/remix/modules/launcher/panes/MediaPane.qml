import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import "../../menu" as Menu
import "../../../"
import "../../../services" as Services
import "../quick_models.js" as QuickModels
import "../launcher_layout.js" as LauncherGeom

// Media pane: now playing, sink/source pickers with volume, stream mixer, cava.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, launcherGeom, quickMode, quickPaneKey, binDir, ...).
Item {
  property var root
  id: quickMediaRoot
  anchors.fill: parent
  // Shared cava (Services.Cava), held only while the launcher shows this pane.
  readonly property bool cavaWanted: root.shouldShow
  onCavaWantedChanged: Services.Cava.hold(quickMediaRoot, quickMediaRoot.cavaWanted)
  readonly property string cavaStatus: Services.Cava.missing ? "cava not installed"
    : !Services.Cava.values.length ? "starting" : Services.Cava.active ? "active" : "waiting for audio"
  readonly property var activeP: Services.Players.active
  // Native Pipewire mixer (omarchy.audio port): live nodes instead of the
  // old 3s `wpctl status` poll — sliders track and write volumes directly.
  readonly property var pwNodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var pwSink: Pipewire.defaultAudioSink
  readonly property var pwSource: Pipewire.defaultAudioSource
  readonly property var candidateSinks: {
    const list = []
    const nodes = quickMediaRoot.pwNodes || []
    for (let i = 0; i < nodes.length; i++) {
      const n = nodes[i]
      if (n && n.isSink && !n.isStream) list.push(n)
    }
    return list
  }
  readonly property var candidateSources: {
    const list = []
    const nodes = quickMediaRoot.pwNodes || []
    for (let i = 0; i < nodes.length; i++) {
      const n = nodes[i]
      if (!n || n.isSink || n.isStream || !QuickModels.isAudioSource(n)) continue
      if ((n.name || "") === "quickshell") continue
      list.push(n)
    }
    return list
  }
  readonly property var candidateStreams: {
    const list = []
    const nodes = quickMediaRoot.pwNodes || []
    for (let i = 0; i < nodes.length; i++) {
      const n = nodes[i]
      if (n && n.isStream && QuickModels.isPlaybackStream(n) && !QuickModels.isDspStream(n)) list.push(n)
    }
    return list
  }
  // Repeaters feed from panel-local snapshots, not the live PipeWire model:
  // PipeWire can remove nodes while quickshell dispatches the removal
  // signal, and rebuilding a Repeater from that signal path has crashed
  // quickshell's PipeWire service (omarchy's snapshot-timer pattern).
  property var displaySinks: []
  property var displaySources: []
  property var displayStreams: []
  function refreshAudioModels() {
    quickMediaRoot.displaySinks = QuickModels.adoptAudioNodes(quickMediaRoot.displaySinks, quickMediaRoot.candidateSinks)
    quickMediaRoot.displaySources = QuickModels.adoptAudioNodes(quickMediaRoot.displaySources, quickMediaRoot.candidateSources)
    quickMediaRoot.displayStreams = QuickModels.adoptAudioNodes(quickMediaRoot.displayStreams, quickMediaRoot.candidateStreams)
  }
  onCandidateSinksChanged: audioModelRefresh.restart()
  onCandidateSourcesChanged: audioModelRefresh.restart()
  onCandidateStreamsChanged: audioModelRefresh.restart()
  Timer { id: audioModelRefresh; interval: 75; onTriggered: quickMediaRoot.refreshAudioModels() }
  // Default sink/source objects go null for a frame on PW republish;
  // hold the last live node so the master cards do not flash empty.
  property var heldSink: null
  property var heldSource: null
  onPwSinkChanged: if (quickMediaRoot.pwSink) quickMediaRoot.heldSink = quickMediaRoot.pwSink
  onPwSourceChanged: if (quickMediaRoot.pwSource) quickMediaRoot.heldSource = quickMediaRoot.pwSource
  property string defaultSinkName: ""
  property string defaultSourceName: ""
  readonly property var shownSink: QuickModels.resolveDefaultNode(
    quickMediaRoot.pwSink, quickMediaRoot.heldSink, quickMediaRoot.displaySinks, quickMediaRoot.defaultSinkName)
  readonly property var shownSource: QuickModels.resolveDefaultNode(
    quickMediaRoot.pwSource, quickMediaRoot.heldSource, quickMediaRoot.displaySources, quickMediaRoot.defaultSourceName)

  readonly property real outVol: quickMediaRoot.shownSink && quickMediaRoot.shownSink.audio ? quickMediaRoot.shownSink.audio.volume : 0
  readonly property bool outMuted: quickMediaRoot.shownSink && quickMediaRoot.shownSink.audio ? quickMediaRoot.shownSink.audio.muted : false
  readonly property real inVol: quickMediaRoot.shownSource && quickMediaRoot.shownSource.audio ? quickMediaRoot.shownSource.audio.volume : 0
  readonly property bool inMuted: quickMediaRoot.shownSource && quickMediaRoot.shownSource.audio ? quickMediaRoot.shownSource.audio.muted : false

  // Moving the output slider unmutes (like the volume keys); the input slider leaves mic mute alone.
  function setOutVol(v) {
    const s = quickMediaRoot.shownSink
    if (!s || !s.audio) return
    s.audio.volume = Math.max(0, Math.min(1, v))
    if (s.audio.muted) s.audio.muted = false  // only a real unmute: writing it every move clicked
  }
  function setInVol(v) {
    const s = quickMediaRoot.shownSource
    if (s && s.audio) s.audio.volume = Math.max(0, Math.min(1, v))
  }
  function toggleOutMute() {
    const s = quickMediaRoot.shownSink
    if (s && s.audio) s.audio.muted = !s.audio.muted
  }
  function toggleInMute() {
    const s = quickMediaRoot.shownSource
    if (s && s.audio) s.audio.muted = !s.audio.muted
  }
  // Default switches are PERSISTED by WirePlumber (default-nodes state), so
  // a stray tap can silently break audio for every future stream — no-op on
  // the already-active device.
  function setDefaultSink(node) {
    if (!node) return
    const key = QuickModels.audioNodeKey(node)
    if (key && key === QuickModels.audioNodeKey(quickMediaRoot.shownSink)) return
    Pipewire.preferredDefaultAudioSink = node
  }
  function setDefaultSource(node) {
    if (!node) return
    const key = QuickModels.audioNodeKey(node)
    if (key && key === QuickModels.audioNodeKey(quickMediaRoot.shownSource)) return
    Pipewire.preferredDefaultAudioSource = node
  }
  // Binds the candidate nodes so .audio/.properties/.description are live.
  PwObjectTracker { objects: [quickMediaRoot.pwSink, quickMediaRoot.pwSource] }
  PwObjectTracker { objects: quickMediaRoot.displaySinks }
  PwObjectTracker { objects: quickMediaRoot.displaySources }
  PwObjectTracker { objects: quickMediaRoot.displayStreams }

  Process {
    id: defaultSinkProc
    command: ["pactl", "get-default-sink"]
    stdout: StdioCollector {
      onStreamFinished: quickMediaRoot.defaultSinkName = (text || "").trim()
    }
  }
  Process {
    id: defaultSourceProc
    command: ["pactl", "get-default-source"]
    stdout: StdioCollector {
      onStreamFinished: quickMediaRoot.defaultSourceName = (text || "").trim()
    }
  }
  Timer {
    interval: 700
    running: root.shouldShow && root.quickMode && root.quickPaneKey === "media"
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!defaultSinkProc.running) defaultSinkProc.running = true
      if (!defaultSourceProc.running) defaultSourceProc.running = true
    }
  }

  Component.onCompleted: {
    if (quickMediaRoot.pwSink) quickMediaRoot.heldSink = quickMediaRoot.pwSink
    if (quickMediaRoot.pwSource) quickMediaRoot.heldSource = quickMediaRoot.pwSource
    quickMediaRoot.refreshAudioModels()
    Services.Cava.hold(quickMediaRoot, quickMediaRoot.cavaWanted)
  }
  Component.onDestruction: Services.Cava.hold(quickMediaRoot, false)

  // Mpris only re-estimates `position` on demand: nudge it once a second while playing.
  Timer {
    interval: 1000; repeat: true
    running: root.shouldShow && root.quickMode && root.quickPaneKey === "media" && !!quickMediaRoot.activeP && quickMediaRoot.activeP.isPlaying
    onTriggered: quickMediaRoot.activeP.positionChanged()
  }
  function fmtTime(s) {
    s = Math.max(0, Math.round(s || 0))
    return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2)
  }
  function pct(v) { return isFinite(v) ? Math.round(v * 100) + "%" : "" }
  function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }

  // M3 widgets shared by the cards below (caelestia look, same as RecordPanel).
  component RoundBtn: Rectangle {
    property string icon
    property int size: 36
    property color bg: Style.m3containerHigh
    property color fg: Style.m3onSurface
    property bool enabledLook: true
    signal clicked()
    width: size; height: size; radius: size / 2
    color: rma.containsMouse ? Qt.lighter(bg, 1.15) : bg
    opacity: enabledLook ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: 120 } }
    Text { anchors.centerIn: parent; text: parent.icon; color: parent.fg; font.family: root.uiFont; font.pixelSize: parent.size * 0.5 }
    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }
  component IconBtn: Rectangle {
    property string icon
    property color tone: Style.m3onSurfaceVariant
    signal clicked()
    width: 30; height: 30; radius: 15
    color: ima.containsMouse ? Style.m3stateHover : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
    Text { anchors.centerIn: parent; text: parent.icon; color: parent.tone; font.family: root.uiFont; font.pixelSize: root.fontPx(13) }
    MouseArea { id: ima; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }
  component CardTitle: Row {
    property string icon
    property string label
    spacing: 8
    Text {
      text: parent.icon; color: Style.m3primary; font.family: root.uiFont; font.pixelSize: root.fontPx(14)
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: parent.label; color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(12)
      font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Row heights follow the type scale so the cards never clip on the larger panel.
  readonly property int devRowH: Math.max(30, root.fontPx(11) + 12)
  readonly property int streamRowH: Math.max(36, root.fontPx(11) + 18)

  ColumnLayout {
    id: mediaCol
    anchors.fill: parent
    spacing: 10

    // Now playing: cover art (or glyph tile), title / artist / album, progress, round controls.
    // Grows with spare height up to 3 rows; the spectrum takes the rest.
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      // From the text, not npRow: the art sizes from this card, so npRow would ratchet it.
      Layout.minimumHeight: Math.max(80, npText.implicitHeight + 24)
      Layout.preferredHeight: Layout.maximumHeight
      Layout.maximumHeight: Math.max(Layout.minimumHeight, Math.round(root.launcherGeom.rowHTall * 3))
      radius: Style.menuPanelRadius
      color: Style.m3container
      readonly property var p: quickMediaRoot.activeP
      readonly property bool hasArt: !!(p && p.trackArtUrl && String(p.trackArtUrl) !== "")
      readonly property bool hasLen: !!(p && p.lengthSupported && p.length > 0)
      id: npCard
      RowLayout {
        id: npRow
        anchors.fill: parent
        anchors.margins: 12
        spacing: 14
        Rectangle {
          readonly property int side: Math.max(56, npCard.height - 24)
          Layout.preferredWidth: side; Layout.preferredHeight: side
          radius: Style.menuRadiusLg
          color: Style.m3primaryContainer
          Text { anchors.centerIn: parent; visible: !npCard.hasArt; text: "󰝚"; color: Style.m3primary; font.family: root.uiFont; font.pixelSize: Math.round(parent.side * 0.45) }
          ClippingRectangle {
            anchors.fill: parent; radius: Style.menuRadiusLg; color: "transparent"; visible: npCard.hasArt
            Image {
              anchors.fill: parent; source: npCard.hasArt ? npCard.p.trackArtUrl : ""
              fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(256, 256)
            }
          }
        }
        ColumnLayout {
          id: npText
          Layout.fillWidth: true
          spacing: 3
          Text {
            Layout.fillWidth: true
            text: npCard.p ? (npCard.p.trackTitle || "Unknown track") : "Nothing playing"
            color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(15); font.weight: Font.DemiBold; elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            text: {
              const p = npCard.p
              if (!p) return "Start a player — its controls show up here"
              return [p.trackArtist || "Unknown artist", p.trackAlbum || ""].filter(s => s !== "").join("  ·  ")
            }
            color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(11); elide: Text.ElideRight
          }
          RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10
            visible: npCard.hasLen
            Text {
              text: quickMediaRoot.fmtTime(npCard.p ? npCard.p.position : 0)
              color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
            }
            Rectangle {
              Layout.fillWidth: true; height: 4; radius: 2; color: Style.m3containerHigh
              Rectangle {
                width: npCard.hasLen ? parent.width * Math.max(0, Math.min(1, npCard.p.position / npCard.p.length)) : 0
                height: parent.height; radius: 2; color: Style.m3primary
                Behavior on width { NumberAnimation { duration: 200 } }
              }
            }
            Text {
              text: quickMediaRoot.fmtTime(npCard.p ? npCard.p.length : 0)
              color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
            }
          }
        }
        RoundBtn {
          icon: "󰒮"; size: root.fontPx(26); enabledLook: !!(npCard.p && npCard.p.canGoPrevious)
          onClicked: { const p = quickMediaRoot.activeP; if (p && p.canGoPrevious) p.previous() }
        }
        RoundBtn {
          icon: npCard.p && npCard.p.isPlaying ? "󰏤" : "󰐊"; size: root.fontPx(34)
          bg: Style.m3primary; fg: Style.m3onPrimary; enabledLook: !!(npCard.p && npCard.p.canTogglePlaying)
          onClicked: { const p = quickMediaRoot.activeP; if (p && p.canTogglePlaying) p.togglePlaying() }
        }
        RoundBtn {
          icon: "󰒭"; size: root.fontPx(26); enabledLook: !!(npCard.p && npCard.p.canGoNext)
          onClicked: { const p = quickMediaRoot.activeP; if (p && p.canGoNext) p.next() }
        }
      }
    }

    // Output / input: header with mute + big percent, master slider, M3 radio device list.
    // Sized to the content, every device shown (no scrolling). fillHeight stays false
    // explicitly: layouts inherit it from the cards' row-filling.
    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: false
      spacing: 10
      Repeater {
        model: [
          { title: "Output", icon: "󰕾", empty: "No output devices", out: true },
          { title: "Input", icon: "󰍬", empty: "No input devices", out: false }
        ]
        delegate: Rectangle {
          id: devCard
          required property var modelData
          readonly property bool isOut: modelData.out
          readonly property var devItems: isOut ? (quickMediaRoot.displaySinks || []) : (quickMediaRoot.displaySources || [])
          readonly property var activeNode: isOut ? quickMediaRoot.shownSink : quickMediaRoot.shownSource
          readonly property bool muted: isOut ? quickMediaRoot.outMuted : quickMediaRoot.inMuted
          readonly property real vol: isOut ? quickMediaRoot.outVol : quickMediaRoot.inVol
          Layout.fillWidth: true
          Layout.fillHeight: true
          implicitHeight: devInner.implicitHeight + 24
          radius: Style.menuRadiusLg
          color: Style.m3container
          ColumnLayout {
            id: devInner
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6
            RowLayout {
              Layout.fillWidth: true
              spacing: 8
              Text {
                text: devCard.isOut
                  ? (devCard.muted ? "󰖁" : QuickModels.sinkGlyph(devCard.activeNode))
                  : (devCard.muted ? "󰍭" : QuickModels.sourceGlyph(devCard.activeNode))
                color: devCard.muted ? Style.red : Style.m3primary; font.family: root.uiFont; font.pixelSize: root.fontPx(14)
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                  text: devCard.modelData.title; color: Style.m3onSurface
                  font.family: root.uiSans; font.pixelSize: root.fontPx(12); font.weight: Font.DemiBold
                }
                Text {
                  Layout.fillWidth: true
                  text: devCard.activeNode ? QuickModels.nodeLabel(devCard.activeNode) : devCard.modelData.empty
                  color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(10); elide: Text.ElideRight
                }
              }
              Text {
                text: devCard.muted ? "Muted" : quickMediaRoot.pct(devCard.vol)
                color: devCard.muted ? Style.red : Style.m3primary
                font.family: root.uiSans; font.pixelSize: root.fontPx(18); font.weight: Font.DemiBold
              }
              IconBtn {
                icon: devCard.isOut ? (devCard.muted ? "󰖁" : "󰕾") : (devCard.muted ? "󰍭" : "󰍬")
                tone: devCard.muted ? Style.red : Style.m3onSurfaceVariant
                onClicked: devCard.isOut ? quickMediaRoot.toggleOutMute() : quickMediaRoot.toggleInMute()
              }
            }
            Menu.MenuSlider {
              Layout.fillWidth: true
              value: devCard.vol
              dimmed: devCard.muted
              onMoved: function(v) { devCard.isOut ? quickMediaRoot.setOutVol(v) : quickMediaRoot.setInVol(v) }
            }
            Menu.MenuDivider { Layout.fillWidth: true }
            // Every device listed (the card grows to fit; no scrolling).
            Column {
              id: deviceCol
              Layout.fillWidth: true
              spacing: 0
              Repeater {
                model: devCard.devItems
                delegate: Rectangle {
                  id: devRow
                  required property var modelData
                  readonly property bool active: QuickModels.audioNodeKey(devCard.activeNode) === QuickModels.audioNodeKey(modelData)
                    && QuickModels.audioNodeKey(modelData) !== ""
                  width: parent.width
                  height: quickMediaRoot.devRowH
                  radius: Style.menuRadiusMd
                  color: devMa.containsMouse ? Style.m3stateHover : "transparent"
                  Behavior on color { ColorAnimation { duration: 120 } }
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 10
                    spacing: 10
                    Rectangle {
                      width: 16; height: 16; radius: 8
                      color: "transparent"
                      border.width: 2
                      border.color: devRow.active ? Style.m3primary : Style.m3outline
                      Behavior on border.color { ColorAnimation { duration: 120 } }
                      Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Style.m3primary; visible: devRow.active }
                    }
                    Text {
                      text: devCard.isOut ? QuickModels.sinkGlyph(devRow.modelData) : QuickModels.sourceGlyph(devRow.modelData)
                      color: devRow.active ? Style.m3primary : Style.m3onSurfaceVariant; font.family: root.uiFont; font.pixelSize: root.fontPx(11)
                    }
                    Text {
                      Layout.fillWidth: true
                      text: QuickModels.nodeLabel(devRow.modelData)
                      color: devRow.active ? Style.m3onSurface : Style.m3onSurfaceVariant
                      font.family: root.uiSans; font.pixelSize: root.fontPx(11); elide: Text.ElideRight
                      font.weight: devRow.active ? Font.Medium : Font.Normal
                    }
                    Text {
                      text: devRow.modelData && devRow.modelData.audio ? quickMediaRoot.pct(devRow.modelData.audio.volume) : ""
                      color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
                    }
                  }
                  MouseArea {
                    id: devMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: devCard.isOut ? quickMediaRoot.setDefaultSink(devRow.modelData) : quickMediaRoot.setDefaultSource(devRow.modelData)
                  }
                }
              }
            }
          }
        }
      }
    }

    // Stream mixer: one slider row per playback stream. Sized to its rows (up to 4,
    // then it scrolls); the spectrum takes the slack.
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: mixInner.implicitHeight + 24
      radius: Style.menuRadiusLg
      color: Style.m3container
      ColumnLayout {
        id: mixInner
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          CardTitle { icon: "󰝚"; label: "Stream mixer" }
          Text {
            text: (quickMediaRoot.displayStreams || []).length + " active"
            color: Style.m3onSurfaceVariant; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
          }
          Item { Layout.fillWidth: true }
          // Tonal pill: the full mixer (profiles, ports) lives in pavucontrol.
          Rectangle {
            implicitWidth: pavuRow.implicitWidth + 24; implicitHeight: 28
            radius: Style.menuRadiusFull
            color: pavuMa.containsMouse ? Qt.lighter(Style.m3secondaryContainer, 1.15) : Style.m3secondaryContainer
            Behavior on color { ColorAnimation { duration: 120 } }
            Row {
              id: pavuRow; anchors.centerIn: parent; spacing: 6
              Text {
                text: "󰕾"; color: Style.m3onSurface; font.family: root.uiFont; font.pixelSize: root.fontPx(12)
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: "pavucontrol"; color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(10)
                font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter
              }
            }
            MouseArea {
              id: pavuMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.execAndClose(["pavucontrol"])
            }
          }
        }
        Text {
          Layout.fillWidth: true
          Layout.preferredHeight: quickMediaRoot.streamRowH
          visible: (quickMediaRoot.displayStreams || []).length === 0
          text: "No active streams"
          color: Style.m3outline; font.family: root.uiSans; font.pixelSize: root.fontPx(11)
          horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        Flickable {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.min(streamCol.implicitHeight, 4 * (quickMediaRoot.streamRowH + 2))
          visible: (quickMediaRoot.displayStreams || []).length > 0
          clip: true
          contentHeight: streamCol.implicitHeight
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: Menu.MenuScrollBar {}
          Column {
            id: streamCol
            width: parent.width
            spacing: 2
            Repeater {
              model: quickMediaRoot.displayStreams || []
              delegate: Rectangle {
                id: streamRow
                required property var modelData
                readonly property var audio: modelData ? modelData.audio : null
                readonly property bool muted: streamRow.audio ? streamRow.audio.muted : false
                readonly property real vol: streamRow.audio ? streamRow.audio.volume : 0
                width: parent.width
                height: quickMediaRoot.streamRowH
                radius: Style.menuRadiusMd
                color: streamMa.containsMouse ? Style.m3stateHover : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                MouseArea { id: streamMa; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 6
                  spacing: 12
                  Rectangle {
                    width: 28; height: 28; radius: 14
                    color: streamRow.muted ? Style.m3containerHigh : Style.m3secondaryContainer
                    Text {
                      anchors.centerIn: parent; text: "󰝚"; color: streamRow.muted ? Style.m3outline : Style.m3secondary
                      font.family: root.uiFont; font.pixelSize: root.fontPx(12)
                    }
                  }
                  Text {
                    Layout.preferredWidth: Math.round(parent.width * 0.28)
                    text: QuickModels.friendlyDeviceLabel(QuickModels.rawStreamLabel(streamRow.modelData)) || "Stream"
                    color: streamRow.muted ? Style.m3onSurfaceVariant : Style.m3onSurface
                    font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.Medium; elide: Text.ElideRight
                  }
                  Menu.MenuSlider {
                    Layout.fillWidth: true
                    value: streamRow.vol
                    dimmed: streamRow.muted
                    onMoved: function(v) { if (streamRow.audio) streamRow.audio.volume = v }
                  }
                  Text {
                    Layout.preferredWidth: root.fontPx(34)
                    horizontalAlignment: Text.AlignRight
                    text: streamRow.muted ? "Muted" : quickMediaRoot.pct(streamRow.vol)
                    color: streamRow.muted ? Style.red : Style.m3onSurface
                    font.family: root.uiSans; font.pixelSize: root.fontPx(11); font.weight: Font.DemiBold
                  }
                  IconBtn {
                    icon: streamRow.muted ? "󰖁" : "󰕾"
                    tone: streamRow.muted ? Style.red : Style.m3onSurfaceVariant
                    onClicked: if (streamRow.audio) streamRow.audio.muted = !streamRow.audio.muted
                  }
                }
              }
            }
          }
        }
      }
    }

    // Live cava spectrum: rounded bars mirrored about the midline, primary →
    // tertiary across the row. Takes the slack Now playing leaves.
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 84
      radius: Style.menuRadiusLg
      color: Style.m3container
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6
        RowLayout {
          Layout.fillWidth: true
          CardTitle { icon: "󰎈"; label: "Spectrum" }
          Item { Layout.fillWidth: true }
          Rectangle {
            implicitWidth: cavaState.implicitWidth + 18; implicitHeight: cavaState.implicitHeight + 8
            radius: Style.menuRadiusFull
            color: quickMediaRoot.cavaStatus === "active" ? Style.m3primaryContainer : Style.m3containerHigh
            Text {
              id: cavaState; anchors.centerIn: parent
              text: quickMediaRoot.cavaStatus
              color: quickMediaRoot.cavaStatus === "active" ? Style.m3primary : Style.m3outline
              font.family: root.uiSans; font.pixelSize: root.fontPx(10); font.weight: Font.Medium
            }
          }
        }
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Row {
            anchors.fill: parent
            spacing: 6
            Repeater {
              model: 24
              delegate: Item {
                required property int index
                width: (parent.width - 23 * parent.spacing) / 24
                height: parent.height
                // Idle: a low static wave so the card reads as a resting visualizer.
                readonly property real idleFrac: 0.04 + 0.05 * (1 + Math.sin(index * 0.55)) / 2
                Rectangle {
                  anchors.centerIn: parent
                  width: Math.min(12, parent.width)
                  radius: width / 2
                  height: Math.max(4, parent.height * (quickMediaRoot.cavaStatus === "active"
                    ? (Services.Cava.values[index] || 0) / 100 : parent.idleFrac))
                  color: quickMediaRoot.cavaStatus === "active"
                    ? quickMediaRoot.mix(Style.m3primary, Style.m3tertiary, index / 23) : Style.m3outlineVariant
                  Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
                }
              }
            }
          }
        }
      }
    }
  }
}
