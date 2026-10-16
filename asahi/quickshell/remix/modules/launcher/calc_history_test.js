#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const H = require("./calc_history.js");

if (typeof H.push !== "function" || typeof H.step !== "function") {
  throw new Error("shipped calc_history.js did not export push/step");
}

let failed = 0;
function assert(cond, msg) {
  if (cond) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg);
  }
}

const h1 = H.push([], "  2+2  ");
assert(h1[0] === "2+2" && h1.length === 1, "push trims and stores newest first");
const h2 = H.push(h1, "2+2");
assert(h2.length === 1 && h2 === h1, "duplicate of newest is a no-op (same array)");
const h3 = H.push(h2, "3*3");
assert(h3[0] === "3*3" && h3[1] === "2+2" && h3.length === 2, "newer expr is unshifted");
const h4 = H.push(h3, "2+2");
assert(h4[0] === "2+2" && h4[1] === "3*3" && h4.length === 2, "re-used expr moves to front");
assert(H.push(h4, "").length === 2, "empty expr is ignored");

const s0 = H.step(h4, "1+1", -1, 1);
assert(s0.index === 0 && s0.text === "2+2", "Up from draft loads newest history");
const s1 = H.step(h4, "1+1", 0, 1);
assert(s1.index === 1 && s1.text === "3*3", "second Up loads older history");
const s2 = H.step(h4, "1+1", 1, 1);
assert(s2.index === 1 && s2.text === "3*3", "Up at oldest stays");
const s3 = H.step(h4, "1+1", 1, -1);
assert(s3.index === 0 && s3.text === "2+2", "Down from older goes toward newer");
const s4 = H.step(h4, "1+1", 0, -1);
assert(s4.index === -1 && s4.text === "1+1", "Down from newest restores draft");
const s5 = H.step([], "9", -1, 1);
assert(s5.index === -1 && s5.text === "9", "empty history stays on draft");

const qml = fs.readFileSync(path.join(__dirname, "LauncherWindow.qml"), "utf8");
assert(qml.indexOf('import "calc_history.js" as CalcHist') !== -1, "LauncherWindow imports CalcHist");
assert(/function walkCalcHistory\(/.test(qml), "LauncherWindow walks calc history from keys");
assert(
  /Key_Up[\s\S]{0,220}walkCalcHistory\(1\)/.test(qml) && /Key_Down[\s\S]{0,220}walkCalcHistory\(-1\)/.test(qml),
  "calc mode Up/Down call walkCalcHistory before result-list nav"
);
assert(/special === "calc" \|\|[\s\S]{0,280}pushCalcHistory\(/.test(qml), "Enter on a calc result stores the expression");

// calculate: own parser, no eval.
const cases = [
  ["2^10 + sqrt(16)", "1028"], ["(1+2)*pi", "9.42477796077"], ["0.1+0.2", "0.3"], ["1e3/4", "250"],
  ["-2^2", "-4"], ["2^3^2", "512"], ["2^-1", "0.5"], ["2**3", "8"], ["3!^2", "36"], ["-3!", "-6"],
  ["17%5", "2"], ["17 mod 5", "2"], ["6×7÷2", "21"], ["5−8", "-3"],
  ["2pi", "6.28318530718"], ["3(4+1)", "15"], ["2sin(pi/2)", "2"], ["2e", "5.43656365692"],
  ["sin(30°)", "0.5"], ["cos(pi)", "-1"], ["tan(45°)", "1"], ["deg(asin(1))", "90"], ["rad(180)", "3.14159265359"],
  ["atan2(1, 1)", "0.785398163397"], ["sinh(0)+cosh(0)", "1"], ["atanh(0.5)", "0.549306144334"],
  ["ln(e)", "1"], ["log(1000)", "3"], ["log(8, 2)", "3"], ["log2(1024)", "10"], ["exp(1)", "2.71828182846"],
  ["cbrt(-27)", "-3"], ["root(-32, 5)", "-2"], ["root(16, 4)", "2"], ["root(16)", "4"], ["log(100)", "2"], ["round(2.4)", "2"], ["abs(-3.5)", "3.5"], ["sign(-2)", "-1"],
  ["floor(-1.5)", "-2"], ["ceil(1.2)", "2"], ["trunc(-1.7)", "-1"], ["round(2.5)", "3"], ["round(-2.5)", "-3"],
  ["round(pi, 3)", "3.142"],
  ["nCr(5, 2)", "10"], ["binom(49, 6)", "13983816"], ["choose(52, 5)", "2598960"], ["nCr(5, 7)", "0"],
  ["nPr(5, 2)", "20"], ["fact(5)", "120"], ["10!", "3628800"], ["18!", "6402373705728000"], ["20!", "2.43290200818e+18"],
  ["0xff + 0b101 + 0o17", "275"], ["tau/2", "3.14159265359"], ["phi^2 - phi", "1"],
  ["1e21*10", "1e+22"], ["5", "5"],
];
for (const [e, want] of cases) {
  const got = H.calculate(e);
  assert(got === want, e + " = " + want + (got === want ? "" : " (got " + got + ")"));
}
for (const e of ["7/0", "sqrt(-1)", "ln(0)", "asin(2)", "1.5!", "nCr(2.5, 1)", "1,5", "sin(1, 2)", "log()", "sin 1",
  "(1+2", "1+", "foo(1)", "root.closeLauncher()", "Qt.quit()", "x = 1", "this", "constructor(1)", "ans", "*2",
  "π", "φ", "min(1, 2)", "max(1, 2)", "hypot(3, 4)", "gcd(4, 6)", "lcm(4, 6)", "round(1, 2, 3)"]) {
  assert(H.calculate(e) === null, JSON.stringify(e) + " is no result");
}
assert(H.calculate("ans*2", "21") === "42" && H.calculate("*2", "21") === "42" && H.calculate("^2", 3) === "9", "ans and leading operator");
assert(H.calculate("-1", "21") === "-1", "leading minus is a negative number, not ans");
assert(H.calculate(H.calculate("1e21*10")) === "1e+22", "exponent result parses back");
assert(H.altFormats("200+55", "255") === "", "no base hint for decimal input");
assert(H.altFormats("0xf0+15", "255") === "0xff" && H.altFormats("0b1010*-1", "-10") === "-0b1010", "hint only in the bases used");
assert(H.altFormats("0xa + 0b1 + 0o1", "12") === "0xc · 0b1100 · 0o14" && H.altFormats("0x1/2", "0.5") === "", "all used bases, integers only");

// rows: result, then history (newest first, tinted while ↑↓ has it loaded); the legend is a footer, not rows
assert(H.rows("", null, [], {}, -1).length === 0, "bare = with no history has no rows");
const legendText = H.LEGEND.map(l => l[0] + " " + l[1].join(" ")).join(" ");
assert(["sin", "atan2", "sinh", "ln", "log(x, b=10)", "exp", "sqrt", "root(x, n=2)", "round(x, n=0)", "nCr(n, k)", "nPr(n, k)",
  "n!", "30°", "pi", "phi", "ans", "0x"].every(w => legendText.indexOf(w) !== -1), "legend names the functions and defaults");
const r1 = H.rows("0xff+1", null, ["2+2", "3*3"], { "2+2": "4", "3*3": "9" }, 1);
assert(r1.length === 3 && r1[0].special === "calc" && r1[0].result === "256" && r1[0].comment === "0x100 · Enter to copy", "result row first, hex hint");
assert(r1[1].special === "calc-hist" && r1[1].name === "2+2" && r1[1].accessory === "= 4" && r1[1].result === "4" && r1[1].tint === "", "history row: expr, = result");
assert(r1[2].expr === "3*3" && r1[2].tint === "mauve", "history row loaded by arrows is tinted");
assert(H.rows("1+", null, ["2+2"], {}, -1)[0].special === "calc-hist", "invalid expression: no result row, history stays");
let hh = [];
for (let i = 0; i < 30; i++) hh = H.push(hh, String(i));
assert(H.MAX === 20 && hh.length === 20 && hh[0] === "29" && hh[19] === "10", "history keeps the last 20 entries");
assert(H.rows("", null, hh, {}, -1).length === 20, "every kept entry is a row (the list scrolls)");

// saved state: round trip, results pruned to the kept history, junk tolerated
const saved = H.saveState(["2+2", "3*3"], { "2+2": "4", "3*3": "9", "old": "1" }, "9");
const st = H.loadState(saved);
assert(st.history.join() === "2+2,3*3" && st.results["3*3"] === "9" && !("old" in st.results) && st.ans === "9", "state round trip, stale results dropped");
const bad = H.loadState("{not json");
assert(bad.history.length === 0 && bad.ans === "" && Object.keys(bad.results).length === 0, "corrupt file loads empty");
const odd = H.loadState(JSON.stringify({ history: ["1+1", 5, "", null, ...Array.from({ length: 30 }, (_, i) => "x" + i)], results: { "1+1": 2 }, ans: 7 }));
assert(odd.history.length === 20 && odd.history[0] === "1+1" && !("1+1" in odd.results) && odd.ans === "", "non-strings dropped, capped at 20");
assert(/calcStateFile\.setText\(CalcHist\.saveState\(/.test(qml) && /CalcHist\.loadState\(calcStateFile\.text\(\)\)/.test(qml), "launcher saves and loads the calc state");
assert(/"calc-hist-" \+ root\.calcHistIndex[\s\S]{0,200}positionViewAtIndex/.test(qml), "walking keeps the loaded history row in view");
assert(new Set(H.rows("1+1", null, ["1+1", "2"], {}, -1).map(r => r.id)).size === 3, "row ids are unique");
assert(/model: CalcHist\.LEGEND/.test(qml) && /anchors\.bottom: root\.calcMode \? calcLegend\.top/.test(qml), "legend is a footer under the list");
assert(/root\.calcMode\) return "↑↓ history/.test(qml), "calc header hint names the history keys");
assert(/root\.resultCount \+ \(root\.calcMode \? 3 : 0\)/.test(qml), "launcher budgets rows for the legend card");
assert(/"Type an expression"/.test(qml) && /clip: root\.calcMode/.test(qml), "calc empty state; list clipped above the card");

assert(/CalcHist\.rows\(q\.substring\(1\), root\.calcAns, root\.calcHistory, root\.calcResults, root\.calcHistIndex\)/.test(qml)
  && /root\.calcAns = res/.test(qml), "launcher builds calc rows and feeds ans");
assert(/special === "calc-hist" && \(!entry\.result \|\| \(root\.query[\s\S]{0,240}setSearchQuery\("=" \+ entry\.expr\)/.test(qml), "a history row not yet loaded loads into the input");
assert(/special === "calc" \|\| entry\.special === "calc-hist"\)[\s\S]{0,200}pushCalcHistory/.test(qml), "the loaded history row copies like a result");
assert(/resultsList\.currentIndex = Math\.max\(0, at\)/.test(qml), "walking selects the loaded history row");

if (failed > 0) {
  console.log("\n" + failed + " assertion(s) failed");
  process.exit(1);
}
console.log("\nall assertions passed");
