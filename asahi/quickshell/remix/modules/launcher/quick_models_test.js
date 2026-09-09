// node asahi/quickshell/remix/modules/launcher/quick_models_test.js
const assert = require("assert")
const M = require("./quick_models.js")

// --- audio labels/glyphs ---
assert.strictEqual(M.friendlyDeviceLabel("Built-in Audio Speaker Output"), "Speaker")
assert.strictEqual(M.friendlyDeviceLabel("sof-soundwire Headphones"), "Headphones")
assert.strictEqual(M.friendlyDeviceLabel("Internal Microphones"), "Internal Microphone")

const bound = (props, extra) => Object.assign({ ready: true, properties: props || {} }, extra || {})
assert.strictEqual(M.nodeLabel(bound({ "node.nick": "Speakers Output" })), "Speakers")
assert.strictEqual(M.nodeLabel(bound({}, { description: "MacBook Speaker" })), "MacBook Speaker")
assert.strictEqual(M.nodeLabel(null), "Unknown")

assert.strictEqual(M.sinkGlyph(bound({}, { name: "bluez_output.AA_BB.1" })), "󰂯")
assert.strictEqual(M.sinkGlyph(bound({}, { description: "AirPods Pro" })), "󰋋")
assert.strictEqual(M.sinkGlyph(bound({}, { description: "HDMI Output" })), "󰍹")
assert.strictEqual(M.sinkGlyph(bound({}, { description: "Speaker" })), "󰓃")
assert.strictEqual(M.sourceGlyph(bound({}, { description: "USB Webcam Analog" })), "󰄀")

assert.strictEqual(M.rawStreamLabel(bound({ "application.name": "Firefox" }, { name: "x" })), "Firefox")
assert.strictEqual(M.rawStreamLabel(bound({}, { description: "mpv", name: "y" })), "mpv")

assert.strictEqual(M.isPlaybackStream({ isStream: true, isSink: true }), true)
assert.strictEqual(M.isPlaybackStream({ isStream: true, isSink: false, type: "Stream/Input/Audio" }), false)
assert.strictEqual(M.isPlaybackStream({ isStream: false, isSink: true }), false)

const sinkA = { id: 12, name: "alsa_output.speaker" }
const sinkB = { id: 13, name: "bluez_output.AA" }
const sameSinks = [sinkA, sinkB]
assert.strictEqual(M.audioNodeKey(sinkA), "id:12")
assert.ok(M.sameAudioNodes(sameSinks, [sinkB, sinkA]), "membership ignores order")
assert.strictEqual(M.adoptAudioNodes(sameSinks, [sinkA, sinkB]), sameSinks, "identical refs keep the snapshot")
assert.strictEqual(M.adoptAudioNodes(sameSinks, [sinkB, sinkA]), sameSinks, "reorder keeps the snapshot")
const tick = [sinkA, sinkB] // new array, same refs
assert.strictEqual(M.adoptAudioNodes(sameSinks, tick), sameSinks, "volume-tick array does not replace")
const added = M.adoptAudioNodes(sameSinks, [sinkA, sinkB, { id: 14, name: "hdmi" }])
assert.strictEqual(added.length, 3)
assert.notStrictEqual(added, sameSinks)

// --- monitor scale math ---
assert.strictEqual(M.cleanScale(2, 2560, 1600), "2")
assert.strictEqual(M.cleanScale(1.25, 2560, 1600), "1.25")
// 1.6 => 2560/1.6=1600, 1600/1.6=1000: valid
assert.strictEqual(M.cleanScale(1.6, 2560, 1600), "1.6")
// invalid scale snaps to a divisor-friendly neighbour
const snapped = M.cleanScale(1.3, 2560, 1600)
assert.ok(snapped !== "", "1.3 should snap to something valid")
assert.strictEqual(M.cleanScale(0, 2560, 1600), "")
// nearest divisor, not the next higher: 1.88 → 1.875, 1.5 on the notch
// panel → 4/3 ("1.333"), not 2. Labels keep 3 decimals so 1.875 ≠ 1.88.
assert.strictEqual(M.cleanScale(1.88, 3840, 2160), "1.875")
assert.strictEqual(M.cleanScale(1.875, 3840, 2160), "1.875")
assert.strictEqual(M.cleanScale(1.5, 3024, 1964), "1.333")
assert.strictEqual(M.formatScale(1.3333334), "1.333")
assert.strictEqual(M.formatScale(1.875), "1.875")
assert.strictEqual(M.formatScale(2), "2")

const gapHdmi = { name: "HDMI-A-1", width: 3840, height: 2160, scale: 1.875, x: -2560, y: -360 }
const gapEdp = { name: "eDP-1", width: 3024, height: 1964, scale: 1.333334, x: 0, y: 0 }
assert.strictEqual(
  M.abutPosition(gapHdmi, 2048, 1152, [gapHdmi, gapEdp]),
  "-2048x-360",
  "scale change keeps HDMI's right edge on eDP-1"
)
assert.strictEqual(
  M.abutPosition(gapEdp, 2268, 1473, [gapHdmi, gapEdp]),
  "0x0",
  "abut leaves the origin output at 0x0"
)
const dell = { name: "HDMI-A-1", width: 2560, height: 1440, scale: 1.25, x: 0, y: -1252 }
assert.strictEqual(
  M.abutPosition(dell, 2048, 1152, [gapEdp, dell]),
  "0x-1152",
  "Dell above eDP-1 uses its own logical height"
)

assert.deepStrictEqual(
  M.scalePresetsFor({ description: "LG Electronics LG ULTRAFINE 112NTMX6B267", width: 3840, height: 2160 }),
  M.SCALE_PRESETS
)
assert.deepStrictEqual(
  M.scalePresetsFor({ description: "Dell Inc. DELL P2723DE 895ZNR3", width: 2560, height: 1440 }),
  M.SCALE_PRESETS
)
assert.ok(M.SCALE_PRESETS.indexOf("1.33") !== -1)
assert.ok(M.SCALE_PRESETS.indexOf("1.875") !== -1)
assert.strictEqual(M.monitorLayoutKey({ name: "HDMI-A-1", description: "LG Electronics LG ULTRAFINE" }), "lg-ultrafine")
assert.strictEqual(M.monitorLayoutKey({ name: "HDMI-A-1", description: "Dell Inc. DELL P2723DE 895ZNR3" }), "dell-p2723de")

const edpScales = M.availableScales(M.scalePresetsFor({ name: "eDP-1", width: 3024, height: 1964, scale: 1.3333334 }), 3024, 1964)
assert.deepStrictEqual(edpScales, ["1", "1.333", "2", "4"])
assert.strictEqual(M.matchingScaleIndex(edpScales, 1.3333334, 3024, 1964), edpScales.indexOf("1.333"))

const lgScales = M.availableScales(M.scalePresetsFor({ width: 3840, height: 2160, scale: 1.875 }), 3840, 2160)
assert.deepStrictEqual(lgScales, ["1", "1.25", "1.333", "1.5", "1.6", "1.875", "2", "3", "4"])
assert.strictEqual(M.matchingScaleIndex(lgScales, 1.875, 3840, 2160), lgScales.indexOf("1.875"))

const dellScales = M.availableScales(M.scalePresetsFor({ width: 2560, height: 1440, scale: 1.25 }), 2560, 1440)
assert.deepStrictEqual(dellScales, ["1", "1.25", "1.333", "1.6", "2", "4"])
assert.ok(dellScales.indexOf("1.875") === -1, "1.875 is not legal on 1440p")
assert.ok(dellScales.indexOf("1.5") === -1, "1.5 snaps too far on 1440p")

const scales = M.availableScales(["1", "1.25", "1.6", "2", "3", "4"], 2560, 1600)
assert.ok(scales.indexOf("1") !== -1 && scales.indexOf("2") !== -1)
assert.strictEqual(M.matchingScaleIndex(scales, "2", 2560, 1600), scales.indexOf("2"))

// --- modes (resolution / refresh) ---
assert.deepStrictEqual(M.parseModeString("2560x1440@59.95Hz"), { width: 2560, height: 1440, refresh: 59.95 })
assert.strictEqual(M.parseModeString("garbage"), null)

const modes = [
  "3024x1890@120.00Hz", "3024x1890@60.00Hz", "3024x1890@59.94Hz",
  "1920x1080@60.00Hz", "1920x1080@50.00Hz", "1280x720@60.00Hz"
]
const resOpts = M.resolutionOptions(modes)
assert.strictEqual(resOpts.length, 3)
assert.strictEqual(resOpts[0].label, "3024\u00d71890")
assert.strictEqual(resOpts[0].best, 120)          // highest refresh per resolution
assert.deepStrictEqual(resOpts[0].refreshes, [120, 60, 59.94])
assert.strictEqual(resOpts[1].width, 1920)
assert.strictEqual(M.resolutionOptions(modes, 2).length, 2)  // limit respected

assert.deepStrictEqual(M.refreshOptions(modes, 3024, 1890), [120, 60, 59.94])
assert.deepStrictEqual(M.refreshOptions(modes, 1280, 720), [60])
assert.deepStrictEqual(M.refreshOptions(modes, 999, 999), [])

assert.strictEqual(M.formatRefresh(120), "120 Hz")
assert.strictEqual(M.formatRefresh(59.95), "59.95 Hz")
assert.strictEqual(M.formatRefresh(59.951), "59.95 Hz")
assert.strictEqual(M.sameRefresh(59.951, 59.95), true)   // hyprctl precision vs mode string
assert.strictEqual(M.sameRefresh(60, 59.94), false)
assert.strictEqual(M.matchingScaleIndex(scales, "9.99", 2560, 1600), -1)

const remembered = M.rememberEnabledMonitor({}, {
  name: "HDMI-A-1", disabled: false, width: 2560, height: 1440,
  description: "Dell Inc. DELL P2723DE 895ZNR3",
  refreshRate: 59.951, scale: 1.25, x: 0, y: -1252
})
assert.deepStrictEqual(remembered["dell-p2723de"], {
  mode: "2560x1440@59.951", position: "0x-1252", scale: 1.25
})
assert.strictEqual(remembered["HDMI-A-1"], undefined, "HDMI-A-1 is shared; remember by sink id")
const rememberedLg = M.rememberEnabledMonitor(remembered, {
  name: "HDMI-A-1", disabled: false, width: 3840, height: 2160,
  description: "LG Electronics LG ULTRAFINE 112NTMX6B267",
  refreshRate: 60, scale: 1.875, x: -2048, y: -360
})
assert.deepStrictEqual(rememberedLg["dell-p2723de"], remembered["dell-p2723de"], "LG must not clobber Dell")
assert.deepStrictEqual(rememberedLg["lg-ultrafine"], {
  mode: "3840x2160@60.000", position: "-2048x-360", scale: 1.875
})
assert.deepStrictEqual(
  M.rememberEnabledMonitor(remembered, { name: "HDMI-A-1", disabled: true, width: 0, height: 0 }),
  remembered,
  "disabled probe must not wipe last-known geometry"
)
const enable = M.enableMonitorFields({
  name: "HDMI-A-1", disabled: true, width: 0, height: 0, x: 0, y: 0,
  description: "Dell Inc. DELL P2723DE 895ZNR3"
}, rememberedLg)
assert.strictEqual(enable.mode, "2560x1440@59.951")
assert.strictEqual(enable.position, "0x-1252")
assert.strictEqual(enable.scale, 1.25)
const enableLg = M.enableMonitorFields({
  name: "HDMI-A-1", disabled: true, width: 0, height: 0,
  description: "LG Electronics LG ULTRAFINE 112NTMX6B267"
}, rememberedLg)
assert.strictEqual(enableLg.position, "-2048x-360")
assert.strictEqual(enableLg.scale, 1.875)
assert.strictEqual(M.enableMonitorFields({ name: "eDP-1", width: 3024, height: 1890, refreshRate: 120, scale: 1.5, x: 0, y: 0 }, {}).mode, "3024x1890@120.000")
const staleEnable = M.enableMonitorFields({
  name: "HDMI-A-1", disabled: true, width: 3840, height: 2160, refreshRate: 60,
  description: "LG Electronics LG ULTRAFINE 112NTMX6B267",
  availableModes: ["2560x1440@59.95Hz", "1920x1080@60.00Hz"],
  x: -2048, y: -360, scale: 1.875
}, rememberedLg)
assert.strictEqual(staleEnable.mode, "preferred", "missing 4K becomes preferred, not a guessed mode")

assert.strictEqual(M.clampBrightness(150), 100)
assert.strictEqual(M.clampBrightness(-5), 1)
assert.strictEqual(M.clampBrightness("42"), 42)
assert.strictEqual(M.brightnessName(100), "Sun blast")
assert.strictEqual(M.brightnessName(5), "Night owl")

// --- bluetooth pending actions ---
let acts = M.withPendingAction({}, "AA:BB", "connecting")
assert.strictEqual(M.pendingAction(acts, "AA:BB"), "connecting")
assert.strictEqual(M.pendingAction(acts, "CC:DD"), "")

// connecting settles once the device reports connected
let settled = M.settledPendingActions(acts, [{ address: "AA:BB", connected: true, paired: true }])
assert.ok(settled && !settled["AA:BB"])
// not settled while still disconnected
assert.strictEqual(M.settledPendingActions(acts, [{ address: "AA:BB", connected: false, paired: true }]), null)
// forgetting settles when the device vanishes or loses pairing
acts = M.withPendingAction({}, "AA:BB", "forgetting")
settled = M.settledPendingActions(acts, [])
assert.ok(settled && !settled["AA:BB"])
settled = M.settledPendingActions(acts, [{ address: "AA:BB", connected: false, paired: false }])
assert.ok(settled && !settled["AA:BB"])
assert.strictEqual(M.settledPendingActions(acts, [{ address: "AA:BB", paired: true }]), null)

// --- network freq ---
assert.strictEqual(M.formatHeaderFreq("2437"), "2.4 GHz")
assert.strictEqual(M.formatHeaderFreq("5180"), "5 GHz")
assert.strictEqual(M.formatHeaderFreq("6115"), "6 GHz")
assert.strictEqual(M.formatHeaderFreq(""), "")

// --- public IP ---
assert.strictEqual(M.parsePublicIp("1.2.3.4\n"), "1.2.3.4")
assert.strictEqual(M.parsePublicIp("256.0.0.1"), "")
assert.strictEqual(M.parsePublicIp("<html>nope</html>"), "")
assert.strictEqual(M.parsePublicIp("2001:db8::1"), "2001:db8::1")

// --- NetworkManager vpn listing (jkoestinger/omarchy-vpn) ---
assert.deepStrictEqual(M.splitNmcliLine("home\\:vpn:uuid-1"), ["home:vpn", "uuid-1"])
assert.deepStrictEqual(M.parseNmcliConnections([
  "Work VPN:uuid-1:vpn:yes:/etc/NetworkManager/system-connections/work.nmconnection",
  "Home WG:uuid-2:wireguard:no:/etc/NetworkManager/system-connections/home.nmconnection",
  "Wired:uuid-3:ethernet:yes:/etc/NetworkManager/system-connections/wired.nmconnection",
  "wg0-mullvad:uuid-9:wireguard:yes:/run/NetworkManager/system-connections/wg0-mullvad.nmconnection",
  ""
].join("\n")), [
  { name: "Work VPN", uuid: "uuid-1", kind: "vpn", active: true },
  { name: "Home WG", uuid: "uuid-2", kind: "wireguard", active: false }
])
assert.deepStrictEqual(M.parseNmcliConnections("Work VPN:uuid-1:vpn:yes"), [
  { name: "Work VPN", uuid: "uuid-1", kind: "vpn", active: true }
])

const ocDetails = M.parseNmcliVpnDetails([
  "connection.uuid:uuid-oc",
  "vpn.service-type:org.freedesktop.NetworkManager.openconnect",
  "vpn.data:authtype = password, cookie-flags = 2, gateway = any1.rz.tuhh.de, gateway-flags = 2, protocol = anyconnect",
  ""
].join("\n"))
assert.strictEqual(M.isOpenConnectService(ocDetails["uuid-oc"].serviceType), true)
assert.strictEqual(ocDetails["uuid-oc"].gateway, "any1.rz.tuhh.de")
assert.strictEqual(M.vpnDataValue("gateway-flags = 2, gateway = vpn.example.com", "gateway"), "vpn.example.com")
assert.strictEqual(M.isOpenVpnService("org.freedesktop.NetworkManager.openconnect"), false)
assert.strictEqual(M.hasVpnUsername("username = alice"), true)
assert.strictEqual(M.hasVpnUsername("username = "), false)

const merged = M.mergeVpnDetails(
  [{ name: "TUHH-VPN", uuid: "uuid-oc", kind: "vpn", active: false }],
  ocDetails
)
assert.strictEqual(merged[0].kind, "openconnect")
assert.strictEqual(merged[0].gateway, "any1.rz.tuhh.de")

const helper = "/dotfiles/asahi/bin/asahi-openconnect-auth"
const ocTargets = M.nmTargets([
  { name: "TUHH-VPN", uuid: "uuid-oc", kind: "openconnect", active: false, gateway: "any1.rz.tuhh.de" },
  { name: "Home", uuid: "uuid-wg", kind: "wireguard", active: false }
], helper)
assert.deepStrictEqual(ocTargets[0].command, [helper, "uuid-oc"])
assert.strictEqual(ocTargets[0].detail, "OpenConnect profile")
assert.strictEqual(ocTargets[0].glyph, M.GLYPH_SHIELD_LOCK)
assert.strictEqual(ocTargets[1].command, undefined)
assert.deepStrictEqual(ocTargets[1].args, ["connection", "up", "uuid", "uuid-wg"])
assert.strictEqual(M.nmTargets([{ name: "Work", uuid: "uuid-oc", kind: "openconnect", active: false }])[0].command, undefined)

const ovpn = M.nmTargets([
  { name: "Work", uuid: "uuid-1", kind: "vpn", active: false, hasUsername: false }
])
assert.strictEqual(ovpn[0].detail, "No username set")
assert.strictEqual(M.nmSummary([]), "No profiles")
assert.strictEqual(M.nmSummary([{ name: "Work", active: false }]), "Not connected")
assert.strictEqual(M.nmSummary([{ name: "TUHH-VPN", active: true }]), "TUHH-VPN")

const ocLive = M.nmDetails([
  { name: "TUHH-VPN", uuid: "uuid-oc", kind: "openconnect", active: true, gateway: "any1.rz.tuhh.de" }
])
assert.deepStrictEqual(ocLive[1], { label: "Type", value: "OpenConnect" })
assert.deepStrictEqual(ocLive[2], { label: "Gateway", value: "any1.rz.tuhh.de" })

assert.deepStrictEqual(M.filterRunnableProfiles(
  [{ kind: "openconnect" }, { kind: "wireguard" }, { kind: "vpn" }],
  { openconnect: true, wireguard: false, openvpn: false }
), [{ kind: "openconnect" }])

assert.deepStrictEqual(M.parseExternalTunnels(
  "enu1u4:ethernet:connected:Wired\ntun0:tun:connected (externally):tun0\nwld0:wifi:unavailable:\n",
  { "TUHH-VPN": true }
), [{ device: "tun0", type: "tun", connection: "tun0" }])
assert.deepStrictEqual(M.parseExternalTunnels(
  "tun0:tun:connected:TUHH-VPN\n",
  { "TUHH-VPN": true }
), [])

console.log("quick_models_test: all assertions passed")
