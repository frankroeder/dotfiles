#!/usr/bin/env python3
"""Local CLI token usage + LiteLLM API $ for sketchybar ccu.lua.

Installed CLIs only (command -v). Windows: today, past 7d, this month.
Pricing: LiteLLM model_prices_and_context_window.json (ccusage-style), cached 6h.
"""

from __future__ import annotations

import json
import shutil
import sys
import time
import urllib.request
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any

LITELLM_URL = (
  "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"
)
PRICING_CACHE = Path.home() / ".cache" / "sketchybar" / "litellm_pricing.json"
PRICING_TTL = 6 * 3600
# Only if LiteLLM JSON is unavailable. Prefer real list prices from LITELLM_URL.
_FALLBACK = (2e-6, 6e-6, 5e-7, 2.5e-6)  # in, out, cache_read, cache_write  ≈ xai/grok-4.5

_pricing: dict[str, tuple[float, float, float, float]] | None = None  # model → rates


def emit(obj: dict[str, Any]) -> None:
  # JSON: sbar.exec parses it into a lua table. Lua literals break on reserved
  # keys (days30.end) and on concat when the callback already got a table.
  print(json.dumps(obj, separators=(",", ":")), flush=True)


def day_of(ts: Any) -> date | None:
  if isinstance(ts, (int, float)):
    sec = float(ts) / 1000.0 if ts > 1e12 else float(ts)
    try:
      return datetime.fromtimestamp(sec).date()
    except (OverflowError, OSError, ValueError):
      return None
  if isinstance(ts, str) and ts:
    try:
      return datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone().date()
    except ValueError:
      return None
  return None


def load_pricing() -> dict[str, tuple[float, float, float, float]]:
  """model → (in, out, cache_read, cache_write) per-token USD from LiteLLM."""
  text = None
  if PRICING_CACHE.is_file() and time.time() - PRICING_CACHE.stat().st_mtime < PRICING_TTL:
    text = PRICING_CACHE.read_text()
  else:
    try:
      req = urllib.request.Request(LITELLM_URL, headers={"User-Agent": "sketchybar-ccu"})
      with urllib.request.urlopen(req, timeout=25) as r:
        text = r.read().decode()
      PRICING_CACHE.parent.mkdir(parents=True, exist_ok=True)
      PRICING_CACHE.write_text(text)
    except Exception:
      if PRICING_CACHE.is_file():
        text = PRICING_CACHE.read_text()
  out: dict[str, tuple[float, float, float, float]] = {}
  if not text:
    return out
  try:
    raw = json.loads(text)
  except json.JSONDecodeError:
    return out
  for name, e in raw.items():
    if not isinstance(e, dict):
      continue
    inp, o = e.get("input_cost_per_token"), e.get("output_cost_per_token")
    if inp is None or o is None:
      continue
    try:
      fi, fo = float(inp), float(o)
    except (TypeError, ValueError):
      continue
    cr = e.get("cache_read_input_token_cost")
    cc = e.get("cache_creation_input_token_cost")
    try:
      fcr = float(cr) if cr is not None else fi * 0.1
    except (TypeError, ValueError):
      fcr = fi * 0.1
    try:
      fcc = float(cc) if cc is not None else fi * 1.25
    except (TypeError, ValueError):
      fcc = fi * 1.25
    out[str(name)] = (fi, fo, fcr, fcc)
  return out


def _norm_model(name: str) -> str:
  n = name.strip().split("/")[-1].lower()
  for suf in ("-build", "-latest", "-beta"):
    if n.endswith(suf):
      n = n[: -len(suf)]
  return n


def rates(model: str) -> tuple[float, float, float, float]:
  """Per-token USD from LiteLLM. Unknown model → zeros (no made-up price)."""
  global _pricing
  if _pricing is None:
    _pricing = load_pricing()
  if not _pricing:
    return _FALLBACK
  m = model.strip()
  n = _norm_model(m)
  for key in (m, n, f"xai/{n}", f"anthropic/{n}", f"openai/{n}"):
    if key in _pricing:
      return _pricing[key]
  # Exact last-segment match; prefer vendor keys over azure/oci/openrouter.
  best = None
  for k, r in _pricing.items():
    last = k.rsplit("/", 1)[-1].lower()
    if last != n and last != n.replace(".", "-"):
      continue
    vendor = k.split("/", 1)[0] if "/" in k else ""
    score = 3 if vendor in ("xai", "anthropic", "openai") else 2 if vendor == "" else 1
    score = score * 1000 + len(k)
    if best is None or score > best[0]:
      best = (score, r)
  return best[1] if best else (0.0, 0.0, 0.0, 0.0)


def cost(model: str, inp: float, out: float, cache_r: float = 0, cache_w: float = 0) -> float:
  fi, fo, fcr, fcw = rates(model)
  return inp * fi + out * fo + cache_r * fcr + cache_w * fcw


def add(dm: dict[date, list[float]], d: date, tok: float, usd: float) -> None:
  if tok <= 0 and usd <= 0:
    return
  if d not in dm:
    dm[d] = [0.0, 0.0]
  dm[d][0] += tok
  dm[d][1] += usd


def windows(dm: dict[date, list[float]], today: date) -> dict[str, Any]:
  # Past 7 days (oldest → newest)
  days = []
  wtok = wusd = 0.0
  for i in range(7):
    d = today - timedelta(days=6 - i)
    t, u = dm.get(d, [0.0, 0.0])
    days.append({"date": d.isoformat(), "dow": d.strftime("%a"), "tokens": round(t), "usd": round(u, 4)})
    wtok += t
    wusd += u

  d30tok = d30usd = 0.0
  for i in range(30):
    d = today - timedelta(days=29 - i)
    t, u = dm.get(d, [0.0, 0.0])
    d30tok += t
    d30usd += u

  # Calendar month totals only — popup does not plot month.days.
  m_start = date(today.year, today.month, 1)
  if today.month == 12:
    m_end = date(today.year + 1, 1, 1) - timedelta(days=1)
  else:
    m_end = date(today.year, today.month + 1, 1) - timedelta(days=1)
  mtok = musd = max_u = 0.0
  d = m_start
  while d <= m_end:
    t, u = dm.get(d, [0.0, 0.0])
    if d <= today:
      mtok += t
      musd += u
      max_u = max(max_u, u)
    d += timedelta(days=1)

  # All-time total from every day we have
  ttok = tusd = 0.0
  for t, u in dm.values():
    ttok += t
    tusd += u

  tt, tu = dm.get(today, [0.0, 0.0])
  return {
    "today": {"date": today.isoformat(), "tokens": round(tt), "usd": round(tu, 4)},
    "weekdays": days,
    "week": {
      "start": (today - timedelta(days=6)).isoformat(),
      "week_end": today.isoformat(),
      "tokens": round(wtok),
      "usd": round(wusd, 4),
      "max_day_usd": round(max((x["usd"] for x in days), default=0.0), 4),
    },
    "days30": {
      "start": (today - timedelta(days=29)).isoformat(),
      "week_end": today.isoformat(),
      "tokens": round(d30tok),
      "usd": round(d30usd, 4),
    },
    "month": {
      "year": today.year,
      "month": today.month,
      "tokens": round(mtok),
      "usd": round(musd, 4),
      "max_day_usd": round(max_u, 4),
    },
    "total": {"tokens": round(ttok), "usd": round(tusd, 4)},
  }


def grok_days() -> dict[date, list[float]]:
  """All-time Grok turn_completed usage from session updates."""
  root = Path.home() / ".grok" / "sessions"
  dm: dict[date, list[float]] = {}
  if not root.is_dir():
    return dm
  for path in root.rglob("updates.jsonl"):
    try:
      f = open(path, "rb")
    except OSError:
      continue
    with f:
      for raw in f:
        if b"turn_completed" not in raw or b"usage" not in raw:
          continue
        try:
          o = json.loads(raw)
        except Exception:
          continue
        upd = (o.get("params") or {}).get("update") or {}
        if upd.get("sessionUpdate") != "turn_completed":
          continue
        usage = upd.get("usage")
        if not isinstance(usage, dict):
          continue
        d = day_of(o.get("timestamp"))
        if d is None:
          continue
        mu = usage.get("modelUsage")
        if isinstance(mu, dict) and mu:
          tok = usd = 0.0
          for model, m in mu.items():
            if not isinstance(m, dict):
              continue
            i = float(m.get("inputTokens") or 0)
            o_ = float(m.get("outputTokens") or 0) + float(m.get("reasoningTokens") or 0)
            cr = float(m.get("cachedReadTokens") or 0)
            tok += i + o_ + cr
            usd += cost(str(model), i, o_, cr)
          add(dm, d, tok, usd)
        else:
          i = float(usage.get("inputTokens") or 0)
          o_ = float(usage.get("outputTokens") or 0) + float(usage.get("reasoningTokens") or 0)
          cr = float(usage.get("cachedReadTokens") or 0)
          tok = float(usage.get("totalTokens") or (i + o_ + cr))
          add(dm, d, tok, cost("grok-4.5", i, o_, cr))
  return dm


def claude_days() -> dict[date, list[float]]:
  root = Path.home() / ".claude" / "projects"
  dm: dict[date, list[float]] = {}
  if not root.is_dir():
    return dm
  seen: set[str] = set()
  for path in root.rglob("*.jsonl"):
    try:
      f = open(path, "rb")
    except OSError:
      continue
    with f:
      for raw in f:
        if b"usage" not in raw:
          continue
        try:
          o = json.loads(raw)
        except Exception:
          continue
        msg = o.get("message")
        if not isinstance(msg, dict):
          continue
        usage = msg.get("usage")
        if not isinstance(usage, dict) or msg.get("role") not in (None, "assistant"):
          continue
        key = str(o.get("requestId") or msg.get("id") or o.get("uuid") or "")
        if not key or key in seen:
          continue
        seen.add(key)
        d = day_of(o.get("timestamp"))
        if d is None:
          continue
        model = str(msg.get("model") or "claude-sonnet-5")
        i = float(usage.get("input_tokens") or 0)
        o_ = float(usage.get("output_tokens") or 0)
        cr = float(usage.get("cache_read_input_tokens") or 0)
        cw = float(usage.get("cache_creation_input_tokens") or 0)
        add(dm, d, i + o_ + cr + cw, cost(model, i, o_, cr, cw))
  return dm


def codex_days() -> dict[date, list[float]]:
  root = Path.home() / ".codex" / "sessions"
  dm: dict[date, list[float]] = {}
  if not root.is_dir():
    return dm
  for path in root.rglob("rollout-*.jsonl"):
    try:
      f = open(path, "rb")
    except OSError:
      continue
    with f:
      for raw in f:
        if b"token_count" not in raw:
          continue
        try:
          o = json.loads(raw)
        except Exception:
          continue
        if o.get("type") != "event_msg":
          continue
        pl = o.get("payload") or {}
        if pl.get("type") != "token_count":
          continue
        last = (pl.get("info") or {}).get("last_token_usage") or {}
        if not isinstance(last, dict):
          continue
        d = day_of(o.get("timestamp"))
        if d is None:
          continue
        i = float(last.get("input_tokens") or 0)
        o_ = float(last.get("output_tokens") or 0) + float(last.get("reasoning_output_tokens") or 0)
        cr = float(last.get("cached_input_tokens") or 0)
        tok = float(last.get("total_tokens") or (i + o_ + cr))
        add(dm, d, tok, cost("gpt-5", max(0.0, i - cr), o_, cr))
  return dm


def main() -> int:
  today = date.today()
  providers = []
  if shutil.which("grok"):
    providers.append({"id": "grok", "label": "Grok", "source": "sessions", **windows(grok_days(), today)})
  if shutil.which("claude"):
    providers.append({"id": "claude", "label": "Claude", "source": "projects", **windows(claude_days(), today)})
  if shutil.which("codex"):
    providers.append({"id": "codex", "label": "Codex", "source": "rollouts", **windows(codex_days(), today)})
  emit({"error": None, "as_of": today.isoformat(), "providers": providers})
  return 0


if __name__ == "__main__":
  try:
    raise SystemExit(main())
  except Exception as e:
    emit({"error": str(e)[:48], "as_of": date.today().isoformat(), "providers": []})
    raise SystemExit(1)
