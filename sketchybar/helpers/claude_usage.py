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

from ccu_common import emit, load_cache, save_cache, short_error

OAUTH_URL = "https://api.anthropic.com/api/oauth/usage"
CRED_PATH = Path.home() / ".claude" / ".credentials.json"
KEYCHAIN_SERVICE = "Claude Code-credentials"
CACHE_PATH = Path.home() / ".cache" / "sketchybar" / "claude_usage.json"
CACHE_TTL_SEC = 90
COOLDOWN_PATH = Path.home() / ".cache" / "sketchybar" / "claude_usage.cooldown"
COOLDOWN_SEC = 300  # skip refetch after 429; dual-bar polls otherwise hammer OAuth


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


def reset_unix(iso: str | None) -> int | None:
  if not iso:
    return None
  dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
  return int(dt.timestamp())


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
    "remaining": max(0.0, 100.0 - used),

    "severity": item.get("severity"),
    "resets_at": resets_at,
    "reset_unix": reset_unix(resets_at),
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
    "remaining": max(0.0, 100.0 - used),

    "severity": None,
    "resets_at": resets_at,
    "reset_unix": reset_unix(resets_at),
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
    err = short_error(f"http_{exc.code}: {body[:120]}")
    if exc.code == 429 or "rate_limit" in err:
      start_cooldown()
    return None, err
  except Exception as exc:  # noqa: BLE001
    return None, short_error(str(exc))


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
    "error": short_error(error),
    "limits": [],
    "session": None,
    "weekly": None,
    "scoped": None,
  }


def start_cooldown() -> None:
  try:
    COOLDOWN_PATH.parent.mkdir(parents=True, exist_ok=True)
    COOLDOWN_PATH.write_text(str(datetime.now(timezone.utc).timestamp()))
  except OSError:
    pass


def in_cooldown() -> bool:
  if not COOLDOWN_PATH.is_file():
    return False
  try:
    ts = float(COOLDOWN_PATH.read_text().strip())
  except (OSError, ValueError):
    return False
  age = datetime.now(timezone.utc).timestamp() - ts
  return 0 <= age < COOLDOWN_SEC


def fetch_usage() -> dict[str, Any]:
  if in_cooldown():
    cached = load_cache(CACHE_PATH, CACHE_TTL_SEC)
    if cached is not None:
      return cached
    return build_error("rate_limited")
  token = load_access_token()
  if not token:
    return build_error("no_oauth: Claude Code credentials missing")
  data, err = fetch_oauth_usage(token)
  if data is None:
    # Prefer last-good cache on transient failures (esp. 429).
    cached = load_cache(CACHE_PATH, CACHE_TTL_SEC)
    if cached is not None:
      return cached
    return build_error(err or "fetch_failed")
  payload = build_payload(data)
  save_cache(CACHE_PATH, payload)
  return payload


def main() -> int:
  payload = fetch_usage()
  emit(payload)
  return 0 if not payload.get("error") else 1


if __name__ == "__main__":
  sys.exit(main())
