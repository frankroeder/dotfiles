#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "lookup.js"), "utf8").replace(/^\.pragma library\s*$/m, "")
const ctx = {};
vm.createContext(ctx);
vm.runInContext(src, ctx);

let failed = 0;
function eq(got, expected, msg) {
  const g = JSON.stringify(got), e = JSON.stringify(expected);
  if (g === e) console.log("ok  " + msg);
  else {
    failed += 1;
    console.log("FAIL  " + msg + " got=" + g + " expected=" + e);
  }
}

const full = "term: Fernweh\npos: noun\nlang: de\ndefinition: Sehnsucht nach fernen Orten.\n"
  + "translation: wanderlust, longing for distant places\nwiki: Fernweh\n";
let e = ctx.parse(full);
eq([e.term, e.pos, e.lang, e.definition, e.translation, e.wiki],
  ["Fernweh", "noun", "de", "Sehnsucht nach fernen Orten.", "wanderlust, longing for distant places", "Fernweh"], "all six keys");

e = ctx.parse("term: serendipity\npos: noun\nlang: en\ndefinition: Luck in find");
eq([e.definition, e.translation], ["Luck in find", undefined], "streamed: half-written last line shows, later keys absent");

e = ctx.parse("term: Hamburg\nlang: de\ntranslation: none\nwiki: None.");
eq([e.translation, e.wiki], [undefined, undefined], "none / None. dropped");

e = ctx.parse("definition: first line\nwrapped on.\nterm: x\nterm: y");
eq([e.definition, e.term], ["first line wrapped on.", "x"], "wrapped value joined, a repeated key keeps the first");

eq(ctx.parse("lang: German\n").lang, "", "non-code lang dropped");
eq(ctx.parse("").lang, "", "empty output");

let l = ctx.links(ctx.parse(full), "Fernweh");
eq(l.wiki, "https://de.wikipedia.org/wiki/Special:Search?go=Go&search=Fernweh", "German entry → de.wikipedia");
eq(l.dict, "https://de.wiktionary.org/wiki/Special:Search?go=Go&search=Fernweh", "German entry → de.wiktionary");
l = ctx.links(ctx.parse("term: kick the bucket\nlang: en\nwiki: Kick the bucket"), "x");
eq(l.wiki, "https://en.wikipedia.org/wiki/Special:Search?go=Go&search=Kick%20the%20bucket", "wiki title used, encoded");
eq(l.dictcc, "https://www.dict.cc/?s=kick%20the%20bucket", "dict.cc by term");
eq(l.kagi, "https://translate.kagi.com/?from=auto&to=de&quality=standard&text=x", "Kagi: the selection, English → German");
eq(ctx.links(ctx.parse(full), " Fernwehs ").kagi, "https://translate.kagi.com/?from=auto&to=en&quality=standard&text=Fernwehs",
  "Kagi: German → English, selection as written");
eq(ctx.links(ctx.parse("term: Ort"), "").kagi, "https://translate.kagi.com/?from=auto&to=en&quality=standard&text=Ort",
  "Kagi: no selection → the term");
l = ctx.links(ctx.parse("lang: fr"), "  bon\n appétit ");
eq(l.dict, "https://en.wiktionary.org/wiki/Special:Search?go=Go&search=bon%20app%C3%A9tit",
  "other language → en wiki; no term yet → the selection, whitespace folded");
l = ctx.links(ctx.parse("term: a&b/../x?y#z"), "");
eq(l.dictcc, "https://www.dict.cc/?s=a%26b%2F..%2Fx%3Fy%23z", "term cannot break out of the query");

eq(ctx.html({ definition: "<img src=http://x>", translation: "a & b" }, "#112233"),
  '<p>&lt;img src=http://x&gt;</p><p style="margin-top:8px;color:#112233">→ a &amp; b</p>', "html escapes model text");
eq(ctx.html({}, "#000000"), "", "html empty before the definition arrives");
eq(ctx.text({ term: "t", definition: "d" }), "t\nd", "copy text skips missing parts");

if (failed) {
  console.log("lookup_test.js: " + failed + " FAILED");
  process.exit(1);
}
console.log("lookup_test.js: all ok");
