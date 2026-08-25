#!/usr/bin/env node
"use strict";

// Tests the shared dict.cc core (dictcc-core.mjs, canonical copy in
// vicinae/extensions/dict-cc/src/, symlinked here for the QML import)
// against a trimmed real m.dict.cc page, plus the LauncherWindow.qml wiring.

const fs = require("fs");
const path = require("path");

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

async function main() {
  const core = await import("./dictcc-core.mjs");

  const fixturePath = path.join(__dirname, "fixtures", "dictcc_haus.html");
  const html = fs.readFileSync(fixturePath, "utf8");
  console.log("fixture " + fixturePath + " bytes " + html.length);

  const copyLang = core.copyLangFromUrl("https://m.dict.cc/deutsch-englisch/haus.html", "xx");
  assert(copyLang === "en", "deutsch-englisch final URL yields copyLang en");
  assert(core.copyLangFromUrl("https://m.dict.cc/deen/?s=x", "en") === "en", "unknown URL keeps fallback");

  const items = core.parseHits(html, "haus", copyLang);
  console.log("items " + items.length);
  assert(items.length > 10, "fixture parses into many hits");
  for (const it of items) {
    assert(typeof it.target === "string" && it.target.length > 0, "hit has target: " + it.target);
    assert(it.copy === it.target, "copy equals stripped target");
    assert(!/[\[\](){}<>]/.test(it.target), "target has no bracket residue: " + it.target);
    break; // spot-check the first; per-item spam is not useful
  }
  const withMeta = items.filter((it) => core.metaText(it.meta).length > 0);
  assert(withMeta.length > 0, "some hits carry meta text");
  assert(!core.metaText(withMeta[0].meta).match(/[\[\]]/), "meta text has no raw brackets");

  // Source-side detection: the German column echoes "haus", so sources are German.
  const germanSources = items.filter((it) => it.source.toLowerCase().includes("haus"));
  assert(germanSources.length > items.length / 2, "query term dominates the source column");

  const q = core.parseQuery("en de house cat", { sourceLanguage: "de", targetLanguage: "en" });
  assert(q.sourceLanguage === "en" && q.targetLanguage === "de" && q.term === "house cat", "en de override parses");
  const plain = core.parseQuery("haus", { sourceLanguage: "de", targetLanguage: "en" });
  assert(plain.sourceLanguage === "de" && plain.term === "haus", "plain query keeps defaults");
  assert(core.buildUrl("de", "en", "haus tür") === "https://m.dict.cc/deen/?s=haus%20t%C3%BCr", "url encodes term");

  core.cachePut("de", "en", "Haus", { items, copyLang, url: "" });
  assert(core.cacheGet("de", "en", "haus") !== undefined, "cache is case-insensitive on term");

  const qmlPath = path.join(__dirname, "LauncherWindow.qml");
  const qml = fs.readFileSync(qmlPath, "utf8");
  assert(qml.includes('import "dictcc-core.mjs" as DictCC'), "LauncherWindow.qml imports shared core");
  assert(qml.includes("DictCC.parseHits"), "LauncherWindow.qml parses via shared core");
  assert(!qml.includes("asahi-dictcc"), "LauncherWindow.qml no longer spawns the python helper");

  if (failed > 0) {
    console.log("\n" + failed + " assertion(s) failed");
    process.exit(1);
  }
  console.log("\nall assertions passed");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
