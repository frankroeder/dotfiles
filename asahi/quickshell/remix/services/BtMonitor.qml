pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "bt_monitor.js" as BtModel
import "bt_i18n.js" as I18n

// Peripheral batteries and connection paths (asahi-bluetooth-monitor, port of
// uBruckhaus/omarchy-bluetooth-monitor): one long-lived helper for the bar chip and the Bluetooth pane.
// It rescans on UPower / HID++ events and our commands, else every 60 s (10 s while `paneOpen`), and owns
// the hidden list, the alert thresholds and the remembered HID++ settings (single writer).
Singleton {
  id: root

  readonly property string binDir: Quickshell.env("HOME") + "/.dotfiles/asahi/bin"
  property var snap: ({})
  // {state: ok | low | critical, kind, name, percent}: worst visible online device.
  readonly property var alert: root.snap.alert || ({ state: "ok" })
  property bool paneOpen: false
  readonly property bool allowing: accessProc.running
  // Pane / tooltip language: the pane setting, else LC_ALL / LC_MESSAGES / LANG (bt_i18n).
  readonly property string sysLang: I18n.systemLanguage(Quickshell.env("LC_ALL"), Quickshell.env("LC_MESSAGES"), Quickshell.env("LANG"))
  readonly property string lang: I18n.resolve(root.snap.language || "auto", root.sysLang)
  // Upstream's hover list, on by default (pane setting turns it off; an exception to "tooltips on tray icons"); empty while the pane is open.
  readonly property string tooltipText: root.snap.bar_tooltip && !root.paneOpen
    ? BtModel.tooltipText(root.snap, (key, args) => I18n.tr(root.lang, key, args)) : ""
  onPaneOpenChanged: root.send({ cmd: root.paneOpen ? "open" : "closed" })

  function send(obj) { if (helper.running) helper.write(JSON.stringify(obj) + "\n") }
  function refresh() { root.send({ cmd: "refresh" }) }
  function setValue(id, key, value) { root.send({ cmd: "set", device: id, key: key, value: value }) }
  function setHidden(key, on) { root.send({ cmd: "hide", key: key, on: on }) }
  function setThresholds(lowAt, criticalAt) { root.send({ cmd: "thresholds", low_at: lowAt, critical_at: criticalAt }) }
  // {other_devices: bool} (UPower + BlueZ in the map / alerts) and / or {language: "auto" | code} (pane strings).
  function setOptions(opts) { root.send(Object.assign({ cmd: "options" }, opts)) }
  // pkexec (PolkitAgent prompts) installs the Logitech hidraw uaccess rule; the next scan opens the nodes.
  function allowAccess() { if (!accessProc.running) accessProc.running = true }
  function kindGlyph(kind) { return BtModel.kindGlyph(kind, false) }

  Process {
    id: helper
    running: true
    stdinEnabled: true
    // pdeathsig: the helper (and its upower --monitor) dies with qs.
    command: ["setpriv", "--pdeathsig", "TERM", root.binDir + "/asahi-bluetooth-monitor"]
    stdout: SplitParser {
      onRead: data => {
        try { root.snap = JSON.parse(data) } catch (e) {}
      }
    }
    onStarted: if (root.paneOpen) root.send({ cmd: "open" })
    onExited: restartTimer.start()
  }
  Timer { id: restartTimer; interval: 5000; onTriggered: helper.running = true }
  Process {
    id: accessProc
    command: ["pkexec", root.binDir + "/asahi-logitech-access"]
    onExited: root.refresh()
  }
}
