#!/usr/bin/env python3
"""asahi-apple-music-lyrics: Chromium's native messaging framing in and out, the file it writes for the shell.

Run: uv run --no-project python asahi/bin/asahi_apple_music_lyrics_test.py
"""
import json
import os
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

HOST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "asahi-apple-music-lyrics")
fails = 0


def check(name, got, want):
  global fails
  if got == want:
    print("ok  ", name)
  else:
    fails += 1
    print("FAIL", name, "got", repr(got), "want", repr(want))


def frame(msg):
  data = json.dumps(msg).encode()
  return struct.pack("<I", len(data)) + data


def replies(out):
  got = []
  while out:
    n = struct.unpack("<I", out[:4])[0]
    got.append(json.loads(out[4:4 + n]))
    out = out[4 + n:]
  return got


rec = {"trackId": "111", "title": "Song ♥", "artist": "Band", "synced": True,
       "lines": [{"t": 12.345, "text": "Rock & roll"}, {"t": 15.1, "text": "Second"}]}
with tempfile.TemporaryDirectory() as run:
  env = dict(os.environ, XDG_RUNTIME_DIR=run)
  out = Path(run, "asahi-apple-music-lyrics.json")
  # Chromium passes the caller's origin as the first argument.
  p = subprocess.run([sys.executable, HOST, "chrome-extension://nigobnphcnhekoibhmpaeadbcmmbcign/"], input=frame(rec), env=env,
                     capture_output=True, check=True)
  check("one reply", replies(p.stdout), [{"ok": True}])
  check("record written", json.loads(out.read_text()), rec)
  check("mode 0600", oct(out.stat().st_mode & 0o777), "0o600")

  # Two in one run (a long-lived port): the last one wins; junk fields and lines dropped, types forced.
  junk = {"trackId": 222, "title": None, "artist": "X", "synced": "yes", "evil": "x" * 10,
          "lines": [{"t": 1, "text": "a", "x": 1}, "not a line", {"t": 2}]}
  p = subprocess.run([sys.executable, HOST], input=frame(rec) + frame(junk) + frame([1, 2]), env=env, capture_output=True, check=True)
  check("a reply each", replies(p.stdout), [{"ok": True}] * 3)
  check("cleaned record", json.loads(out.read_text()),
        {"trackId": "222", "title": "", "artist": "X", "synced": False, "lines": [{"t": 1, "text": "a"}, {"t": 2, "text": ""}]})
  check("no temp files left", sorted(os.listdir(run)), ["asahi-apple-music-lyrics.json"])

  # Chromium closes stdin without a message: no file change, clean exit.
  before = out.read_text()
  p = subprocess.run([sys.executable, HOST], input=b"", env=env, capture_output=True, check=False)
  check("empty stdin", (p.returncode, p.stdout, out.read_text() == before), (0, b"", True))

raise SystemExit(1 if fails else 0)
