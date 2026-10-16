// Bluetooth pane strings in English and German (the two languages checked here; upstream has six more). The tables are
// uBruckhaus/omarchy-bluetooth-monitor's I18n.js (MIT) minus keys nothing uses; the keys after `// ---- pane` are this
// pane's own. Language = the pane setting, else LC_ALL / LC_MESSAGES / LANG.
// Conservative ES2018, node-testable via module.exports (bt_i18n_test.js).

var LANGUAGES = [{ code: "en", name: "English" }, { code: "de", name: "Deutsch" }]

var TABLES = {
  en: {
    settings: "Settings", back: "Back", backTip: "Back (Backspace, Esc)", language: "Language", systemLanguage: "System ({0})",
    tipAccess: "No access to the receivers yet. Click to allow it.", tipNone: "No receiver or battery-powered device found.",
    charging: "charging", charged: "charged", notConnected: "not connected", noBattery: "no battery reading", slotN: "slot {0}",
    connectedOf: "{0} of {1} devices connected", receiversN: ["1 dongle", "{0} dongles"], accessNeeded: "Access needed",
    nothingFound: "Nothing found", looking: "Looking for devices …", lowestBattery: "Lowest battery {0}%",
    setupText: "Linux only lets root talk to the receivers. Allowing access installs one udev rule (the same one Solaar uses) that gives the " +
      "logged-in user access to Logitech receivers and devices. You will be asked for your password once.",
    waitingPassword: "Waiting for password …", allowAccess: "Allow access",
    error: "Error: {0}", devices: "Devices",
    dpi: "Pointer speed (DPI)", dpiDefault: "default", wheelMode: "Scroll wheel mode", smartshift: "SmartShift",
    smartshiftTip: "Ratchet that switches to free spin when you flick the wheel", ratchet: "Ratchet", ratchetTip: "Always click by click",
    freespin: "Free spin", freespinTip: "Always spins freely", sensitivity: "Sensitivity",
    sensitivityHint: "Lower values switch to free spin with a gentler flick.", natural: "Natural scrolling",
    naturalHint: "Content follows the wheel, like on a touchpad", hires: "High-resolution scrolling",
    hiresHint: "Smoother, finer steps in apps that support it", fnswap: "Swap Fn keys",
    fnswapOn: "On: top row gives media and special functions, hold Fn for F1–F12",
    fnswapOff: "Off: top row gives F1–F12, hold Fn for media and special functions", refresh: "Refresh", conn_unifying: "Unifying dongle",
    conn_bolt: "Bolt dongle",
    conn_nano: "Nano dongle", conn_lightspeed: "Lightspeed dongle", conn_bluetooth: "Bluetooth", conn_usb: "USB cable",
    conn_wireless: "Wireless", unnamed: "Logitech device", errNotConnected: "That device is not connected right now.",
    errChange: "Could not change the setting ({0}).", lowAt: "Low battery warning", criticalAt: "Critical battery warning",
    atOrBelow: "at {0}% or less", otherDevices: "Other Bluetooth devices",
    otherDevicesHint: "Trackpads, earphones, controllers and more (battery only)", connections: "Connections", thisPc: "This PC",
    btAdapter: "Bluetooth adapter", dongleSub: "{0} of {1} slots", radioHint: "Dotted line: radio link. Solid line: plugged in or built in.",
    deviceOff: "off", btBuiltin: "Built-in Bluetooth", btBuiltinSub: "Inside this PC", btDongle: "Bluetooth dongle", btDongleSub: "USB stick",
    access: "Receiver access", accessGranted: "Granted", accessMissing: "Not granted", bluetooth: "Bluetooth",
    btTurnOn: "Turn Bluetooth on", btSecConnected: "Connected", btSecPaired: "Paired", btSecAvailable: "Available",
    btScanning: "Scanning for devices…",
    btScanningShort: "Scanning", btOffHint: "Turn Bluetooth on to scan", btNoAdapter: "No Bluetooth adapter", btOn: "On", btOffState: "Off",
    btReallyForget: "Really forget?",
    btConnecting: "Connecting…", btDisconnecting: "Disconnecting…", btForgetting: "Forgetting…",
    // ---- pane
    btManager: "Bluetooth manager", btScan: "Scan", btSecWired: "USB & receivers",
    offDetail: "Paired devices reconnect once Bluetooth is back on.", pairHint: "Put the device in pairing mode.",
    scanHint: "Scan to discover devices nearby.", updatedAt: "updated {0}", alerts: "Battery alerts",
    alertsHint: "The bar's Bluetooth icon turns into the device's icon: orange when low, red when critical.",
    nfConnected: "Connected", nfConnectFailed: "Could not connect", nfDisconnected: "Disconnected", nfPaired: "Paired",
    nfPairFailed: "Pairing failed", nfForgotten: "Forgotten", nfForgetFailed: "Could not forget",
    barTooltip: "Tooltip on the bar icon", barTooltipHint: "Hovering the bar's Bluetooth icon lists every device's battery.",
    lvl_full: "Full", lvl_good: "Good", lvl_low: "Low", lvl_critical: "Critical", lvl_empty: "Empty",
    turningOn: "Turning on…", turningOff: "Turning off…"
  },
  de: {
    settings: "Einstellungen", back: "Zurück", backTip: "Zurück (Rücktaste, Esc)", language: "Sprache", systemLanguage: "System ({0})",
    tipAccess: "Noch kein Zugriff auf die Empfänger. Zum Erlauben klicken.", tipNone: "Kein Empfänger und kein Gerät mit Akku gefunden.",
    charging: "lädt", charged: "geladen", notConnected: "nicht verbunden", noBattery: "kein Akkustand", slotN: "Platz {0}",
    connectedOf: "{0} von {1} Geräten verbunden", receiversN: ["1 Dongle", "{0} Dongles"], accessNeeded: "Zugriff nötig",
    nothingFound: "Nichts gefunden", looking: "Suche Geräte …", lowestBattery: "Niedrigster Akku {0}%",
    setupText: "Unter Linux darf nur root mit den Empfängern sprechen. „Zugriff erlauben“ installiert eine udev-Regel (dieselbe wie Solaar), " +
      "die dem angemeldeten Benutzer Zugriff auf Logitech-Empfänger und -Geräte gibt. Das Passwort wird einmal abgefragt.",
    waitingPassword: "Warte auf Passwort …", allowAccess: "Zugriff erlauben",
    error: "Fehler: {0}", devices: "Geräte",
    dpi: "Zeigergeschwindigkeit (DPI)", dpiDefault: "Standard", wheelMode: "Scrollrad-Modus", smartshift: "SmartShift",
    smartshiftTip: "Rastet, wechselt aber in den Freilauf, wenn du das Rad anschnippst", ratchet: "Rastend", ratchetTip: "Immer Klick für Klick",
    freespin: "Freilauf", freespinTip: "Dreht immer frei", sensitivity: "Empfindlichkeit",
    sensitivityHint: "Niedrigere Werte schalten schon bei sanftem Anschnippen in den Freilauf.", natural: "Natürliches Scrollen",
    naturalHint: "Der Inhalt folgt dem Rad, wie auf einem Touchpad", hires: "Hochauflösendes Scrollen",
    hiresHint: "Feinere, weichere Schritte in Apps, die es unterstützen", fnswap: "Fn-Tasten tauschen",
    fnswapOn: "An: obere Reihe gibt Medien- und Sonderfunktionen, Fn halten für F1–F12",
    fnswapOff: "Aus: obere Reihe gibt F1–F12, Fn halten für Medien- und Sonderfunktionen", refresh: "Aktualisieren",
    conn_unifying: "Unifying-Dongle", conn_bolt: "Bolt-Dongle",
    conn_nano: "Nano-Dongle", conn_lightspeed: "Lightspeed-Dongle", conn_bluetooth: "Bluetooth", conn_usb: "USB-Kabel",
    conn_wireless: "Funk", unnamed: "Logitech-Gerät", errNotConnected: "Dieses Gerät ist gerade nicht verbunden.",
    errChange: "Einstellung konnte nicht geändert werden ({0}).", lowAt: "Warnung bei niedrigem Akku", criticalAt: "Warnung bei kritischem Akku",
    atOrBelow: "bei {0}% oder weniger", otherDevices: "Andere Bluetooth-Geräte",
    otherDevicesHint: "Trackpads, Kopfhörer, Controller und mehr (nur Akku)", connections: "Verbindungen", thisPc: "Dieser PC",
    btAdapter: "Bluetooth-Adapter", dongleSub: "{0} von {1} Plätzen",
    radioHint: "Gepunktete Linie: Funkverbindung. Durchgezogen: eingesteckt oder eingebaut.", deviceOff: "aus",
    btBuiltin: "Eingebautes Bluetooth", btBuiltinSub: "Im PC eingebaut", btDongle: "Bluetooth-Dongle", btDongleSub: "USB-Stick",
    access: "Zugriff auf Empfänger", accessGranted: "Erlaubt", accessMissing: "Nicht erlaubt", bluetooth: "Bluetooth",
    btTurnOn: "Bluetooth einschalten",
    btSecConnected: "Verbunden", btSecPaired: "Gekoppelt", btSecAvailable: "Verfügbar",
    btScanning: "Suche nach Geräten …", btScanningShort: "Suche läuft", btOffHint: "Bluetooth einschalten, um zu suchen",
    btNoAdapter: "Kein Bluetooth-Adapter", btOn: "Ein", btOffState: "Aus", btReallyForget: "Wirklich entfernen?",
    btConnecting: "Verbinde …", btDisconnecting: "Trenne …",
    btForgetting: "Entferne …",
    // ---- pane
    btManager: "Bluetooth-Verwaltung", btScan: "Suchen", btSecWired: "USB & Empfänger",
    offDetail: "Gekoppelte Geräte verbinden sich wieder, sobald Bluetooth an ist.",
    pairHint: "Gerät in den Kopplungsmodus versetzen.", scanHint: "Suchen, um Geräte in der Nähe zu finden.", updatedAt: "aktualisiert {0}",
    alerts: "Akku-Warnungen",
    alertsHint: "Das Bluetooth-Symbol in der Leiste wird zum Symbol des Geräts: orange bei niedrigem, rot bei kritischem Akku.",
    nfConnected: "Verbunden", nfConnectFailed: "Verbinden fehlgeschlagen", nfDisconnected: "Getrennt", nfPaired: "Gekoppelt",
    nfPairFailed: "Koppeln fehlgeschlagen", nfForgotten: "Entfernt", nfForgetFailed: "Entfernen fehlgeschlagen",
    barTooltip: "Tooltip am Leistensymbol",
    barTooltipHint: "Beim Überfahren des Bluetooth-Symbols in der Leiste erscheint der Akkustand jedes Geräts.",
    lvl_full: "Voll", lvl_good: "Gut", lvl_low: "Niedrig", lvl_critical: "Kritisch", lvl_empty: "Leer",
    turningOn: "Wird eingeschaltet …", turningOff: "Wird ausgeschaltet …"
  }
}

function supported(code) {
  for (var i = 0; i < LANGUAGES.length; i++) if (LANGUAGES[i].code === code) return true
  return false
}

function languageName(code) {
  for (var i = 0; i < LANGUAGES.length; i++) if (LANGUAGES[i].code === code) return LANGUAGES[i].name
  return code
}

// First of LC_ALL, LC_MESSAGES, LANG that names a language ("de_DE.UTF-8" -> de); C / POSIX / unset skip; else en.
function systemLanguage(lcAll, lcMessages, lang) {
  var vals = [lcAll, lcMessages, lang]
  for (var i = 0; i < vals.length; i++) {
    var code = String(vals[i] || "").toLowerCase().split(/[_.@-]/)[0]
    if (!code || code === "c" || code === "posix") continue
    return supported(code) ? code : "en"
  }
  return "en"
}

function resolve(setting, systemCode) {
  return supported(setting) ? setting : systemCode
}

function format(text, args) {
  return String(text).replace(/\{(\d+)\}/g, function(m, i) { return args && args[i] !== undefined ? String(args[i]) : m })
}

function lookup(lang, key) {
  var table = TABLES[lang] || TABLES.en
  return table[key] !== undefined ? table[key] : (TABLES.en[key] !== undefined ? TABLES.en[key] : key)
}

function tr(lang, key, args) {
  var v = lookup(lang, key)
  return format(Array.isArray(v) ? v[v.length - 1] : v, args)
}

// [singular, plural] by n.
function trn(lang, key, n, args) {
  var v = lookup(lang, key)
  return format(Array.isArray(v) ? v[n === 1 ? 0 : v.length - 1] : v, args)
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { LANGUAGES: LANGUAGES, TABLES: TABLES, supported: supported, languageName: languageName, systemLanguage: systemLanguage,
    resolve: resolve, tr: tr, trn: trn }
}
