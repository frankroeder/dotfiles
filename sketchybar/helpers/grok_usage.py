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
BILLING_URL = "https://cli-chat-proxy.grok.com/v1/billing"
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
  except Exception as exc:  # noqa: BLE001
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


def fetch_billing(token: str) -> dict[str, Any]:
  req = urllib.request.Request(
    BILLING_URL,
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
  except Exception as exc:  # noqa: BLE001 — network DNS/timeout → soft error
    raise RuntimeError(f"network: {exc}") from exc


def build_payload(data: dict[str, Any]) -> dict[str, Any]:
  cfg = data.get("config") or {}
  used = money_val(cfg.get("used"))
  limit = money_val(cfg.get("monthlyLimit"))
  on_demand = money_val(cfg.get("onDemandCap"))
  period_end = cfg.get("billingPeriodEnd")
  period_start = cfg.get("billingPeriodStart")

  utilization = None
  remaining = None
  if used is not None and limit and limit > 0:
    utilization = round(100.0 * used / limit, 1)
    # Clamp remaining so over-limit never yields negative % in the bar.
    remaining = max(0.0, round(100.0 - utilization, 1))

  return {
    "source": "grok_billing",
    "error": None,
    "utilization": utilization,
    "remaining": remaining,
    "used": used,
    "monthly_limit": limit,
    "on_demand_cap": on_demand,
    "resets_at": period_end,
    "resets_at_de": format_berlin(period_end),
    "period_start": period_start,
    "period_end": period_end,
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
    "resets_at": None,
    "resets_at_de": None,
    "period_start": None,
    "period_end": None,
  }


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
    billing = fetch_billing(token)
  except RuntimeError as exc:
    msg = str(exc)
    if "http_401" in msg or "http_403" in msg:
      try:
        data, scope, entry = load_auth()
        token = refresh_token(data, scope, entry)
        billing = fetch_billing(token)
      except RuntimeError as retry_exc:
        return build_error(str(retry_exc))
    else:
      return build_error(msg)

  return build_payload(billing)


def main() -> int:
  payload = fetch_usage()
  print(lua_literal(payload))
  return 0 if not payload.get("error") else 1


if __name__ == "__main__":
  sys.exit(main())
