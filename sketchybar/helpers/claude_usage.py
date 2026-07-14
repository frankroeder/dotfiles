#!/usr/bin/env python3
"""Fetch Claude OAuth usage for sketchybar ccu.lua.

Auth: Claude Code OAuth from Keychain service "Claude Code-credentials"
or ~/.claude/.credentials.json (claudeAiOauth.accessToken).
"""

from __future__ import annotations

import json
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

OAUTH_URL = "https://api.anthropic.com/api/oauth/usage"
CRED_PATH = Path.home() / ".claude" / ".credentials.json"
KEYCHAIN_SERVICE = "Claude Code-credentials"


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
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'
  if isinstance(value, dict):
    parts = [f"{k}={lua_literal(v)}" for k, v in value.items()]
    return "{" + ",".join(parts) + "}"
  if isinstance(value, list):
    return "{" + ",".join(lua_literal(v) for v in value) + "}"
  return lua_literal(str(value))


def token_from_json(data: dict[str, Any]) -> str | None:
  oauth = data.get("claudeAiOauth")
  if isinstance(oauth, dict) and oauth.get("accessToken"):
    return str(oauth["accessToken"])
  if data.get("access_token"):
    return str(data["access_token"])
  return None


def load_access_token() -> str | None:
  # Keychain first (macOS Claude Code)
  try:
    out = subprocess.check_output(
      ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
      stderr=subprocess.DEVNULL,
      text=True,
    ).strip()
    token = token_from_json(json.loads(out))
    if token:
      return token
  except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError, OSError):
    pass

  if CRED_PATH.is_file():
    try:
      return token_from_json(json.loads(CRED_PATH.read_text()))
    except (json.JSONDecodeError, OSError):
      return None
  return None


def format_reset(iso: str | None) -> str | None:
  if not iso:
    return None
  dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
  secs = (dt - datetime.now(timezone.utc)).total_seconds()
  if secs <= 0:
    return "now"
  days = int(secs // 86400)
  hours = int((secs % 86400) // 3600)
  minutes = int((secs % 3600) // 60)
  if days > 0:
    return f"{days}d {hours}h"
  if hours > 0:
    return f"{hours}h {minutes}m"
  return f"{minutes}m"


def limit_label(item: dict[str, Any]) -> str:
  scope = item.get("scope") or {}
  model = (scope.get("model") or {}).get("display_name") if isinstance(scope, dict) else None
  if model:
    return str(model)
  kind = item.get("kind") or ""
  if kind == "session":
    return "Session"
  if kind == "weekly_all":
    return "Weekly"
  if kind == "weekly_scoped":
    return "Scoped"
  return str(kind)


def parse_limit(item: dict[str, Any]) -> dict[str, Any] | None:
  kind = item.get("kind")
  percent = item.get("percent")
  if kind is None or percent is None:
    return None
  used = float(percent)
  resets_at = item.get("resets_at")
  return {
    "kind": str(kind),
    "group": item.get("group"),
    "label": limit_label(item),
    "used": used,
    "remaining": 100.0 - used,
    "severity": item.get("severity"),
    "resets_at": resets_at,
    "reset_text": format_reset(resets_at),
    "active": bool(item.get("is_active")),
    "model": ((item.get("scope") or {}).get("model") or {}).get("display_name")
    if isinstance(item.get("scope"), dict)
    else None,
  }


def parse_window(data: dict[str, Any], key: str, label: str, kind: str) -> dict[str, Any] | None:
  block = data.get(key)
  if not isinstance(block, dict) or block.get("utilization") is None:
    return None
  used = float(block["utilization"])
  resets_at = block.get("resets_at")
  return {
    "kind": kind,
    "group": None,
    "label": label,
    "used": used,
    "remaining": 100.0 - used,
    "severity": None,
    "resets_at": resets_at,
    "reset_text": format_reset(resets_at),
    "active": kind == "session",
    "model": None,
  }


def fetch_oauth_usage(token: str) -> tuple[dict[str, Any] | None, str | None]:
  req = urllib.request.Request(
    OAUTH_URL,
    headers={
      "Authorization": f"Bearer {token}",
      "anthropic-beta": "oauth-2025-04-20",
      "Accept": "application/json",
    },
  )
  try:
    with urllib.request.urlopen(req, timeout=20) as resp:
      return json.loads(resp.read()), None
  except urllib.error.HTTPError as exc:
    body = exc.read().decode("utf-8", errors="replace")
    return None, f"http_{exc.code}: {body[:120]}"
  except Exception as exc:  # noqa: BLE001
    return None, str(exc)


def build_payload(data: dict[str, Any]) -> dict[str, Any]:
  limits: list[dict[str, Any]] = []
  for item in data.get("limits") or []:
    if isinstance(item, dict):
      lim = parse_limit(item)
      if lim:
        limits.append(lim)

  # Prefer limits[]; fall back to top-level windows.
  if not limits:
    for key, label, kind in (
      ("five_hour", "Session", "session"),
      ("seven_day", "Weekly", "weekly_all"),
      ("seven_day_opus", "Opus", "weekly_opus"),
      ("seven_day_sonnet", "Sonnet", "weekly_sonnet"),
    ):
      win = parse_window(data, key, label, kind)
      if win:
        limits.append(win)

  by_kind = {lim["kind"]: lim for lim in limits}
  scoped = next((lim for lim in limits if lim["kind"] == "weekly_scoped"), None)

  return {
    "source": "oauth",
    "error": None,
    "limits": limits,
    "session": by_kind.get("session"),
    "weekly": by_kind.get("weekly_all"),
    "scoped": scoped,
  }


def build_error(error: str) -> dict[str, Any]:
  return {
    "source": "oauth",
    "error": error,
    "limits": [],
    "session": None,
    "weekly": None,
    "scoped": None,
  }


def fetch_usage() -> dict[str, Any]:
  token = load_access_token()
  if not token:
    return build_error("no_oauth: Claude Code credentials missing")
  data, err = fetch_oauth_usage(token)
  if data is None:
    return build_error(err or "fetch_failed")
  return build_payload(data)


def main() -> int:
  payload = fetch_usage()
  print(lua_literal(payload))
  return 0 if not payload.get("error") else 1


if __name__ == "__main__":
  sys.exit(main())
