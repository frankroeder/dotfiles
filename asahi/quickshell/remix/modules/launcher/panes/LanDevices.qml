import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../menu" as Menu
import "../../../"
import "../lan_models.js" as Lan

// Devices tab of the Network pane over asahi-lan (idea: uBruckhaus/omarchy-wlan-monitor). `lan` is the collector's
// latest snapshot; every edit goes back as one `command` (a JSON line on its stdin). Trust / grouping / Rescan sit in the
// pane's card header.
ColumnLayout {
  id: lanView
  property var root
  property var lan: ({})
  property string query: ""
  property string expanded: ""  // mac of the open row
  property string renaming: ""
  property string copied: ""  // key whose copy icon shows the tick
  property var pings: ({})  // mac → parsePing result | {busy: true}
  signal command(var cmd)
  spacing: 6

  readonly property var viewState: lanView.lan.view || ({ mode: "list", collapsed: [] })
  readonly property var rows: Lan.listRows(lanView.lan, lanView.viewState.mode, lanView.viewState.collapsed, lanView.query)

  function copy(text, key) {
    Quickshell.execDetached(["wl-copy", text])
    lanView.copied = key
    copyTick.restart()
  }
  Timer { id: copyTick; interval: 1500; onTriggered: lanView.copied = "" }
  function toggleMode() {
    lanView.command({ cmd: "view", mode: lanView.viewState.mode === "type" ? "list" : "type", collapsed: lanView.viewState.collapsed || [] })
  }
  function toggleGroup(id) {
    const c = (lanView.viewState.collapsed || []).filter(g => g !== id)
    if (c.length === (lanView.viewState.collapsed || []).length) c.push(id)
    lanView.command({ cmd: "view", mode: lanView.viewState.mode, collapsed: c })
  }
  function openWeb(url) { root.execAndClose([root.binDir + "/asahi-launch", "xdg-open", url]) }
  // Ghostty stays open after ssh exits, so a refused / failed login stays readable.
  function openSsh(d) { root.execAndClose(["env", "ASAHI_TUI_WAIT=1", root.binDir + "/asahi-launch-tui"].concat(Lan.sshArgs(d))) }
  // On-demand ping of one device (4 echoes, ~1 s); the result stays in its open row. Nothing pings by itself.
  function ping(d) {
    if (pingProc.running) return
    pingProc.mac = d.mac
    pingProc.command = ["ping", "-n", "-q", "-c", "4", "-i", "0.2", "-W", "1", d.ip]
    lanView.pings = Object.assign({}, lanView.pings, { [d.mac]: { busy: true } })
    pingProc.running = true
  }
  Process {
    id: pingProc
    property string mac: ""
    stdout: StdioCollector {
      onStreamFinished: lanView.pings = Object.assign({}, lanView.pings, { [pingProc.mac]: Lan.parsePing(text) })
    }
  }
  function saveName(mac, name) {
    lanView.command({ cmd: "rename", mac: mac, name: name })
    lanView.renaming = ""
  }
  // Launcher Esc: one layer per press (rename → open row → search).
  function handleEscape() {
    if (lanView.renaming) { lanView.renaming = ""; return true }
    if (lanView.expanded) { lanView.expanded = ""; return true }
    if (lanView.query) { searchIn.text = ""; return true }
    return false
  }

  component Pill: Menu.MenuPill { fontScale: lanView.root.uiFontScale; bg: Style.m3container }
  component IconBtn: Menu.MenuIconBtn { fontScale: lanView.root.uiFontScale }
  component Secondary: Text {
    color: Style.m3onSurfaceVariant
    font.family: lanView.root.uiSans
    font.pixelSize: lanView.root.fontPx(10)
    elide: Text.ElideRight
    textFormat: Text.PlainText  // device names, hosts, makers come off the network
  }
  component Glyph: Text {
    font.family: lanView.root.uiFont
    font.pixelSize: lanView.root.fontPx(13)
    color: Style.m3onSurfaceVariant
  }
  component Badge: Rectangle {
    implicitWidth: badgeText.implicitWidth + 10; implicitHeight: badgeText.implicitHeight + 2
    radius: height / 2; color: Style.m3primary
    Text {
      id: badgeText; anchors.centerIn: parent; text: "NEW"; color: Style.m3onPrimary
      font.family: lanView.root.uiSans; font.pixelSize: lanView.root.fontPx(7); font.weight: Font.Bold
    }
  }
  // Swallow keys a field leaves unhandled (arrows at its ends, Tab, Return): they would reach the launcher tiles.
  component Field: TextInput {
    property string hint: ""
    color: Style.m3onSurface; font.family: lanView.root.uiSans; font.pixelSize: lanView.root.fontPx(10)
    clip: true; verticalAlignment: TextInput.AlignVCenter
    Keys.priority: Keys.AfterItem
    Keys.onPressed: event => {
      if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Tab, Qt.Key_Backtab].indexOf(event.key) !== -1)
        event.accepted = true
    }
    Text {
      anchors.fill: parent; verticalAlignment: Text.AlignVCenter
      text: parent.hint; color: Style.m3onSurfaceVariant; font: parent.font
      visible: parent.text === "" && !parent.activeFocus
    }
  }
  component FieldBox: Rectangle {
    implicitHeight: 30; radius: Style.menuRadiusFull
    color: Style.m3container
  }

  // A VPN that cuts the home LAN off: devices only look idle / asleep.
  Rectangle {
    visible: !!lanView.lan.vpn_blocked
    Layout.fillWidth: true
    implicitHeight: vpnRow.implicitHeight + 16
    radius: Style.menuRadiusMd
    color: Style.panelDangerBg
    RowLayout {
      id: vpnRow
      anchors.fill: parent; anchors.margins: 8
      spacing: 10
      Glyph { text: "󰦞"; color: Style.red; font.pixelSize: root.fontPx(15) }
      Secondary {
        Layout.fillWidth: true; wrapMode: Text.Wrap; color: Style.m3onSurface
        text: "The VPN (" + lanView.lan.vpn_blocked + ") blocks the home network: devices look idle or asleep. "
          + "Allow LAN access in its settings, or disconnect it."
      }
    }
  }

  // Search: only once the list is long enough to need it (a campus network).
  FieldBox {
    visible: (lanView.lan.total || 0) > 12 || lanView.query !== ""
    Layout.fillWidth: true
    color: searchIn.activeFocus ? Style.m3containerHigh : Style.m3container
    Glyph {
      id: searchGlyph
      anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
      text: "󰍉"; color: searchIn.activeFocus ? Style.m3primary : Style.m3onSurfaceVariant; font.pixelSize: root.fontPx(11)
    }
    Field {
      id: searchIn
      anchors.left: searchGlyph.right; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
      anchors.leftMargin: 8; anchors.rightMargin: 12
      hint: "Filter by name, type, maker, model or IP (\"printer\")"
      onTextChanged: lanView.query = text.trim()
      Keys.onEscapePressed: { text = ""; root.focusLauncherInput() }
    }
  }

  ListView {
    id: devList
    visible: !!lanView.lan.active
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: Menu.MenuScrollBar { id: devScroll }
    model: ScriptModel { objectProp: "key"; values: lanView.rows }
    delegate: Column {
      id: row
      required property var modelData
      readonly property var d: modelData
      readonly property bool open: !d.header && lanView.expanded === d.mac
      readonly property color tone: d.state === "online" ? Style.m3primary : (d.state === "idle" ? Style.m3onSurface : Style.m3onSurfaceVariant)
      width: devList.width - (devScroll.overflow ? devScroll.implicitWidth + 4 : 0)
      spacing: 2

      // Group header: chevron, title, NEW, online / count.
      Rectangle {
        visible: row.d.header
        width: parent.width; height: root.fontPx(24)
        radius: Style.menuRadiusMd
        color: headMa.containsMouse ? Style.m3stateHover : "transparent"
        MouseArea { id: headMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lanView.toggleGroup(row.d.id) }
        RowLayout {
          anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 10
          spacing: 6
          Glyph { text: row.d.collapsed ? "󰅂" : "󰅀"; font.pixelSize: root.fontPx(11) }
          Text {
            text: row.d.title || ""; textFormat: Text.PlainText
            color: Style.m3onSurface; font.family: root.uiSans; font.pixelSize: root.fontPx(9); font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase; font.letterSpacing: 1
          }
          Badge { visible: !!row.d.fresh }
          Item { Layout.fillWidth: true }
          Secondary {
            font.pixelSize: root.fontPx(9)
            text: row.d.online === row.d.count ? String(row.d.count) : row.d.online + " / " + row.d.count + " online"
          }
        }
      }

      // Device: kind glyph, name + badges, second line, status / IP, ssh / web / copy IP (the open row has the rest).
      Rectangle {
        visible: !row.d.header
        width: parent.width; height: root.fontPx(34)
        radius: Style.menuRadiusMd
        color: devMa.containsMouse || row.open ? Style.m3stateHover : "transparent"
        MouseArea {
          id: devMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onClicked: lanView.expanded = row.open ? "" : row.d.mac
        }
        RowLayout {
          anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 4
          spacing: 10
          Glyph {
            text: Lan.glyph(row.d.kind); color: row.tone; opacity: row.d.state === "asleep" ? 0.55 : 1
            font.pixelSize: root.fontPx(15)
            Layout.preferredWidth: root.fontPx(18)
          }
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
              spacing: 6
              Layout.fillWidth: true
              Text {
                Layout.maximumWidth: devList.width * 0.5
                text: row.d.name || ""; textFormat: Text.PlainText; elide: Text.ElideRight
                color: row.d.state === "asleep" ? Style.m3onSurfaceVariant : Style.m3onSurface
                font.family: root.uiSans; font.pixelSize: root.fontPx(11)
                font.weight: row.d.state === "online" ? Font.DemiBold : Font.Normal
              }
              Badge { visible: !!row.d.new }
              Glyph { visible: !!row.d.pinned; text: "󰐃"; font.pixelSize: root.fontPx(10) }
              Item { Layout.fillWidth: true }
            }
            Secondary { Layout.fillWidth: true; text: Lan.secondary(row.d); font.pixelSize: root.fontPx(9) }
          }
          Secondary {
            text: Lan.status(row.d)
            color: row.d.self || row.d.gw ? Style.m3primary : Style.m3onSurfaceVariant
          }
          IconBtn { visible: Lan.canSsh(row.d); icon: "󰆍"; onClicked: lanView.openSsh(row.d) }
          IconBtn { visible: !!row.d.web; icon: "󰖟"; onClicked: lanView.openWeb(row.d.web) }
          IconBtn {
            visible: !!row.d.ip
            icon: lanView.copied === row.d.mac ? "󰄬" : "󰆏"
            onClicked: lanView.copy(row.d.ip, row.d.mac)
          }
        }
      }

      // Open row: what the state means, ping result, the facts, the actions.
      Rectangle {
        visible: row.open
        width: parent.width; height: detailCol.implicitHeight + 16
        radius: Style.menuRadiusMd
        color: Style.m3containerHigh
        ColumnLayout {
          id: detailCol
          anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 8; anchors.leftMargin: root.fontPx(18) + 20
          spacing: 6
          Secondary { Layout.fillWidth: true; wrapMode: Text.Wrap; text: row.open ? Lan.stateText(row.d, !!lanView.lan.trusted) : "" }
          Secondary {
            visible: row.d.mac in lanView.pings
            Layout.fillWidth: true
            text: "Ping: " + Lan.pingText(lanView.pings[row.d.mac])
            color: (lanView.pings[row.d.mac] || {}).got === 0 ? Style.red : Style.m3onSurface
          }
          Flow {
            Layout.fillWidth: true
            spacing: 16
            Repeater {
              model: row.open ? Lan.details(row.d) : []
              delegate: Row {
                required property var modelData
                spacing: 6
                Secondary { text: modelData[0]; font.weight: Font.DemiBold }
                Secondary { text: modelData[1]; color: Style.m3onSurface }
              }
            }
          }
          // Rename in place: Enter saves, Esc cancels; an empty name goes back to the automatic one.
          RowLayout {
            visible: lanView.renaming === row.d.mac
            Layout.fillWidth: true
            spacing: 8
            FieldBox {
              Layout.fillWidth: true
              Field {
                id: nameIn
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                hint: row.d.auto || ""; maximumLength: 40
                Keys.onReturnPressed: lanView.saveName(row.d.mac, text)
                Keys.onEscapePressed: lanView.renaming = ""
              }
            }
            Pill { icon: "󰄬"; label: "Save"; bg: Style.m3primary; fg: Style.m3onPrimary; onClicked: lanView.saveName(row.d.mac, nameIn.text) }
          }
          Flow {
            visible: lanView.renaming !== row.d.mac
            Layout.fillWidth: true
            spacing: 6
            Pill {
              visible: !row.d.self && !!row.d.ip
              icon: "󰓅"; label: pingProc.running && pingProc.mac === row.d.mac ? "Pinging…" : "Ping"
              onClicked: lanView.ping(row.d)
            }
            Pill {
              icon: "󰏫"; label: "Rename"
              onClicked: {
                lanView.renaming = row.d.mac
                nameIn.text = row.d.custom ? row.d.name : ""
                nameIn.forceActiveFocus()
              }
            }
            Pill {
              icon: "󰐃"; label: row.d.pinned ? "Unpin" : "Pin to top"
              onClicked: lanView.command({ cmd: "pin", mac: row.d.mac, on: !row.d.pinned })
            }
            Pill {
              visible: !!row.d.new
              icon: "󰄬"; label: "It's mine"; bg: Style.m3primaryContainer
              onClicked: lanView.command({ cmd: "known", mac: row.d.mac })
            }
            Pill {
              icon: lanView.copied === "mac:" + row.d.mac ? "󰄬" : "󰆏"; label: "Copy MAC"
              onClicked: lanView.copy(row.d.mac, "mac:" + row.d.mac)
            }
          }
        }
      }
    }
  }

  Menu.MenuEmptyState {
    visible: !lanView.lan.active
    Layout.alignment: Qt.AlignCenter
    Layout.fillHeight: true
    fontScale: root.uiFontScale; iconFamily: root.uiFont; fontFamily: root.uiSans
    glyph: lanView.lan.time === undefined ? "󰐷" : "󰤮"
    tint: Style.m3onSurfaceVariant
    title: lanView.lan.time === undefined ? "Looking around…" : "Not on a LAN"
    detail: lanView.lan.time === undefined ? "" : "Connect to Wi-Fi or Ethernet to see who else is on it."
  }
}
