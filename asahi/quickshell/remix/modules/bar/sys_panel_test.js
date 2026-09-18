#!/usr/bin/env node
"use strict";
const fs = require("fs");
const path = require("path");
const S = require("./sys_panel.js");

// Captured asahi-cpu / asahi-memory tooltips.
const cpu = S.parseCpuTooltip(
  "CPU 12%\nLoad 1/5/15: 0.10 0.20 0.30\nCores: 10\nFreq avg 1.20 GHz, min 0.60, max 3.20\nThermal 42.1 C (macsmc_hwmon / WiFi/BT Module Temp)\nHeatpipe 4.2 W (SoC dissipation; no die sensor)\nSensor: /sys/class/hwmon/hwmon2/temp4_input"
);
if (cpu.load !== "0.10 0.20 0.30" || cpu.cores !== "10") throw new Error("load/cores " + JSON.stringify(cpu));
if (cpu.temp !== 42.1 || cpu.freq !== "1.20 GHz") throw new Error("temp/freq " + JSON.stringify(cpu));
if (!isNaN(S.parseCpuTooltip("").temp)) throw new Error("missing thermal must be NaN");

const mem = S.parseMemTooltip("RAM 12.2/32.0 GiB (38%)\\nSwap 0.0/8.0 GiB (0%)");
if (mem.ramUsed !== "12.2" || mem.ramTotal !== "32.0" || mem.swapTotal !== "8.0") throw new Error("ram " + JSON.stringify(mem));

const ps = S.parsePs("%CPU COMMAND\n 12.0 firefox\n  8.1 RDD Process\n  0.1 ps\n");
if (ps.length !== 2 || ps[0].comm !== "firefox" || ps[1].comm !== "RDD Process") throw new Error("ps " + JSON.stringify(ps));

const hot = S.hottest([{ value: 40, label: "a" }, { value: 71, label: "b" }, { value: 55, label: "c" }], 2);
if (hot[0].label !== "b" || hot[1].label !== "c") throw new Error("hottest");

const pts = S.sparkPoints([0, 50, 100]);
if (pts.length !== 3 || pts[0].y !== 1 || pts[2].y !== 0 || pts[2].x !== 1) throw new Error("spark " + JSON.stringify(pts));
if (S.heat(41) !== 0 || S.heat(55) !== 1 || S.heat(80) !== 2 || S.heat(NaN) !== 0) throw new Error("heat");
if (S.heatW(4) !== 0 || S.heatW(15) !== 1 || S.heatW(25) !== 2 || S.heatW(NaN) !== 0) throw new Error("heatW");
if (S.fanFraction({ value: 2317, min: 2317, max: 6800 }) !== 0) throw new Error("fan idle");
if (S.pressureClass(50) !== "normal" || S.pressureClass(80) !== "warning" || S.pressureClass(95) !== "critical") throw new Error("pressure");

// Bar wiring: one CPU/RAM chip left of media so RAM stays left of the notch; panel anchors to that chip.
const host = fs.readFileSync(path.join(__dirname, "BarHost.qml"), "utf8");
const sysAt = host.indexOf("id: sysBlock");
if (!(sysAt >= 0 && host.indexOf("BarComponents.MediaPlayer") > sysAt)) throw new Error("MediaPlayer must sit right of the sys chip");
if (/id:\s*(cpuBlock|memBlock)/.test(host)) throw new Error("CPU and RAM are one chip now");
if (!/BarComponents\.SysPanel[\s\S]{0,200}anchor\.item:\s*sysBlock/.test(host)) throw new Error("SysPanel must anchor to sysBlock");
if (host.indexOf("BarComponents.Brightness") !== -1) throw new Error("brightness icon must not be on the bar");
if (!/heatpipeW/.test(host)) throw new Error("BarHost must expose heatpipe watts");
const panel = fs.readFileSync(path.join(__dirname, "components/SysPanel.qml"), "utf8");
if (panel.indexOf("asahi-metrics") !== -1) throw new Error("disk/net rates belong in Storage, not SysPanel");
if (/text:\s*"disks"/.test(panel) || /SectionTitle \{ text: "network"/.test(panel))
  throw new Error("SysPanel is CPU/RAM only");
if (panel.indexOf("HEAT") < 0) throw new Error("SysPanel must show the heatpipe tile");
if (panel.indexOf("per-core") < 0) throw new Error("SysPanel must show per-core bars");
if (/caption:\s*root\.cpu\.load/.test(panel) || /text:\s*parent\.caption/.test(panel))
  throw new Error("load/mem labels must not overlay the sparkline");
if (/SectionTitle \{ text: "power"/.test(panel)) throw new Error("power rails belong in the battery pane");
if (panel.indexOf("temp_display.js") !== -1) throw new Error("SysPanel reads asahi-temperature --json, not the human parser");
if (panel.indexOf('"--json"') < 0) throw new Error("SysPanel must request asahi-temperature --json");
if (panel.indexOf("\uFFFD") !== -1) throw new Error("SysPanel QML must not contain a replacement character");

console.log("ok  sys_panel.js");
