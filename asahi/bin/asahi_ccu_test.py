#!/usr/bin/env python3
"""Drive shipped asahi-ccu format/pace/chart helpers. No network."""

from __future__ import annotations

import os
import sys
import time
from importlib.machinery import SourceFileLoader
from pathlib import Path

os.environ["TZ"] = "UTC"
if hasattr(time, "tzset"):
  time.tzset()

SRC = Path(__file__).resolve().parent / "asahi-ccu"
ccu = SourceFileLoader("asahi_ccu", str(SRC)).load_module()

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
eq(ccu.used_line(claude, now), "31% used · resets in 15h 59m", "used · resets in")

codex_reset = now + 4 * 86400 + 22 * 3600
codex = ccu.weekly(0.18, codex_reset)
eq(ccu.countdown(codex_reset, now), "4d 22h", "4d 22h countdown")
eq(ccu.bar_chip("Claude", claude, now), "Claude 31% · 15h 59m", "claude chip")
eq(ccu.bar_chip("Codex", codex, now), "Codex 18% · 4d 22h", "codex chip")
eq(ccu.bar_chip("Codex", None, now), "Codex —", "unavailable weekly chip")

grok = ccu.weekly(0.22, now + 3 * 86400, week)
cursor = ccu.from_helper_window({
  "utilization": 31,
  "reset_unix": now + 16 * 86400,
  "span_sec": 30 * 86400,
})
eq(ccu.bar_chip("Grok", grok, now), "Grok 22% · 3d 0h", "grok chip")
eq(ccu.bar_chip("Cursor", cursor, now), "Cursor 31% · 16d 0h", "cursor chip")
eq(ccu.window_name(week), "weekly", "7d window is weekly")
eq(ccu.window_name(30 * 86400), "monthly", "30d window is monthly")
eq(ccu.usage_line(grok), "22% of weekly limit used", "grok usage line")
eq(ccu.usage_line(cursor), "31% of monthly limit used", "cursor usage line")
ok("Resets" in ccu.reset_line(grok, now), "reset line has Resets")
ok("3d 0h" in ccu.reset_line(grok, now), "reset line has countdown")

eq(ccu.renews_line(now, False), "Renews Nov 14, 2023", "renews date")
eq(ccu.renews_line(now, True), "Ends Nov 14, 2023", "cancels at period end")
eq(ccu.renews_line(0, False), "", "missing rebill is empty")
eq(ccu.ident_text("a@x.com", now, False), "a@x.com · Renews Nov 14, 2023", "ident email+rebill")

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
eq(ccu.extra_line(extras[0]["weekly"], now), "42% used · 3h 12m", "extra line has no resets-in")
ok(ccu.is_extra("Fable Weekly"), "Fable Weekly is extra")
ok(not ccu.is_extra("Weekly"), "Weekly is not extra")

cursor_extras = ccu.extra_windows([
  {"kind": "cursor_auto", "label": "Cursor Models", "used": 40, "reset_unix": now + 86400},
  {"kind": "cursor_api", "label": "Other Models", "used": 12, "reset_unix": now + 86400},
])
eq(len(cursor_extras), 2, "cursor auto+api extras")
eq(cursor_extras[0]["label"], "Cursor Models", "cursor models extra")
eq(cursor_extras[1]["label"], "Other Models", "cursor other extra")
eq(ccu.extra_line(cursor_extras[1]["weekly"], now), "12% used · 1d 0h", "cursor extra line")

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
eq(ccu.spark_char(0), "·", "zero spark is a dot")
eq(ccu.spark_char(1), "█", "peak spark")

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
    "today": {"tokens": 15, "usd": 1.5},
    "week": {"tokens": 100, "usd": 9},
    "total": {"tokens": 1.86e8, "usd": 1500},
  },
  now,
)
eq(grok_card["head"], "SuperGrok Heavy", "grok head is plan name")
eq(grok_card["usage_line"], "22% of weekly limit used", "grok sub usage")
ok(grok_card["ident"].startswith("a@x.com"), "grok ident has email")
eq(grok_card["chip"], "Grok 22% · 3d 0h", "grok chip on card")
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
eq(len(cursor_card["extras"]), 3, "cursor models + other + spend")
eq(cursor_card["extras"][2]["text"], "$86.00 of $400 used", "cursor spend extra on card")
eq(cursor_card["ident"], "dev@cursor.com", "cursor ident is email only")

claude_card = ccu.serialize_card(
  {"id": "claude", "label": "Claude", "accent": "peach", "bar": False, "url": ccu.CLAUDE_USAGE},
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
eq(claude_card["head"], "31% used · resets in 15h 59m", "claude keeps single-line head")
eq(claude_card["usage_line"], "", "claude has no plan subline")
eq(claude_card["ident"], "", "claude has no ident")

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

src = SRC.read_text()
qml = Path(__file__).resolve().parent.parent / "quickshell" / "remix" / "modules" / "bar" / "components" / "Ccu.qml"
qml_src = qml.read_text()
ok("cursor_usage" in src, "asahi-ccu imports cursor_usage")
ok("grok_usage" in src, "asahi-ccu imports grok_usage")
ok('id": "grok"' in src and '"id": "cursor"' in src, "provider order grok then cursor")
ok(src.find('"id": "grok"') < src.find('"id": "cursor"') < src.find('"id": "claude"'), "grok < cursor < claude")
ok("AGENT USAGE" in qml_src, "Ccu.qml headed AGENT USAGE")
ok("usage_line" in qml_src and "reset_line" in qml_src, "Ccu.qml renders usage subline")
ok("categories" in qml_src, "Ccu.qml renders category meter")
ok("total_line" in qml_src and "days30_line" in qml_src, "Ccu.qml All time / 30d / 7d")
ok("chipText" in qml_src, "Ccu.qml bar chip uses helper chip text")
ok("cursor_usage.py" not in qml_src, "QML does not fetch helpers itself")
ok("tooltip" not in src, "asahi-ccu emits no hover tooltip")
ok("TooltipWindow" not in qml_src, "Ccu.qml has no hover tooltip")
ok("PopupWindow" in qml_src, "Ccu.qml keeps the usage popup")

if FAILED:
  print(f"\n{FAILED} failed")
  sys.exit(1)
print("\nall passed")
