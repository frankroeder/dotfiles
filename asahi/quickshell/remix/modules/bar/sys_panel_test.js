#!/usr/bin/env node
"use strict";
const fs = require("fs");
const path = require("path");
const S = require("./sys_panel.js");

// Captured asahi-cpu / asahi-memory tooltips.
const cpu = S.parseCpuTooltip(
  "CPU 12%\nLoad 1/5/15: 0.10 0.20 0.30\nCores: 10\nFreq avg 1.20 GHz, min 0.60, max 3.20\nThermal 42.1 C (macsmc_hwmon / CPU)\nSensor: /sys/class/hwmon/hwmon2/temp1_input"
);
if (cpu.load !== "0.10 0.20 0.30" || cpu.cores !== "10") throw new Error("load/cores " + JSON.stringify(cpu));
if (cpu.temp !== 42.1 || cpu.freq !== "1.20 GHz") throw new Error("temp/freq " + JSON.stringify(cpu));
if (!isNaN(S.parseCpuTooltip("").temp)) throw new Error("missing thermal must be NaN");

const mem = S.parseMemTooltip("RAM 12.2/32.0 GiB (38%)\\nSwap 0.0/8.0 GiB (0%)");
if (mem.ramUsed !== "12.2" || mem.ramTotal !== "32.0" || mem.swapTotal !== "8.0") throw new Error("ram " + JSON.stringify(mem));

const ps = S.parsePs("%CPU COMMAND\n 12.0 firefox\n  8.1 RDD Process\n  0.1 ps\n");
if (ps.length !== 2 || ps[0].comm !== "firefox" || ps[1].comm !== "RDD Process") throw new Error("ps " + JSON.stringify(ps));

const df = S.parseDfRoot("Filesystem      Size  Used Avail Use% Mounted on\n/dev/nvme0n1p6  225G   94G  130G  42% /\n");
if (df.pct !== 42 || df.size !== "225G" || df.used !== "94G") throw new Error("df " + JSON.stringify(df));
if (S.parseDfRoot("").pct !== -1) throw new Error("df empty");

const hot = S.hottest([{ value: 40, label: "a" }, { value: 71, label: "b" }, { value: 55, label: "c" }], 2);
if (hot[0].label !== "b" || hot[1].label !== "c") throw new Error("hottest");

const pts = S.sparkPoints([0, 50, 100]);
if (pts.length !== 3 || pts[0].y !== 1 || pts[2].y !== 0 || pts[2].x !== 1) throw new Error("spark " + JSON.stringify(pts));
if (S.heat(41) !== 0 || S.heat(55) !== 1 || S.heat(80) !== 2 || S.heat(NaN) !== 0) throw new Error("heat");

// Bar wiring: one CPU/RAM chip left of media so RAM stays left of the notch; panel anchors to that chip.
const host = fs.readFileSync(path.join(__dirname, "BarHost.qml"), "utf8");
const sysAt = host.indexOf("id: sysBlock");
if (!(sysAt >= 0 && host.indexOf("BarComponents.MediaPlayer") > sysAt)) throw new Error("MediaPlayer must sit right of the sys chip");
if (/id:\s*(cpuBlock|memBlock)/.test(host)) throw new Error("CPU and RAM are one chip now");
if (!/BarComponents\.SysPanel[\s\S]{0,200}anchor\.item:\s*sysBlock/.test(host)) throw new Error("SysPanel must anchor to sysBlock");
if (host.indexOf("BarComponents.Brightness") !== -1) throw new Error("brightness icon must not be on the bar");

console.log("ok  sys_panel.js");
