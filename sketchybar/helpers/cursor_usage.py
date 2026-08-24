#!/usr/bin/env python3
"""Fetch Cursor plan usage for sketchybar ccu.lua.

Auth from Cursor's local store (state.vscdb / auth.json) or the Cursor CLI
(token in the macOS login keychain, user id in ~/.cursor/cli-config.json).
Expired CLI session JWTs are refreshed via api2.cursor.sh and written back
to auth.json atomically.

Besides the period pools (Cursor Models / Other Models), the scan loads the
plan name (GetPlanInfo), account name/email (GetMe), and on-demand spend
figures so the bar popup can show the full subscription picture.
"""

from __future__ import annotations

import json
import math
import os
import sqlite3
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

HOME = Path.home()
CACHE_PATH = HOME / ".cache" / "sketchybar" / "cursor_usage.json"
CACHE_TTL_SEC = 90
API_BASE = "https://api2.cursor.sh/aiserver.v1.DashboardService"
PERIOD_URL = f"{API_BASE}/GetCurrentPeriodUsage"
PLAN_URL = f"{API_BASE}/GetPlanInfo"
ME_URL = f"{API_BASE}/GetMe"
SUMMARY_URL = "https://cursor.com/api/usage-summary"
LEGACY_URL = "https://cursor.com/api/usage"
TOKEN_URL = "https://api2.cursor.sh/oauth/token"
CLIENT_ID = "KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB"

VSCDB_PATHS = (
  HOME / "Library" / "Application Support" / "Cursor" / "User" / "globalStorage" / "state.vscdb",
  HOME / ".config" / "Cursor" / "User" / "globalStorage" / "state.vscdb",
)
AUTH_JSON_PATHS = (
  HOME / ".config" / "cursor" / "auth.json",
  HOME / ".cursor" / "auth.json",
)
CLI_CONFIG_PATH = HOME / ".cursor" / "cli-config.json"
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


def cents_or_none(*values: Any) -> int | None:
  for value in values:
    if value is None or value == "":
      continue
    try:
      number = float(value)
    except (TypeError, ValueError):
      continue
    if not math.isfinite(number):
      continue
    return int(round(number))
  return None


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


def auth_from_json() -> dict[str, Any] | None:
  for path in AUTH_JSON_PATHS:
    if not path.is_file():
      continue
    try:
      data = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError):
      continue
    if not isinstance(data, dict):
      continue
    nested = data.get("auth") if isinstance(data.get("auth"), dict) else {}
    token = data.get("accessToken") or data.get("access_token") or nested.get("accessToken")
    refresh = data.get("refreshToken") or data.get("refresh_token") or nested.get("refreshToken")
    uid = data.get("userId") or data.get("user_id") or data.get("cachedUserId") or nested.get("userId")
    uid = find_user_id(uid) or find_user_id(data)
    if token:
      return {
        "token": str(token),
        "uid": uid,
        "refresh_token": str(refresh or ""),
        "auth_path": path,
        "auth_data": data,
      }
  return None


def auth_from_vscdb() -> dict[str, Any] | None:
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
    token = kv.get("cursorAuth/accessToken")
    uid = None
    for key in ("cursorAuth/cachedUserId", "cursorAuth/userId", "cursorAuth/authId"):
      found = find_user_id(kv.get(key))
      if found:
        uid = found
        break
    if token:
      return {
        "token": str(token),
        "uid": uid,
        "refresh_token": "",
        "auth_path": None,
        "auth_data": None,
        "membership": kv.get("cursorAuth/stripeMembershipType") or "",
        "cached_email": kv.get("cursorAuth/cachedEmail") or "",
      }
  return None


def auth_from_cli() -> dict[str, Any] | None:
  """Cursor CLI: access token in the login keychain, user id in cli-config.json."""
  try:
    proc = subprocess.run(
      ["security", "find-generic-password", "-s", "cursor-access-token", "-a", "cursor-user", "-w"],
      capture_output=True,
      text=True,
      timeout=10,
    )
  except (OSError, subprocess.TimeoutExpired):
    return None
  token = proc.stdout.strip() if proc.returncode == 0 else None
  if not token:
    return None
  uid = None
  if CLI_CONFIG_PATH.is_file():
    try:
      uid = find_user_id(json.loads(CLI_CONFIG_PATH.read_text()))
    except (json.JSONDecodeError, OSError):
      pass
  return {"token": token, "uid": uid, "refresh_token": "", "auth_path": None, "auth_data": None}


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


def load_auth() -> dict[str, Any]:
  creds = auth_from_json() or auth_from_vscdb() or auth_from_cli()
  if not creds:
    raise RuntimeError("no_auth: open Cursor and sign in")
  if not creds.get("uid"):
    creds["uid"] = user_id_from_sentry()
  return creds


def save_auth(creds: dict[str, Any]) -> None:
  """Atomically write refreshed tokens back to CLI auth.json (mode 0600)."""
  path = creds.get("auth_path")
  data = creds.get("auth_data")
  if path is None or not isinstance(data, dict):
    return
  data = dict(data)
  data["accessToken"] = creds["token"]
  if creds.get("refresh_token"):
    data["refreshToken"] = creds["refresh_token"]
  creds["auth_data"] = data

  try:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".auth.", suffix=".tmp", dir=str(path.parent))
    try:
      with os.fdopen(fd, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")
      os.chmod(tmp, 0o600)
      os.replace(tmp, path)
    except Exception:
      try:
        os.unlink(tmp)
      except OSError:
        pass
      raise
  except Exception as exc:
    sys.stderr.write(f"cursor_usage: could not write auth.json: {exc}\n")


def refresh_token(creds: dict[str, Any]) -> bool:
  refresh = str(creds.get("refresh_token") or "").strip()
  if not refresh:
    return False

  body = json.dumps({
    "grant_type": "refresh_token",
    "client_id": CLIENT_ID,
    "refresh_token": refresh,
  }).encode()
  req = urllib.request.Request(
    TOKEN_URL,
    data=body,
    method="POST",
    headers={
      "Content-Type": "application/json",
      "Accept": "application/json",
      "User-Agent": "sketchybar-ccu",
    },
  )
  try:
    with urllib.request.urlopen(req, timeout=20) as resp:
      payload = json.loads(resp.read())
  except Exception:
    return False

  if not isinstance(payload, dict) or payload.get("shouldLogout") is True:
    return False
  access = payload.get("access_token") or payload.get("accessToken")
  if not access:
    return False

  creds["token"] = str(access)
  new_refresh = payload.get("refresh_token") or payload.get("refreshToken")
  if new_refresh:
    creds["refresh_token"] = str(new_refresh)
  save_auth(creds)
  return True


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


def with_auth_retry(creds: dict[str, Any], fetch):
  """Call fetch(creds); on 401/403 refresh the CLI token once and retry."""
  try:
    return fetch(creds)
  except RuntimeError as exc:
    msg = str(exc)
    if "http_401" not in msg and "http_403" not in msg:
      raise
    if not refresh_token(creds):
      raise
    return fetch(creds)


def plan_label(raw: dict[str, Any]) -> str | None:
  for key in ("individualMembershipType", "membershipType", "planName", "plan"):
    v = raw.get(key)
    if isinstance(v, str) and v:
      return v.replace("_", " ").replace("pro plus", "Pro+").title() if v.islower() else v
  return None


def fetch_plan_name(creds: dict[str, Any]) -> str:
  payload = http_json(PLAN_URL, creds["token"], creds.get("uid"), method="POST")
  info = payload.get("planInfo") if isinstance(payload, dict) else None
  if not isinstance(info, dict):
    return ""
  return str(info.get("planName") or "").strip()


def fetch_account(creds: dict[str, Any]) -> tuple[str, str]:
  payload = http_json(ME_URL, creds["token"], creds.get("uid"), method="POST")
  if not isinstance(payload, dict):
    return "", ""
  email = str(payload.get("email") or "").strip()
  name = str(payload.get("name") or "").strip()
  if not name:
    first = str(payload.get("firstName") or payload.get("given_name") or "").strip()
    last = str(payload.get("lastName") or payload.get("family_name") or "").strip()
    name = " ".join(part for part in (first, last) if part)
  return name, email


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

  plan_dict = pu if isinstance(pu, dict) else {}
  included = cents_or_none(plan_dict.get("includedSpend"), raw.get("includedSpend"))
  spend_limit = cents_or_none(
    plan_dict.get("spendLimit"), plan_dict.get("limit"), raw.get("spendLimit")
  )
  spend_remaining = cents_or_none(
    plan_dict.get("spendRemaining"), plan_dict.get("remaining"), raw.get("spendRemaining")
  )

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
    "email": None,
    "name": None,
    "included_spend_cents": included,
    "spend_limit_cents": spend_limit,
    "spend_remaining_cents": spend_remaining,
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
    "email": None,
    "name": None,
    "included_spend_cents": None,
    "spend_limit_cents": None,
    "spend_remaining_cents": None,
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


def fetch_raw(creds: dict[str, Any]) -> dict[str, Any]:
  token, uid = creds["token"], creds.get("uid")
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
    creds = load_auth()
  except RuntimeError as exc:
    cached = load_cache()
    return cached if cached is not None else build_error(str(exc))
  try:
    raw = with_auth_retry(creds, fetch_raw)
  except RuntimeError as exc:
    cached = load_cache()
    return cached if cached is not None else build_error(str(exc))
  payload = build_payload(raw)

  # Plan name and account identity are best-effort; period usage still stands.
  try:
    plan = with_auth_retry(creds, fetch_plan_name)
    if plan:
      payload["plan"] = plan
  except RuntimeError:
    pass
  if not payload.get("plan") and creds.get("membership"):
    payload["plan"] = plan_label({"membershipType": str(creds["membership"])})
  try:
    name, email = with_auth_retry(creds, fetch_account)
    payload["name"] = name or None
    payload["email"] = email or None
  except RuntimeError:
    pass
  if not payload.get("email") and creds.get("cached_email"):
    payload["email"] = str(creds["cached_email"])

  save_cache(payload)
  return payload


def main() -> int:
  payload = fetch_usage()
  print(lua_literal(payload))
  return 0 if not payload.get("error") else 1


if __name__ == "__main__":
  sys.exit(main())
