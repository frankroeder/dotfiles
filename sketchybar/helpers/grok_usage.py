#!/usr/bin/env python3
"""Fetch Grok Build subscription usage for sketchybar ccu.lua.

Auth: OIDC access token from ~/.grok/auth.json (same store as `grok login`).
Refreshes the token when expired / rejected.
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

BERLIN = ZoneInfo("Europe/Berlin")
AUTH_PATH = Path.home() / ".grok" / "auth.json"
# Official Grok Build client uses format=credits (creditUsagePercent + weekly period).
# Unified prepaid users often omit creditUsagePercent; bare /v1/billing still has used/monthlyLimit.
CREDITS_URL = "https://cli-chat-proxy.grok.com/v1/billing?format=credits"
BARE_URL = "https://cli-chat-proxy.grok.com/v1/billing"
TOKEN_URL = "https://auth.x.ai/oauth2/token"


def lua_literal(value: Any) -> str:
  if value is None:
    return "nil"
  if value is True:
    return "true"
  if value is False:
    return "false"
  if isinstance(value, (int, float)):
    return str(value)
  if isinstance(value, str):
    # Escape control chars — bare newlines break Lua double-quoted strings.
    escaped = (
      value.replace("\\", "\\\\")
      .replace('"', '\\"')
      .replace("\n", "\\n")
      .replace("\r", "\\r")
      .replace("\t", "\\t")
    )
    return f'"{escaped}"'
  if isinstance(value, dict):
    parts = [f"{k}={lua_literal(v)}" for k, v in value.items()]
    return "{" + ",".join(parts) + "}"
  if isinstance(value, list):
    return "{" + ",".join(lua_literal(v) for v in value) + "}"
  return lua_literal(str(value))


def money_val(obj: Any) -> float | None:
  if obj is None:
    return None
  if isinstance(obj, (int, float)):
    return float(obj)
  if isinstance(obj, dict) and "val" in obj:
    return float(obj["val"])
  return None


def format_berlin(iso: str | None) -> str | None:
  if not iso:
    return None
  dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
  local = dt.astimezone(BERLIN)
  return local.strftime("%Y-%m-%d %H:%M (%Z)")


def load_auth() -> tuple[dict[str, Any], str, dict[str, Any]]:
  if not AUTH_PATH.is_file():
    raise RuntimeError("missing_auth: run `grok login`")
  data = json.loads(AUTH_PATH.read_text())
  if not isinstance(data, dict) or not data:
    raise RuntimeError("invalid_auth: empty ~/.grok/auth.json")
  scope = next(iter(data))
  entry = data[scope]
  if not isinstance(entry, dict) or not entry.get("key"):
    raise RuntimeError("invalid_auth: no access token")
  return data, scope, entry


def save_auth(data: dict[str, Any]) -> None:
  AUTH_PATH.write_text(json.dumps(data, indent=2) + "\n")


def token_expired(entry: dict[str, Any], skew_sec: int = 60) -> bool:
  exp = entry.get("expires_at")
  if not exp:
    return False
  try:
    dt = datetime.fromisoformat(str(exp).replace("Z", "+00:00"))
  except ValueError:
    return False
  return datetime.now(timezone.utc) >= dt - timedelta(seconds=skew_sec)


def refresh_token(data: dict[str, Any], scope: str, entry: dict[str, Any]) -> str:
  refresh = entry.get("refresh_token")
  client_id = entry.get("oidc_client_id")
  if not refresh or not client_id:
    raise RuntimeError("missing_refresh: run `grok login`")

  body = urllib.parse.urlencode({
    "grant_type": "refresh_token",
    "refresh_token": refresh,
    "client_id": client_id,
  }).encode()
  req = urllib.request.Request(
    TOKEN_URL,
    data=body,
    headers={
      "Content-Type": "application/x-www-form-urlencoded",
      "Accept": "application/json",
    },
    method="POST",
  )
  try:
    with urllib.request.urlopen(req, timeout=20) as resp:
      tok = json.loads(resp.read())
  except urllib.error.HTTPError as exc:
    raise RuntimeError(f"refresh_failed: http_{exc.code}") from exc
  except Exception as exc:
    raise RuntimeError(f"refresh_failed: {exc}") from exc

  access = tok.get("access_token")
  if not access:
    raise RuntimeError("refresh_failed: no access_token")

  entry["key"] = access
  if tok.get("refresh_token"):
    entry["refresh_token"] = tok["refresh_token"]
  expires_in = int(tok.get("expires_in") or 21600)
  entry["expires_at"] = (
    datetime.now(timezone.utc) + timedelta(seconds=expires_in)
  ).isoformat().replace("+00:00", "Z")
  data[scope] = entry
  save_auth(data)
  return access


def fetch_billing(token: str, url: str) -> dict[str, Any]:
  req = urllib.request.Request(
    url,
    headers={
      "Authorization": f"Bearer {token}",
      "Accept": "application/json",
      "User-Agent": "grok-build",
    },
  )
  try:
    with urllib.request.urlopen(req, timeout=20) as resp:
      return json.loads(resp.read())
  except urllib.error.HTTPError as exc:
    body = exc.read().decode("utf-8", errors="replace")
    raise RuntimeError(f"http_{exc.code}: {body[:120]}") from exc
  except Exception as exc:
    raise RuntimeError(f"network: {exc}") from exc


def build_payload(credits: dict[str, Any], bare: dict[str, Any] | None = None) -> dict[str, Any]:
  """Map billing JSON → Lua fields for ccu.lua.

  Prefer credits shape (creditUsagePercent + currentPeriod / billingPeriodEnd).
  Unified prepaid often omits creditUsagePercent and used/limit on the credits
  response — merge bare /v1/billing used/monthlyLimit when needed.
  """
  cfg = credits.get("config") or {}
  bare_cfg = (bare or {}).get("config") or {}

  used = money_val(cfg.get("used"))
  if used is None:
    used = money_val(bare_cfg.get("used"))
  limit = money_val(cfg.get("monthlyLimit"))
  if limit is None:
    limit = money_val(bare_cfg.get("monthlyLimit"))
  on_demand = money_val(cfg.get("onDemandCap"))
  if on_demand is None:
    on_demand = money_val(bare_cfg.get("onDemandCap"))
  prepaid = money_val(cfg.get("prepaidBalance"))
  od_used = money_val(cfg.get("onDemandUsed"))
  if od_used is None:
    od_used = money_val(bare_cfg.get("onDemandUsed"))

  period = cfg.get("currentPeriod") if isinstance(cfg.get("currentPeriod"), dict) else {}
  period_end = period.get("end") or cfg.get("billingPeriodEnd") or bare_cfg.get("billingPeriodEnd")
  period_start = period.get("start") or cfg.get("billingPeriodStart") or bare_cfg.get("billingPeriodStart")
  period_type = period.get("type")

  utilization = None
  remaining = None
  source = "grok_billing"

  # Credits-first: official Build % (weekly unified pool).
  credit_pct = cfg.get("creditUsagePercent")
  if credit_pct is not None:
    try:
      utilization = round(float(credit_pct), 1)
      remaining = max(0.0, round(100.0 - utilization, 1))
      source = "grok_credits"
    except (TypeError, ValueError):
      utilization = None

  # Legacy money ratio when credits % absent (common for unified prepaid).
  if utilization is None and used is not None and limit and limit > 0:
    utilization = round(100.0 * used / limit, 1)
    remaining = max(0.0, round(100.0 - utilization, 1))
    source = "grok_billing"

  # Prepaid depleted → on-demand fill ratio (still no used/limit).
  if utilization is None and prepaid is not None and prepaid <= 0 and on_demand and on_demand > 0:
    utilization = round(100.0 * (od_used or 0.0) / on_demand, 1)
    remaining = max(0.0, round(100.0 - utilization, 1))
    source = "grok_on_demand"

  # Still have prepaid, no other signal: treat as fully remaining.
  if utilization is None and prepaid is not None and prepaid > 0:
    utilization = 0.0
    remaining = 100.0
    source = "grok_prepaid"

  reset_ts = None
  if period_end:
    try:
      reset_ts = int(datetime.fromisoformat(str(period_end).replace("Z", "+00:00")).timestamp())
    except ValueError:
      reset_ts = None
  start_ts = None
  if period_start:
    try:
      start_ts = int(datetime.fromisoformat(str(period_start).replace("Z", "+00:00")).timestamp())
    except ValueError:
      start_ts = None
  span_sec = (reset_ts - start_ts) if start_ts and reset_ts and reset_ts > start_ts else None

  return {
    "source": source,
    "error": None,
    "utilization": utilization,
    "remaining": remaining,
    "used": used,
    "monthly_limit": limit,
    "on_demand_cap": on_demand,
    "prepaid_balance": prepaid,
    "resets_at": period_end,
    "resets_at_de": format_berlin(period_end),
    "reset_unix": reset_ts,
    "period_start": period_start,
    "period_start_unix": start_ts,
    "period_end": period_end,
    "span_sec": span_sec,
    "period_type": period_type,
  }


def build_error(error: str) -> dict[str, Any]:
  one = " ".join(str(error).split())
  if len(one) > 48:
    one = one[:45] + "..."
  return {
    "source": "grok_billing",
    "error": one,
    "utilization": None,
    "remaining": None,
    "used": None,
    "monthly_limit": None,
    "on_demand_cap": None,
    "prepaid_balance": None,
    "resets_at": None,
    "resets_at_de": None,
    "reset_unix": None,
    "period_start": None,
    "period_start_unix": None,
    "period_end": None,
    "span_sec": None,
    "period_type": None,
  }


def _billing_with_auth(token: str, data: dict[str, Any], scope: str, entry: dict[str, Any], url: str) -> tuple[str, dict[str, Any]]:
  """Fetch url; refresh once on 401/403. Returns (token, body)."""
  try:
    return token, fetch_billing(token, url)
  except RuntimeError as exc:
    msg = str(exc)
    if "http_401" not in msg and "http_403" not in msg:
      raise
    data, scope, entry = load_auth()
    token = refresh_token(data, scope, entry)
    return token, fetch_billing(token, url)


def fetch_usage() -> dict[str, Any]:
  try:
    data, scope, entry = load_auth()
  except RuntimeError as exc:
    return build_error(str(exc))

  token = entry["key"]
  if token_expired(entry):
    try:
      token = refresh_token(data, scope, entry)
    except RuntimeError as exc:
      return build_error(str(exc))

  try:
    token, credits = _billing_with_auth(token, data, scope, entry, CREDITS_URL)
  except RuntimeError as exc:
    return build_error(str(exc))

  bare = None
  cfg = credits.get("config") or {}
  # Bare merge only when credits alone cannot produce a %.
  needs_bare = cfg.get("creditUsagePercent") is None and money_val(cfg.get("used")) is None
  if needs_bare:
    try:
      _, bare = _billing_with_auth(token, data, scope, entry, BARE_URL)
    except RuntimeError:
      bare = None  # still try prepaid / on-demand paths from credits alone

  return build_payload(credits, bare)


def main() -> int:
  try:
    payload = fetch_usage()
  except Exception as exc:  # noqa: BLE001 — bar must always get a Lua table
    payload = build_error(str(exc))
  print(lua_literal(payload))
  return 0 if not payload.get("error") else 1


if __name__ == "__main__":
  sys.exit(main())
