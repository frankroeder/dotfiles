// node asahi/quickshell/remix/services/bt_monitor_test.js
const assert = require("assert")
const M = require("./bt_monitor.js")
const I = require("./bt_i18n.js")
const t = (k, a) => I.tr("en", k, a)
const cp = (s) => s.codePointAt(0).toString(16)

// --- glyphs / text ---
assert.strictEqual(cp(M.kindGlyph("mouse")), "f037d")
assert.strictEqual(cp(M.kindGlyph("headset")), "f02cb")
assert.strictEqual(M.kindGlyph("device", true), M.GLYPH_BT_CONNECTED)
assert.strictEqual(M.kindGlyph("nope", false), M.GLYPH_BT)
assert.strictEqual(M.kindOfIcon("audio-headphones"), "headset")
assert.strictEqual(M.kindOfIcon("input-keyboard"), "keyboard")
assert.strictEqual(M.kindOfIcon("input-gaming"), "gamepad")
assert.strictEqual(M.kindOfIcon(""), "device")

assert.strictEqual(M.batteryGlyph(null), "")
assert.strictEqual(cp(M.batteryGlyph({ percent: 100 })), "f0079")
assert.strictEqual(cp(M.batteryGlyph({ percent: 2 })), "f008e")
assert.strictEqual(cp(M.batteryGlyph({ percent: 50 })), "f007e")
assert.strictEqual(cp(M.batteryGlyph({ percent: 88 })), "f0082")
assert.strictEqual(cp(M.batteryGlyph({ percent: 40, charging: true })), "f0084")
assert.strictEqual(cp(M.batteryGlyph({ percent: null, level: "good" })), "f0091")
assert.strictEqual(M.batteryText({ percent: 7 }), "7%")
assert.strictEqual(M.batteryText({ percent: null, level: "low" }), "Low")
assert.strictEqual(M.batteryText({ percent: null, level: "unknown" }), "")

assert.strictEqual(M.batteryState({ percent: 25 }, 25, 10), "low")
assert.strictEqual(M.batteryState({ percent: 10 }, 25, 10), "critical")
assert.strictEqual(M.batteryState({ percent: 9, charging: true }, 25, 10), "ok")
assert.strictEqual(M.batteryState(null, 25, 10), "ok")

assert.strictEqual(M.connectionLabel({ receiver: "r-hidraw3", connection: "bolt", slot: 2 }, t), "Bolt dongle · slot 2")
assert.strictEqual(M.connectionLabel({ connection: "usb" }, t), "USB cable")
assert.strictEqual(M.connectionLabel({ connection: "bolt", slot: 1 }, (k, a) => I.tr("de", k, a)), "Bolt-Dongle · Platz 1")
assert.strictEqual(M.hasSettings({ online: true, dpi: { min: 100 } }), true)
assert.strictEqual(M.hasSettings({ online: true, denied: true, dpi: { min: 100 } }), false)
assert.strictEqual(M.hasSettings({ online: false, dpi: { min: 100 } }), false)

// --- DPI slider ---
const range = { min: 100, max: 25600, step: 50 }
assert.strictEqual(M.dpiAt(range, 0), 100)
assert.strictEqual(M.dpiAt(range, 1), 25600)
assert.strictEqual(M.dpiAt(range, 0.5) % 50, 0)
assert.strictEqual(M.dpiFrac(range, 25600), 1)
assert.strictEqual(M.dpiAt(range, M.dpiFrac(range, 1600)), 1600)
const choices = { min: 400, max: 3200, step: 0, choices: [400, 800, 1600, 3200] }
assert.strictEqual(M.dpiAt(choices, 0.4), 800)
assert.strictEqual(M.dpiFrac(choices, 1700), 2 / 3)

// --- connection map ---
const snap = {
  adapters: [{ id: "hci0", builtin: true, bus: "pci", vendor: "Broadcom" }],
  receivers: [{ id: "r-hidraw3", family: "bolt", name: "Bolt receiver", devices: ["hidraw3-1"], max_devices: 6 },
              { id: "r-hidraw5", family: "bolt", name: "Bolt receiver", devices: [], max_devices: 6 }],
  devices: [
    { id: "hidraw3-1", key: "4082", name: "MX Master 3", kind: "mouse", online: true, receiver: "r-hidraw3", connection: "bolt",
      battery: { percent: 8 }, state: "critical", hidden: false },
    { id: "up-kbd", key: "up:SER", name: "Apple Inc. Magic Keyboard", kind: "keyboard", online: true, connection: "usb", source: "upower",
      battery: { percent: 100 }, state: "ok", hidden: false },
    { id: "bt-E8", key: "bt:E8:85", address: "E8:85", name: "Pömpel", kind: "headset", online: true, connection: "bluetooth",
      adapter: "hci0", source: "bluez", battery: null, state: "ok", hidden: false },
    { id: "hidraw7-direct", key: "c08b", name: "G502", kind: "mouse", online: true, connection: "usb", denied: true, hidden: true }
  ],
  hidden: ["c08b"], low_at: 25, critical_at: 10
}
let links = M.mapLinks(snap, false)
assert.deepStrictEqual(links.map(l => t(l.title) + (l.n ? " " + l.n : "")), ["Built-in Bluetooth", "Bolt dongle 1", "Bolt dongle 2", "USB cable"])
assert.deepStrictEqual([links[0].vendor, t(links[0].sub)], ["Broadcom", "Inside this PC"])
assert.deepStrictEqual(links[0].devices.map(d => d.name), ["Pömpel"])
assert.strictEqual(t(links[1].sub, links[1].subArgs), "1 of 6 slots")
assert.strictEqual(links[2].devices.length, 0)  // empty receiver still shows (free slots)
assert.deepStrictEqual(links[3].devices.map(d => d.id), ["up-kbd"])  // hidden G502 left out
assert.deepStrictEqual(M.mapLinks(snap, true)[3].devices.map(d => d.id), ["up-kbd", "hidraw7-direct"])
assert.deepStrictEqual(M.mapLinks({ devices: [] }, false), [])  // no adapter, nothing connected: no map

// --- pane rows ---
const bluez = [
  { address: "E8:85", label: "Pömpel", connected: true, paired: true, icon: "audio-headphones" },
  { address: "B0:BE", label: "Frank’s Magic Keyboard", connected: false, paired: true, icon: "input-keyboard" },
  { address: "11:22", label: "Speaker", connected: false, paired: false, icon: "audio-card" },
  { address: "33:44", label: "Old Mouse", connected: true, paired: true, icon: "input-mouse", batteryAvailable: true, battery: 20 }
]
let rows = M.paneRows(bluez, snap, false, false)
assert.deepStrictEqual(rows.map(r => r.label), ["Old Mouse", "Pömpel", "Apple Inc. Magic Keyboard", "MX Master 3", "Frank’s Magic Keyboard"])
assert.deepStrictEqual(rows.map(r => r.section && t(r.section)), ["Connected", "", "USB & receivers", "", "Paired"])
assert.strictEqual(rows[1].id, "bt-E8")                 // merged with the monitor's BlueZ entry
assert.strictEqual(rows[0].state, "low")                // BlueZ battery fallback uses the thresholds
assert.strictEqual(rows[3].state, "critical")
assert.strictEqual(rows[3].wired, true)
assert.strictEqual(new Set(rows.map(r => r.uid)).size, rows.length)
rows = M.paneRows(bluez, Object.assign({}, snap, { hidden: ["bt:E8:85", "c08b"] }), false, true)
assert.strictEqual(rows.find(r => r.label === "Pömpel").hidden, true)  // BlueZ rows stay, tagged (upstream Bluetooth page)
assert.ok(!rows.some(r => r.id === "hidraw7-direct"))   // hidden USB device drops out
assert.strictEqual(rows[rows.length - 1].section, "btSecAvailable")
const many = []
for (let i = 0; i < 55; i++) many.push({ address: "AA:" + i, label: "Dev " + String(i).padStart(2, "0"), paired: false, icon: "" })
assert.strictEqual(M.paneRows(many, {}, false, true).length, 40)  // upstream caps each section at 40
rows = M.paneRows(bluez, Object.assign({}, snap, { hidden: ["bt:E8:85"] }), true, false)
assert.strictEqual(rows.find(r => r.label === "Pömpel").hidden, true)
assert.ok(rows.some(r => r.id === "hidraw7-direct"))   // shown (dimmed) with showHidden

// --- bar tooltip (opt-in) ---
const tipSnap = { phase: "ok", devices: [
  { name: "MX Master 3", online: true, battery: { percent: 8 } },
  { name: "Keys", online: true, battery: { percent: 60, charging: true } },
  { name: "Buds", online: true, battery: null },
  { name: "Off", online: false, battery: { percent: 50 } },
  { name: "Hidden", online: true, hidden: true, battery: { percent: 5 } }] }
assert.strictEqual(M.tooltipText(tipSnap, t), "Bluetooth\n● MX Master 3  8%\n● Keys  60% ⚡\n● Buds  no battery reading")
assert.strictEqual(M.tooltipText({ phase: "permission" }, t), "Bluetooth\nNo access to the receivers yet. Click to allow it.")
assert.strictEqual(M.tooltipText({ phase: "none" }, (k, a) => I.tr("de", k, a)), "Bluetooth\nKein Empfänger und kein Gerät mit Akku gefunden.")

console.log("bt_monitor_test: ok")
