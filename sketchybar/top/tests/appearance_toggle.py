#!/usr/bin/env python3
"""Live Light↔Dark dump of sketchybar widget colors. Restores original appearance."""

import json
import subprocess
import time

TOP = "/opt/homebrew/bin/sketchybar-top"
BOT = "/opt/homebrew/bin/sketchybar"
ISL = "/opt/homebrew/bin/sketchybar-island"

# (bin, item or None for bar, json path, key)
PROBES = [
    (TOP, None, ("color",), "top_bar"),
    (BOT, None, ("color",), "bot_bar"),
    (ISL, None, ("color",), "isl_bar"),
    (ISL, None, ("border_color",), "isl_border"),
    (TOP, "widgets.calendar", ("label", "color"), "cal"),
    (TOP, "widgets.volume", ("icon", "color"), "vol"),
    (TOP, "widgets.battery", ("icon", "color"), "bat"),
    (TOP, "widgets.wifi", ("icon", "color"), "wifi"),
    (TOP, "widgets.brew", ("icon", "color"), "brew"),
    (TOP, "widgets.mic", ("icon", "color"), "mic"),
    (TOP, "widgets.bluetooth", ("icon", "color"), "bt"),
    (TOP, "widgets.network_up", ("icon", "color"), "net_up"),
    (TOP, "widgets.network_down", ("icon", "color"), "net_down"),
    (TOP, "widgets.space.1", ("icon", "color"), "space"),
    (TOP, "widgets.yabai_layout", ("icon", "color"), "layout"),
    (BOT, "widgets.cpu_temp", ("label", "color"), "cpu"),
    (BOT, "widgets.uptime", ("icon", "color"), "uptime"),
    (BOT, "widgets.ssd.volume", ("icon", "color"), "ssd"),
    (BOT, "widgets.coffee", ("icon", "color"), "coffee"),
    (BOT, "widgets.power", ("icon", "color"), "power"),
    (BOT, "widgets.gpu_temp", ("label", "color"), "gpu"),
    (BOT, "widgets.ccu", ("label", "color"), "ccu"),
    (BOT, "widgets.media", ("label", "color"), "media"),
]


def run(cmd):
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)


def sys_mode():
    try:
        out = run(["defaults", "read", "-g", "AppleInterfaceStyle"]).strip()
    except subprocess.CalledProcessError:
        return "Light"
    return "Dark" if "dark" in out.lower() else "Light"


def walk(obj, path):
    cur = obj
    for key in path:
        if not isinstance(cur, dict):
            return None
        cur = cur.get(key)
    return cur


def query(bin_path, item):
    cmd = [bin_path, "--query", "bar" if item is None else item]
    for _ in range(8):
        try:
            return json.loads(run(cmd))
        except (subprocess.CalledProcessError, json.JSONDecodeError):
            time.sleep(0.15)
    return None


def snapshot():
    row = {"sys": sys_mode()}
    for bin_path, item, path, key in PROBES:
        data = query(bin_path, item)
        row[key] = walk(data, path) if data else None
    return row


def toggle():
    run([
        "osascript",
        "-e",
        'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode',
    ])


def changed(a, b):
    out = {}
    for k in a:
        if k == "sys":
            continue
        out[k] = a.get(k) != b.get(k) and a.get(k) is not None and b.get(k) is not None
    return out


def main():
    start = sys_mode()
    print("START", start)
    time.sleep(1.5)
    a = snapshot()
    print("A", a)
    toggle()
    time.sleep(3.5)
    b = snapshot()
    print("B", b)
    toggle()
    time.sleep(3.5)
    c = snapshot()
    print("C", c)
    ab = changed(a, b)
    bc = changed(b, c)
    print("A->B", ab)
    print("B->C", bc)
    miss = [k for k in ab if k != "isl_bar" and (not ab[k] or not bc[k])]
    print("island_black", a.get("isl_bar") == "0xff000000" and b.get("isl_bar") == "0xff000000")
    print("did_not_follow", miss)
    print("restored_sys", c["sys"] == start)
    if c["sys"] != start:
        toggle()
        print("re-toggled to", sys_mode())
    if miss:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
