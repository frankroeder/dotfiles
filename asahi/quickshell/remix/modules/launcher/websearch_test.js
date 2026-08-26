#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const shipped = require("./websearch.js");
if (typeof shipped.parseConfig !== "function") {
  throw new Error("shipped websearch.js did not export parseConfig");
}

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

const dir = __dirname;
const jsonPath = path.join(dir, "websearch.json");
const assetsDir = path.join(dir, "../../assets");
const qmlPath = path.join(dir, "LauncherWindow.qml");

const raw = fs.readFileSync(jsonPath, "utf8");
assert(raw.indexOf("\t") === -1, "websearch.json has no tab indentation");
const parsed = shipped.parseConfig(raw, "file:///assets/");
assert(!!parsed, "parseConfig returns engines from websearch.json");
const engines = parsed.engines;
console.log("engines " + engines.length);
engines.forEach(function (e) {
  console.log("  " + e.prefix + "  " + e.name + "  icon=" + (e.icon || ""));
});

assert(engines.length >= 15, "at least 15 engines (got " + engines.length + ")");
const prefixes = engines.map(function (e) { return e.prefix; });
assert(prefixes.indexOf("sp") >= 0, "Startpage prefix 'sp' is present");
assert(prefixes.indexOf("kagi") >= 0, "Kagi prefix is present");
assert(prefixes.indexOf("qw") >= 0, "Qwant prefix 'qw' is present");
assert(prefixes.indexOf("ddg") >= 0, "DuckDuckGo prefix 'ddg' is present");
assert(prefixes.indexOf("brave") >= 0, "Brave Search prefix is present");
assert(prefixes.indexOf("hypr") >= 0, "Hyprland wiki prefix is present");
assert(prefixes.indexOf("arch") >= 0, "Arch wiki prefix is present");
assert(new Set(prefixes).size === prefixes.length, "engine prefixes are unique");

function byPrefix(p) {
  return engines.find(function (e) { return e.prefix === p; });
}
const qw = byPrefix("qw");
assert(!!qw && /qwant/i.test(qw.name), "qw maps to Qwant");
assert(!!qw && /qwant\.com\/\?q=%TERM%/.test(qw.url), "Qwant url keeps q=%TERM%&t=web");
const ddg = byPrefix("ddg");
assert(!!ddg && /duckduckgo/i.test(ddg.name), "ddg maps to DuckDuckGo");
assert(!!ddg && /duckduckgo\.com\/\?ia=web/.test(ddg.url) && /q=%TERM%/.test(ddg.url),
  "DuckDuckGo url keeps ia=web and q=%TERM%");
const brave = byPrefix("brave");
assert(!!brave && /brave/i.test(brave.name), "brave maps to Brave Search");
assert(!!brave && /search\.brave\.com\/search\?q=%TERM%/.test(brave.url),
  "Brave url is search.brave.com/search?q=%TERM%");

const sp = engines.find(function (e) { return e.prefix === "sp"; });
assert(!!sp && /startpage/i.test(sp.name), "sp maps to Startpage");
assert(!!sp && /startpage\.png/.test(sp.icon), "Startpage icon resolves to startpage.png");
assert(!!sp && /startpage\.com/.test(sp.url), "Startpage url points at startpage.com");

const json = JSON.parse(raw);
json.engines.forEach(function (e) {
  assert(!!e.icon, e.name + " declares an icon file");
  const iconPath = path.join(assetsDir, e.icon);
  assert(fs.existsSync(iconPath), e.icon + " exists in remix/assets (" + e.name + ")");
  const ident = require("child_process").spawnSync("identify", ["-format", "%wx%h %m", iconPath], { encoding: "utf8" });
  const meta = (ident.stdout || "").trim();
  console.log("  asset " + e.icon + " " + meta);
  assert(/64x64/.test(meta), e.icon + " is 64x64 (got " + meta + ")");
});

const qml = fs.readFileSync(qmlPath, "utf8");
assert(qml.indexOf('import "websearch.js" as WebSearch') !== -1, "LauncherWindow.qml imports websearch.js");
assert(qml.indexOf("WebSearch.parseConfig") !== -1, "parseWebsearchConfig uses shipped WebSearch.parseConfig");
assert(qml.indexOf("websearchConfig.text()") !== -1, "FileView content is read via text() (not the bare text identifier)");
assert(!/onLoaded:\s*root\.parseWebsearchConfig\(text\)/.test(qml), "onLoaded does not pass the FileView text method as JSON");
assert(
  /property var webEngines:\s*\[\]/.test(qml),
  "webEngines is not a stale hardcoded list missing Startpage"
);

const empty = shipped.parseConfig("", "file:///");
assert(empty === null, "empty config returns null (keep previous engines)");
const dropped = shipped.parseConfig(JSON.stringify({ engines: [{ name: "X", url: "http://x" }] }), "");
assert(dropped === null, "engine without prefix is dropped, empty list is null");
const kept = shipped.parseConfig(JSON.stringify({
  engines: [
    { name: "Startpage", prefix: "sp", url: "https://eu.startpage.com/sp/search?q=%TERM%", icon: "startpage.png" },
    { name: "Bad", prefix: "", url: "http://x" }
  ]
}), "file:///a/");
assert(kept && kept.engines.length === 1 && kept.engines[0].prefix === "sp", "valid engines survive a sibling with empty prefix");

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
