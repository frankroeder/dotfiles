// node asahi/quickshell/remix/services/bt_i18n_test.js
const assert = require("assert")
const I = require("./bt_i18n.js")

// Every language carries every English key (upstream's 102 + the pane's own), same placeholders.
const keys = Object.keys(I.TABLES.en)
assert.ok(keys.length >= 120, "key inventory: " + keys.length)
for (const l of I.LANGUAGES) {
  const t = I.TABLES[l.code]
  assert.ok(t, "table " + l.code)
  for (const k of keys) {
    assert.ok(t[k] !== undefined, l.code + " misses " + k)
    const ph = (v) => [...new Set(JSON.stringify(v).match(/\{\d\}/g) || [])].sort().join()
    assert.strictEqual(ph(t[k]), ph(I.TABLES.en[k]), l.code + "." + k + " placeholders")
  }
  assert.deepStrictEqual(Object.keys(t).filter(k => !(k in I.TABLES.en)), [], l.code + " has unknown keys")
}

assert.strictEqual(I.systemLanguage("", "", "de_DE.UTF-8"), "de")
assert.strictEqual(I.systemLanguage("en_US.UTF-8", "", "de_DE.UTF-8"), "en")
assert.strictEqual(I.systemLanguage("C", "pl_PL", ""), "pl")
assert.strictEqual(I.systemLanguage("", "", "ja_JP.UTF-8"), "en")
assert.strictEqual(I.systemLanguage("", "", ""), "en")
assert.strictEqual(I.resolve("auto", "fr"), "fr")
assert.strictEqual(I.resolve("nl", "fr"), "nl")
assert.strictEqual(I.resolve("xx", "fr"), "fr")

assert.strictEqual(I.tr("de", "connectedOf", [2, 5]), "2 von 5 Geräten verbunden")
assert.strictEqual(I.tr("xx", "thisPc"), "This PC")
assert.strictEqual(I.tr("de", "noSuchKey"), "noSuchKey")
assert.strictEqual(I.tr("en", "slotN", []), "slot {0}")
assert.strictEqual(I.trn("en", "receiversN", 1), "1 dongle")
assert.strictEqual(I.trn("en", "receiversN", 3, [3]), "3 dongles")
assert.strictEqual(I.trn("pl", "receiversN", 3, [3]), "3 dongle")
assert.strictEqual(I.trn("pl", "receiversN", 5, [5]), "5 dongli")
assert.strictEqual(I.trn("pl", "receiversN", 12, [12]), "12 dongli")
assert.strictEqual(I.languageName("pt"), "Português")

console.log("bt_i18n_test: ok")
