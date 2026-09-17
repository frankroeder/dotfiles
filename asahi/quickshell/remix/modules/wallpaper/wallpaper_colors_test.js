#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const C = require("./wallpaper_colors.js");
const T = require("./wallpaper_thumbs.js");

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

console.log("== oklch (same math as theme/oklab.py) ==");
const pure = { "#ff0000": 29, "#ffff00": 110, "#00ff00": 142, "#00ffff": 195, "#0000ff": 264, "#ff00ff": 328 };
for (const hex of Object.keys(pure)) {
  const c = C.oklch(hex);
  assert(Math.abs(c.H - pure[hex]) < 3, hex + " hue " + c.H.toFixed(0) + " ≈ " + pure[hex]);
}
assert(C.oklch("#000000").L < 0.01, "black has ~0 lightness");
assert(C.oklch("#ffffff").L > 0.99, "white has ~1 lightness");
assert(C.oklch("#808080").C < C.MONO_CHROMA, "mid grey is below the mono chroma cut");
assert(C.oklch("nonsense") === null && C.oklch("") === null, "malformed hex returns null");

// The JS mirrors theme/oklab.py by hand (QML cannot call it), so check the two
// actually agree instead of trusting the comment that says they do.
console.log("\n== oklch agrees with theme/oklab.py ==");
const samples = ["#12162c", "#d25a3c", "#5aa0c8", "#e6e2d6", "#808080", "#7a4f10"];
const PY = [
  "import sys, json",
  "sys.path.insert(0, '.')",
  "from theme.oklab import from_srgb8",
  "out = []",
  "for h in sys.argv[1:]:",
  "    c = from_srgb8(int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)).to_oklch()",
  "    out.append([c.L, c.C, c.H])",
  "print(json.dumps(out))",
].join("\n");
const py = JSON.parse(require("child_process").execFileSync(
  "uv", ["run", "python", "-c", PY].concat(samples),
  { cwd: path.join(__dirname, "../../../../"), encoding: "utf8" }
));
for (let i = 0; i < samples.length; i++) {
  const a = C.oklch(samples[i]);
  const [L, Ch, H] = py[i];
  const near = Math.abs(a.L - L) < 1e-6 && Math.abs(a.C - Ch) < 1e-6
    && (Ch < 1e-6 || Math.abs(a.H - H) < 1e-4);
  assert(near, samples[i] + " L/C/H matches python (" + a.L.toFixed(4) + " vs " + L.toFixed(4) + ")");
}

console.log("\n== bucketOf ==");
assert(C.bucketOf(0.0, 260) === "mono", "no chroma is mono whatever the hue");
assert(C.bucketOf(0.01, 29) === "mono", "near-grey is mono");
for (const hex of Object.keys(pure)) {
  const c = C.oklch(hex);
  console.log("  " + hex + " -> " + C.bucketOf(c.C, c.H));
}
assert(C.bucketOf(C.oklch("#ff0000").C, C.oklch("#ff0000").H) === "red", "pure red buckets red");
assert(C.bucketOf(C.oklch("#00ff00").C, C.oklch("#00ff00").H) === "green", "pure green buckets green");
assert(C.bucketOf(C.oklch("#0000ff").C, C.oklch("#0000ff").H) === "blue", "pure blue buckets blue");
assert(C.bucketOf(C.oklch("#ff00ff").C, C.oklch("#ff00ff").H) === "pink", "magenta buckets pink, not purple");
assert(C.bucketOf(0.2, 359.9) === "pink" && C.bucketOf(0.2, 0) === "red", "hue wraps without falling through");
assert(C.bucketOf(0.2, 720) === "red", "out-of-range hue is normalised");
const keys = C.BUCKETS.map(b => b.key);
assert(new Set(keys).size === keys.length, "bucket keys are unique");

console.log("\n== entryFor ==");
const dark = C.entryFor("/d.jpg", ["#101018", "#1a1a28", "#2a3050"]);
assert(dark.tone === "dark", "dark swatches -> dark tone");
assert(dark.swatches.length === 3, "swatches kept in order");
const light = C.entryFor("/l.jpg", ["#f4f2ee", "#e8e6e0", "#dcd8d0"]);
assert(light.tone === "light", "pale swatches -> light tone");
assert(light.L >= C.LIGHT_MODE_THRESHOLD, "light entry sits above the autotheme threshold");
const mixed = C.entryFor("/m.jpg", ["#1a1a1a", "#d23c3c"]);
assert(mixed.bucket === "red", "a chromatic minority still names the bucket");
assert(mixed.accent === "#d23c3c", "accent is the chromatic swatch, not the dominant grey");
assert(C.entryFor("/e.jpg", []).swatches.length === 0, "no swatches is not a crash");
assert(C.entryFor("/e.jpg", ["zzz", "#GGHHII"]).swatches.length === 0, "junk hexes are dropped");
assert(C.entryFor("/u.jpg", ["#D23C3C"]).swatches[0] === "#d23c3c", "hexes are lowercased");

console.log("\n== parseIndex ==");
const idx = C.parseIndex([
  "/a.jpg\t#101018,#1a1a28,#2a3050",
  "/b.jpg\t#f4f2ee,#e8e6e0",
  "/c.jpg\t#d23c3c,#801010",
  "malformed line with no tab",
  ""
].join("\n"));
assert(Object.keys(idx).length === 3, "three rows parsed, junk skipped");
assert(idx["/a.jpg"].tone === "dark" && idx["/b.jpg"].tone === "light", "tones parsed per row");
assert(C.parseIndex("").constructor === Object, "empty index is an empty object");
assert(C.parseIndex("/x y.jpg\t#d23c3c")["/x y.jpg"] !== undefined, "paths with spaces survive");

console.log("\n== arrange ==");
const paths = ["/a.jpg", "/b.jpg", "/c.jpg", "/unindexed.jpg"];
assert(C.arrange(paths, idx, {}).length === 4, "no filters keeps everything, unindexed included");
assert(C.arrange(paths, idx, { tone: "light" }).join() === "/b.jpg", "tone filter");
assert(C.arrange(paths, idx, { bucket: "red" }).join() === "/c.jpg", "bucket filter");
assert(C.arrange(paths, idx, { query: "UNIND" }).join() === "/unindexed.jpg", "query is case-insensitive on the basename");
assert(C.arrange(paths, idx, { tone: "dark", bucket: "red" }).join() === "/c.jpg", "filters compose");
assert(C.arrange(paths, idx, { bucket: "green" }).length === 0, "an empty bucket yields nothing");
assert(C.arrange(paths, idx, {}).join() === paths.join(), "default sort keeps the incoming (name) order");
const byTone = C.arrange(paths, idx, { sort: "tone" });
assert(byTone[0] === "/a.jpg" && byTone[byTone.length - 1] === "/unindexed.jpg",
  "tone sort runs dark -> light, unindexed last");
const byColor = C.arrange(paths, idx, { sort: "color" });
assert(byColor[0] === "/c.jpg", "color sort leads with the chromatic entry");
assert(byColor.indexOf("/a.jpg") > byColor.indexOf("/c.jpg"), "mono buckets sort after colored ones");
assert(C.arrange(null, null, {}).length === 0, "null inputs are safe");

console.log("\n== counts ==");
const n = C.counts(paths, idx, {});
assert(n.tones.dark === 2 && n.tones.light === 1, "tone counts skip unindexed rows");
assert(n.buckets.red === 1, "bucket counts");
assert(C.counts(paths, idx, { tone: "light" }).buckets.red === undefined,
  "bucket counts honour the active tone filter");
assert(C.counts(paths, idx, { bucket: "red" }).tones.dark === 1,
  "tone counts honour the active bucket filter");

console.log("\n== flavours mirror theme/palette.py ==");
const palettePy = fs.readFileSync(
  path.join(__dirname, "../../../../theme/palette.py"), "utf8");
const block = palettePy.slice(palettePy.indexOf("FLAVORS: dict[str, Flavor] = {"));
const pyKeys = (block.slice(0, block.indexOf("\n}")).match(/^\s{4}"([a-z]+)":/gm) || [])
  .map(s => s.replace(/[^a-z]/g, ""));
const jsKeys = C.FLAVORS.map(f => f.key);
console.log("  python: " + pyKeys.join(", "));
console.log("  qml:    " + jsKeys.join(", "));
assert(pyKeys.length === 5, "palette.py exposes five flavours — fewer, further apart");
assert(pyKeys.slice().sort().join() === jsKeys.slice().sort().join(),
  "every --variant the picker offers exists in palette.py and vice versa");
assert(jsKeys.every(k => C.flavorHint(k) !== ""), "every flavour has a hint");
assert(C.flavorHint("nope") === "", "unknown flavour has no hint");

console.log("\n== autotheme accepts every flavour ==");
const autotheme = fs.readFileSync(path.join(__dirname, "../../../../bin/asahi-autotheme"), "utf8");
assert(/choices=tuple\(FLAVORS\)/.test(autotheme), "--variant choices come from palette.FLAVORS, so they cannot drift");
assert(/--mode/.test(autotheme) && /"auto", "dark", "light"/.test(autotheme), "--mode can force dark/light");

console.log("\n== color index script (wallpaper_thumbs.js) ==");
const dir = "/cache/thumbs";
const script = T.colorIndexScript(["/w/a.png", "/w/b b.png"], dir);
assert(T.colorIndexPath(dir) === "/cache/thumbs/colors.tsv", "index lives beside the thumbs");
assert(T.colorIndexPath("/cache/thumbs/") === "/cache/thumbs/colors.tsv", "trailing slash tolerated");
assert(/-newer "\$IDX"/.test(script), "a warm cache is one find, not a rebuild");
assert(script.indexOf("'/w/b b.png'") !== -1, "paths with spaces are quoted");
assert(script.indexOf(T.thumbPath("/w/a.png", dir)) !== -1, "samples the thumb, not the original");
assert(/mv "\$IDX.tmp" "\$IDX"/.test(script), "index is swapped in atomically");
assert(script.trim().endsWith("echo COLORS_DONE"), "completion marker is last");
assert((script.match(/^wait$/gm) || []).length >= 1, "jobs are batched with wait");
assert(/IM=\/usr\/bin\/magick/.test(script), "prefers magick, falls back to convert");
assert(T.colorIndexScript([], dir).indexOf("COLORS_DONE") !== -1, "empty list still terminates");

console.log("\n== service + picker wiring ==");
const svc = fs.readFileSync(path.join(__dirname, "WallpaperService.qml"), "utf8");
assert(/property bool liveMode: false/.test(svc), "live preview is off until armed");
assert(/if \(!root\.liveMode \|\| path === root\.previewPath\) return/.test(svc),
  "preview() is a no-op while disarmed");
assert(/root\.browsePath = path/.test(svc), "the centre tile is remembered so arming previews it at once");
assert(/function setLive\(/.test(svc) && /function setFlavor\(/.test(svc), "setLive and setFlavor exist");
assert(/"--variant", root\.flavor/.test(svc), "autotheme is always called with the chosen flavour");
assert((svc.match(/"--variant", root\.flavor/g) || []).length >= 3,
  "apply, preview and restore all carry the flavour");
assert(/previewWaitMs: 70/.test(svc), "armed preview is real-time (key-repeat coalescing only)");

const mgr = fs.readFileSync(path.join(__dirname, "WallpaperManager.qml"), "utf8");
assert(/Qt\.Key_Shift/.test(mgr), "Shift toggles live preview in the picker");
assert(/handleKey\(event, true\)/.test(mgr), "the search field marks itself as typing so Shift stays a modifier");
assert(/WallpaperFilterBar/.test(mgr) && /WallpaperPalette/.test(mgr) && /WallpaperFlavors/.test(mgr),
  "picker shows the filter bar, palette strip and flavour row");
assert(/WallpaperService\.arranged\(root\.searchText\)/.test(mgr), "picker list goes through arrange()");

const launcher = fs.readFileSync(path.join(__dirname, "../launcher/LauncherWindow.qml"), "utf8");
assert(/ipc:\s*"wallpaper"/.test(launcher),
  "Launcher -> Wallpapers opens the same card as Super+Shift+W, not a second picker");

const qmldir = fs.readFileSync(path.join(__dirname, "qmldir"), "utf8");
for (const t of ["WallpaperChip", "WallpaperFilterBar", "WallpaperFlavors", "WallpaperPalette"]) {
  assert(qmldir.indexOf(t + " 1.0 " + t + ".qml") !== -1, "qmldir registers " + t);
}

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
