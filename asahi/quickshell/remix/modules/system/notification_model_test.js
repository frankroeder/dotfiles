#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "NotificationModel.js"), "utf8");
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

// Decks: newest first, grouped by sender in the order of their newest card.
const t = (key, group) => ({ key, group });
const toasts = [t("a3", "chat"), t("b1", "mail"), t("a2", "chat"), t("a1", "chat"), t("a0", "chat")];
eq(ctx.decks(toasts).map(d => d.key + ":" + d.cards.map(c => c.key).join(",")), ["chat:a3,a2,a1,a0", "mail:b1"],
  "decks keep newest-card order");
eq(ctx.decks([t("1", "constructor"), t("2", "toString")]).map(d => d.key), ["constructor", "toString"], "prototype names are senders");

const heights = { a3: 80, a2: 120, a1: 60, a0: 60, b1: 70 };
let lay = ctx.layout(toasts, heights, "");
eq([lay.places.a3.y, lay.places.a2.y, lay.places.a1.y, lay.places.a0.y], [0, 10, 20, 20],
  "collapsed deck peeks 10 px, depth 3+ stays at the last sliver");
eq([lay.places.a2.height, lay.places.a1.height], [80, 80], "back cards take the front card's height");
eq([lay.places.a3.opacity, lay.places.a2.opacity, lay.places.a1.opacity, lay.places.a0.opacity], [1, 0.85, 0.55, 0], "back cards fade");
eq(lay.places.a2.scale, 0.965, "back cards shrink");
eq(lay.places.b1.y, 80 + 20 + 12, "next deck below the slivers + deck gap");
eq(lay.height, 112 + 70, "layout height");
eq(lay.decks.map(d => [d.key, d.top, d.bottom]), [["chat", 0, 100], ["mail", 112, 182]], "deck spans");

lay = ctx.layout(toasts, heights, "chat");
eq([lay.places.a3.y, lay.places.a2.y, lay.places.a1.y, lay.places.a0.y], [0, 88, 216, 284], "open deck spreads with card gap");
eq([lay.places.a2.height, lay.places.a2.scale, lay.places.a0.opacity], [120, 1, 1], "open deck: own heights, full scale");
eq(lay.places.b1.y, 344 + 12, "deck below an open deck");
eq(ctx.layout([t("x", "x")], {}, "").places.x.height, 76, "unknown height falls back");

eq([ctx.deckAt(lay, 5), ctx.deckAt(lay, 349), ctx.deckAt(lay, 351), ctx.deckAt(lay, 500)], ["chat", "chat", "mail", ""],
  "deckAt splits the gap");

const many = [t("1", "a"), t("2", "b"), t("3", "c"), t("4", "a"), t("5", "d"), t("6", "e"), t("7", "a")];
eq(ctx.overflowKeys(many, 4, 2), ["7", "6"], "overflow: 5th sender and 3rd card of a deck");

const msg = (body) => ({ group: "a", appName: "A", summary: "s", body });
eq(ctx.sameContent(msg("b"), msg("b")), true, "same content");
eq(ctx.sameContent(msg("b"), msg("c")), false, "different body");

// Markup: only b/i/u/s, br and safe anchors survive; unknown tags are text.
eq(ctx.richBody("Jane <jane@example.org>"), "Jane &lt;jane@example.org&gt;", "address stays text");
eq(ctx.richBody("Vec<String> & co"), "Vec&lt;String&gt; &amp; co", "generic stays text");
eq(ctx.richBody("<b>bold</b> <em>it</em><br>next"), "<b>bold</b> <i>it</i><br/>next", "simple tags kept, em -> i");
eq(ctx.richBody("a <img src=\"/etc/x\"> b <span style=\"x\">c</span>"), "a  b c", "img / span dropped");
eq(ctx.richBody("<a href=\"https://example.org/x?a=1&amp;b=2\">site</a>"), "<a href=\"https://example.org/x?a=1&b=2\">site</a>",
  "safe anchor kept, href raw (StyledText keeps &amp; in it)");
eq(ctx.richBody("<a href=\"javascript:alert(1)\">x</a> y"), "x y", "unsafe anchor drops to its label");
eq(ctx.richBody("see https://kernel.org/doc. ok\nline 2"),
  "see <a href=\"https://kernel.org/doc\">https://kernel.org/doc</a>. ok<br/>line 2", "bare URL linkified, punctuation outside");
eq(ctx.richBody("<a href=\"https://a.org/\">a</a> https://b.org"), "<a href=\"https://a.org/\">a</a> https://b.org",
  "no linkify when the sender sent an anchor");
eq(ctx.richBody("fix &lt;b&gt; handling"), "fix &lt;b&gt; handling", "escaped tag stays text");
eq(ctx.richBody("&amp;lt;b&amp;gt;x"), "&lt;b&gt;x", "double-escaped tag stays text");
eq(ctx.richBody("call <constructor> &constructor; now"), "call &lt;constructor&gt; &amp;constructor; now", "prototype names are text");
eq(ctx.richBody("<a href=\"https://a.org/\">open"), "<a href=\"https://a.org/\">open</a>", "unclosed anchor closed");
eq(ctx.plainBody("<b>Hi</b> <a href=\"https://a.org\">there</a><br/>Jane <jane@x.org> &amp; co"), "Hi there\nJane <jane@x.org> & co",
  "plain body");
eq(ctx.richBody("Sabine <s.mueller@tuhh.de> wrote"), "Sabine &lt;s.mueller@tuhh.de&gt; wrote", "address after an initial stays text");
eq(ctx.plainBody("<b.jones@x.org> <a-team@x.org> rest"), "<b.jones@x.org> <a-team@x.org> rest", "addresses stay in the plain body");
eq(ctx.richBody("<s>old</s> <u>new</u> <strong>S</strong> <IMG SRC=\"x\"><A HREF=\"https://a.org/\">A</A>"),
  "<s>old</s> <u>new</u> <b>S</b> <a href=\"https://a.org/\">A</a>", "s / u / strong kept, uppercase tags read");
eq(ctx.richBody("&#60;img src=x&#62; <__proto__>"), "&lt;img src=x&gt; &lt;__proto__&gt;", "encoded tag and __proto__ stay text");
eq(ctx.textRich("Reply <b>STOP</b> & <a href=\"https://e.org/\">bank</a>\nok"),
  "Reply &lt;b&gt;STOP&lt;/b&gt; &amp; &lt;a href=&quot;https://e.org/&quot;&gt;bank&lt;/a&gt;<br/>ok", "a plain body is never parsed again");
const t0 = Date.now();
ctx.richBody("see http://x.org/" + ".".repeat(40000) + "a");
eq(Date.now() - t0 < 200, true, "a long punctuation run after a URL stays linear");

// URLs
eq(ctx.safeHttpUrl("https://Example.org"), "https://example.org/", "host lowercased, path added");
eq(ctx.safeHttpUrl("http://example.org:8080/a#b"), "http://example.org:8080/a#b", "port and fragment kept");
for (const bad of ["javascript:alert(1)", "file:///etc/passwd", "https://user@example.org/", "https://localhost/", "http://127.0.0.1/",
  "http://0x7f.1/", "https://example.org:99999/", "https://exa mple.org/", "https://example.org/%0a", "https://-bad.org/", "data:text/html,x",
  "http://foo.localhost:631/", "http://localhost.localdomain:8080/", "http://localhost4.localdomain4/"]) {
  eq(ctx.safeHttpUrl(bad), "", "refused " + bad);
}
eq(ctx.safeHttpUrl("https://localhostfans.org/"), "https://localhostfans.org/", "a name merely starting with localhost is fine");

// Codes (omarchy Detect.js cases + false hits)
eq(ctx.detectCodes("Your code is 938 271"), ["938271"], "spaced code");
eq(ctx.detectCodes("Verification code: 938-271"), ["938271"], "dashed code");
eq(ctx.detectCodes("Your code is 938\n271"), ["938271"], "code across a line break");
eq(ctx.detectCodes("Use 72-9182 to verify"), ["729182"], "code before the keyword");
eq(ctx.detectCodes("G-123456 is your Google verification code"), ["123456"], "G- prefix");
eq(ctx.detectCodes("Your one-time passcode A9F3K2"), ["A9F3K2"], "alphanumeric code");
eq(ctx.detectCodes("Build 4123 finished"), [], "no keyword, no code");
eq(ctx.detectCodes("Grab the code from 2025"), [], "year is no code");
eq(ctx.detectCodes("please review code abc123"), [], "lowercase word is no code");
eq(ctx.detectCodes("Claude Code finished task 4821"), [], "product name is no keyword");
eq(ctx.detectCodes("Order 123456 shipped. Your PIN for the locker is 4711"), ["123456", "4711"], "every code near a keyword");
eq(ctx.detectCodes("Build 4521 failed\nexit code 2"), [], "exit code is no login code");
eq(ctx.detectCodes("Error 2 (code 1) in 3412 ms"), [], "error code is no login code");
eq(ctx.detectCodes("Pin 2 messages? Room 4410"), [], "pin a count is no login code");
eq(ctx.detectCodes("status code 404 for build 5521"), [], "status code is no login code");
eq(ctx.detectCodes("PR #4821: fix verify step"), [], "#number is no code");
eq(ctx.detectCodes("Your PIN: 1234"), ["1234"], "PIN with a colon");
eq(ctx.detectCodes("code 1234 ".repeat(20000)).length, 1, "a repeated code counts once");
eq(ctx.detectCodes("x".repeat(4100) + " code 482910"), [], "text past 4096 chars is not scanned");
eq(ctx.detectCodes("Your Code: 482910"), ["482910"], "capitalised Code after Your");
eq(ctx.detectCodes("Login Code 482910"), ["482910"], "Login Code");
eq(ctx.detectCodes("VS Code 1.95 released, build 48291"), [], "VS Code stays a product");
eq(ctx.detectCodes("Ihr Code lautet 482910"), ["482910"], "German: Ihr Code lautet");
eq(ctx.detectCodes("Ihr Bestätigungscode: 482910"), ["482910"], "German compound");
eq(ctx.detectCodes("Ihre TAN: 482910"), ["482910"], "TAN");
eq(ctx.detectCodes("Mr Tan sent 3 files, order 48213"), [], "Tan is a name");

// Only unambiguous phrases break Do Not Disturb.
eq(ctx.isLoginCode("Your code is 938 271", ["938271"]), true, "your code is a login code");
eq(ctx.isLoginCode("G-123456 is your Google verification code", ["123456"]), true, "verification is a login code");
eq(ctx.isLoginCode("Please confirm: meeting at 1530 in room 2041", ["1530"]), false, "confirm alone is no login code");
eq(ctx.isLoginCode("Code review requested on PR 4821", ["4821"]), false, "code review is no login code");
eq(ctx.isLoginCode("Your code is", []), false, "no code, no login code");
eq(ctx.isLoginCode("Your code review is ready (PR 4821)", ["4821"]), false, "your code review is no login code");
eq(ctx.isLoginCode("Your code compiled in 4821 ms", ["4821"]), false, "your code compiled is no login code");
eq(ctx.isLoginCode("Your code: 482910", ["482910"]), true, "your code: is a login code");
eq(ctx.isLoginCode("Your login code for GitHub is 482910", ["482910"]), true, "login code is a login code");
eq(ctx.isLoginCode("Ihr Code lautet 482910", ["482910"]), true, "German: Ihr Code lautet");
eq(ctx.isLoginCode("Ihr Bestätigungscode: 482910", ["482910"]), true, "German compound is a login code");
eq(ctx.isLoginCode("Ihr Code wurde geprüft (PR 4821)", ["4821"]), false, "German: a reviewed code is no login code");

// Actions and history
const acts = [{ identifier: "reply", text: "Reply" }, { identifier: "default", text: "" }, { identifier: "settings", text: "Settings" },
  { identifier: "", text: "x" }, { identifier: "read", text: "" }, { identifier: "a", text: "A" }, { identifier: "b", text: "B" }];
eq(ctx.actionList(acts), [{ id: "reply", text: "Reply" }, { id: "read", text: "read" }, { id: "a", text: "A" }, { id: "b", text: "B" }],
  "actions: no default (the card click runs it), no settings, capped");
eq(ctx.actionList([{ identifier: "x", text: "Mark the whole conversation as read now" }])[0].text, "Mark the whole conversa…",
  "long label ellipsized");
eq(ctx.actionList(null), [], "no actions");
eq(ctx.actionList([{ identifier: "x", text: "a".repeat(22) + "😀😀" }])[0].text, "a".repeat(22) + "…", "ellipsize keeps an emoji whole");

const entry = { key: "k", appName: "Bank", group: "bank", summary: "Login 938 271", body: "Your code is 938 271 (expires 10:42)",
  rich: "Your code is 938 271", image: "/tmp/x.png", codes: ["938271"], actions: [{ id: "default" }], count: 1 };
const h = ctx.historyCopy(entry);
eq([h.summary, h.body, h.rich, h.image, h.codes, h.actions, h.group, h.key, h.count],
  ["Login ••••", "Your code is •••• (expires 10:42)", undefined, "", [], undefined, undefined, "k", 1], "codes masked in history");
eq(ctx.maskCodes("PR 4821 at 1530, G-123456, A9F3K2", ["4821", "123456", "A9F3K2"]), "PR •••• at 1530, ••••, ••••",
  "mask only the codes");
eq(ctx.historyCopy({ key: "x", summary: "s", body: "b", codes: [], actions: [] }).body, "b", "plain entry kept");
eq(entry.summary, "Login 938 271", "historyCopy leaves the toast entry alone");
eq(ctx.textRich(ctx.historyCopy({ key: "y", summary: "", body: "Code 482910. Reply <b>STOP</b>", codes: ["482910"] }).body),
  "Code ••••. Reply &lt;b&gt;STOP&lt;/b&gt;", "history card: codes masked, escaped markup stays text");

if (failed > 0) {
  console.log(failed + " failed");
  process.exit(1);
}
