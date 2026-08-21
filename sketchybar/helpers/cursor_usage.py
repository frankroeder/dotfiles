#!/usr/bin/env python3
"""Fetch Cursor plan usage for sketchybar ccu.lua.

Auth from Cursor's local store (state.vscdb / auth.json), same session the IDE uses.
No Omarchy collectors.
"""

from __future__ import annotations

import json
import sqlite3
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

HOME = Path.home()
CACHE_PATH = HOME / ".cache" / "sketchybar" / "cursor_usage.json"
CACHE_TTL_SEC = 90
SUMMARY_URL = "https://cursor.com/api/usage-summary"
LEGACY_URL = "https://cursor.com/api/usage"
PERIOD_URL = "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage"

VSCDB_PATHS = (
  HOME / "Library" / "Application Support" / "Cursor" / "User" / "globalStorage" / "state.vscdb",
  HOME / ".config" / "Cursor" / "User" / "globalStorage" / "state.vscdb",
)
AUTH_JSON_PATHS = (
  HOME / ".config" / "cursor" / "auth.json",
  HOME / ".cursor" / "auth.json",
)
SENTRY_PATHS = (
  HOME / "Library" / "Application Support" / "Cursor" / "sentry" / "scope_v3.json",
  HOME / "Library" / "Application Support" / "Cursor" / "sentry" / "session.json",
  HOME / ".config" / "Cursor" / "sentry" / "scope_v3.json",
)


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


def short_error(msg: str) -> str:
  one = " ".join(str(msg).split())
  if len(one) > 48:
    return one[:45] + "..."
  return one


def parse_unix(value: Any) -> int | None:
  if value is None or value == "":
    return None
  if isinstance(value, (int, float)):
    n = float(value)
    if n > 1e12:
      n = n / 1000.0
    return int(n)
  s = str(value).strip()
  if s.isdigit():
    n = int(s)
    if n > 1e12:
      n //= 1000
    return n
  try:
    return int(datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp())
  except ValueError:
    return None


def pct(value: Any) -> float | None:
  if value is None:
    return None
  try:
    n = float(value)
  except (TypeError, ValueError):
    return None
  if n < 0:
    return 0.0
  return n


def find_user_id(obj: Any) -> str | None:
  if isinstance(obj, str):
    if obj.startswith("user_") and len(obj) > 20:
      return obj
    if "|" in obj:
      for part in obj.split("|"):
        if part.startswith("user_") and len(part) > 20:
          return part
    return None
  if isinstance(obj, dict):
    for v in obj.values():
      found = find_user_id(v)
      if found:
        return found
  if isinstance(obj, list):
    for v in obj:
      found = find_user_id(v)
      if found:
        return found
  return None


def auth_from_json() -> tuple[str | None, str | None]:
  for path in AUTH_JSON_PATHS:
    if not path.is_file():
      continue
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
      continue
    nested = data.get("auth") if isinstance(data.get("auth"), dict) else {}
    token = data.get("accessToken") or data.get("access_token") or nested.get("accessToken")
    uid = data.get("userId") or data.get("user_id") or data.get("cachedUserId") or nested.get("userId")
    uid = find_user_id(uid) or find_user_id(data)
    if token:
      return str(token), uid
  return None, None


def auth_from_vscdb() -> tuple[str | None, str | None]:
  token = uid = None
  for db in VSCDB_PATHS:
    if not db.is_file():
      continue
    con = sqlite3.connect(str(db))
    try:
      rows = con.execute(
        "SELECT key, value FROM ItemTable WHERE key LIKE 'cursorAuth/%'"
      ).fetchall()
    finally:
      con.close()
    kv = {str(k): v for k, v in rows}
    token = kv.get("cursorAuth/accessToken") or token
    for key in ("cursorAuth/cachedUserId", "cursorAuth/userId", "cursorAuth/authId"):
      found = find_user_id(kv.get(key))
      if found:
        uid = found
        break
    if token:
      return str(token), uid
  return None, None


def user_id_from_sentry() -> str | None:
  for path in SENTRY_PATHS:
    if not path.is_file():
      continue
    try:
      data = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError):
      continue
    found = find_user_id(data)
    if found:
      return found
  return None


def load_auth() -> tuple[str, str | None]:
  token, uid = auth_from_json()
  if not token:
    token, uid = auth_from_vscdb()
  if not uid:
    uid = user_id_from_sentry()
  if not token:
    raise RuntimeError("no_auth: open Cursor and sign in")
  return token, uid


def http_json(url: str, token: str, uid: str | None, method: str = "GET") -> dict[str, Any]:
  headers = {
    "Authorization": f"Bearer {token}",
    "Accept": "application/json",
    "User-Agent": "sketchybar-ccu",
  }
  if uid:
    headers["Cookie"] = f"WorkosCursorSessionToken={uid}%3A%3A{token}"
  body = b"{}" if method == "POST" else None
  if method == "POST":
    headers["Content-Type"] = "application/json"
    headers["Connect-Protocol-Version"] = "1"
  req = urllib.request.Request(url, data=body, headers=headers, method=method)
  try:
    with urllib.request.urlopen(req, timeout=20) as resp:
      return json.loads(resp.read())
  except urllib.error.HTTPError as exc:
    raw = exc.read().decode("utf-8", errors="replace")
    raise RuntimeError(f"http_{exc.code}: {raw[:120]}") from exc
  except Exception as exc:
    raise RuntimeError(f"network: {exc}") from exc


def plan_label(raw: dict[str, Any]) -> str | None:
  for key in ("individualMembershipType", "membershipType", "planName", "plan"):
    v = raw.get(key)
    if isinstance(v, str) and v:
      return v.replace("_", " ").replace("pro plus", "Pro+").title() if v.islower() else v
  return None


def build_payload(raw: dict[str, Any]) -> dict[str, Any]:
  """Map Cursor usage JSON → Lua fields. Accepts usage-summary / period / legacy shapes."""
  pu = raw.get("planUsage") if isinstance(raw.get("planUsage"), dict) else raw
  total = pct(pu.get("totalPercentUsed") if isinstance(pu, dict) else None)
  if total is None:
    total = pct(raw.get("totalPercentUsed"))
  api = pct(pu.get("apiPercentUsed") if isinstance(pu, dict) else None)
  if api is None:
    api = pct(raw.get("apiPercentUsed"))
  auto = pct(pu.get("autoPercentUsed") if isinstance(pu, dict) else None)
  if auto is None:
    auto = pct(raw.get("autoPercentUsed"))

  gpt4 = raw.get("gpt-4") if isinstance(raw.get("gpt-4"), dict) else None
  if total is None and gpt4 and gpt4.get("maxRequestUsage"):
    cap = float(gpt4["maxRequestUsage"])
    if cap > 0:
      total = 100.0 * float(gpt4.get("numRequests") or 0) / cap

  used_pct = total if total is not None else api
  end = parse_unix(raw.get("billingCycleEnd") or (pu.get("billingCycleEnd") if isinstance(pu, dict) else None))
  start = parse_unix(
    raw.get("billingCycleStart")
    or raw.get("startOfMonth")
    or (pu.get("billingCycleStart") if isinstance(pu, dict) else None)
  )
  span = (end - start) if start and end and end > start else None

  limits = []
  if auto is not None:
    limits.append({
      "kind": "cursor_auto",
      "label": "Cursor Models",
      "used": auto,
      "remaining": max(0.0, 100.0 - auto),
      "reset_unix": end,
    })
  if api is not None:
    limits.append({
      "kind": "cursor_api",
      "label": "Other Models",
      "used": api,
      "remaining": max(0.0, 100.0 - api),
      "reset_unix": end,
    })

  return {
    "source": "cursor",
    "error": None,
    "utilization": used_pct,
    "remaining": None if used_pct is None else max(0.0, 100.0 - used_pct),
    "reset_unix": end,
    "resets_at": None,
    "span_sec": span,
    "period_start_unix": start,
    "plan": plan_label(raw),
    "limits": limits,
  }


def build_error(error: str) -> dict[str, Any]:
  return {
    "source": "cursor",
    "error": short_error(error),
    "utilization": None,
    "remaining": None,
    "reset_unix": None,
    "resets_at": None,
    "span_sec": None,
    "period_start_unix": None,
    "plan": None,
    "limits": [],
  }


def load_cache() -> dict[str, Any] | None:
  if not CACHE_PATH.is_file():
    return None
  try:
    raw = json.loads(CACHE_PATH.read_text())
  except (json.JSONDecodeError, OSError):
    return None
  if not isinstance(raw, dict) or not isinstance(raw.get("payload"), dict):
    return None
  age = datetime.now(timezone.utc).timestamp() - float(raw.get("ts") or 0)
  if age < 0 or age > CACHE_TTL_SEC * 4:
    return None
  payload = raw["payload"]
  if payload.get("error"):
    return None
  return payload


def save_cache(payload: dict[str, Any]) -> None:
  if payload.get("error"):
    return
  try:
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    CACHE_PATH.write_text(json.dumps({"ts": datetime.now(timezone.utc).timestamp(), "payload": payload}))
  except OSError:
    pass


def fetch_raw(token: str, uid: str | None) -> dict[str, Any]:
  last_err = None
  try:
    return http_json(PERIOD_URL, token, uid, method="POST")
  except RuntimeError as exc:
    last_err = exc
  try:
    return http_json(SUMMARY_URL, token, uid)
  except RuntimeError as exc:
    last_err = exc
  if uid:
    try:
      return http_json(f"{LEGACY_URL}?user={uid}", token, uid)
    except RuntimeError as exc:
      last_err = exc
  raise last_err or RuntimeError("fetch_failed")


def fetch_usage() -> dict[str, Any]:
  try:
    token, uid = load_auth()
  except RuntimeError as exc:
    cached = load_cache()
    return cached if cached is not None else build_error(str(exc))
  try:
    raw = fetch_raw(token, uid)
  except RuntimeError as exc:
    cached = load_cache()
    return cached if cached is not None else build_error(str(exc))
  payload = build_payload(raw)
  save_cache(payload)
  return payload


def main() -> int:
  payload = fetch_usage()
  print(lua_literal(payload))
  return 0 if not payload.get("error") else 1


if __name__ == "__main__":
  sys.exit(main())
