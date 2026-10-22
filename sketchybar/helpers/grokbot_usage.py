#!/usr/bin/env python3
"""Fetch Grok Bot weekly allowance (idea: jexmarc/omarchy-spacexai-usage).

Grok Bot is an Electron app on Cursor's backend. Its tokens live in
~/.config/Grok Bot/sand-secrets.json, encrypted with Chromium's os_crypt (v10/v11:
AES-128-CBC, PBKDF2-SHA1 key from the libsecret password or "peanuts"). Usage is
DashboardService/GetSandUsageStatus on api2.cursor.sh. Refreshed tokens stay in
memory -- the app owns its secrets file; a 401 triggers one refresh.
"""

from __future__ import annotations

import base64
import hashlib
import json
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path
from typing import Any

from ccu_common import emit, short_error, with_auth_retry
from cursor_usage import API_BASE, parse_unix, refresh_token

SECRETS_PATH = Path.home() / ".config" / "Grok Bot" / "sand-secrets.json"
USAGE_URL = f"{API_BASE}/GetSandUsageStatus"
JWT_RE = re.compile(rb"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+")


def safe_storage_passwords() -> list[bytes]:
  out: list[bytes] = []
  proc = subprocess.run(["secret-tool", "lookup", "application", "Grok Bot"], capture_output=True, timeout=10)
  if proc.returncode == 0 and proc.stdout.strip():
    out.append(proc.stdout.strip())
  out.append(b"peanuts")
  return out


def aes_cbc_decrypt(key: bytes, blob: bytes) -> bytes | None:
  proc = subprocess.run(
    ["openssl", "enc", "-d", "-aes-128-cbc", "-K", key.hex(), "-iv", (b" " * 16).hex()],
    input=blob,
    capture_output=True,
    timeout=10,
  )
  return proc.stdout if proc.returncode == 0 else None


def blob_bytes(value: Any) -> bytes:
  if isinstance(value, dict) and isinstance(value.get("data"), list):  # Node Buffer JSON
    return bytes(value["data"])
  s = str(value or "")
  if s.startswith(("v10", "v11", "eyJ")):
    return s.encode("latin-1")
  try:
    return base64.b64decode(s, validate=True)
  except ValueError:
    return s.encode("latin-1")


def decrypt_secret(value: Any, passwords: list[bytes]) -> str:
  blob = blob_bytes(value)
  if blob.startswith(b"eyJ"):
    return blob.decode()
  if blob[:3] in (b"v10", b"v11"):
    blob = blob[3:]
  for pw in passwords:
    for iterations in (1, 1003):
      plain = aes_cbc_decrypt(hashlib.pbkdf2_hmac("sha1", pw, b"saltysalt", iterations, 16), blob)
      m = JWT_RE.search(plain or b"")
      if m:
        return m.group().decode()
  return ""


def load_auth() -> dict[str, Any]:
  if not SECRETS_PATH.is_file():
    raise RuntimeError("no_auth: sign in to Grok Bot")
  secrets = json.loads(SECRETS_PATH.read_text())
  accounts = json.loads(secrets.get("cursor-accounts") or "{}")
  account = (accounts.get("accounts") or {}).get(accounts.get("active")) or {}
  passwords = safe_storage_passwords()
  token = decrypt_secret(account.get("cursor-access-token"), passwords)
  if not token:
    raise RuntimeError("no_auth: cannot decrypt Grok Bot token")
  refresh = decrypt_secret(account.get("cursor-refresh-token"), passwords)
  return {"token": token, "refresh_token": refresh, "auth_path": None, "auth_data": None}


def checksum() -> str:
  """Cursor's x-cursor-checksum: XOR-chained ms/1e6 timestamp + machine id."""
  ts = int(time.time() * 1000) // 1_000_000
  b = bytearray((ts >> s) & 0xFF for s in (40, 32, 24, 16, 8, 0))
  prev = 165
  for i in range(len(b)):
    b[i] = ((b[i] ^ prev) + i) & 0xFF
    prev = b[i]
  return base64.urlsafe_b64encode(bytes(b)).decode().rstrip("=") + str(uuid.uuid4())


def fetch_raw(creds: dict[str, Any]) -> dict[str, Any]:
  req = urllib.request.Request(USAGE_URL, data=b"{}", method="POST", headers={
    "Authorization": f"Bearer {creds['token']}",
    "Content-Type": "application/json",
    "Accept": "application/json",
    "Connect-Protocol-Version": "1",
    "x-cursor-checksum": checksum(),
    "x-cursor-client-type": "sand",
    "x-cursor-client-version": "0.1.0",
    "x-sand-box-namespace": "prod",
    "x-ghost-mode": "true",
    "x-request-id": str(uuid.uuid4()),
  })
  try:
    with urllib.request.urlopen(req, timeout=20) as resp:
      return json.loads(resp.read())
  except urllib.error.HTTPError as exc:
    raise RuntimeError(f"http_{exc.code}: {exc.read()[:120].decode(errors='replace')}") from exc
  except OSError as exc:
    raise RuntimeError(f"network: {exc}") from exc


def build_payload(raw: dict[str, Any]) -> dict[str, Any]:
  # usagePercent is 0-100 (the app clamps it there and labels 0 < x < 1 as "1%"): 0.77 is 0.77 %, not 77 %.
  used = raw.get("usagePercent")
  if used is None:
    used = 0.0 if raw.get("hasAvailableUsage") else 100.0
  return {
    "source": "grokbot",
    "error": None,
    "utilization": min(max(float(used), 0.0), 100.0),
    "reset_unix": parse_unix(raw.get("nextResetTimestampUtc")),
    "plan": raw.get("grokPlanLabel") or None,
  }


def fetch_usage() -> dict[str, Any]:
  try:
    creds = load_auth()
    return build_payload(with_auth_retry(creds, fetch_raw, refresh_token))
  except (RuntimeError, OSError, ValueError, subprocess.SubprocessError) as exc:
    return {"source": "grokbot", "error": short_error(exc), "utilization": None, "reset_unix": None, "plan": None}


if __name__ == "__main__":
  payload = fetch_usage()
  emit(payload)
  sys.exit(0 if not payload.get("error") else 1)
