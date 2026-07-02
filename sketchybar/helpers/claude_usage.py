#!/usr/bin/env python3
"""Fetch Claude usage and print a Lua table for sketchybar ccu.lua.

Auth: session key from ~/.config/claude-session-key, org id from
~/.config/claude-org-id. No browser cookie reading.
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

BERLIN = ZoneInfo("Europe/Berlin")

CONFIG = Path.home() / ".config"
SESSION_KEY_PATH = CONFIG / "claude-session-key"
ORG_ID_PATH = CONFIG / "claude-org-id"
OAUTH_URL = "https://api.anthropic.com/api/oauth/usage"


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


def read_session_key() -> str | None:
    if not SESSION_KEY_PATH.is_file():
        return None
    key = SESSION_KEY_PATH.read_text().strip()
    return key or None


def read_org_id() -> str | None:
    if not ORG_ID_PATH.is_file():
        return None
    org = ORG_ID_PATH.read_text().strip()
    return org or None


def token_kind(key: str) -> str:
    if key.startswith("sk-ant-sid"):
        return "web_session"
    if key.startswith(("sk-ant-oat", "sk-ant-ort")):
        return "oauth"
    if key.startswith("sk-ant-rh"):
        return "routing"
    return "unknown"


def fetch_oauth_usage(token: str) -> tuple[dict[str, Any] | None, str | None]:
    req = urllib.request.Request(
        OAUTH_URL,
        headers={
            "Authorization": f"Bearer {token}",
            "anthropic-beta": "oauth-2025-04-20",
            "anthropic-version": "2023-06-01",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read()), None
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            err = json.loads(body).get("error", {})
            code = err.get("error_code") or err.get("type") or f"http_{exc.code}"
            msg = err.get("message") or body[:120]
        except json.JSONDecodeError:
            code, msg = f"http_{exc.code}", body[:120]
        return None, f"{code}: {msg}"
    except Exception as exc:  # noqa: BLE001
        return None, str(exc)


def fetch_web_usage(session_key: str, org_id: str) -> tuple[dict[str, Any] | None, str | None]:
    url = f"https://claude.ai/api/organizations/{org_id}/usage"
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "content-type": "application/json",
            "anthropic-client-platform": "web_claude_ai",
            "anthropic-client-version": "1.0.0",
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
            ),
            "origin": "https://claude.ai",
            "referer": "https://claude.ai/settings/usage",
            "Cookie": f"sessionKey={session_key}",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            body = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        if "Just a moment" in body or "<!DOCTYPE html>" in body:
            return None, "cloudflare_challenge: refresh sessionKey in ~/.config/claude-session-key"
        try:
            err = json.loads(body).get("error", {})
            code = err.get("error_code") or err.get("type") or f"http_{exc.code}"
            msg = err.get("message") or body[:120]
        except json.JSONDecodeError:
            code, msg = f"http_{exc.code}", body[:120]
        return None, f"{code}: {msg}"
    except Exception as exc:  # noqa: BLE001
        return None, str(exc)

    if "Just a moment" in body or "<!DOCTYPE html>" in body:
        return None, "cloudflare_challenge: refresh sessionKey in ~/.config/claude-session-key"
    try:
        return json.loads(body), None
    except json.JSONDecodeError:
        return None, "invalid_json: response was not usage JSON"


def routing_key_hint(key: str, err: str | None) -> str | None:
    if not key.startswith("sk-ant-rh"):
        return None
    if err and not any(
        token in err
        for token in ("account_session_invalid", "permission_error", "Invalid authorization")
    ):
        return None
    return (
        "session_key_type_mismatch: ~/.config/claude-session-key has a routing token "
        "(sk-ant-rh); paste the sessionKey cookie (sk-ant-sid01) from claude.ai DevTools"
    )


def format_berlin(iso: str | None) -> str | None:
    if not iso:
        return None
    dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
    local = dt.astimezone(BERLIN)
    return local.strftime("%Y-%m-%d %H:%M (%Z)")


def enrich_usage_blocks(data: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key in ("five_hour", "seven_day"):
        block = dict(data.get(key) or {})
        resets_at = block.get("resets_at")
        if resets_at:
            block["resets_at_de"] = format_berlin(resets_at)
        out[key] = block
    out["extra_usage"] = data.get("extra_usage") or {}
    return out


def build_payload(data: dict[str, Any], source: str) -> dict[str, Any]:
    blocks = enrich_usage_blocks(data)
    return {
        "source": source,
        "error": None,
        "five_hour": blocks["five_hour"],
        "seven_day": blocks["seven_day"],
        "extra_usage": blocks["extra_usage"],
    }


def build_error(error: str, source: str) -> dict[str, Any]:
    return {
        "source": source,
        "error": error,
        "five_hour": {},
        "seven_day": {},
        "extra_usage": {},
    }


def fetch_usage() -> dict[str, Any]:
    session_key = read_session_key()
    if not session_key:
        return build_error(
            "missing_session_key: create ~/.config/claude-session-key",
            "session_key",
        )

    kind = token_kind(session_key)
    org = read_org_id()
    errors: list[str] = []

    def try_web() -> dict[str, Any] | None:
        if not org:
            errors.append("missing_org: create ~/.config/claude-org-id")
            return None
        data, err = fetch_web_usage(session_key, org)
        if data is not None:
            return build_payload(data, "session_key_web")
        if err:
            hint = routing_key_hint(session_key, err)
            errors.append(hint or err)
        return None

    def try_oauth() -> dict[str, Any] | None:
        data, err = fetch_oauth_usage(session_key)
        if data is not None:
            return build_payload(data, "session_key_oauth")
        if err:
            errors.append(err)
        return None

    if kind == "oauth":
        payload = try_oauth() or try_web()
    elif kind == "web_session":
        payload = try_web()
    else:
        payload = try_web() or try_oauth()

    if payload is not None:
        return payload
    return build_error(errors[0] if errors else "fetch_failed", "session_key")


def main() -> int:
    payload = fetch_usage()
    print(lua_literal(payload))
    return 0 if not payload.get("error") else 1


if __name__ == "__main__":
    sys.exit(main())
