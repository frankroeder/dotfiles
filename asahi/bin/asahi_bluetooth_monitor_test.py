#!/usr/bin/env python3
"""asahi-bluetooth-monitor: HID++ parsing (fake node + a real socketpair), UPower / BlueZ / sysfs parsing on
fixtures, the alert rule, bounded children and the Monitor's commands + state file. No hidraw, no BlueZ."""

import io
import json
import os
import shutil
import socket
import sys
import tempfile
import threading
import time
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path

sys.dont_write_bytecode = True  # no __pycache__ beside the scripts
loader = SourceFileLoader("asahi_bluetooth_monitor", str(Path(__file__).resolve().parent / "asahi-bluetooth-monitor"))
bm = module_from_spec(spec_from_loader(loader.name, loader))
loader.exec_module(bm)

FAILED = 0


def eq(got, expected, msg):
  global FAILED
  if got == expected:
    print(f"ok   {msg}")
  else:
    FAILED += 1
    print(f"FAIL  {msg} got={got!r} expected={expected!r}", file=sys.stderr)


def write(path, data):
  path = Path(path)
  path.parent.mkdir(parents=True, exist_ok=True)
  path.write_bytes(data if isinstance(data, bytes) else data.encode())


tmp = Path(tempfile.mkdtemp(prefix="btmon-test-"))

# ---- pure helpers ----
eq(bm.clean(b"MX <b>Master</b>\0junk"), "MX bMaster/b", "clean: NUL cut, markup chars dropped")
eq(bm.clean("a\x07b" + "x" * 80), "ab" + "x" * 62, "clean: control chars dropped, 64 cap")
eq(bm.parse_dpi_list(bytes([0x00, 0x64, 0xE0, 0x32, 0x01, 0x2C, 0, 0])), [100, 150, 200, 250, 300], "dpi list: range 100..300 step 50")
eq(bm.parse_dpi_list(bytes([0x01, 0x90, 0x03, 0x20, 0x06, 0x40, 0, 0])), [400, 800, 1600], "dpi list: plain values")
eq(bm.dpi_range([100, 150, 200]), {"min": 100, "max": 200, "step": 50}, "dpi range: even steps")
eq(bm.dpi_range([400, 800, 1600])["step"], 0, "dpi range: uneven = choices")
eq(bm.dpi_range([]), {"choices": []}, "dpi range: empty")
eq(bm.smartshift_state(1, 20, True)["mode"], "freespin", "smartshift: wheel mode 1 = free spin")
eq(bm.smartshift_state(2, 0xFF, False)["mode"], "ratchet", "smartshift: auto 0xFF = ratchet")
eq(bm.smartshift_state(2, 30, True), {"mode": "smartshift", "threshold": 30, "enhanced": True}, "smartshift: threshold")
eq([bm.level_for(p) for p in (None, 5, 20, 50, 90)], ["unknown", "critical", "low", "good", "full"], "level_for")
eq((bm.voltage_percent(3922), bm.voltage_percent(5000), bm.voltage_percent(3000)), (70, 100, 0), "voltage curve")
eq(bm.kind_from_name("Logitech G502 HERO Gaming Mouse"), "mouse", "kind from HID name")
eq(bm.address_of("/org/bluez/hci0/dev_E8_85_4B_18_75_5D"), "E8:85:4B:18:75:5D", "address from BlueZ path")
eq(bm.address_of("hid-b0:be:83:f2:07:42-battery"), "B0:BE:83:F2:07:42", "address from kernel HID battery")
eq(bm.address_of("hid-F0T1495S63M13CKAL-battery-144"), "", "serial is no address")

# ---- alert rule ----
st = bm.battery_state
eq([st({"percent": p}, 25, 10) for p in (26, 25, 11, 10)], ["ok", "low", "low", "critical"], "battery_state: inclusive thresholds")
eq(st({"percent": 3, "charging": True}, 25, 10), "ok", "battery_state: charging is ok")
eq(st({"percent": None, "level": "empty"}, 25, 10), "critical", "battery_state: coarse empty")
eq(st(None, 25, 10), "ok", "battery_state: no battery")
devs = [
  {"name": "Kbd", "kind": "keyboard", "online": True, "state": "low", "battery": {"percent": 22}},
  {"name": "Mouse", "kind": "mouse", "online": True, "state": "low", "battery": {"percent": 18}},
  {"name": "Pad", "kind": "gamepad", "online": False, "state": "critical", "battery": {"percent": 2}},
  {"name": "Buds", "kind": "headset", "online": False, "state": "critical", "battery": {"percent": 4}},
]
eq(bm.battery_alert(devs), {"state": "low", "kind": "mouse", "name": "Mouse", "percent": 18}, "alert: worst visible online")
tie = [{"name": "Kbd", "kind": "keyboard", "online": True, "state": "low", "battery": {"percent": 12}},
       {"name": "Pad", "kind": "gamepad", "online": True, "state": "low", "battery": {"percent": 11}},
       {"name": "Mouse", "kind": "mouse", "online": True, "state": "low", "battery": {"percent": 24}}]
eq(bm.battery_alert(tie)["name"], "Mouse", "alert: a mouse at the same level takes over (upstream)")
eq(bm.battery_alert(tie[:2])["name"], "Kbd", "alert: else the first device at the worst level (upstream)")
eq(bm.battery_alert(devs[2:]), {"state": "ok"}, "alert: offline devices never warn")
eq(bm.lowest_battery(devs)["name"], "Mouse", "lowest: online only")

# ---- UPower ----
(tmp / "usbdev/3-1/3-1:1.0/0003:05AC:029C.000C").mkdir(parents=True)  # a USB-cabled keyboard's HID battery
(tmp / "psy/hid-SER-battery-1").mkdir(parents=True)
os.symlink(tmp / "usbdev/3-1/3-1:1.0/0003:05AC:029C.000C", tmp / "psy/hid-SER-battery-1/device")
dump = """Device: /org/freedesktop/UPower/devices/line_power_macsmc_ac
  native-path:          macsmc-ac
  power supply:         yes
  line-power
    online:              no

Device: /org/freedesktop/UPower/devices/battery_macsmc_battery
  native-path:          macsmc-battery
  battery
    present:             yes
    percentage:          80%

Device: /org/freedesktop/UPower/devices/battery_hid_SER_battery_1
  native-path:          hid-SER-battery-1
  model:                Apple Inc. Magic Keyboard
  serial:               SER
  keyboard
    present:             yes
    state:               fully-charged
    percentage:          100%
  History (charge):
    1760605478	100.000	fully-charged

Device: /org/freedesktop/UPower/devices/keyboard_hid_b0obeo83of2o07o42_battery
  native-path:          hid-b0:be:83:f2:07:42-battery
  model:                Magic Keyboard
  keyboard
    present:             yes
    state:               discharging
    percentage:          18.5%

Device: /org/freedesktop/UPower/devices/mouse_hidpp_battery_0
  native-path:          hidpp_battery_0
  model:                MX Master 3
  mouse
    percentage:          50%

Device: /org/freedesktop/UPower/devices/headset_dev_E8_85
  native-path:          /org/bluez/hci0/dev_E8_85_4B_18_75_5D
  model:                Pömpel
  headset
    present:             yes
    battery-level:       low
    percentage:          0%

Device: /org/freedesktop/UPower/devices/mouse_gone
  native-path:          gone
  model:                Gone
  mouse
    present:             no
    percentage:          40%

Device: /org/freedesktop/UPower/devices/DisplayDevice
  keyboard
    percentage:          1%

Daemon:
  daemon-version:  1.90.9
  state:  charging
"""
up = bm.parse_upower(dump, sysfs=str(tmp / "psy"))
eq([d["name"] for d in up], ["Apple Inc. Magic Keyboard", "Magic Keyboard", "Pömpel"], "upower: peripherals only (no AC / laptop / hidpp / absent / display)")
eq((up[0]["connection"], up[0]["key"], up[0]["battery"]["status"], up[0]["battery"]["external_power"]), ("usb", "up:SER", "full", True),
   "upower: USB-cabled keyboard via sysfs, charged")
eq((up[1]["connection"], up[1]["address"], up[1]["battery"]["percent"]), ("bluetooth", "B0:BE:83:F2:07:42", 18), "upower: BT keyboard, int percent")
eq((up[2]["battery"]["percent"], up[2]["battery"]["level"], up[2]["kind"]), (None, "low", "headset"), "upower: coarse level, 0% = unknown percent")
eq([d["name"] for d in bm.parse_upower(dump, sysfs=str(tmp / "psy"), skip_hidpp=False)][2], "MX Master 3",
   "upower: hidpp_battery kept while hidraw is denied (the kernel driver's reading)")
monitor_lines = ["[14:52:01.1]\tdevice changed:     /org/freedesktop/UPower/devices/battery_macsmc_battery",
                 "[14:52:01.2]\tdevice changed:     /org/freedesktop/UPower/devices/line_power_macsmc_ac",
                 "[14:52:02.0]\tdevice changed:     /org/freedesktop/UPower/devices/mouse_hidpp_battery_0"]
eq([bool(bm.UPOWER_SELF.search(x)) for x in monitor_lines], [True, True, False], "upower --monitor: laptop battery / AC do not rescan")

# ---- BlueZ ----
bluez = json.dumps({"type": "a{oa{sa{sv}}}", "data": [{
  "/org/bluez/hci0": {"org.bluez.Adapter1": {"Address": {"type": "s", "data": "5C:E9"}}},
  "/org/bluez/hci0/dev_E8_85_4B_18_75_5D": {"org.bluez.Device1": {
    "Address": {"type": "s", "data": "E8:85:4B:18:75:5D"}, "Alias": {"type": "s", "data": "Pömpel <3>"},
    "Icon": {"type": "s", "data": "audio-headphones"}, "Paired": {"type": "b", "data": True}, "Connected": {"type": "b", "data": True}}},
  "/org/bluez/hci0/dev_11": {"org.bluez.Device1": {
    "Address": {"type": "s", "data": "11:22:33:44:55:66"}, "Alias": {"type": "s", "data": "Pad"}, "Icon": {"type": "s", "data": "input-gaming"},
    "Paired": {"type": "b", "data": True}, "Connected": {"type": "b", "data": True}},
    "org.bluez.Battery1": {"Percentage": {"type": "y", "data": 9}}},
  "/org/bluez/hci0/dev_22": {"org.bluez.Device1": {
    "Address": {"type": "s", "data": "22:22:33:44:55:66"}, "Alias": {"type": "s", "data": "Phone"}, "Icon": {"type": "s", "data": "computer"},
    "Paired": {"type": "b", "data": True}, "Connected": {"type": "b", "data": True}}},
  "/org/bluez/hci0/dev_33": {"org.bluez.Device1": {
    "Address": {"type": "s", "data": "33:22:33:44:55:66"}, "Alias": {"type": "s", "data": "Off"}, "Icon": {"type": "s", "data": "input-mouse"},
    "Paired": {"type": "b", "data": True}, "Connected": {"type": "b", "data": False}}},
}]})
bz = bm.parse_bluez(bluez)
eq([(d["name"], d["kind"]) for d in bz], [("Pad", "gamepad"), ("Pömpel 3", "headset")], "bluez: paired + connected, known icons, clean names")
eq(bz[0]["battery"]["percent"], 9, "bluez: Battery1 percentage")
eq(bm.parse_bluez("not json"), [], "bluez: garbage = nothing")
eq(bm.parse_bluez('{"data": [[1, 2]]}'), [], "bluez: wrong shape = nothing")

pads = [{"name": "Xbox Wireless Controller", "address": "AA:01"}, {"name": "Xbox Wireless Controller", "address": "AA:02"}]
eq(len(bm.merge([], pads)), 2, "merge: same-named devices of one source both stay")
merged = bm.merge(list(up), bz)
eq([d["name"] for d in merged], ["Apple Inc. Magic Keyboard", "Magic Keyboard", "Pömpel", "Pad"], "merge: BlueZ Pömpel dropped (UPower path / address)")

# ---- sysfs: adapters, hidraw discovery ----
bt = tmp / "bt"
write(tmp / "dev/platform/soc/pcie/pci0000:00/0000:01:00.1/vendor", "0x14e4\n")
write(tmp / "dev/usb1/1-2/idVendor", "8087\n")
write(tmp / "dev/usb1/1-2/removable", "removable\n")
write(tmp / "dev/usb1/1-3/idVendor", "0a12\n")
write(tmp / "dev/usb1/1-3/manufacturer", "Cambridge Silicon Radio Inc.\n")
write(tmp / "dev/usb1/1-3/removable", "removable\n")
(tmp / "dev/usb1/1-2/1-2:1.0").mkdir(parents=True)
(tmp / "dev/usb1/1-3/1-3:1.0").mkdir(parents=True)
for name, target in (("hci0", "dev/platform/soc/pcie/pci0000:00/0000:01:00.1"), ("hci1", "dev/usb1/1-2/1-2:1.0"), ("hci2", "dev/usb1/1-3/1-3:1.0")):
  (bt / name).mkdir(parents=True)
  os.symlink(tmp / target, bt / name / "device")
(bt / "hci0:11").mkdir()
eq(bm.bt_adapters(str(bt)), [
  {"id": "hci0", "builtin": True, "bus": "pci", "vendor": "Broadcom"},
  {"id": "hci1", "builtin": True, "bus": "usb", "vendor": "Intel"},
  {"id": "hci2", "builtin": False, "bus": "usb", "vendor": "Cambridge Silicon Radio"},
], "adapters: PCI Broadcom, internal Intel on USB, a USB stick; connections skipped")

HIDPP_DESC = bytes.fromhex("0600ff0901a1018510750895061500 26ff00 0901 8100 c0".replace(" ", ""))
MOUSE_DESC = bytes.fromhex("05010902a1010901a100c0c0")
hr = tmp / "hidraw"
def hid(node, parent, hid_id, name, desc, uniq=""):
  d = tmp / "hiddev" / parent
  write(d / "uevent", f"HID_ID={hid_id}\nHID_NAME={name}\nHID_UNIQ={uniq}\n")
  write(d / "report_descriptor", desc)
  (hr / node).mkdir(parents=True)
  os.symlink(d, hr / node / "device")
hid("hidraw0", "5-1/5-1:1.2/0003:046D:C548.0001", "0003:0000046D:0000C548", "Logitech USB Receiver", HIDPP_DESC)
hid("hidraw1", "5-1/5-1:1.2/0003:046D:C548.0001/0003:046D:4082.0002", "0003:0000046D:00004082", "MX Master 3", HIDPP_DESC)
hid("hidraw2", "5-2/5-2:1.0/0003:046D:C08B.0003", "0003:0000046D:0000C08B", "G502", MOUSE_DESC)
hid("hidraw3", "5-2/5-2:1.1/0003:046D:C08B.0004", "0003:0000046D:0000C08B", "Logitech G502 HERO Gaming Mouse", HIDPP_DESC)
hid("hidraw4", "bt/0005:046D:B023.0005", "0005:0000046D:0000B023", "MX Ergo", HIDPP_DESC, "aa:bb:cc:dd:ee:ff")
hid("hidraw5", "3-1/3-1:1.0/0003:05AC:029C.0006", "0003:000005AC:0000029C", "Magic Keyboard", HIDPP_DESC)
LONG_DESC = bytes.fromhex("0600ff0902a1018511750895131500 26ff00 0902 8100 c0".replace(" ", ""))
hid("hidraw6", "bt/0005:046D:B034.0007", "0005:0000046D:0000B034", "MX Master 3S", LONG_DESC, "aa:bb:cc:dd:ee:01")
found = bm.discover(str(hr))
eq([(n["node"], n["family"], n["bus"], n["short"]) for n in found],
   [("hidraw0", "bolt", 3, True), ("hidraw3", None, 3, True), ("hidraw4", None, 5, True), ("hidraw6", None, 5, False)],
   "discover: receiver, wired HID++ interface, BT devices (one long-only); DJ child / mouse interface / Apple skipped")


# ---- HID++ over a fake node ----
class FakeNode:
  """Answers root getFeature / ping and canned feature replies; raises HID++ errors like a device."""

  def __init__(self, features, replies, proto=(4, 5)):
    self.features, self.replies, self.proto, self.sent = features, replies, proto, []

  def request(self, dev, b2, b3, params=b"", timeout=1.5):
    fn, params = b3 >> 4, bytes(params)
    self.sent.append((dev, b2, fn, params))
    if b2 == 0 and fn == 1:
      if self.proto is None:
        raise bm.HidppError(0x09)
      if self.proto == 1:
        raise bm.HidppError(0x01)
      return bytes(self.proto) + b"\0" * 14
    if b2 == 0 and fn == 0:
      return bytes([self.features.get(params[0] << 8 | params[1], 0)]) + b"\0" * 15
    fid = next(f for f, i in self.features.items() if i == b2)
    r = self.replies.get((fid, fn))
    if r is None:
      raise bm.HidppError(0x07)
    return (r(params) if callable(r) else r).ljust(16, b"\0")


wheel_mode = [0x02]
node = FakeNode({bm.NAME: 1, bm.UNIFIED: 2, bm.DPI: 3, bm.SMARTSHIFT2: 4, bm.WHEEL: 5, 0x40A3: 6, bm.HOSTS: 7}, {
  (bm.NAME, 0): bytes([11]),
  (bm.NAME, 1): lambda p: b"MX Master 3"[p[0]:p[0] + 16],
  (bm.UNIFIED, 1): bytes([42, 4, 0, 0]),
  (bm.DPI, 1): bytes([0, 0x00, 0xC8, 0xE0, 0x32, 0x0F, 0xA0, 0, 0]),
  (bm.DPI, 2): bytes([0, 0x06, 0x40, 0x03, 0xE8]),
  (bm.DPI, 3): b"",
  (bm.SMARTSHIFT2, 1): bytes([2, 20, 10]),
  (bm.SMARTSHIFT2, 2): b"",
  (bm.WHEEL, 1): lambda p: bytes(wheel_mode),
  (bm.WHEEL, 2): lambda p: (wheel_mode.__setitem__(0, p[0]), b"")[1],
  (bm.HOSTS, 0): bytes([0, 0, 2, 1]),
  (0x40A3, 0): lambda p: bytes([p[0], 1]),
  (0x40A3, 1): b"",
})
dev = bm.Device(node, 1)
eq(dev.ping(), 4.5, "ping: protocol 4.5")
eq(dev.name(), "MX Master 3", "name: chunked 0x0005")
eq(dev.battery(), {"percent": 42, "level": "good", "status": "discharging", "charging": False, "external_power": False}, "battery: unified 0x1004")
eq(dev.dpi(), {"min": 200, "max": 4000, "step": 50, "value": 1600, "default": 1000}, "dpi: range + current/default")
eq(dev.smartshift(), {"mode": "smartshift", "threshold": 20, "enhanced": True}, "smartshift: enhanced 0x2111")
eq(dev.wheel(), {"invert": False, "hires": True, "raw": 2}, "wheel: mode bits")
eq(dev.fnswap(), {"on": True}, "fnswap: per host 0x40A3 (host from 0x1815)")
eq(node.sent[-1][3][:1], bytes([1]), "fnswap: asks for the current host")
dev.set_wheel_bit(0x04, True)
eq(wheel_mode[0], 0x06, "set invert: read-modify-write keeps hires")
dev.set_smartshift("ratchet")
eq(node.sent[-1][3][:3], bytes([2, 0xFF, 0]), "set ratchet: wheel 2, auto 0xFF")
dev.set_smartshift("smartshift", 99)
eq(node.sent[-1][3][:3], bytes([2, 50, 0]), "set smartshift: threshold clamped to 50")
dev.set_dpi(1600)
eq(node.sent[-1][3][:3], bytes([0, 0x06, 0x40]), "set dpi: sensor 0 + big-endian value")
eq(bm.Device(FakeNode({}, {}, proto=1), 1).ping(), 1.0, "ping: invalid sub-ID = HID++ 1.0")
eq(bm.Device(FakeNode({}, {}, proto=None), 1).ping(), None, "ping: unreachable = offline")
eq(bm.Device(FakeNode({}, {}), 1).battery(), None, "battery: no feature = None")
volt = bm.Device(FakeNode({bm.VOLTAGE: 1}, {(bm.VOLTAGE, 0): bytes([0x0F, 0x52, 0x00])}), 1)
eq(volt.battery()["percent"], 70, "battery: voltage 3922 mV = 70 %")
eq(bm.Device(FakeNode({bm.NAME: 1}, {(bm.NAME, 2): bytes([3])}), 1).kind(), "mouse", "kind: 0x0005 getDeviceType 3 = mouse")


class SleepyNode(FakeNode):
  """The first getFeature fails with 0x09 (asleep), later ones answer."""
  asleep = True

  def request(self, dev, b2, b3, params=b"", timeout=1.5):
    if b2 == 0 and b3 >> 4 == 0 and self.asleep:
      self.asleep = False
      raise bm.HidppError(0x09)
    return super().request(dev, b2, b3, params, timeout)


sleepy = bm.Device(SleepyNode({bm.UNIFIED: 2}, {(bm.UNIFIED, 1): bytes([30, 4, 0, 0])}), 1)
try:
  sleepy.battery()
except bm.HidppError:
  pass
eq(sleepy.battery()["percent"], 30, "feature: an unreachable lookup is not cached as unsupported")

class FakeReceiver(bm.Receiver):
  def __init__(self, family, regs):
    super().__init__(None, family)
    self.regs = regs
  def register(self, reg, params=b"", long=True):
    r = self.regs.get((reg, bytes(params)[:2]))
    if r is None:
      raise bm.HidppError(0x02)
    return r
uni = FakeReceiver("unifying", {
  (0xB5, bytes([0x20])): bytes([0x20, 0, 0, 0x40, 0x82, 0, 0, 0x02]),
  (0xB5, bytes([0x40])): bytes([0x40, 3]) + b"M3X",
  (0xB5, bytes([0x21])): bytes([0x21, 0, 0, 0xFF, 0xFF, 0, 0, 0x01]),
  (0x02, b""): bytes([0, 1, 0]),
})
eq(uni.paired(), [(1, 0x4082, "mouse", "M3X")], "unifying: slot 1 paired, empty slot skipped")
eq(uni.connected_count(), 1, "unifying: connected count")
bolt = FakeReceiver("bolt", {
  (0xB5, bytes([0x52])): bytes([0x52, 0x01, 0x8A, 0x40]),
  (0xB5, bytes([0x62, 0x01])): bytes([0x62, 0x01, 7]) + b"MX Keys",
})
eq(bolt.paired(), [(2, 0x408A, "keyboard", "MX Keys")], "bolt: little-endian wpid + long name")
nano = FakeReceiver("nano", {(0xB5, bytes([0x20])): bytes([0x20, 0, 0, 0x40, 0x7A, 0, 0, 0x02])})
eq(nano.paired(), [(1, 0x407A, "mouse", "")], "nano: a slot without a name register keeps its device")

# ---- Node.request over a socketpair (message boundaries like hidraw) ----
a, b = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
a.setblocking(False)
n = bm.Node.__new__(bm.Node)
n.fd, n.events, n.short = a.fileno(), [], True
reply_ok = bytes([0x11, 0x01, 0x03, 0x1E, 0x2A]) + b"\0" * 15
def device_side():  # a flooding device: unrelated reports must neither stall nor grow the queue
  for _ in range(600):
    b.send(bytes([0x11, 0x01, 0x05, 0x00]) + b"\0" * 16)  # blocks while the queue is full (the reader drains)
  b.send(reply_ok)
sender = threading.Thread(target=device_side)
sender.start()
eq(n.request(1, 0x03, 0x1E, [0], timeout=10), reply_ok[4:], "socket: reply found after a flood")
sender.join()
eq(len(n.events), bm.MAX_EVENTS, "socket: event queue capped")
n.events = []  # a scan clears them
b.send(bytes([0x10, 0x01, 0x41, 0x04, 0x01, 0x82, 0x40]))
m = bm.Monitor(out=io.StringIO(), state=str(tmp / "state.json"))
m.nodes = {"x": n}
eq(m.wants_refresh(), True, "socket: 0x41 connection notice wants a rescan")
eq(n.events, [], "socket: drained")
threading.Timer(0.1, b.send, [bytes([0x11, 0x01, 0xFF, 0x03, 0x1E, 0x09]) + b"\0" * 14]).start()  # after the request (it drains first)
try:
  n.request(1, 0x03, 0x1E)
  eq("no error", "HidppError 0x09", "socket: HID++ 2.0 error")
except bm.HidppError as e:
  eq(e.code, 0x09, "socket: HID++ 2.0 error raised")
t0 = time.monotonic()
try:
  n.request(1, 0x03, 0x1E, timeout=0.3)
except bm.Timeout:
  pass
eq(0.25 < time.monotonic() - t0 < 1.0, True, "socket: silent device times out")
a.close()
b.close()

a, b = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
a.setblocking(False)
n = bm.Node.__new__(bm.Node)
n.fd, n.events, n.short = a.fileno(), [], False
threading.Timer(0.1, b.send, [bytes([0x11, 0xFF, 0x00, 0x1E, 4, 2]) + b"\0" * 14]).start()
eq(n.request(0xFF, 0x00, 0x1E, [0, 0, 7])[:2], bytes([4, 2]), "long-only node: request answered")
sent = b.recv(64)
eq((len(sent), sent[0]), (bm.LONG_LEN, bm.LONG), "long-only node: a 3-byte request goes out as a long report")
a.close()
b.close()

# Unplug: the hidraw fd turns readable and read() fails (EIO); a pty with its other end closed does the same.
master, slave = os.openpty()
os.set_blocking(master, False)
os.close(slave)
gone = bm.Node.__new__(bm.Node)
gone.fd, gone.events, gone.short = master, [], True
m = bm.Monitor(out=io.StringIO(), state=str(tmp / "state.json"))
m.nodes = {"/dev/hidraw8": gone}
eq((m.wants_refresh(), list(m.nodes)), (True, []), "unplug: the failing node is dropped and a rescan follows (no crash)")

# ---- bounded children ----
t0 = time.monotonic()
eq(bm.run_bounded(["sleep", "10"], timeout=0.5), "", "run_bounded: a child that never ends")
eq(time.monotonic() - t0 < 2, True, "run_bounded: returns at the deadline")
eq(len(bm.run_bounded(["yes"], timeout=2, limit=4096)), 4096, "run_bounded: output capped")
eq(bm.run_bounded(["/nonexistent-binary"]), "", "run_bounded: missing binary")

# ---- Monitor: commands, state file, scan ----
state = tmp / "state.json"
m = bm.Monitor(out=io.StringIO(), state=str(state))
eq(m.handle(b"not json"), False, "handle: garbage ignored")
eq(m.handle(json.dumps({"cmd": "open"})), True, "handle: open rescans")
eq((m.opened, m.handle(json.dumps({"cmd": "closed"})), m.opened), (True, False, False), "handle: closed, no rescan")
m.handle(json.dumps({"cmd": "thresholds", "low_at": 30, "critical_at": 50}))
eq(m.handle(json.dumps({"cmd": "thresholds", "low_at": "x"})), False, "handle: bad threshold ignored")
eq(m.handle('{"cmd": "thresholds", "low_at": Infinity, "critical_at": 1}'), False, "handle: Infinity ignored, no crash")
eq(m.handle(json.dumps({"cmd": "set", "device": ["x"], "key": {}, "value": [1]})), True, "handle: odd set types reach set, no crash")
saved = json.loads(state.read_text())
eq((saved["low_at"], saved["critical_at"], "hidden" in saved), (30, 30, False), "state: thresholds (critical ≤ low), no hidden list")
m.handle(json.dumps({"cmd": "set", "device": "nope", "key": "dpi", "value": 800}))
eq(m.message, ("errNotConnected", []), "set: unknown device")

wheel_mode[0] = 0x02
m.by_id = {"hidraw0-1": (dev, "4082")}
m.set("hidraw0-1", "threshold", 70)
m.set("hidraw0-1", "dpi", "bad")
eq((m.message[0], m.message[1][0].startswith("dpi: ")), ("errChange", True), "set: bad value reports, nothing stored")
m.set("hidraw0-1", "invert", True)
eq(json.loads(state.read_text())["devices"], {"4082": {"invert": True, "smartshift": "smartshift", "threshold": 50}}, "set: remembered per wpid")
wheel_mode[0] = 0x02
node.sent = []
m.reapply(dev, "4082")
eq(wheel_mode[0], 0x06, "reapply: invert written back")
eq(any(s[3][:2] == bytes([2, 50]) for s in node.sent), True, "reapply: smartshift with the stored threshold")
eq(bm.load_settings(str(state))["low_at"], 30, "state: reloads")
write(tmp / "bad.json", "[1, 2]")
eq(bm.load_settings(str(tmp / "bad.json"))["low_at"], 25, "state: wrong shape = defaults")
write(tmp / "odd.json", json.dumps({"devices": {"4082": [1], "c08b": {"dpi": 800}}, "low_at": "x"}))
eq((bm.load_settings(str(tmp / "odd.json"))["devices"], bm.load_settings(str(tmp / "odd.json"))["low_at"]), ({"c08b": {"dpi": 800}}, 25),
   "state: non-dict device entries and wrong types dropped")

bm.discover = lambda sysfs=None: []
bm.bt_adapters = lambda sysfs=None: [{"id": "hci0", "builtin": True, "bus": "pci", "vendor": "Broadcom"}]
bm.run_bounded = lambda argv, **kw: dump if argv[0] == "upower" else bluez
bm.upower_connection = lambda native, sysfs=None: "bluetooth" if bm.address_of(native) or native.startswith("/org/bluez/") else "usb"
m.scan()
snap = m.snap
eq([d["name"] for d in snap["devices"]], ["Apple Inc. Magic Keyboard", "Magic Keyboard", "Pömpel", "Pad"], "scan: UPower then new BlueZ devices")
eq([d.get("address") for d in snap["devices"]][1:], ["B0:BE:83:F2:07:42", "E8:85:4B:18:75:5D", "11:22:33:44:55:66"],
   "scan: Bluetooth devices carry their address (the pane merges by it)")
eq(snap["alert"], {"state": "critical", "kind": "keyboard", "name": "Magic Keyboard", "percent": 18}, "scan: alert = first critical (30/30)")
eq(snap["devices"][1]["state"], "critical", "scan: 18 % ≤ critical 30")
eq(snap["devices"][3]["adapter"], "hci0", "scan: Bluetooth devices name their adapter")
eq("native" in snap["devices"][2], False, "scan: native paths stay internal")
eq(snap["phase"], "ok", "scan: phase ok")
json.dumps(snap)
m.handle(json.dumps({"cmd": "set", "device": "nope", "key": "dpi", "value": 800}))
m.scan()
first = m.snap["message_code"]
m.scan()
eq((first, m.snap["message_code"]), ("errNotConnected", ""), "message: shown in one snapshot, then cleared")

m.handle(json.dumps({"cmd": "options", "other_devices": False, "language": "de"}))
m.scan()
eq((m.snap["devices"], m.snap["phase"], m.snap["language"]), ([], "none", "de"), "options: other devices off = HID++ only; language kept")
eq(json.loads(state.read_text())["other_devices"], False, "options: saved")
eq(m.snap["bar_tooltip"], True, "options: bar tooltip on by default (upstream)")
m.handle(json.dumps({"cmd": "options", "other_devices": True, "bar_tooltip": False}))
m.scan()
eq((m.snap["bar_tooltip"], json.loads(state.read_text())["bar_tooltip"]), (False, False), "options: bar tooltip switched off, saved")


# ---- end to end: an emulated Bolt receiver + MX Master on a socket (real report framing) ----
EMU_FEATURES = {0x0005: 1, 0x1004: 2, 0x2201: 3, 0x2111: 4, 0x2121: 5}


class Emulator(threading.Thread):
  """Speaks HID++ like a Bolt receiver with one mouse in slot 1 (wpid 0x4082). `online` False = asleep (error 0x09)."""


  def __init__(self, sock):
    super().__init__(daemon=True)
    self.sock, self.online, self.dpi, self.wheel, self.ss, self.writes = sock, True, 1600, 0x02, [2, 20], []

  def send(self, *b):
    self.sock.send(bytes(b).ljust(bm.LONG_LEN if b[0] == bm.LONG else bm.SHORT_LEN, b"\0"))

  def run(self):
    while True:
      try:
        req = self.sock.recv(64)
      except OSError:
        return
      if not req:
        return
      _, dev, b2, b3 = req[:4]
      p = req[4:]
      if dev == 0xFF:
        self.receiver(b2, b3, p)
      else:
        self.device(dev, b2, b3, p)

  def receiver(self, sub, reg, p):
    if reg == 0x02:
      return self.send(bm.SHORT, 0xFF, sub, reg, 0, 1, 0)
    if reg == 0xB5 and p[0] == 0x51:
      self.send(bm.LONG, 0xFF, 0x83, 0xB5, 0x52, 0x01, 0x8A, 0x40)  # another slot's answer first: the echo must skip it
      return self.send(bm.LONG, 0xFF, 0x83, 0xB5, 0x51, 0x02, 0x82, 0x40)
    if reg == 0xB5 and p[0] == 0x61:
      return self.send(bm.LONG, 0xFF, 0x83, 0xB5, 0x61, 0x01, 20, *b"MX Master 3 for Business"[:13])
    self.send(bm.SHORT, 0xFF, 0x8F, sub, reg, 0x02)  # empty slot

  def device(self, dev, b2, b3, p):
    fn = b3 >> 4
    if dev != 1 or not self.online:
      return self.send(bm.SHORT, dev, 0x8F, b2, b3, 0x09)
    if b2 == 0:
      if fn == 1:
        return self.send(bm.LONG, dev, 0, b3, 4, 5, p[2])
      return self.send(bm.LONG, dev, 0, b3, EMU_FEATURES.get(p[0] << 8 | p[1], 0))
    fid = next((f for f, i in EMU_FEATURES.items() if i == b2), None)
    r = None
    if fid == 0x0005:
      r = [11] if fn == 0 else [3] if fn == 2 else list(b"MX Master 3"[p[0]:p[0] + 16])
    elif fid == 0x1004 and fn == 1:
      r = [55, 4, 0, 0]
    elif fid == 0x2201:
      if fn == 1:
        r = [0, 0x00, 0xC8, 0xE0, 0x32, 0x0F, 0xA0, 0, 0]
      elif fn == 2:
        r = [0, self.dpi >> 8, self.dpi & 0xFF, 0x03, 0xE8]
      elif fn == 3:
        self.dpi, r = p[1] << 8 | p[2], []
        self.writes.append(("dpi", self.dpi))
    elif fid == 0x2111:
      if fn == 1:
        r = self.ss + [10]
      elif fn == 2:
        self.ss, r = [p[0], p[1]], []
        self.writes.append(("smartshift", tuple(self.ss)))
    elif fid == 0x2121:
      if fn == 1:
        r = [self.wheel]
      elif fn == 2:
        self.wheel, r = p[0], []
    if r is None:
      return self.send(bm.LONG, dev, 0xFF, b2, b3, 0x07)
    self.send(bm.LONG, dev, b2, b3, *r)


def emulated():
  """A fresh receiver on a socketpair (a replug): (node, emulator)."""
  a, b = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
  a.setblocking(False)
  emu = Emulator(b)
  emu.start()
  node = bm.Node.__new__(bm.Node)
  node.fd, node.events, node.short, node.sock = a.fileno(), [], True, a  # keep the socket object alive
  return node, emu


node, emu = emulated()
bm.discover = lambda sysfs=None: [{"node": "hidraw9", "path": "/dev/hidraw9", "bus": 3, "product": 0xC548, "family": "bolt",
                                   "name": "Logitech USB Receiver", "uniq": "", "short": True}]
e2e = bm.Monitor(out=io.StringIO(), state=str(tmp / "e2e.json"))
e2e.handle(json.dumps({"cmd": "options", "other_devices": False}))
e2e.nodes["/dev/hidraw9"] = node
e2e.scan()
s = e2e.snap
eq(s["receivers"], [{"id": "r-hidraw9", "family": "bolt", "name": "Bolt receiver", "node": "hidraw9", "max_devices": 6, "connected": 1,
                     "devices": ["hidraw9-1"]}], "e2e: receiver, slot echo skips the other slot's reply")
d = s["devices"][0]
eq((d["id"], d["key"], d["name"], d["kind"], d["protocol"], d["connection"], d["slot"]),
   ("hidraw9-1", "4082", "MX Master 3", "mouse", 4.5, "bolt", 1), "e2e: device identity")
eq((d["battery"]["percent"], d["dpi"]["value"], d["dpi"]["max"], d["smartshift"]["threshold"], d["wheel"]["hires"]),
   (55, 1600, 4000, 20, True), "e2e: battery, DPI, SmartShift, wheel read")
e2e.handle(json.dumps({"cmd": "set", "device": "hidraw9-1", "key": "dpi", "value": 3200}))
e2e.handle(json.dumps({"cmd": "set", "device": "hidraw9-1", "key": "smartshift", "value": "freespin"}))
e2e.scan()
eq((e2e.snap["devices"][0]["dpi"]["value"], e2e.snap["devices"][0]["smartshift"]["mode"]), (3200, "freespin"), "e2e: set reaches the device")
eq(json.loads((tmp / "e2e.json").read_text())["devices"], {"4082": {"dpi": 3200, "smartshift": "freespin"}}, "e2e: remembered per wpid")
emu.online = False
e2e.scan()
eq((e2e.snap["devices"][0]["online"], e2e.snap["devices"][0]["battery"]), (False, None), "e2e: asleep = offline, no readings")
e2e.handle(json.dumps({"cmd": "set", "device": "hidraw9-1", "key": "dpi", "value": 800}))
eq(e2e.message, ("errNotConnected", []), "e2e: no writes to an offline device")
emu.online, emu.dpi, emu.ss, emu.writes = True, 1000, [2, 20], []  # powered back on with its own defaults
e2e.scan()
eq(emu.writes, [("dpi", 3200), ("smartshift", (1, 0))], "e2e: reapplied once it answers again")
eq(e2e.snap["devices"][0]["dpi"]["value"], 3200, "e2e: snapshot shows the reapplied DPI")
emu.writes = []
e2e.scan()
eq(emu.writes, [], "e2e: no reapply while it stays online")
fresh = bm.Monitor(out=io.StringIO(), state=str(tmp / "e2e.json"))
fresh.settings["other_devices"] = False
fresh.nodes["/dev/hidraw9"] = node
fresh.scan()
eq(emu.writes, [], "e2e: a first sighting keeps the device's own settings (upstream)")

# Replug: the receiver's node vanishes (dropped), a new one appears with the device back on its defaults.
plugged = bm.discover
bm.discover = lambda sysfs=None: []
e2e.scan()
eq((list(e2e.nodes), e2e.online.get("4082")), ([], False), "replug: node dropped, device marked gone")
bm.discover = plugged
replug = {}
e2e.node = lambda path, short=True: e2e.nodes.setdefault(path, replug.setdefault("node", emulated())[0])
e2e.scan()
eq(replug["node"][1].writes, [("dpi", 3200), ("smartshift", (1, 0))], "replug: remembered settings reapplied")

shutil.rmtree(tmp)

print("FAILED" if FAILED else "all ok", file=sys.stderr if FAILED else sys.stdout)
sys.exit(1 if FAILED else 0)
