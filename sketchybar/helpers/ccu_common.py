#!/usr/bin/env python3
"""Shared plumbing for the CCU usage helpers.

claude_usage / cursor_usage / grok_usage each talk to a different API but agree
on how they hand results back (a Lua literal for sketchybar's `sbar.exec`, JSON
under --json for asahi-ccu), how they cache, and how they persist refreshed
tokens. That common half lives here so a fix lands once.

Import-safe from any cwd: the helpers are run as scripts, so sys.path[0] is this
directory; asahi-ccu prepends it explicitly.
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable


def lua_literal(value: Any) -> str:
  """Render a payload as a Lua table literal for sbar.exec's callback."""
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


def emit(payload: dict[str, Any]) -> None:
  """Lua literal for sketchybar, JSON for asahi-ccu (--json)."""
  if "--json" in sys.argv:
    json.dump(payload, sys.stdout, ensure_ascii=True)
    sys.stdout.write("\n")
  else:
    print(lua_literal(payload))


def short_error(msg: Any) -> str:
  """Collapse API error bodies to a single short line for the popup."""
  one = " ".join(str(msg).split())
  low = one.lower()
  if "rate_limit" in low or "http_429" in low:
    return "rate_limited"
  if len(one) > 48:
    return one[:45] + "..."
  return one


def load_cache(path: Path, ttl_sec: float) -> dict[str, Any] | None:
  """Last good payload, if it is younger than 4x the poll TTL. Errors never cache."""
  if not path.is_file():
    return None
  try:
    raw = json.loads(path.read_text())
  except (json.JSONDecodeError, OSError):
    return None
  if not isinstance(raw, dict) or not isinstance(raw.get("payload"), dict):
    return None
  age = datetime.now(timezone.utc).timestamp() - float(raw.get("ts") or 0)
  if age < 0 or age > ttl_sec * 4:
    return None
  payload = raw["payload"]
  if payload.get("error"):
    return None
  return payload


def save_cache(path: Path, payload: dict[str, Any]) -> None:
  if payload.get("error"):
    return
  try:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"ts": datetime.now(timezone.utc).timestamp(), "payload": payload}))
  except OSError:
    pass


def with_auth_retry(creds: dict[str, Any], fetch: Callable, refresh: Callable):
  """Call fetch(creds); on 401/403 refresh the token once and retry.

  `refresh` may signal failure either by raising or by returning False.
  """
  try:
    return fetch(creds)
  except RuntimeError as exc:
    msg = str(exc)
    if "http_401" not in msg and "http_403" not in msg:
      raise
    if refresh(creds) is False:
      raise
    return fetch(creds)


def write_json_atomic(path: Path, data: dict[str, Any], label: str) -> None:
  """Replace path with `data` via a same-dir temp file, mode 0600.

  Non-fatal: a token that could not be persisted still works for this scan.
  """
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
    sys.stderr.write(f"{label}: could not write {path.name}: {exc}\n")
