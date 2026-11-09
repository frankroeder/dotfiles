// node: the intro's span slices must match asahi-wallpaper-span's crops (source px, ±1).
const fs = require("fs"), vm = require("vm")
const src = fs.readFileSync(__dirname + "/wallpaper_intro_geom.js", "utf8").replace(".pragma library", "")
const G = {}; vm.runInNewContext(src + "\nthis.videoRect = videoRect", G)
const rects = [{ name: "eDP-1", x: 0, y: 0, w: 1512, h: 982 }, { name: "DP-1", x: -2048, y: -360, w: 2048, h: 1152 }]
// asahi-wallpaper-span crops(frames(rects, 24), 3840, 2160): (w, h, x, y)
const want = { "eDP-1": [1620, 1052, 2220, 747], "DP-1": [2194, 1234, 0, 361] }
let fail = 0
for (const r of rects) {
  const v = G.videoRect(rects, r.name, true, 24)
  const s = Math.max(v.w / 3840, v.h / 2160)                          // cover
  const ox = (v.w - 3840 * s) / 2, oy = (v.h - 2160 * s) / 2           // centred
  const got = [r.w / s, r.h / s, (-v.x - ox) / s, (-v.y - oy) / s].map(Math.round)
  const ok = got.every((g, i) => Math.abs(g - want[r.name][i]) <= 1)
  console.log((ok ? "ok  " : "FAIL ") + r.name + " slice " + got + " vs span " + want[r.name])
  if (!ok) fail++
}
const off = G.videoRect(rects, "DP-1", false, 24)
if (off.x !== 0 || off.w !== 2048) { console.log("FAIL span off"); fail++ } else console.log("ok  span off = own rect")
const gone = G.videoRect(rects, "HDMI-A-1", true, 24)   // output removed before its window
if (gone.w !== 0) { console.log("FAIL unknown output"); fail++ } else console.log("ok  unknown output = empty rect")
process.exit(fail)
