#!/usr/bin/env python3
"""Fetch SuperGrok weekly usage for sketchybar ccu.lua.

SuperGrok paid plans share one weekly usage pool across products (Chat,
Grok Build, Imagine, Voice, API). The pool percent, reset time, and the
per-product split come from the gRPC-web GetGrokCreditsConfig endpoint on
grok.com — the same data as grok.com Settings → Usage. Tier label, account
email/name, and the subscription rebill date come from the Grok
subscription APIs.

Auth: OIDC access token from ~/.grok/auth.json (same store as `grok login`).
Expired tokens are refreshed via auth.x.ai and written back atomically.
"""

from __future__ import annotations

import base64
import json
import os
import struct
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

AUTH_PATH = Path.home() / ".grok" / "auth.json"
CREDITS_URL = "https://grok.com/grok_api_v2.GrokBuildBilling/GetGrokCreditsConfig"
# Same settings surface the Grok CLI uses for subscription_tier_display.
SETTINGS_URL = "https://cli-chat-proxy.grok.com/v1/settings"
USER_URL = "https://cli-chat-proxy.grok.com/v1/user"
SUBSCRIPTIONS_URL = "https://grok.com/rest/subscriptions"
TOKEN_URL = "https://auth.x.ai/oauth2/token"
USER_AGENT = "sketchybar-ccu/1.0"

# Product labels for the credit-usage category enum (field 1.7). Confirmed
# against grok.com Settings → Usage: type 4 → Chat, type 2 → Grok Build.
CATEGORY_LABELS = {
  1: "API",
  2: "Grok Build",
  3: "Imagine",
  4: "Chat",
  5: "Voice",
}

# Legend order matching the official Usage card (Chat, then Grok Build, …).
CATEGORY_ORDER = {4: 0, 2: 1, 1: 2, 3: 3, 5: 4}


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


def short_error(msg: str) -> str:
  one = " ".join(str(msg).split())
  if len(one) > 48:
    return one[:45] + "..."
  return one


def parse_iso(value: Any) -> datetime | None:
  text = str(value or "").strip()
  if not text:
    return None
  try:
    if text.endswith("Z"):
      text = text[:-1] + "+00:00"
    dt = datetime.fromisoformat(text)
    if dt.tzinfo is None:
      dt = dt.replace(tzinfo=timezone.utc)
    return dt
  except ValueError:
    return None


def to_unix(value: Any) -> int | None:
  dt = parse_iso(value)
  return int(dt.timestamp()) if dt else None


def to_iso(dt: datetime | None) -> str | None:
  if dt is None:
    return None
  return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


# --- auth ---


def load_auth() -> dict[str, Any]:
  if not AUTH_PATH.is_file():
    raise RuntimeError("missing_auth: run `grok login`")
  data = json.loads(AUTH_PATH.read_text())
  if not isinstance(data, dict) or not data:
    raise RuntimeError("invalid_auth: empty ~/.grok/auth.json")

  # Prefer auth.x.ai OIDC entries (current SuperGrok / Grok Build login).
  preferred: list[tuple[str, dict[str, Any]]] = []
  others: list[tuple[str, dict[str, Any]]] = []
  for scope, entry in data.items():
    if not isinstance(entry, dict):
      continue
    if not entry.get("key") and not entry.get("access_token"):
      continue
    if str(scope).startswith("https://auth.x.ai"):
      preferred.append((scope, entry))
    else:
      others.append((scope, entry))

  candidates = preferred + others
  if not candidates:
    raise RuntimeError("invalid_auth: no access token")

  scope, entry = candidates[0]
  return {
    "scope": scope,
    "token": str(entry.get("key") or entry.get("access_token")),
    "refresh_token": str(entry.get("refresh_token") or ""),
    "expires_at": str(entry.get("expires_at") or ""),
    "client_id": str(entry.get("oidc_client_id") or ""),
    "auth_data": data,
  }


def token_is_fresh(creds: dict[str, Any], skew_sec: int = 120) -> bool:
  exp = parse_iso(creds.get("expires_at"))
  if exp is None:
    return True  # no expiry recorded — treat as usable
  return exp > datetime.now(timezone.utc) + timedelta(seconds=skew_sec)


def save_auth(creds: dict[str, Any]) -> None:
  """Atomically write refreshed tokens back to auth.json (mode 0600)."""
  data = creds["auth_data"]
  entry = dict(data.get(creds["scope"]) or {})
  entry["key"] = creds["token"]
  if creds.get("refresh_token"):
    entry["refresh_token"] = creds["refresh_token"]
  if creds.get("expires_at"):
    entry["expires_at"] = creds["expires_at"]
  data[creds["scope"]] = entry

  try:
    AUTH_PATH.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".auth.", suffix=".tmp", dir=str(AUTH_PATH.parent))
    try:
      with os.fdopen(fd, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")
      os.chmod(tmp, 0o600)
      os.replace(tmp, AUTH_PATH)
    except Exception:
      try:
        os.unlink(tmp)
      except OSError:
        pass
      raise
  except Exception as exc:
    # Non-fatal: the in-memory token still works for this scan.
    sys.stderr.write(f"grok_usage: could not write auth.json: {exc}\n")


def refresh_token(creds: dict[str, Any]) -> None:
  refresh = creds.get("refresh_token") or ""
  client_id = creds.get("client_id") or ""
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
    method="POST",
    headers={
      "Content-Type": "application/x-www-form-urlencoded",
      "Accept": "application/json",
      "User-Agent": USER_AGENT,
    },
  )
  try:
    with urllib.request.urlopen(req, timeout=20) as resp:
      payload = json.loads(resp.read())
  except urllib.error.HTTPError as exc:
    raise RuntimeError(f"refresh_failed: http_{exc.code}") from exc
  except Exception as exc:
    raise RuntimeError(f"refresh_failed: {exc}") from exc

  access = payload.get("access_token")
  if not access:
    raise RuntimeError("refresh_failed: no access_token")

  creds["token"] = str(access)
  if payload.get("refresh_token"):
    creds["refresh_token"] = str(payload["refresh_token"])
  expires_in = payload.get("expires_in")
  if expires_in is not None:
    try:
      exp = datetime.now(timezone.utc) + timedelta(seconds=int(expires_in))
      creds["expires_at"] = to_iso(exp) or ""
    except (TypeError, ValueError):
      pass
  save_auth(creds)


# --- http ---


def _auth_headers(token: str, content_type: str | None = None) -> dict[str, str]:
  headers = {
    "Authorization": f"Bearer {token}",
    "Accept": content_type or "application/json",
    "User-Agent": USER_AGENT,
    # Same surface header the CLI sends so settings match the TUI.
    "x-grok-client-surface": "grok-build",
  }
  if content_type:
    headers["Content-Type"] = content_type
  return headers


def http_get_json(url: str, token: str, timeout: int = 15) -> Any:
  req = urllib.request.Request(url, method="GET", headers=_auth_headers(token))
  try:
    with urllib.request.urlopen(req, timeout=timeout) as resp:
      return json.loads(resp.read())
  except urllib.error.HTTPError as exc:
    exc.read()
    raise RuntimeError(f"http_{exc.code}") from exc
  except Exception as exc:
    raise RuntimeError(f"network: {exc}") from exc


def http_post_grpc(url: str, token: str, body: bytes, timeout: int = 20) -> bytes:
  headers = _auth_headers(token, content_type="application/grpc-web+proto")
  headers["x-grpc-web"] = "1"
  req = urllib.request.Request(url, data=body, method="POST", headers=headers)
  try:
    with urllib.request.urlopen(req, timeout=timeout) as resp:
      return resp.read()
  except urllib.error.HTTPError as exc:
    exc.read()
    raise RuntimeError(f"http_{exc.code}") from exc
  except Exception as exc:
    raise RuntimeError(f"network: {exc}") from exc


def with_auth_retry(creds: dict[str, Any], fetch):
  """Call fetch(creds); on 401/403 refresh once and retry."""
  try:
    return fetch(creds)
  except RuntimeError as exc:
    msg = str(exc)
    if "http_401" not in msg and "http_403" not in msg:
      raise
    refresh_token(creds)
    return fetch(creds)


# --- protobuf / gRPC-web ---


def _read_varint(buf: bytes, index: int) -> tuple[int | None, int]:
  value = 0
  shift = 0
  while index < len(buf) and shift < 64:
    b = buf[index]
    index += 1
    value |= (b & 0x7F) << shift
    if (b & 0x80) == 0:
      return value, index
    shift += 7
  return None, index


def _grpc_web_data_frames(raw: bytes) -> list[bytes] | None:
  frames = []
  i = 0
  while i + 5 <= len(raw):
    flags = raw[i]
    length = int.from_bytes(raw[i + 1:i + 5], "big")
    start = i + 5
    end = start + length
    if length < 0 or end > len(raw):
      return None
    if (flags & 0x80) == 0:
      frames.append(raw[start:end])
    i = end
  return frames


def _looks_like_protobuf(buf: bytes) -> bool:
  if not buf:
    return False
  field = buf[0] >> 3
  wire = buf[0] & 0x07
  return field > 0 and wire in (0, 1, 2, 5)


def _scan_protobuf(buf: bytes, depth: int = 0, path: list[int] | None = None) -> dict[str, list]:
  if path is None:
    path = []
  fixed32: list[tuple[list[int], float, int]] = []
  varints: list[tuple[list[int], int]] = []
  categories: list[tuple[int, float]] = []
  index = 0
  order = 0

  while index < len(buf):
    field_start = index
    key, index = _read_varint(buf, index)
    if key is None or key == 0:
      index = field_start + 1
      continue
    field_number = key >> 3
    wire_type = key & 0x07
    field_path = path + [field_number]

    if wire_type == 0:
      value, index = _read_varint(buf, index)
      if value is None:
        index = field_start + 1
        continue
      varints.append((field_path, value))
    elif wire_type == 1:
      if index + 8 > len(buf):
        break
      index += 8
    elif wire_type == 2:
      length, index = _read_varint(buf, index)
      if length is None or index + length > len(buf):
        index = field_start + 1
        continue
      start = index
      end = start + length
      nested = buf[start:end]
      # Category entries live at path [1, 7] as repeated messages.
      if len(field_path) == 2 and field_path[0] == 1 and field_path[1] == 7:
        cat_type = None
        cat_pct = None
        nested_fields = _scan_protobuf(nested, depth + 1, field_path)
        for p, v in nested_fields["varints"]:
          if p and p[-1] == 1:
            cat_type = int(v)
        for p, v, _ord in nested_fields["fixed32"]:
          if p and p[-1] == 2 and 0 <= v <= 100:
            cat_pct = float(v)
        if cat_type is not None:
          categories.append((cat_type, cat_pct if cat_pct is not None else 0.0))
        else:
          fixed32.extend(nested_fields["fixed32"])
          varints.extend(nested_fields["varints"])
      elif depth < 4:
        nested_fields = _scan_protobuf(nested, depth + 1, field_path)
        fixed32.extend(nested_fields["fixed32"])
        varints.extend(nested_fields["varints"])
        categories.extend(nested_fields["categories"])
      index = end
    elif wire_type == 5:
      if index + 4 > len(buf):
        break
      value = struct.unpack_from("<f", buf, index)[0]
      fixed32.append((field_path, float(value), order))
      order += 1
      index += 4
    else:
      index = field_start + 1

  return {"fixed32": fixed32, "varints": varints, "categories": categories}


def parse_credits_config(raw: bytes) -> dict[str, Any] | None:
  """Return {used_percent, reset_unix, start_unix, categories[]} or None."""
  if not raw:
    return None

  frames = _grpc_web_data_frames(raw)
  if not frames:
    if _looks_like_protobuf(raw):
      frames = [raw]
    else:
      return None

  all_fixed: list[tuple[list[int], float, int]] = []
  all_varint: list[tuple[list[int], int]] = []
  all_cats: list[tuple[int, float]] = []
  for payload in frames:
    scan = _scan_protobuf(payload)
    all_fixed.extend(scan["fixed32"])
    all_varint.extend(scan["varints"])
    all_cats.extend(scan["categories"])

  # credit_usage_percent: fixed32 float 0–100, field number ending in 1;
  # prefer shallower paths (min path length, then wire order).
  percent_candidates = [
    (path, value, ord_)
    for path, value, ord_ in all_fixed
    if path and path[-1] == 1 and 0 <= value <= 100
  ]
  percent_candidates.sort(key=lambda item: (len(item[0]), item[2]))
  used_percent = percent_candidates[0][1] if percent_candidates else None

  # Period timestamps: start [1, 4, 1], end [1, 5, 1] (unix seconds).
  now_sec = datetime.now(timezone.utc).timestamp()
  ts_fields = [
    (path, value)
    for path, value in all_varint
    if 1_700_000_000 <= value <= 2_100_000_000
  ]
  future = [(p, v) for p, v in ts_fields if v > now_sec]
  reset_unix = None
  preferred_end = next((v for p, v in future if p == [1, 5, 1]), None)
  if preferred_end is not None:
    reset_unix = preferred_end
  elif future:
    reset_unix = min(v for _, v in future)

  start_unix = next((v for p, v in ts_fields if p == [1, 4, 1]), None)
  # Fallback: any past timestamp at [1, 4, *] or latest past ts before reset.
  if start_unix is None:
    past = [(p, v) for p, v in ts_fields if v <= now_sec]
    preferred_start = next(
      (v for p, v in past if len(p) >= 2 and p[0] == 1 and p[1] == 4),
      None,
    )
    if preferred_start is not None:
      start_unix = preferred_start
    elif past and reset_unix is not None:
      candidates = [v for _, v in past if v < reset_unix]
      if candidates:
        start_unix = max(candidates)

  # proto3 omits zero floats — period present + no % → 0% used.
  has_usage_period = any(
    (len(p) >= 2 and p[0] == 1 and p[1] == 6)
    or (p == [1, 8, 1] and v in (1, 2))
    for p, v in all_varint
  )
  if used_percent is None and not all_fixed and reset_unix is not None and has_usage_period:
    used_percent = 0.0

  if used_percent is None:
    return None

  categories = []
  for type_id, pct in all_cats:
    type_id = int(type_id)
    categories.append({
      "label": CATEGORY_LABELS.get(type_id, f"Category {type_id}"),
      "type": type_id,
      "percent": round(float(pct), 1),
    })
  categories.sort(
    key=lambda c: (CATEGORY_ORDER.get(c["type"], 99), -c["percent"], c["label"])
  )

  return {
    "used_percent": round(float(used_percent), 1),
    "reset_unix": reset_unix,
    "start_unix": start_unix,
    "categories": categories,
  }


def fetch_weekly(creds: dict[str, Any]) -> dict[str, Any]:
  # Empty gRPC-web message: flags=0, length=0, no payload.
  raw = http_post_grpc(CREDITS_URL, creds["token"], b"\x00\x00\x00\x00\x00")
  parsed = parse_credits_config(raw)
  if parsed is None:
    raise RuntimeError("credits_parse_failed")
  return parsed


# --- tier / account / subscription (best-effort) ---


def fetch_tier(creds: dict[str, Any]) -> str:
  payload = http_get_json(SETTINGS_URL, creds["token"])
  if not isinstance(payload, dict):
    return ""
  return str(payload.get("subscription_tier_display") or "").strip()


def jwt_tier_fallback(token: str) -> str:
  """Best-effort tier from the OIDC access-token claim (numeric)."""
  try:
    parts = str(token or "").split(".")
    if len(parts) < 2:
      return ""
    pad = "=" * (-len(parts[1]) % 4)
    payload = json.loads(base64.urlsafe_b64decode(parts[1] + pad))
  except Exception:
    return ""

  for key in ("subscription_tier_display", "subscription_tier", "tier_name", "plan"):
    val = payload.get(key)
    if isinstance(val, str) and val.strip():
      return val.strip()

  # Numeric `tier` claim observed in auth.x.ai access tokens; known values only.
  try:
    tier_n = int(payload.get("tier"))
  except (TypeError, ValueError):
    return ""
  return {5: "SuperGrok Heavy"}.get(tier_n, "")


def fetch_account(creds: dict[str, Any]) -> tuple[str, str]:
  payload = http_get_json(USER_URL, creds["token"])
  if not isinstance(payload, dict):
    return "", ""
  email = str(payload.get("email") or "").strip()
  name = str(payload.get("name") or "").strip()
  if not name:
    first = str(payload.get("firstName") or payload.get("given_name") or "").strip()
    last = str(payload.get("lastName") or payload.get("family_name") or "").strip()
    name = " ".join(part for part in (first, last) if part)
  return name, email


def fetch_rebill(creds: dict[str, Any]) -> tuple[int | None, bool]:
  """(rebill unix, cancels at period end) of the active Super Grok subscription."""
  payload = http_get_json(SUBSCRIPTIONS_URL, creds["token"])
  subs = payload.get("subscriptions") if isinstance(payload, dict) else None
  if not isinstance(subs, list):
    return None, False

  active = []
  for sub in subs:
    if not isinstance(sub, dict):
      continue
    tier = str(sub.get("tier") or "")
    if "SUPER_GROK" not in tier and "HEAVY" not in tier:
      continue
    if str(sub.get("status") or "") != "SUBSCRIPTION_STATUS_ACTIVE":
      continue
    active.append(sub)
  if not active:
    return None, False

  def period_end(sub: dict[str, Any]) -> str:
    stripe = sub.get("stripe") if isinstance(sub.get("stripe"), dict) else {}
    return str(sub.get("billingPeriodEnd") or stripe.get("currentPeriodEnd") or "")

  best = max(active, key=period_end)
  stripe = best.get("stripe") if isinstance(best.get("stripe"), dict) else {}
  cancels = bool(best.get("cancelAtPeriodEnd") or stripe.get("cancelAtPeriodEnd"))
  return to_unix(period_end(best)), cancels


# --- payload ---


def build_error(error: str) -> dict[str, Any]:
  return {
    "source": "grok_credits",
    "error": short_error(error),
    "utilization": None,
    "remaining": None,
    "resets_at": None,
    "reset_unix": None,
    "period_start_unix": None,
    "span_sec": None,
    "tier": None,
    "email": None,
    "name": None,
    "renews_unix": None,
    "cancels": False,
    "categories": [],
  }


def fetch_usage() -> dict[str, Any]:
  try:
    creds = load_auth()
  except RuntimeError as exc:
    return build_error(str(exc))

  if not token_is_fresh(creds):
    try:
      refresh_token(creds)
    except RuntimeError as exc:
      return build_error(str(exc))

  try:
    weekly = with_auth_retry(creds, fetch_weekly)
  except RuntimeError as exc:
    return build_error(str(exc))

  reset_unix = weekly.get("reset_unix")
  start_unix = weekly.get("start_unix")
  span_sec = None
  if start_unix and reset_unix and reset_unix > start_unix:
    span_sec = reset_unix - start_unix

  # Tier / account / rebill are best-effort; never fail the scan on them.
  tier = ""
  try:
    tier = with_auth_retry(creds, fetch_tier)
  except RuntimeError:
    pass
  if not tier:
    tier = jwt_tier_fallback(creds["token"])

  name, email = "", ""
  try:
    name, email = with_auth_retry(creds, fetch_account)
  except RuntimeError:
    pass

  renews_unix, cancels = None, False
  try:
    renews_unix, cancels = with_auth_retry(creds, fetch_rebill)
  except RuntimeError:
    pass

  used = weekly["used_percent"]
  return {
    "source": "grok_credits",
    "error": None,
    "utilization": used,
    "remaining": max(0.0, round(100.0 - used, 1)),
    "resets_at": to_iso(datetime.fromtimestamp(reset_unix, timezone.utc)) if reset_unix else None,
    "reset_unix": reset_unix,
    "period_start_unix": start_unix,
    "span_sec": span_sec,
    "tier": tier or None,
    "email": email or None,
    "name": name or None,
    "renews_unix": renews_unix,
    "cancels": cancels,
    "categories": [
      {"label": c["label"], "percent": c["percent"]} for c in weekly["categories"]
    ],
  }


def main() -> int:
  try:
    payload = fetch_usage()
  except Exception as exc:  # noqa: BLE001 — bar must always get a Lua table
    payload = build_error(str(exc))
  print(lua_literal(payload))
  return 0 if not payload.get("error") else 1


if __name__ == "__main__":
  sys.exit(main())
