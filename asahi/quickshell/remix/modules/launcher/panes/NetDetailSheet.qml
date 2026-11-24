import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../menu" as Menu
import "../../../"
import "../quick_models.js" as QuickModels
import "../net_detail.js" as NetDetail

// Detail sheet of one Wi-Fi network over the Network pane (idea: caelestia NetworkDetailPage / SavedNetworksPage):
// the access point, the saved profile's switches and IPv4, the current lease. Reads `nmcli -t` on open and after an
// edit; every edit is one `nmcli connection modify uuid <u> …` (argv only: SSIDs / names are untrusted). `uuid` "" =
// a network without a profile (header only).
Rectangle {
  id: sheet
  property var root
  property var pane  // NetworkPane: signal words, QR, forget, rescan
  property string uuid: ""
  property string ssid: ""
  property bool open: false

  property var p: ({})  // parsed `connection show`
  property var ap: null  // pickAp of the cached scan
  property var link: ({})  // `ip -j link` of the active device: address, permaddr
  property var saved: NetDetail.ipv4Form({})
  property var form: NetDetail.ipv4Form({})
  property string status: ""
  property bool statusError: false
  property bool forgetArmed: false

  readonly property bool active: sheet.p["GENERAL.STATE"] === "activated"
  readonly property string netSsid: sheet.p["802-11-wireless.ssid"] || sheet.ssid
  readonly property string name: sheet.p["connection.id"] || ""
  readonly property bool busy: modifyProc.running || upProc.running
  readonly property bool dirty: !!sheet.uuid && !NetDetail.sameForm(sheet.form, sheet.saved)
  readonly property string formError: sheet.dirty ? NetDetail.ipv4Error(sheet.form) : ""
  readonly property int strength: sheet.ap ? sheet.ap.signal : 0
  // The line beside Revert / Apply: progress or a failure, else what to fix, else what Apply does.
  readonly property string note: sheet.busy || sheet.statusError || !sheet.dirty ? sheet.status
    : sheet.formError || (sheet.active ? "Applying reconnects " + sheet.netSsid : "Takes effect on the next connect")

  radius: Style.menuRadiusLg
  color: Style.m3container
  // Shared-axis forward (the pane switch's motion): fades in from 36 px right, leaves the same way.
  opacity: sheet.open ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { Menu.MenuAnim { effects: true; exit: !sheet.open } }
  transform: Translate { x: sheet.open ? 0 : 36; Behavior on x { Menu.MenuAnim { exit: !sheet.open } } }
  // The pane under it takes no clicks or hover.
  MouseArea { anchors.fill: parent; hoverEnabled: true }

  function load() {
    sheet.status = ""
    sheet.statusError = false
    sheet.forgetArmed = false
    if (sheet.uuid) {
      showProc.running = false  // another network's read: a running one does not restart on `running = true`
      showProc.command = ["nmcli", "-e", "no", "-t", "-f",
        "connection.id,connection.uuid,connection.autoconnect,connection.metered,connection.timestamp,802-11-wireless.ssid,"
        + "802-11-wireless.cloned-mac-address,802-11-wireless-security.key-mgmt,ipv4.method,ipv4.addresses,ipv4.gateway,"
        + "ipv4.dns,ipv6.method,ipv6.addresses,GENERAL.STATE,GENERAL.DEVICES,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.DNS",
        "connection", "show", "uuid", sheet.uuid]
      showProc.running = true
    } else {
      sheet.p = ({})
      sheet.link = ({})
      readAp()
    }
  }
  function readAp() { if (!apProc.running) apProc.running = true }
  function resetForm() {
    sheet.form = sheet.saved
    addrBox.input.text = sheet.saved.address
    gwBox.input.text = sheet.saved.gateway
    dnsBox.input.text = sheet.saved.dns
  }
  function edit(key, value) {
    const next = Object.assign({}, sheet.form)
    next[key] = value
    sheet.form = next
    sheet.status = ""
    sheet.statusError = false
  }
  function revert() {
    sheet.status = ""
    sheet.statusError = false
    sheet.resetForm()
  }
  // One profile edit through a transient unit (must finish if the pane goes away). The IPv4 form re-activates an active
  // connection after; a switch only patches the read (an IPv4 edit in progress stays).
  function modify(args) {
    if (sheet.busy || !sheet.uuid) return
    const ipv4 = args[0] === "ipv4.method"
    sheet.status = ipv4 ? "Saving…" : ""
    sheet.statusError = false
    modifyProc.args = args
    modifyProc.reconnect = ipv4 && sheet.active
    modifyProc.command = ["systemd-run", "--user", "--wait", "--quiet", "--collect",
      "nmcli", "connection", "modify", "uuid", sheet.uuid].concat(args)
    modifyProc.running = true
  }
  function apply() {
    if (!sheet.dirty || sheet.formError || sheet.busy) return
    sheet.modify(NetDetail.ipv4Args(sheet.form))
  }
  function forget() {
    if (!sheet.forgetArmed) { sheet.forgetArmed = true; disarm.restart(); return }
    sheet.pane.forgetSsid(sheet.name, sheet.uuid)
    sheet.pane.closeDetail()
  }
  Timer { id: disarm; interval: 3000; onTriggered: sheet.forgetArmed = false }
  // The pane's list changes with every scan that differs: the signal here follows it (the cached list, no rescan).
  Connections {
    target: sheet.pane
    function onWifiNetworksChanged() { if (sheet.open) sheet.readAp() }
  }

  Process {
    id: showProc
    stdout: StdioCollector {
      onStreamFinished: {
        const p = NetDetail.parseShow(text)
        if (p["connection.uuid"] !== sheet.uuid) return
        sheet.p = p
        sheet.saved = NetDetail.ipv4Form(sheet.p)
        sheet.resetForm()
        sheet.link = ({})
        const dev = (sheet.p["GENERAL.DEVICES"] || "").split(",")[0]
        if (dev) { linkProc.command = ["ip", "-j", "link", "show", "dev", dev]; linkProc.running = true }
        sheet.readAp()
      }
    }
  }
  Process {
    id: apProc
    command: ["nmcli", "-t", "-f", "IN-USE,BSSID,SSID,CHAN,FREQ,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "no"]
    stdout: StdioCollector {
      onStreamFinished: {
        const rows = text.split("\n").filter(l => l).map(l => QuickModels.nmcliFields(l))
        sheet.ap = NetDetail.pickAp(rows, sheet.netSsid)
      }
    }
  }
  Process {
    id: linkProc
    stdout: StdioCollector { onStreamFinished: sheet.link = (JSON.parse(text || "[]")[0] || {}) }
  }
  Process {
    id: modifyProc
    property var args: []
    property bool reconnect: false
    onExited: function(code) {
      if (code !== 0) {
        sheet.status = "Not saved: NetworkManager refused it"
        sheet.statusError = true
        return
      }
      if (modifyProc.args[0] !== "ipv4.method") {
        const next = Object.assign({}, sheet.p)
        next[modifyProc.args[0]] = modifyProc.args[1]
        sheet.p = next
        return
      }
      if (modifyProc.reconnect) {
        sheet.status = "Reconnecting…"
        upProc.command = ["systemd-run", "--user", "--wait", "--quiet", "--collect", "nmcli", "connection", "up", "uuid", sheet.uuid]
        upProc.running = true
        return
      }
      sheet.load()
      sheet.status = "Saved"
    }
  }
  Process {
    id: upProc
    onExited: function(code) {
      sheet.load()
      sheet.status = code === 0 ? "Saved and reconnected" : "Saved; reconnect failed"
      sheet.statusError = code !== 0
      sheet.pane.scanWifi()
    }
  }

  component Pill: Menu.MenuPill { fontScale: sheet.root.uiFontScale }
  component Chip: Menu.MenuChip { fontScale: sheet.root.uiFontScale }
  component Secondary: Text {
    color: Style.m3onSurfaceVariant
    font.family: sheet.root.uiSans
    font.pixelSize: sheet.root.fontPx(10)
    elide: Text.ElideRight
    textFormat: Text.PlainText  // SSIDs, profile names, resolver lists
  }
  component Caption: Secondary {
    font.pixelSize: sheet.root.fontPx(8); font.weight: Font.DemiBold; font.letterSpacing: 1.2
    font.capitalization: Font.AllUppercase
  }
  // Label column + a machine string (the Wi-Fi card's fact rows) + an optional word after it.
  component Fact: RowLayout {
    property string label: ""
    property string value: ""
    property string note: ""
    Layout.fillWidth: true
    spacing: 10
    Secondary { text: parent.label; Layout.preferredWidth: sheet.root.fontPx(10) * 7 }
    Secondary { text: parent.value; color: Style.m3onSurface; font.family: Style.fontData; Layout.fillWidth: parent.note === "" }
    Secondary { visible: parent.note !== ""; text: parent.note; Layout.fillWidth: true }
  }
  // Text field: Return applies, Esc closes the sheet; keys it leaves unhandled (arrows at its ends, Tab) stay here —
  // they would reach the launcher's tiles / search (LanDevices' Field).
  component Field: Rectangle {
    id: fieldBox
    property string label: ""
    property string hint: ""
    property alias input: fieldIn
    signal edited(string text)
    Layout.fillWidth: true
    implicitHeight: 30
    radius: Style.menuRadiusFull
    color: fieldIn.activeFocus ? Style.m3containerHigh : Qt.alpha(Style.m3onSurface, 0.06)
    border.width: fieldIn.activeFocus ? 1 : 0
    border.color: Style.m3primary
    Text {
      id: fieldLabel
      anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
      text: fieldBox.label; color: Style.m3onSurfaceVariant
      font.family: sheet.root.uiSans; font.pixelSize: sheet.root.fontPx(9)
    }
    TextInput {
      id: fieldIn
      anchors.left: fieldLabel.right; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
      anchors.leftMargin: 8; anchors.rightMargin: 12
      color: Style.m3onSurface; font.family: Style.fontData; font.pixelSize: sheet.root.fontPx(10)
      clip: true; verticalAlignment: TextInput.AlignVCenter; selectByMouse: true; maximumLength: 120
      onTextEdited: fieldBox.edited(text)
      Keys.priority: Keys.AfterItem
      Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) sheet.pane.closeDetail()
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) sheet.apply()
        else if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_Tab, Qt.Key_Backtab].indexOf(event.key) === -1) return
        event.accepted = true
      }
      Text {
        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
        text: fieldBox.hint; color: Qt.alpha(Style.m3onSurfaceVariant, 0.6); font: parent.font
        visible: parent.text === "" && !parent.activeFocus
      }
    }
  }

  Flickable {
    id: flick
    anchors.fill: parent
    anchors.margins: 12
    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: Menu.MenuScrollBar { id: sheetScroll; autoHide: false }  // no edge fades here

    ColumnLayout {
      id: col
      width: flick.width - (sheetScroll.overflow ? sheetScroll.implicitWidth + 4 : 0)
      spacing: 10

      // Header: back, the network, its signal.
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Menu.MenuIconBtn {
          fontScale: sheet.root.uiFontScale; icon: "󰁍"; tone: Style.m3onSurface
          onClicked: sheet.pane.closeDetail()
        }
        Menu.MenuGlyphTile {
          glyph: sheet.pane.signalGlyph(sheet.strength); fontScale: sheet.root.uiFontScale
          tint: sheet.active ? Style.m3primary : Style.m3onSurfaceVariant
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Text {
            Layout.fillWidth: true
            text: sheet.netSsid || sheet.name; textFormat: Text.PlainText; elide: Text.ElideRight
            color: Style.m3onSurface; font.family: sheet.root.uiSans; font.pixelSize: sheet.root.fontPx(15); font.weight: Font.DemiBold
          }
          Secondary {
            Layout.fillWidth: true
            text: !sheet.uuid ? "Not saved on this computer"
              : NetDetail.sinceText(Number(sheet.p["connection.timestamp"]) || 0, Date.now() / 1000, sheet.active)
                + (sheet.name && sheet.name !== sheet.netSsid ? " · profile " + sheet.name : "")
          }
        }
        Text {
          visible: !!sheet.ap
          text: sheet.strength + "% · " + sheet.pane.signalWord(sheet.strength)
          color: sheet.pane.signalColor(sheet.strength)
          font.family: sheet.root.uiSans; font.pixelSize: sheet.root.fontPx(11); font.weight: Font.DemiBold
        }
      }

      // The access point: protection, band / channel, BSSID (only while it is in the cached scan).
      Flow {
        Layout.fillWidth: true
        spacing: 6
        Chip {
          icon: "󰌾"
          label: sheet.uuid && sheet.p["connection.id"] ? NetDetail.keyMgmtLabel(sheet.p["802-11-wireless-security.key-mgmt"])
            : QuickModels.wifiSecurityLabel(sheet.ap ? sheet.ap.sec : "")
        }
        Chip {
          visible: !!sheet.ap && sheet.ap.freq > 0
          icon: "󰖩"
          label: sheet.ap ? QuickModels.formatHeaderFreq(sheet.ap.freq) + " · ch " + sheet.ap.chan + " · " + sheet.ap.freq + " MHz" : ""
        }
        Chip { visible: !!sheet.ap; icon: "󰑩"; label: sheet.ap ? sheet.ap.bssid.toLowerCase() : ""; fontFamily: Style.fontData }
        Chip { visible: !sheet.ap; icon: "󰤮"; label: "Not in the last scan" }
      }

      // Profile switches: apply at once.
      RowLayout {
        visible: !!sheet.p["connection.id"]
        Layout.fillWidth: true
        spacing: 8
        Secondary { text: "Connect automatically"; color: Style.m3onSurface }
        Menu.MenuSwitch {
          checked: sheet.p["connection.autoconnect"] === "yes"; locked: sheet.busy
          onToggled: sheet.modify(["connection.autoconnect", checked ? "no" : "yes"])
        }
        Item { Layout.fillWidth: true }
        Secondary { text: "Metered"; color: Style.m3onSurface }
        Repeater {
          model: [{ key: "unknown", label: "Auto" }, { key: "yes", label: "Yes" }, { key: "no", label: "No" }]
          delegate: Pill {
            required property var modelData
            label: modelData.label
            selected: NetDetail.meteredKey(sheet.p["connection.metered"]) === modelData.key
            bg: "transparent"; fg: Style.m3onSurfaceVariant
            onClicked: if (!selected) sheet.modify(["connection.metered", modelData.key])
          }
        }
      }

      // IPv4: DHCP / DHCP + own DNS / Manual; Apply shows once something changed.
      RowLayout {
        visible: !!sheet.p["connection.id"]
        Layout.fillWidth: true
        spacing: 6
        Caption { text: "IPv4"; Layout.rightMargin: 4 }
        Repeater {
          model: [{ key: "dhcp", label: "DHCP" }, { key: "dns", label: "DHCP + DNS" }, { key: "manual", label: "Manual" }]
          delegate: Pill {
            required property var modelData
            label: modelData.label
            selected: sheet.form.mode === modelData.key
            bg: "transparent"; fg: Style.m3onSurfaceVariant
            onClicked: sheet.edit("mode", modelData.key)
          }
        }
        Item { Layout.fillWidth: true }
      }
      RowLayout {
        visible: !!sheet.p["connection.id"] && sheet.form.mode === "manual"
        Layout.fillWidth: true
        spacing: 8
        Field { id: addrBox; label: "Address"; hint: "192.168.1.50/24"; onEdited: t => sheet.edit("address", t) }
        Field { id: gwBox; label: "Gateway"; hint: "192.168.1.1"; onEdited: t => sheet.edit("gateway", t) }
      }
      Field {
        id: dnsBox
        visible: !!sheet.p["connection.id"] && (sheet.form.mode === "dns" || sheet.form.mode === "manual")
        label: "DNS"; hint: "1.1.1.1, 9.9.9.9"
        onEdited: t => sheet.edit("dns", t)
      }
      Fact { visible: !!sheet.p["connection.id"]; label: "IPv6"; value: NetDetail.ipv6Text(sheet.p) }
      RowLayout {
        visible: sheet.dirty || sheet.status !== ""
        Layout.fillWidth: true
        spacing: 8
        Secondary {
          Layout.fillWidth: true
          text: sheet.note
          color: sheet.statusError || (!sheet.busy && sheet.formError !== "") ? Style.red : Style.m3onSurfaceVariant
        }
        Pill {
          visible: sheet.dirty && !sheet.busy
          label: "Revert"; bg: "transparent"; fg: Style.m3onSurfaceVariant
          onClicked: sheet.revert()
        }
        Pill {
          visible: sheet.dirty
          enabled: !sheet.formError && !sheet.busy; opacity: enabled ? 1 : 0.45
          icon: "󰄬"; label: "Apply"; bg: Style.m3primary; fg: Style.m3onPrimary
          onClicked: sheet.apply()
        }
      }

      // Current lease, while connected; the join code beside it.
      RowLayout {
        visible: sheet.active
        Layout.fillWidth: true
        spacing: 12
        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignTop
          spacing: 1
          Caption { text: "Current lease"; Layout.bottomMargin: 4 }
          Fact { label: "IP"; value: (sheet.p["IP4.ADDRESS"] || []).join(", ") }
          Fact { label: "Gateway"; value: sheet.p["IP4.GATEWAY"] || "" }
          Fact { label: "DNS"; value: (sheet.p["IP4.DNS"] || []).concat(sheet.p["IP6.DNS"] || []).join(", ") }
          Fact {
            label: "MAC"; value: sheet.link.address || ""
            // permaddr only shows when the address differs from the hardware one.
            note: (sheet.link.permaddr && sheet.link.permaddr !== sheet.link.address ? "private" : "hardware")
              + " · " + NetDetail.macPolicy(sheet.p["802-11-wireless.cloned-mac-address"])
          }
        }
        Rectangle {
          visible: !!sheet.pane.wifiQrPath
          Layout.alignment: Qt.AlignTop
          Layout.preferredWidth: 112; Layout.minimumWidth: 112; Layout.maximumWidth: 112
          Layout.preferredHeight: 112; Layout.minimumHeight: 112; Layout.maximumHeight: 112
          radius: Style.menuRadiusMd; color: "white"
          Image {
            anchors.fill: parent; anchors.margins: 6; source: sheet.pane.wifiQrPath
            cache: false; smooth: false; fillMode: Image.PreserveAspectFit
          }
        }
      }
      Secondary {
        visible: sheet.active && !!sheet.pane.wifiQrError && !sheet.pane.wifiQrPath
        Layout.fillWidth: true; text: sheet.pane.wifiQrError; color: Style.red
      }

      // Share the active network (the card's asahi-wifi-qr); Forget asks twice.
      RowLayout {
        visible: !!sheet.uuid
        Layout.fillWidth: true
        spacing: 8
        Pill {
          visible: sheet.active && sheet.pane.wifiEnabled
          icon: "󰐲"; label: sheet.pane.wifiQrPath ? "Hide QR" : "Share QR"
          bg: Style.m3secondaryContainer; selected: !!sheet.pane.wifiQrPath
          onClicked: sheet.pane.toggleWifiQr()
        }
        Item { Layout.fillWidth: true }
        Pill {
          icon: "󰩺"; label: sheet.forgetArmed ? "Forget " + (sheet.name || sheet.netSsid) + "?" : "Forget"
          fg: Style.red; bg: sheet.forgetArmed ? Qt.alpha(Style.red, 0.18) : Style.m3containerHigh
          onClicked: sheet.forget()
        }
      }
    }
  }
}
