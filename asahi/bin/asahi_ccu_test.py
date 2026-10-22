#!/usr/bin/env python3
"""Drive shipped asahi-ccu format/pace/chart helpers. No network."""

from __future__ import annotations

import os
import sys
import time
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path

os.environ["TZ"] = "UTC"
if hasattr(time, "tzset"):
  time.tzset()

# No __pycache__ next to the scripts. load_module() is deprecated: spec + exec_module.
sys.dont_write_bytecode = True
SRC = Path(__file__).resolve().parent / "asahi-ccu"
loader = SourceFileLoader("asahi_ccu", str(SRC))
ccu = module_from_spec(spec_from_loader("asahi_ccu", loader))
sys.modules["asahi_ccu"] = ccu
loader.exec_module(ccu)

FAILED = 0


def fail(msg: str) -> None:
  global FAILED
  FAILED += 1
  print(f"FAIL  {msg}", file=sys.stderr)


def ok(cond: bool, msg: str) -> None:
  if cond:
    print(f"ok   {msg}")
  else:
    fail(msg)


def eq(got, expected, msg: str) -> None:
  if got == expected:
    print(f"ok   {msg}")
  else:
    fail(f"{msg} got={got!r} expected={expected!r}")


now = 1700000000
week = ccu.WEEK_SEC

claude_reset = now + 15 * 3600 + 59 * 60
claude = ccu.weekly(0.31, claude_reset)
eq(ccu.percent(claude["used"]), "31%", "31% used")
eq(ccu.countdown(claude_reset, now), "15h 59m", "15h 59m countdown")

codex_reset = now + 4 * 86400 + 22 * 3600
codex = ccu.weekly(0.18, codex_reset)
eq(ccu.countdown(codex_reset, now), "4d 22h", "4d 22h countdown")

grok = ccu.weekly(0.22, now + 3 * 86400, week)
cursor = ccu.from_helper_window({
  "utilization": 31,
  "reset_unix": now + 16 * 86400,
  "span_sec": 30 * 86400,
})
eq(ccu.window_name(week), "weekly", "7d window is weekly")
eq(ccu.window_name(30 * 86400), "monthly", "30d window is monthly")
eq(ccu.window_name(ccu.SESSION_SPAN_SEC), "session", "5h window is a session")
eq(ccu.usage_line(grok), "22% of weekly limit used", "grok usage line")
eq(ccu.usage_line(cursor), "31% of monthly limit used", "cursor usage line")

ok(ccu.is_fresh({"utilization": 1}, True), "successful fetch is fresh")
ok(not ccu.is_fresh({"error": "timeout"}, True), "failed fetch is stale")
ok(ccu.is_fresh({"error": "timeout"}, False), "unwanted provider is fresh")
ok(not ccu.is_fresh(None, True), "missing result is stale")
eq(ccu.ago(now, now), "just now", "now is just now")
eq(ccu.ago(now, now, True), "now", "short now")
eq(ccu.ago(now - 120, now), "2m ago", "2m ago")
eq(ccu.ago(now - 120, now, True), "2m", "short 2m")
eq(ccu.ago(now - 3600, now), "1h ago", "1h ago")
eq(ccu.ago(now - 3 * 86400, now), "3d ago", "3d ago")
eq(ccu.ago(now - 10 * 86400, now), "Nov 4", "week+ uses date")
eq(ccu.ago(0, now), "", "missing ts is empty")
eq(ccu.cache_times({"_fetched_at": {"grok": now - 60, "cursor": "x"}}), {"grok": now - 60}, "cache_times keeps unix")
eq(ccu.cache_times({}), {}, "empty cache times")
ok("Resets" in ccu.reset_line(grok, now), "reset line has Resets")
ok("3d 0h" in ccu.reset_line(grok, now), "reset line has countdown")

eq(ccu.renews_line(now, False), "Renews Nov 14, 2023", "renews date")
eq(ccu.renews_line(now, True), "Ends Nov 14, 2023", "cancels at period end")
eq(ccu.renews_line(0, False), "", "missing rebill is empty")
eq(ccu.ident_text("a@x.com", now, False), "a@x.com · Renews Nov 14, 2023", "ident email+rebill")

ok(ccu.reset_passed(ccu.weekly(0.5, now - 60), now), "past reset is passed")
ok(not ccu.reset_passed(grok, now), "future reset is not passed")
ok(not ccu.reset_passed(ccu.weekly(0.5, 0), now), "unknown reset is not passed")

card = ccu.serialize_card(
  {"id": "cursor", "label": "Cursor", "accent": "mauve", "mark": "cursor", "bar": True},
  {"weekly": cursor, "tier": "Ultra", "extras": [
    {"label": "Other Models", "weekly": ccu.weekly(1.0, now + 16 * 86400, 30 * 86400)},
    {"label": "Usage-based spend", "text": "$233 of $400 used"},
  ]},
  now,
)
eq(card["chip_pct"], "31%", "chip is the main window")
eq(card["chip_subs"], [100.0], "sub-limits become the chip's mini bars")
eq(card["mark"], "cursor", "card carries the mark")
eq([lim["title"] for lim in card["limits"]], ["Monthly limit", "Other Models"], "one limit per window")
eq(card["notes"], [{"label": "Usage-based spend", "text": "$233 of $400 used"}], "windowless extras are notes")
calm = ccu.serialize_card({"id": "grok", "label": "Grok", "accent": "teal", "bar": True}, {"weekly": grok}, now)
eq(calm["chip_subs"], [], "no sub-limits, no mini bars")
session = ccu.weekly(0.62, now + 2 * 3600, ccu.SESSION_SPAN_SEC)
claude_wk = ccu.weekly(0.10, now + 3 * 86400)
cl = ccu.serialize_card({"id": "claude", "label": "Claude", "accent": "peach", "bar": True},
  {"weekly": claude_wk, "extras": [{"label": "Session (5-hour)", "weekly": session}]}, now)
eq((cl["chip_pct"], cl["chip_subs"]), ("10%", [62.0]), "a fuller session stays a mini bar, the ring keeps the week")

eq(ccu.claude_usage.plan_label("team", "default_claude_max_5x"), "Team · Max 5x", "claude team seat on max 5x")
eq(ccu.claude_usage.plan_label("max", "default_claude_max_20x"), "Max 20x", "claude max 20x")
eq(ccu.claude_usage.plan_label("pro", "default_claude_ai"), "Pro", "claude pro")
eq(ccu.claude_usage.plan_label(None, None), None, "claude plan unknown")
eq(ccu.claude_state({"plan": "Max 20x", "email": "a@x.com", "weekly": None})["tier"], "Max 20x", "claude card gets the plan")
lim = ccu.extra_windows([{"kind": "session", "label": "Session", "used": 40, "reset_unix": now + 3600}])[0]["weekly"]
eq(ccu.window_name(lim["span"]), "session", "session extra keeps its 5-hour span")

eq(ccu.countdown(now + 16 * 3600, now), "16h 0m", "16h 0m")
eq(ccu.countdown(now, now), "now", "now when reset==now")
eq(ccu.countdown(0, now), "now", "now when reset missing")

eq(ccu.token_count(5.63e7), "56.3M", "5.63e7 → 56.3M")
eq(ccu.token_count(1.86e8), "186M", "1.86e8 → 186M")
eq(ccu.token_count(1000), "1K", "1000 → 1K")
eq(ccu.token_count(999), "999", "999 stays raw")
eq(ccu.token_count(1e9), "1B", "1e9 → 1B")

eq(ccu.usd(12.3), "$12.30", "usd cents")
eq(ccu.usd(100), "$100", "usd dollars")
eq(ccu.usd(1500), "$1.5k", "usd thousands")
eq(ccu.total_line(1.86e8, 1500), "All time · 186M · $1.5k", "all-time line with cost")
eq(ccu.days30_line(5.63e7, 12.3), "30d · 56.3M · $12.30", "30d window cell")
eq(ccu.week_line(450e6, 8), "7d · 450M · $8.00", "7d window cell")
eq(ccu.stat_line("30d", None, None), "30d · —", "missing window is em dash")

win = ccu.from_helper_window({"used": 31, "reset_unix": claude_reset})
eq(ccu.percent(win["used"]), "31%", "helper used 31 → 31%")
eq(ccu.countdown(win["reset"], now), "15h 59m", "helper reset_unix")

extras = ccu.extra_windows([
  {"kind": "session", "label": "Session", "used": 42, "reset_unix": now + 3 * 3600 + 12 * 60},
  {"kind": "weekly_all", "label": "Weekly", "used": 31, "reset_unix": claude_reset},
  {"kind": "weekly_scoped", "label": "Fable", "used": 12, "reset_unix": codex_reset},
])
eq(len(extras), 2, "session + fable extras, weekly dropped")
eq(extras[0]["label"], "Session (5-hour)", "session extra label")
eq(extras[1]["label"], "Fable Weekly", "fable extra label")
ok(ccu.is_extra("Fable Weekly"), "Fable Weekly is extra")
ok(not ccu.is_extra("Weekly"), "Weekly is not extra")

cursor_extras = ccu.extra_windows([
  {"kind": "cursor_auto", "label": "Cursor Models", "used": 40, "reset_unix": now + 86400},
  {"kind": "cursor_api", "label": "Other Models", "used": 12, "reset_unix": now + 86400},
])
eq(len(cursor_extras), 2, "cursor auto+api extras")
eq(cursor_extras[0]["label"], "Cursor Models", "cursor models extra")
eq(cursor_extras[1]["label"], "Other Models", "cursor other extra")

spend = ccu.spend_extra({
  "spend_limit_cents": 40000,
  "spend_remaining_cents": 31400,
})
eq(spend["label"], "Usage-based spend", "spend extra label")
eq(spend["text"], "$86.00 of $400 used", "spend extra $86 of $400")

cats = ccu.categories([
  {"label": "Chat", "percent": 12.2},
  {"label": "Grok Build", "percent": 8.0},
  {"label": "API", "percent": 0.01},
  {"label": "Imagine", "percent": 1.4},
  {"label": "Voice", "percent": 0.4},
])
eq([c["label"] for c in cats], ["Chat", "Grok Build", "Imagine", "Voice"], "drop near-zero API")
eq(cats[0]["color"], "blue", "Chat is blue")
eq(cats[1]["color"], "mauve", "Grok Build is mauve")
eq(cats[0]["percent"], "12%", "Chat 12%")
eq(ccu.category_percent(0.004), "<1%", "tiny category is <1%")

friday = int(time.mktime((2026, 8, 21, 12, 0, 0, 0, 0, 0)))
days = [
  {"date": "2026-08-15", "tokens": 10, "usd": 1},
  {"date": "2026-08-16", "tokens": 0, "usd": 0},
  {"date": "2026-08-17", "tokens": 50, "usd": 4},
  {"date": "2026-08-18", "tokens": 20, "usd": 2},
  {"date": "2026-08-19", "tokens": 0, "usd": 0},
  {"date": "2026-08-20", "tokens": 5, "usd": 0.5},
  {"date": "2026-08-21", "tokens": 15, "usd": 1.5},
]
cols = ccu.chart_days(days, friday)
eq(cols[0]["date"], "2026-08-15", "leftmost is 6 days ago")
eq(cols[6]["dow"], "Fri", "rightmost is current day")
eq(cols[2]["compact"], "50", "peak compact")
eq(cols[2]["height"], 1.0, "peak height")
eq(cols[1]["height"], 0.0, "zero day height")
wtok, wusd = ccu.window_sum(days, friday)
eq(wtok, 100.0, "window_sum tokens")
eq(wusd, 9.0, "window_sum usd")

grok_card = ccu.serialize_card(
  {"id": "grok", "label": "Grok", "accent": "teal", "bar": True, "url": ccu.GROK_USAGE},
  {
    "weekly": grok,
    "cats": cats,
    "tier": "SuperGrok Heavy",
    "email": "a@x.com",
    "renews_unix": now + 20 * 86400,
    "cancels": False,
    "extras": [],
    "status": None,
    "total_tokens": 1.86e8,
    "total_usd": 1500,
    "days30_tokens": 5.63e7,
    "days30_usd": 12.3,
    "week_tokens": 450e6,
    "week_usd": 8,
    "days": days,
  },
  now,
)
eq(grok_card["head"], "SuperGrok Heavy", "grok head is plan name")
eq(grok_card["usage_line"], "22% of weekly limit used", "grok sub usage")
ok(grok_card["ident"].startswith("a@x.com"), "grok ident has email")
ok(grok_card["fresh"], "serialize_card defaults fresh")
eq(grok_card["fetched_at"], 0, "serialize_card defaults fetched_at 0")
eq(len(grok_card["categories"]), 4, "grok category split")
eq(grok_card["total_line"], "All time · 186M · $1.5k", "grok all-time")
eq(len(grok_card["chart"]), 7, "grok week chart")
ok(grok_card["has_stats"], "grok has stats")

cursor_card = ccu.serialize_card(
  {"id": "cursor", "label": "Cursor", "accent": "mauve", "bar": True, "url": ccu.CURSOR_USAGE},
  {
    "weekly": cursor,
    "cats": [],
    "tier": "Pro",
    "email": "dev@cursor.com",
    "renews_unix": None,
    "cancels": False,
    "extras": cursor_extras + [spend],
    "status": None,
  },
  now,
)
eq(cursor_card["head"], "Pro", "cursor head is plan")
eq(cursor_card["usage_line"], "31% of monthly limit used", "cursor monthly subline")
eq(len(cursor_card["limits"]), 3, "cursor monthly + models + other as limits")
eq(cursor_card["notes"], [{"label": "Usage-based spend", "text": "$86.00 of $400 used"}], "cursor spend note on card")
eq(cursor_card["ident"], "dev@cursor.com", "cursor ident is email only")

claude_card = ccu.serialize_card(
  {"id": "claude", "label": "Claude", "accent": "peach", "bar": True, "url": ccu.CLAUDE_USAGE},
  {
    "weekly": claude,
    "cats": [],
    "tier": None,
    "email": None,
    "renews_unix": None,
    "cancels": False,
    "extras": extras,
    "status": None,
  },
  now,
)
eq(claude_card["head"], "", "claude has no plan in the head")
eq(claude_card["usage_line"], "31% of weekly limit used", "claude usage subline")
eq(claude_card["reset_line"], ccu.reset_line(claude, now), "claude reset subline with clock time")
eq(claude_card["ident"], "", "claude has no ident")

stale_card = ccu.serialize_card(
  {"id": "grok", "label": "Grok", "accent": "teal", "bar": True, "url": ccu.GROK_USAGE},
  {"weekly": grok, "cats": [], "tier": None, "email": None, "renews_unix": None, "cancels": False, "extras": [], "status": None},
  now,
  fresh=False,
  fetched_at=now - 3600,
)
ok(not stale_card["fresh"], "failed refresh marks the card stale")
eq(stale_card["fetched_at"], now - 3600, "stale card keeps last-ok unix")

# Claude Code normally reports no weekly window, only the rolling 5-hour
# session. That has to reach the bar chip as a percentage rather than an em
# dash, and be named "session" rather than defaulting to a week-long span.
session_only = ccu.claude_state({
  "weekly": None,
  "scoped": None,
  "session": {
    "kind": "session",
    "label": "Session",
    "used": 16.0,
    "reset_unix": now + 4 * 3600,
  },
  "limits": [],
})
eq(session_only["weekly"]["used"], 0.16, "session promoted to the primary window")
eq(session_only["weekly"]["span"], float(ccu.SESSION_SPAN_SEC), "promoted session spans 5h")
eq(session_only["extras"], [], "promoted session is not also an extra")
eq(ccu.usage_line(session_only["weekly"]), "16% of session limit used", "session usage line")

# A real weekly window still wins, and the session stays an extra.
both = ccu.claude_state({
  "weekly": {"used": 40.0, "reset_unix": now + 3 * 86400, "span_sec": week},
  "scoped": None,
  "session": {"kind": "session", "label": "Session", "used": 16.0, "reset_unix": now + 3600},
  "limits": [],
})
eq(both["weekly"]["used"], 0.4, "weekly wins over session when present")
eq(len(both["extras"]), 1, "session stays an extra alongside a weekly window")

st = ccu.grok_state({
  "utilization": 21.0,
  "reset_unix": now + 5 * 86400,
  "span_sec": week,
  "tier": "SuperGrok Heavy",
  "email": "a@x.com",
  "renews_unix": now,
  "cancels": False,
  "categories": [{"label": "Chat", "percent": 12}, {"label": "API", "percent": 3}],
})
eq(round(st["weekly"]["used"] * 100), 21, "grok_state used")
eq(st["tier"], "SuperGrok Heavy", "grok_state tier")
eq(len(st["cats"]), 2, "grok_state cats")

st_c = ccu.cursor_state({
  "utilization": 31,
  "reset_unix": now + 16 * 86400,
  "span_sec": 30 * 86400,
  "period_start_unix": now,
  "plan": "Pro",
  "email": "dev@cursor.com",
  "spend_limit_cents": 40000,
  "spend_remaining_cents": 31400,
  "limits": [
    {"kind": "cursor_auto", "label": "Cursor Models", "used": 40, "reset_unix": now + 86400},
    {"kind": "cursor_api", "label": "Other Models", "used": 12, "reset_unix": now + 86400},
  ],
})
eq(st_c["tier"], "Pro", "cursor_state plan")
eq(len(st_c["extras"]), 3, "cursor_state extras include spend")

gb = ccu.grokbot_usage.build_payload({"usagePercent": 42, "nextResetTimestampUtc": str((now + 86400) * 1000), "grokPlanLabel": "SuperGrok"})
eq(round(gb["utilization"]), 42, "grokbot percent usagePercent")
eq(gb["reset_unix"], now + 86400, "grokbot reset from ms string")
eq(ccu.grokbot_usage.build_payload({"hasAvailableUsage": False})["utilization"], 100.0, "grokbot exhausted without percent")
st_b = ccu.grokbot_state(gb)
eq(st_b["tier"], "SuperGrok", "grokbot_state plan")
eq(round(st_b["weekly"]["used"], 2), 0.42, "grokbot_state weekly used")
eq(ccu.grokbot_state({"error": "http_401: x"})["status"], "auth_error", "grokbot_state auth error")
eq(len(ccu.grokbot_usage.checksum()), 8 + 36, "grokbot checksum = 8 b64 chars + uuid")

src = SRC.read_text()
qml = Path(__file__).resolve().parent.parent / "quickshell" / "remix" / "modules" / "bar" / "components" / "Ccu.qml"
qml_src = qml.read_text()
ok("cursor_usage" in src, "asahi-ccu imports cursor_usage")
ok("grok_usage" in src, "asahi-ccu imports grok_usage")
ok('id": "grok"' in src and '"id": "cursor"' in src, "provider order grok then cursor")
ok(src.find('"id": "grok"') < src.find('"id": "cursor"') < src.find('"id": "claude"'), "grok < cursor < claude")
ok("AGENT USAGE" in qml_src, "Ccu.qml headed AGENT USAGE")
ok("usage_line" in qml_src and "reset_line" in qml_src, "Ccu.qml keeps the main window as text line + full bar")
ok("subLimits" in qml_src and "reset_passed" in qml_src, "Ccu.qml renders the other windows as mini tiles")
ok("ownReset" in qml_src, "Ccu.qml shows a tile's reset only when it is not the main reset")
eq(card["limits"][1]["reset_unix"], now + 16 * 86400, "limits carry reset_unix")
ok("chipSwap" in qml_src and "shownIndex" in qml_src, "Ccu.qml animates the chip rotation")
ok("chipRing" in qml_src and "PathAngleArc" in qml_src, "Ccu.qml chip is a usage ring around the mark")
ok("chip.subs" in qml_src and ".hot" not in qml_src, "Ccu.qml: mini bars for the other windows, wash on the main one")
ok("Marks.paths" in qml_src and "component Mark" in qml_src, "Ccu.qml draws provider marks")
ok("cardData.tier" in qml_src, "Ccu.qml shows the plan in the popup")
ok("chip.plan" not in qml_src, "Ccu.qml keeps the plan out of the bar chip")
ok("categories" in qml_src, "Ccu.qml renders category meter")
ok("total_line" in qml_src and "days30_line" in qml_src, "Ccu.qml All time / 30d / 7d")
ok("chipText" in qml_src, "Ccu.qml shows CCu until the first answer")
ok("chipBoxW" in qml_src, "Ccu.qml uses a fixed chip box so rotation does not resize")
ok("barFontBody" in qml_src, "Ccu.qml chip uses Style.barFontBody")
ok("pixelSize: 14" not in qml_src, "Ccu.qml chip is not a hardcoded 14px")
ok("cursor_usage.py" not in qml_src, "QML does not fetch helpers itself")
ok("tooltip" not in src, "asahi-ccu emits no hover tooltip")
ok("TooltipWindow" not in qml_src, "Ccu.qml has no hover tooltip")
ok("PopupWindow" in qml_src, "Ccu.qml keeps the usage popup")
ok("chipFresh" in qml_src, "Ccu.qml dims a stale chip")
ok("stale, last ok" in qml_src, "Ccu.qml popup marks a stale card with last-ok")
ok("stale, last refresh failed" in qml_src, "Ccu.qml popup falls back when no last-ok")
ok("onEntered" not in qml_src, "Ccu.qml does not refresh on hover")
ok("5 * 60 * 1000" in qml_src, "Ccu.qml polls usage every 5 min")
ok("interval: 10000" in qml_src, "Ccu.qml still rotates chips every 10s")
ok("usageColor" in qml_src, "Ccu.qml keeps absolute usage bands")
ok("nextChip" in qml_src, "Ccu.qml still rotates chips")
ok("updatedShort" not in qml_src, "Ccu.qml bar chip has no refresh age")
ok("updatedLabel" in qml_src, "Ccu.qml popup shows last refresh age")
ok("chipBehind" not in qml_src, "Ccu.qml has no behind-pace color")
ok("cardData.pace" not in qml_src, "Ccu.qml popup has no pace line")
ok("behind_pace" not in src and "pace_text" not in src, "asahi-ccu dropped pace helpers")
ok('"fresh"' in src and "updated_at" in src, "asahi-ccu emits fresh and updated_at")

if FAILED:
  print(f"\n{FAILED} failed")
  sys.exit(1)
print("\nall passed")
