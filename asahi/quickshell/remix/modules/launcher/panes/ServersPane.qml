import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../menu" as Menu
import "../../../"

// Servers pane (idea: serpantinum-kde's servers panel): what listens on this Mac and the services behind it.
// Listening = ports with their owner, `local` or `LAN` (orange: reachable from the network), Open for web ports;
// Services = enabled user services + every unit owning a port, with Start / Stop / Restart (system units ask polkit,
// a system Stop takes a second click within 3 s). Containers only when podman exists. `asahi-servers --json` on open
// and every 5 s while shown, again after an action.
// `root` is the LauncherWindow (fontPx, uiFont/uiSans, binDir, shouldShow, quickMode, quickPaneKey, execAndClose, ...).
Item {
  property var root
  id: srvRoot
  anchors.fill: parent

  // Rows are rebuilt only when their shape changes; live values (state, since, memory) come from `unitState` by key, so
  // a poll does not recreate the row under the pointer.
  property var listening: []
  property var services: []
  property var containers: []
  property var unitState: ({})
  property bool loaded: false
  property string busyKey: ""   // "<scope>/<unit>" while its action runs
  property string busyVerb: ""
  property string stopArmed: "" // system unit whose Stop waits for the second click
  property string error: ""
  readonly property bool shown: root.shouldShow && root.quickMode && root.quickPaneKey === "servers"
  readonly property int lanCount: srvRoot.listening.filter(r => !r.local).length
  readonly property int runningCount: srvRoot.services.filter(s => (srvRoot.unitState[s.scope + "/" + s.unit] || {}).active === "active").length

  function refresh() { if (!listProc.running) listProc.running = true }
  function apply(d) {
    const shape = (d.services || []).map(s => ({ unit: s.unit, scope: s.scope, description: s.description, ports: s.ports }))
    if (JSON.stringify(shape) !== JSON.stringify(srvRoot.services)) srvRoot.services = shape
    if (JSON.stringify(d.listening) !== JSON.stringify(srvRoot.listening)) srvRoot.listening = d.listening || []
    if (JSON.stringify(d.containers) !== JSON.stringify(srvRoot.containers)) srvRoot.containers = d.containers || []
    const st = {}
    for (const s of d.services || []) st[s.scope + "/" + s.unit] = s
    srvRoot.unitState = st
    srvRoot.loaded = true
  }
  function act(verb, s) {
    const key = s.scope + "/" + s.unit
    if (actProc.running) return
    if (verb === "stop" && s.scope === "system" && srvRoot.stopArmed !== key) { srvRoot.stopArmed = key; disarm.restart(); return }
    srvRoot.stopArmed = ""
    srvRoot.error = ""
    srvRoot.busyVerb = verb   // before busyKey: the row reads it as soon as it is busy
    srvRoot.busyKey = key
    actProc.command = [root.binDir + "/asahi-servers", verb, s.scope, s.unit]
    actProc.running = true
  }
  function dur(t) {
    const s = Math.max(0, Date.now() / 1000 - t)
    if (s < 60) return "<1 min"
    if (s < 3600) return Math.floor(s / 60) + " min"
    if (s < 172800) return Math.floor(s / 3600) + " h"
    return Math.floor(s / 86400) + " d"
  }
  function status(st) {
    if (!st) return ""
    if (st.active === "active") return st.since ? "up " + srvRoot.dur(st.since) : "running"
    if (st.active === "failed" || st.active === "inactive") {
      const word = st.active === "failed" ? "failed" : "stopped"
      return st.since ? word + " " + srvRoot.dur(st.since) + " ago" : word
    }
    return st.sub || st.active   // activating, deactivating, reloading
  }
  function stateColor(st) {
    if (!st) return Style.m3outline
    if (st.active === "active") return Style.green
    if (st.active === "failed") return Style.red
    return st.active === "inactive" ? Style.m3outline : Style.orange
  }
  function stem(unit) { return String(unit || "").replace(/\.service$/, "") }
  function ports(list) { return (list || []).map(p => ":" + p).join(" ") }
  readonly property var descOf: {
    const m = {}
    for (const s of srvRoot.services) m[s.unit] = s.description
    return m
  }

  Process {
    id: listProc
    command: [root.binDir + "/asahi-servers", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { srvRoot.apply(JSON.parse(String(text || "").trim() || "{}")) } catch (e) {}
      }
    }
  }
  Timer {
    interval: 5000; running: srvRoot.shown; repeat: true; triggeredOnStart: true
    onTriggered: srvRoot.refresh()
  }
  Process {
    id: actProc
    stderr: StdioCollector { onStreamFinished: srvRoot.error = String(text || "").trim() }
    onExited: { srvRoot.busyKey = ""; srvRoot.refresh() }
  }
  Timer { id: disarm; interval: 3000; onTriggered: srvRoot.stopArmed = "" }

  component Chip: Menu.MenuChip { fontScale: srvRoot.root.uiFontScale; implicitHeight: srvRoot.root.fontPx(20) }
  component IconBtn: Menu.MenuIconBtn {
    fontScale: srvRoot.root.uiFontScale
    implicitWidth: srvRoot.root.fontPx(24); implicitHeight: implicitWidth
    opacity: enabled ? 1 : 0   // a missing button keeps its slot: columns line up row to row
  }
  component Name: Text {
    color: Style.m3onSurface
    font.family: srvRoot.root.uiSans; font.pixelSize: srvRoot.root.fontPx(11); font.weight: Font.Medium
    textFormat: Text.PlainText   // process names come from the processes
    elide: Text.ElideRight
  }
  component Secondary: Text {
    color: Style.m3onSurfaceVariant
    font.family: srvRoot.root.uiSans; font.pixelSize: srvRoot.root.fontPx(10)
    textFormat: Text.PlainText   // unit descriptions, addresses
    elide: Text.ElideRight
  }
  component Section: RowLayout {
    id: section
    property string glyph: ""
    property color tint: Style.m3primary
    property string title: ""
    property string count: ""
    Layout.fillWidth: true
    Layout.leftMargin: 6; Layout.rightMargin: 8
    Layout.bottomMargin: 2
    spacing: 8
    Menu.MenuGlyphTile { glyph: section.glyph; tint: section.tint; fontScale: srvRoot.root.uiFontScale }
    Text {
      Layout.fillWidth: true
      text: section.title
      color: Style.m3onSurface; font.family: srvRoot.root.uiSans; font.pixelSize: srvRoot.root.fontPx(13); font.weight: Font.DemiBold
    }
    Secondary { text: section.count }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 12

    // Hero: what is reachable from the network, port and service counts.
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: heroRow.implicitHeight + 20
      radius: Style.menuPaneRadius
      color: Style.m3container
      Menu.MenuRunner {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: parent.radius; rightMargin: parent.radius }
        busy: !srvRoot.loaded
      }
      RowLayout {
        id: heroRow
        anchors.fill: parent; anchors.margins: 10; anchors.leftMargin: 12; anchors.rightMargin: 16
        spacing: 14
        Rectangle {
          width: Math.round(36 * root.uiFontScale); height: width; radius: Style.menuRadiusMd   // hero tile: one size in every pane
          color: Style.m3primaryContainer
          Text {
            anchors.centerIn: parent; text: "󰒍"; color: Style.m3primary
            font.family: root.uiFont; font.pixelSize: Math.round(22 * root.uiFontScale)
          }
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text {
            Layout.fillWidth: true
            text: "Servers"
            color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(17); font.weight: Font.DemiBold
            font.variableAxes: Style.opsz(root.fontPx(17))
          }
          Text {
            Layout.fillWidth: true
            text: !srvRoot.loaded ? "Reading sockets…"
              : srvRoot.lanCount > 0 ? srvRoot.lanCount + (srvRoot.lanCount === 1 ? " port is" : " ports are") + " reachable from the network"
              : "Nothing is reachable from the network"
            color: srvRoot.lanCount > 0 ? Style.orange : Style.m3onSurfaceVariant
            font.family: root.uiSans; font.pixelSize: root.fontPx(11); elide: Text.ElideRight
          }
        }
        Chip { icon: "󰈀"; label: srvRoot.listening.length + " ports"; bg: Style.m3secondaryContainer }
        Chip { icon: "󰒓"; label: srvRoot.runningCount + " / " + srvRoot.services.length + " running"; bg: Style.m3tertiaryContainer }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      radius: Style.menuRadiusLg
      color: Style.m3container
      clip: true
      Flickable {
        id: listFlick
        anchors.fill: parent
        anchors.margins: 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: listCol.implicitHeight
        ScrollBar.vertical: Menu.MenuScrollBar { id: listScroll }
        Menu.MenuEdgeFade { parent: listFlick; surface: Style.m3container; atTop: true; gutter: listScroll.width }
        Menu.MenuEdgeFade { parent: listFlick; surface: Style.m3container; gutter: listScroll.width }
        ColumnLayout {
          id: listCol
          visible: srvRoot.listening.length + srvRoot.services.length + srvRoot.containers.length > 0
          width: listFlick.width - (listScroll.overflow ? listScroll.implicitWidth + 4 : 0)
          spacing: 2

          // ---- Listening: one row per port and owner ----
          Section {
            glyph: "󰈀"
            title: "Listening"
            count: srvRoot.listening.length + " ports" + (srvRoot.lanCount > 0 ? " · " + srvRoot.lanCount + " on the LAN" : "")
          }
          Repeater {
            model: srvRoot.listening
            delegate: Rectangle {
              id: portRow
              required property var modelData
              readonly property var r: modelData
              Layout.fillWidth: true
              implicitHeight: root.fontPx(26)
              radius: Style.menuRowRadius
              color: portHover.hovered ? Style.m3stateHover : "transparent"
              Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
              HoverHandler { id: portHover }
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6; anchors.rightMargin: 6
                spacing: 8
                Chip {
                  fixedWidth: root.fontPx(100)
                  label: ":" + portRow.r.port + " " + portRow.r.protos.slice().sort().join("·")
                  fontFamily: Style.fontData
                  bg: Style.m3secondaryContainer
                }
                // Our own process by name; a root daemon (no pid for us) by its unit; else nobody we can see.
                Name {
                  Layout.preferredWidth: root.fontPx(100)
                  text: portRow.r.process || srvRoot.stem(portRow.r.unit) || "unknown owner"
                  color: portRow.r.process || portRow.r.unit ? Style.m3onSurface : Style.m3onSurfaceVariant
                }
                Secondary {
                  Layout.fillWidth: true
                  text: [portRow.r.addrs.indexOf("*") >= 0 ? "all interfaces" : portRow.r.addrs.join(", "),
                    portRow.r.unit ? (srvRoot.descOf[portRow.r.unit] || portRow.r.unit) : ""].filter(x => x).join(" · ")
                }
                Chip {
                  fixedWidth: root.fontPx(46)
                  label: portRow.r.local ? "local" : "LAN"
                  bg: portRow.r.local ? Style.m3containerHigh : Qt.alpha(Style.orange, 0.2)
                  fg: portRow.r.local ? Style.m3onSurfaceVariant : Style.orange
                }
                IconBtn {
                  enabled: !!portRow.r.url
                  icon: "󰏌"
                  hot: Style.m3primary
                  onClicked: root.execAndClose([root.binDir + "/asahi-launch", "xdg-open", portRow.r.url])
                }
              }
            }
          }
          Menu.MenuEmptyState {
            visible: srvRoot.loaded && srvRoot.listening.length === 0
            Layout.leftMargin: 4
            quiet: true; fontScale: root.uiFontScale
            glyph: "󰒍"
            title: "No listening sockets"
          }

          // ---- Services: state dot, name, user / system, description + ports, since, memory, actions ----
          Section {
            Layout.topMargin: 10
            glyph: "󰒓"
            tint: Style.m3tertiary
            title: "Services"
            count: srvRoot.runningCount + " of " + srvRoot.services.length + " running"
          }
          Repeater {
            model: srvRoot.services
            delegate: Rectangle {
              id: svcRow
              required property var modelData
              readonly property var s: modelData
              readonly property string key: s.scope + "/" + s.unit
              readonly property var st: srvRoot.unitState[key] || null
              readonly property bool active: !!st && st.active === "active"
              readonly property bool busy: srvRoot.busyKey === key
              readonly property bool armed: srvRoot.stopArmed === key
              Layout.fillWidth: true
              implicitHeight: root.fontPx(26)
              radius: Style.menuRowRadius
              color: svcHover.hovered ? Style.m3stateHover : "transparent"
              Behavior on color { ColorAnimation { duration: Style.menuStateMs } }
              HoverHandler { id: svcHover }
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 6
                spacing: 10
                Rectangle {
                  implicitWidth: root.fontPx(7); implicitHeight: implicitWidth; radius: width / 2
                  Layout.leftMargin: (root.listSlot - width) / 2; Layout.rightMargin: (root.listSlot - width) / 2
                  color: srvRoot.stateColor(svcRow.st)
                  Behavior on color { ColorAnimation { duration: 200 } }
                }
                // Middle: sibling units share a prefix (speakerguardd-v2-graph / -session).
                Name { Layout.preferredWidth: root.fontPx(118); text: srvRoot.stem(svcRow.s.unit); elide: Text.ElideMiddle }
                Chip {
                  fixedWidth: root.fontPx(46)
                  label: svcRow.s.scope
                  bg: svcRow.s.scope === "user" ? Style.m3secondaryContainer : Style.m3tertiaryContainer
                }
                Secondary {
                  Layout.fillWidth: true
                  text: [srvRoot.ports(svcRow.s.ports), svcRow.s.description].filter(x => x).join(" · ")
                }
                Secondary {
                  Layout.preferredWidth: root.fontPx(92)
                  horizontalAlignment: Text.AlignRight
                  font.features: Style.fontTabular
                  text: svcRow.busy ? ({ start: "starting…", stop: "stopping…", restart: "restarting…" })[srvRoot.busyVerb]
                    : svcRow.armed ? "click again to stop" : srvRoot.status(svcRow.st)
                  color: svcRow.busy ? Style.m3primary : svcRow.armed || (svcRow.st && svcRow.st.active === "failed") ? Style.red
                    : Style.m3onSurfaceVariant
                }
                Secondary {
                  Layout.preferredWidth: root.fontPx(48)
                  horizontalAlignment: Text.AlignRight
                  font.features: Style.fontTabular
                  text: svcRow.st && svcRow.st.memory > 0 ? root.prettyBytes(svcRow.st.memory) : ""
                }
                // Running: Restart + Stop; stopped: Start (Restart's slot stays empty). Speaker protection: Start only.
                IconBtn {
                  enabled: svcRow.active && !svcRow.busy && !svcRow.s.protected
                  icon: "󰜉"
                  hot: Style.m3primary
                  onClicked: srvRoot.act("restart", svcRow.s)
                }
                IconBtn {
                  enabled: !svcRow.busy && !(svcRow.active && svcRow.s.protected)
                  opacity: enabled ? 1 : 0.35
                  icon: svcRow.active ? "󰓛" : "󰐊"
                  hot: svcRow.active ? Style.red : Style.green
                  tone: svcRow.armed ? Style.red : Style.m3onSurfaceVariant
                  bg: svcRow.armed ? Qt.alpha(Style.red, 0.22) : "transparent"
                  onClicked: srvRoot.act(svcRow.active ? "stop" : "start", svcRow.s)
                }
              }
            }
          }

          // ---- Containers (podman), read-only ----
          Section {
            visible: srvRoot.containers.length > 0
            Layout.topMargin: 10
            glyph: "󰡨"
            tint: Style.blue
            title: "Containers"
            count: String(srvRoot.containers.length)
          }
          Repeater {
            model: srvRoot.containers
            delegate: RowLayout {
              required property var modelData
              Layout.fillWidth: true
              Layout.leftMargin: 10; Layout.rightMargin: 6
              Layout.preferredHeight: root.fontPx(26)
              spacing: 10
              Rectangle {
                implicitWidth: root.fontPx(7); implicitHeight: implicitWidth; radius: width / 2
                Layout.leftMargin: (root.listSlot - width) / 2; Layout.rightMargin: (root.listSlot - width) / 2
                color: modelData.state === "running" ? Style.green : Style.m3outline
              }
              Name { Layout.preferredWidth: root.fontPx(118); text: modelData.name }
              Secondary { Layout.fillWidth: true; text: [srvRoot.ports(modelData.ports), modelData.image].filter(x => x).join(" · ") }
              Secondary { text: modelData.status }
            }
          }

          Text {
            visible: srvRoot.error !== ""
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.leftMargin: 8
            text: srvRoot.error
            textFormat: Text.PlainText
            color: Style.red; font.family: root.uiSans; font.pixelSize: root.fontPx(9)
            wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
          }
        }
      }
      Menu.MenuEmptyState {
        anchors.centerIn: parent
        visible: !listCol.visible
        fontScale: root.uiFontScale
        iconFamily: root.uiFont
        fontFamily: root.uiSans
        glyph: "󰒍"
        tint: Style.m3primary
        title: srvRoot.loaded ? "Nothing is listening" : "Reading sockets…"
        detail: srvRoot.loaded ? "No open ports and no enabled services" : ""
      }
    }
  }
}
