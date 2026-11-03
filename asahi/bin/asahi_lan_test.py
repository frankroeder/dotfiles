#!/usr/bin/env python3
"""asahi-lan: DNS / mDNS parsing, naming + kind rules, store commands, NEW flags, the ping / nudge policy.
No network traffic except the read-only --once run; the store lives in a scratch XDG_STATE_HOME."""
import importlib.machinery
import importlib.util
import json
import os
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
TMP = tempfile.mkdtemp(prefix="asahi-lan-test-")
os.environ["XDG_STATE_HOME"] = TMP + "/state"
loader = importlib.machinery.SourceFileLoader("asahi_lan", str(HERE / "asahi-lan"))
spec = importlib.util.spec_from_loader("asahi_lan", loader)
lan = importlib.util.module_from_spec(spec)
loader.exec_module(lan)


def label(name):
  return b"".join(bytes([len(p)]) + p.encode() for p in name.split(".")) + b"\0"


def rr(name, rtype, rdata):
  return (label(name) if isinstance(name, str) else name) + struct.pack("!HHIH", rtype, 1, 120, len(rdata)) + rdata


def txt(*items):
  return b"".join(bytes([len(i)]) + i.encode() for i in items)


def response(*records):
  return struct.pack("!6H", 0, 0x8400, 0, len(records), 0, 0) + b"".join(records)


def fake_monitor(ip="192.168.178.124", gw="192.168.178.1"):
  m = lan.Monitor.__new__(lan.Monitor)
  m.key, m.trusted, m.live, m.link_t = "Home|74:42:7f:00:00:01", True, {}, 0
  m.icmp = m.udp = None
  m.msock, m.bound = None, "wlan0"  # armed: the fake sockets below stay
  m.reset()
  m.net = {"iface": "wlan0", "gw": gw, "ip": ip, "prefix": 24, "ssid": "Home", "mac": "aa:bb:cc:00:00:01",
    "subnet": lan.ipaddress.ip_network(ip + "/24", strict=False)}
  return m


class Dns(unittest.TestCase):
  def test_query_roundtrip(self):
    q = lan.dns_query(0x1234, ["50.178.168.192.in-addr.arpa", "_ipp._tcp.local"], rd=True)
    qid, flags, qd = struct.unpack("!3H", q[:6])
    self.assertEqual((qid, flags, qd), (0x1234, 0x0100, 2))
    self.assertEqual(lan.dns_name(q, 12)[0], ["50", "178", "168", "192", "in-addr", "arpa"])

  def test_compressed_ptr_answer(self):
    head = struct.pack("!6H", 7, 0x8180, 1, 1, 0, 0)
    question = label("50.178.168.192.in-addr.arpa") + b"\0\x0c\0\x01"
    answer = b"\xc0\x0c" + struct.pack("!HHIH", 12, 1, 60, 0) + label("raspberrypi.fritz.box")
    buf = bytearray(head + question + answer)
    struct.pack_into("!H", buf, len(head + question) + 10, len(label("raspberrypi.fritz.box")))
    qid, _, recs = lan.dns_records(bytes(buf))
    self.assertEqual(qid, 7)
    self.assertEqual(lan.dns_name(bytes(buf), recs[0][2])[0], ["raspberrypi", "fritz", "box"])

  def test_pointer_loop_is_an_error(self):
    with self.assertRaises(ValueError):
      lan.dns_name(b"\xc0\x00", 0)

  def test_ptr_reply_needs_a_pending_id(self):
    m = fake_monitor()
    m.pending[9] = "192.168.178.50"
    buf = struct.pack("!6H", 9, 0x8180, 0, 1, 0, 0) + rr("50.178.168.192.in-addr.arpa", 12, label("raspberrypi.fritz.box"))
    m.on_ptr(buf)
    self.assertEqual(m.ptr["192.168.178.50"][0], "raspberrypi.fritz.box")
    m.on_ptr(buf.replace(b"\x00\x09", b"\x00\x0a", 1))  # unknown id: dropped
    self.assertEqual(len(m.ptr), 1)


class Mdns(unittest.TestCase):
  def test_services_instances_txt_srv(self):
    m = fake_monitor()
    srv = struct.pack("!HHH", 0, 0, 8080) + label("Living-Room.local")
    buf = response(
      rr("_services._dns-sd._udp.local", 12, label("_googlecast._tcp.local")),
      rr("_googlecast._tcp.local", 12, label("Chromecast-Ultra-0123456789abcdef0123456789abcdef._googlecast._tcp.local")),
      rr("Chromecast-Ultra-0123456789abcdef0123456789abcdef._googlecast._tcp.local", 16, txt("fn=Living Room", "md=Chromecast")),
      rr("Living-Room._http._tcp.local", 33, srv),
      rr("Living-Room._http._tcp.local", 16, txt("path=/setup/")),
      rr("Living-Room.local", 1, socket.inet_aton("192.168.178.60")))
    m.on_mdns("192.168.178.60", buf)
    info = m.mdns["192.168.178.60"]
    self.assertIn("_googlecast._tcp", info["services"])
    self.assertEqual(lan.mdns_name(info), "Living Room")
    self.assertEqual(lan.mdns_model(info), "Chromecast")
    self.assertEqual(lan.mdns_web("192.168.178.60", info), "http://192.168.178.60:8080/setup/")
    self.assertEqual(lan.classify("Living Room", info["services"], ""), "tv")
    self.assertEqual(lan.service_labels(info["services"]), ["Cast", "Web"])

  def test_sleep_proxy_answer_goes_to_the_named_host(self):
    m = fake_monitor()
    m.on_mdns("192.168.178.2", response(rr("Franks-MacBook.local", 1, socket.inet_aton("192.168.178.70"))))
    self.assertIn("Franks-MacBook", m.mdns["192.168.178.70"]["hosts"])
    self.assertNotIn("192.168.178.2", m.mdns)

  def test_queries_and_outside_answers_are_ignored(self):
    m = fake_monitor()
    m.on_mdns("192.168.178.9", struct.pack("!6H", 0, 0, 0, 1, 0, 0) + rr("x.local", 1, socket.inet_aton("192.168.178.9")))
    m.on_mdns("10.0.0.5", response(rr("x.local", 1, socket.inet_aton("10.0.0.5"))))
    self.assertEqual(m.mdns, {})

  def test_truncated_record_is_malformed_not_fatal(self):
    m = fake_monitor()
    buf = response(rr("x.local", 1, socket.inet_aton("192.168.178.9")))[:-2]  # A record cut short
    with self.assertRaises(ValueError):  # recv() drops ValueError; an OSError used to end `watch`
      m.on_mdns("192.168.178.9", buf)

  def test_web_path_is_sanitised(self):
    info = {"ports": {"_http._tcp": 80}, "txt": {"_http._tcp": {"path": "/x?<script>"}}}
    self.assertEqual(lan.mdns_web("192.168.178.5", info), "http://192.168.178.5/")

  def test_printer_admin_page(self):
    # IPP only: the adminurl names an mDNS host; the link keeps scheme, port and path but always uses the device's IP.
    info = {"txt": {"_ipp._tcp": {"adminurl": "https://BRW1C1BB5D2E3F4.local.:8443/general/status.html", "ty": "Brother HL-L2350DW"}}}
    self.assertEqual(lan.mdns_web("192.168.178.61", info), "https://192.168.178.61:8443/general/status.html")
    self.assertEqual(lan.mdns_web("192.168.178.61", {"txt": {"_ipp._tcp": {"adminurl": "javascript:alert(1)"}}}), "")
    self.assertEqual(lan.mdns_model(info), "Brother HL-L2350DW")
    self.assertEqual(lan.mdns_model({"txt": {"_raop._tcp": {"md": "0,1,2"}, "_device-info._tcp": {"model": "Mac14,2"}}}), "Mac14,2")


class Names(unittest.TestCase):
  def test_friendly(self):
    self.assertEqual(lan.friendly("A1B2C3D4E5F6@Living Room"), "Living Room")
    self.assertEqual(lan.friendly("nas [00:11:32:aa:bb:cc]"), "nas")
    self.assertEqual(lan.friendly("32:00:00:00:00:01@fe80::3000:ff:fe00:1-supportsRP-26"), "")
    self.assertEqual(lan.friendly("0123456789abcdef0123456789abcdef"), "")
    self.assertEqual(lan.friendly("PC-192-168-178-50"), "")

  def test_tidy(self):
    self.assertEqual(lan.tidy("PHILIPS_EP8757_20_000000"), "Philips EP8757")
    self.assertEqual(lan.tidy("Franks-iPhone"), "Franks iPhone")
    self.assertEqual(lan.tidy("ESP-1A2B3C"), "ESP")
    self.assertEqual(lan.tidy("raspberrypi"), "raspberrypi")

  def test_short_vendor(self):
    self.assertEqual(lan.short_vendor("Raspberry Pi Trading Ltd"), "Raspberry Pi")
    self.assertEqual(lan.short_vendor("AVM Audiovisuelles Marketing und Computersysteme GmbH"), "AVM")
    self.assertEqual(lan.short_vendor("Apple, Inc."), "Apple")
    self.assertEqual(lan.short_vendor("Espressif Inc."), "Espressif")
    self.assertEqual(lan.short_vendor("Samsung Electronics Co.,Ltd"), "Samsung")

  def test_classify_order(self):
    self.assertEqual(lan.classify("Franks-iPhone", set(), "Apple, Inc."), "phone")
    self.assertEqual(lan.classify("MacBook-Pro", set(), ""), "laptop")
    self.assertEqual(lan.classify("", {"_ipp._tcp"}, ""), "printer")
    self.assertEqual(lan.classify("", set(), "Espressif Inc."), "smarthome")
    self.assertEqual(lan.classify("BRW-HL_L2350DW", set(), ""), "printer")
    self.assertEqual(lan.classify("", set(), ""), "unknown")
    self.assertEqual([lan.classify(t, set(), "") for t in ("Android TV", "Galaxy Tab S8", "Galaxy Watch", "Pixel Tablet")],
      ["tv", "tablet", "watch", "tablet"])

  def test_device_names(self):
    m = fake_monitor()
    m.ptr["192.168.178.123"] = ("0XX-EU-XXX0000X.fritz.box", 0)
    m.ptr["192.168.178.30"] = ("PC-192-168-178-30.fritz.box", 0)
    lan._oui = {"446ff8": "Dyson Limited", "d83add": "Raspberry Pi Trading Ltd"}
    seen = {"ip": "192.168.178.123", "t": time.time(), "state": "idle"}
    d = m.device("44:6f:f8:00:00:01", seen, {}, time.time(), "")
    self.assertEqual((d["name"], d["kind"]), ("Appliance (Dyson)", "appliance"))  # serial hostname → vendor label
    d = m.device("d8:3a:dd:00:00:02", dict(seen, ip="192.168.178.30"), {"name": "Pi"}, time.time(), "")
    self.assertEqual((d["name"], d["auto"], d["custom"]), ("Pi", "Computer (Raspberry Pi)", True))
    d = m.device("26:00:00:00:00:31", dict(seen, ip="192.168.178.31"), {}, time.time(), "")
    self.assertTrue(d["private"])
    self.assertEqual(d["vendor"], "")

  def test_platform(self):
    self.assertIn("_apple-mobdev2._tcp", lan.BROWSE)
    self.assertIn("_adb-tls-connect._tcp", lan.BROWSE)
    self.assertEqual(lan.platform_of("phone", "", "Franks iPhone", "", "", set()), "apple")
    for name in ("Franks iMac", "Franks Mac mini", "Kitchen HomePod"):  # private MACs: no Apple vendor to go on
      self.assertEqual(lan.platform_of("computer", "", name, "", "", set()), "apple", name)
    self.assertEqual(lan.platform_of("computer", "", "frank-mbp", "", "", set(), ["Apple"]), "apple")  # saved label, asleep
    self.assertEqual(lan.platform_of("computer", "Apple", "mac", "", "", set()), "apple")
    self.assertEqual(lan.platform_of("unknown", "", "", "", "", {"_companion-link._tcp"}), "apple")
    self.assertEqual(lan.platform_of("phone", "Samsung", "Galaxy S24", "", "", set()), "android")
    self.assertEqual(lan.platform_of("unknown", "Samsung", "", "", "", set()), "android")
    self.assertEqual(lan.platform_of("unknown", "", "x", "", "", {"_adb-tls-connect._tcp"}), "android")
    self.assertEqual(lan.platform_of("tv", "Samsung", "Living Room", "", "UE55", set()), "media")  # vendor alone is not enough
    self.assertEqual(lan.platform_of("printer", "Brother", "HL-L2350DW", "", "", set()), "office")
    self.assertEqual(lan.platform_of("router", "AVM", "Router", "", "", set()), "network")
    self.assertEqual(lan.platform_of("phone", "", "Phone", "", "", set()), "mobile")
    m = fake_monitor()
    m.ptr["192.168.178.40"] = ("Franks-iPhone.fritz.box", 0)
    d = m.device("26:00:00:00:00:28", {"ip": "192.168.178.40", "t": time.time(), "state": "idle"}, {"name": "Work phone"}, time.time(), "")
    self.assertEqual((d["name"], d["platform"], d["group"]), ("Work phone", "apple", "mobile"))  # the rename is not the group

  def test_address_taken_over_drops_old_names(self):
    m = fake_monitor()
    m.ptr["192.168.178.50"] = ("raspberrypi.fritz.box", 0)
    m.neigh = {"192.168.178.50": ("aa:00:00:00:00:99", "REACHABLE")}  # someone else holds .50 now
    d = m.device("d8:3a:dd:00:00:02", {"ip": "192.168.178.50", "t": time.time() - 600, "state": "asleep"}, {"auto": "pi"}, time.time(), "")
    self.assertEqual(d["name"], "pi")

  def test_saved_services_must_be_a_label_list(self):
    seen = {"ip": "192.168.178.10", "t": time.time(), "state": "online"}
    d = fake_monitor().device("aa:00:00:00:00:10", seen, {"services": "Print"}, time.time(), "")
    self.assertEqual(d["services"], [])  # a string is not a label list


class Store(unittest.TestCase):
  def setUp(self):
    lan.STORE.unlink(missing_ok=True)
    self.m = fake_monitor()
    self.m.live = {"d8:3a:dd:00:00:02": {"mac": "d8:3a:dd:00:00:02", "ip": "192.168.178.50", "auto": "raspberrypi", "kind": "computer",
      "state": "online"}}
    self.m.neigh = {"192.168.178.1": ("74:42:7f:00:00:01", "REACHABLE")}

  def net(self):
    return lan.load_store()["networks"][self.m.key]

  def test_commands(self):
    m = self.m
    self.assertTrue(m.handle("trust"))
    self.assertTrue(self.net()["trusted"] > 0)
    m.handle(json.dumps({"cmd": "rename", "mac": "d8:3a:dd:00:00:02", "name": "  Pi <hole>\n"}))
    m.handle(json.dumps({"cmd": "pin", "mac": "d8:3a:dd:00:00:02", "on": True}))
    m.handle(json.dumps({"cmd": "pin", "mac": "aa:aa:aa:aa:aa:aa", "on": True}))  # not listed: ignored
    m.handle(json.dumps({"cmd": "view", "mode": "type", "collapsed": ["office"]}))
    m.handle(json.dumps({"cmd": "view", "mode": "nope"}))
    m.handle(json.dumps({"cmd": "view", "mode": "band"}))
    m.handle("{broken")
    d = self.net()["devices"]
    self.assertEqual(list(d), ["d8:3a:dd:00:00:02"])
    self.assertEqual((d["d8:3a:dd:00:00:02"]["name"], d["d8:3a:dd:00:00:02"]["pinned"]), ("Pi hole", True))
    st = lan.load_store()
    self.assertEqual(st["view"], {"mode": "type", "collapsed": ["office"]})
    m.handle(json.dumps({"cmd": "view", "mode": "platform", "collapsed": ["apple", "android"]}))
    self.assertEqual(lan.load_store()["view"], {"mode": "platform", "collapsed": ["apple", "android"]})
    self.assertEqual(oct(lan.STORE.stat().st_mode & 0o777), "0o600")
    m.handle("untrust")
    self.assertEqual(self.net()["trusted"], 0)

  def test_oversized_stdin_is_dropped_whole(self):
    """`trust` sits inside the oversized line; only the following view command applies."""
    m = self.m
    blob = b"x" * (lan.MAX_COMMAND + 8) + b'{"cmd":"trust"}\n{"cmd":"view","mode":"platform"}\n'
    fresh, buf, skipping = lan.take_stdin(m, b"", False, blob)
    st = lan.load_store()
    self.assertEqual((fresh, buf, skipping), (True, b"", False))
    self.assertEqual(st["view"]["mode"], "platform")
    self.assertNotIn(self.m.key, st["networks"])
    # The same rule across two reads: the tail that arrives later is still the oversized line.
    m.handle(json.dumps({"cmd": "view", "mode": "type"}))
    fresh, buf, skipping = lan.take_stdin(m, b"", False, b"y" * (lan.MAX_COMMAND + 1))
    self.assertEqual((fresh, buf, skipping), (False, b"", True))
    lan.take_stdin(m, buf, skipping, b'{"cmd":"trust"}\n{"cmd":"view","mode":"platform"}\n')
    st = lan.load_store()
    self.assertEqual(st["view"]["mode"], "platform")
    self.assertNotIn(self.m.key, st["networks"])

  def test_nested_command_then_a_real_one(self):
    m = self.m
    self.assertFalse(m.handle('{"a":' * 3000))
    self.assertTrue(m.handle("trust"))
    self.assertGreater(self.net()["trusted"], 0)

  def test_hostile_collapsed_then_a_real_command(self):
    """collapsed: 1 is valid JSON and not a list. It must not kill the watcher; the next command still applies."""
    m = self.m
    chunk = b'{"cmd":"view","mode":"platform","collapsed":1}\n{"cmd":"trust"}\n'
    fresh, buf, skipping = lan.take_stdin(m, b"", False, chunk)
    st = lan.load_store()
    self.assertEqual((fresh, buf, skipping), (True, b"", False))
    self.assertEqual(st["view"]["mode"], "list")
    self.assertGreater(st["networks"][m.key]["trusted"], 0)

  def test_full_store_still_loads(self):
    """The writer keeps 32 networks of 512 devices. A store of that size must load, and the next command must not replace it."""
    m = self.m
    with lan.store_tx() as st:
      for n in range(lan.KEEP_NETS):
        devs = {}
        for d in range(lan.KEEP_DEVICES):
          mac = f"02:00:{n:02x}:{d // 256:02x}:{d % 256:02x}:00"
          devs[mac] = {"first": 1700000000 + d, "last": 1700000000 + d, "ip": f"10.{n}.{d // 256}.{d % 256}",
            "auto": "Ä" * 60, "kind": "smarthome", "name": "N" * 40, "pinned": True, "new": True, "host": "H" * 60,
            "model": "M" * 40, "services": ["Workstation", "HomeKit", "AirPlay", "Spotify", "ESPHome", "Matter", "Shelly", "Print"]}
        st["networks"][f"net-{n:02d}|02:00:00:00:00:{n:02x}"] = {"ssid": "S" * 64, "trusted": 1700000000, "seen": n, "devices": devs}
    size = lan.STORE.stat().st_size
    self.assertGreater(size, 256 * 1024)
    self.assertLess(size, lan.MAX_STORE)
    key, mac = "net-31|02:00:00:00:00:1f", "02:00:1f:01:ff:00"
    st = lan.load_store()
    self.assertEqual(st["networks"][key]["devices"][mac]["name"], "N" * 40)
    self.assertEqual(sum(len(net["devices"]) for net in st["networks"].values()), lan.KEEP_NETS * lan.KEEP_DEVICES)
    self.assertTrue(m.handle('{"cmd":"view","mode":"platform","collapsed":["apple"]}'))
    st = lan.load_store()
    self.assertEqual(st["view"], {"mode": "platform", "collapsed": ["apple"]})
    self.assertEqual(st["networks"][key]["devices"][mac]["auto"], "Ä" * 60)
    self.assertEqual(sum(len(net["devices"]) for net in st["networks"].values()), lan.KEEP_NETS * lan.KEEP_DEVICES)

  def test_store_ignores_symlink_fifo_and_nested_json(self):
    real = lan.STORE
    d = Path(TMP) / "store-hostile"
    d.mkdir(exist_ok=True)
    try:
      good = d / "real.json"
      good.write_text(json.dumps({"view": {"mode": "platform", "collapsed": ["apple"]}, "networks": {"kept": {}}}))
      link = d / "link.json"
      link.unlink(missing_ok=True)
      link.symlink_to(good)
      lan.STORE = link
      st = lan.load_store()
      self.assertEqual((st["view"]["mode"], st["networks"]), ("list", {}))
      fifo = d / "fifo.json"
      if fifo.exists():
        fifo.unlink()
      os.mkfifo(fifo)
      lan.STORE = fifo

      def boom(signum, frame):
        raise TimeoutError("fifo read blocked")

      old = signal.signal(signal.SIGALRM, boom)
      signal.alarm(2)
      try:
        st = lan.load_store()
      finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old)
      self.assertEqual((st["view"]["mode"], st["networks"]), ("list", {}))
      deep = d / "deep.json"
      deep.write_text("[" * 200000)
      lan.STORE = deep
      st = lan.load_store()
      self.assertEqual((st["view"]["mode"], st["networks"]), ("list", {}))
    finally:
      lan.STORE = real

  def record(self, trusted_ago, since_ago=10):
    m, now = self.m, time.time()
    with lan.store_tx() as st:
      st["networks"][m.key] = {"ssid": "Home", "trusted": int(now) - trusted_ago if trusted_ago else 0, "devices": {}}
    m.seen = {"d8:3a:dd:00:00:02": {"ip": "192.168.178.50", "t": now, "state": "online", "since": now - since_ago}}
    devs = [{"mac": "d8:3a:dd:00:00:02", "ip": "192.168.178.50", "name": "pi", "auto": "pi", "kind": "computer", "state": "online",
      "self": False, "gw": False, "new": False}]
    m.record(now, devs, lan.load_store())
    return devs[0], self.net()["devices"].get("d8:3a:dd:00:00:02")

  def test_new_after_baseline(self):
    dev, rec = self.record(3600)
    self.assertTrue(dev["new"] and rec["new"])
    self.m.handle(json.dumps({"cmd": "known", "mac": "d8:3a:dd:00:00:02"}))
    self.assertNotIn("new", self.net()["devices"]["d8:3a:dd:00:00:02"])

  def test_within_baseline_is_known(self):
    dev, rec = self.record(60)
    self.assertFalse(dev["new"])
    self.assertNotIn("new", rec)

  def test_names_get_5s_before_recording(self):
    self.assertIsNone(self.record(3600, since_ago=1)[1])

  def test_record_caches_facts_and_a_blank_look_keeps_them(self):
    m, now = self.m, time.time()
    with lan.store_tx() as st:
      st["networks"][m.key] = {"ssid": "Home", "trusted": int(now) - 3600, "devices": {}}
    m.seen = {"d8:3a:dd:00:00:02": {"ip": "192.168.178.50", "t": now, "state": "online", "since": now - 10}}
    full = {"mac": "d8:3a:dd:00:00:02", "ip": "192.168.178.50", "name": "Living Room", "auto": "Living Room",
      "kind": "tv", "host": "Living-Room", "model": "Chromecast", "services": ["Cast", "Web"],
      "state": "online", "self": False, "gw": False, "new": False}
    m.record(now, [full], lan.load_store())
    rec = self.net()["devices"]["d8:3a:dd:00:00:02"]
    self.assertEqual((rec["host"], rec["model"], rec["services"], rec["auto"]), ("Living-Room", "Chromecast", ["Cast", "Web"], "Living Room"))
    blank = dict(full, model="", services=[], host="", auto="192.168.178.50", kind="unknown")
    m.record(now + 1, [blank], lan.load_store())
    rec = self.net()["devices"]["d8:3a:dd:00:00:02"]
    self.assertEqual((rec["host"], rec["model"], rec["services"], rec["auto"], rec["kind"]),
      ("Living-Room", "Chromecast", ["Cast", "Web"], "Living Room", "tv"))
    made_up = dict(full, auto="TV (Google)", label="TV", vendor="Google")  # the fallback name is not a heard one
    m.record(now + 1, [made_up], lan.load_store())
    self.assertEqual(self.net()["devices"]["d8:3a:dd:00:00:02"]["auto"], "Living Room")
    m.record(now + 2, [dict(full, services=["Cast", "Web", "Print"])], lan.load_store())
    self.assertEqual(self.net()["devices"]["d8:3a:dd:00:00:02"]["services"], ["Cast", "Web", "Print"])

  def test_untrusted_meanwhile_flags_nothing(self):
    self.m.trusted = True  # stale: the pane untrusted after this tick read the store
    self.assertIsNone(self.record(0)[1])


class Stored(unittest.TestCase):
  """A collector that just started (empty seen / mDNS / PTR, as when the Devices tab opens) lists what lan.json
  already knows for this network. A blank look keeps those facts; a new service is added."""

  def test_first_snapshot_shows_saved_facts(self):
    lan.STORE.unlink(missing_ok=True)
    m = fake_monitor()
    self.assertEqual((m.seen, m.mdns, m.ptr), ({}, {}, {}))
    now = time.time()
    mac, pin, other = "aa:00:00:00:00:2a", "aa:00:00:00:00:2c", "aa:00:00:00:00:2b"
    saved = {"name": "Shelf", "auto": "diskbox", "kind": "nas", "host": "shelf-host", "model": "DS220",
      "services": ["Files", "Print"]}
    with lan.store_tx() as st:
      st["networks"][m.key] = {"ssid": "Home", "trusted": int(now) - 80000, "seen": int(now) - 10000, "devices": {
        mac: dict(first=int(now) - 80000, last=int(now) - 10000, ip="192.168.178.42", **saved),
        pin: {"pinned": True, "name": "Printer", "auto": "hl", "kind": "printer", "host": "hl", "model": "HL",
          "services": ["Print"], "ip": "192.168.178.61", "last": int(now) - 10000, "first": int(now) - 80000},
      }}
      st["networks"]["Other|11:22:33:00:00:01"] = {"ssid": "Other", "devices": {
        other: {"name": "Elsewhere", "auto": "elsewhere", "kind": "phone", "ip": "10.0.0.9", "last": int(now)}}}
    by = {d["mac"]: d for d in m.snapshot(now, lan.load_store(), "", record=True)["devices"]}
    self.assertNotIn(other, by)
    d = by[mac]
    self.assertEqual((d["name"], d["auto"], d["kind"], d["host"], d["model"], d["services"]),
      ("Shelf", "diskbox", "nas", "shelf-host", "DS220", ["Files", "Print"]))
    self.assertEqual((d["web"], d["ssh"], d["state"]), ("", 0, "asleep"))
    self.assertIn(pin, by)
    # Online, but this look learned no names: the saved facts stay, on the row and in the store.
    m.neigh = {"192.168.178.42": (mac, "REACHABLE")}
    shown = {d["mac"]: d for d in m.snapshot(now + 1, lan.load_store(), "", record=True)["devices"]}[mac]
    self.assertEqual((shown["name"], shown["auto"], shown["kind"], shown["host"], shown["model"], shown["services"]),
      ("Shelf", "diskbox", "nas", "shelf-host", "DS220", ["Files", "Print"]))
    rec = lan.load_store()["networks"][m.key]["devices"][mac]
    self.assertEqual((rec["auto"], rec["kind"], rec["host"], rec["model"], rec["services"]),
      ("diskbox", "nas", "shelf-host", "DS220", ["Files", "Print"]))
    # A service this look did hear is added. Eight saved labels plus one new one stay at the cap.
    full = ["Files", "Print", "Scan", "AirPlay", "Spotify", "Sonos", "Cast", "Hue"]
    with lan.store_tx() as st:
      st["networks"][m.key]["devices"][mac]["services"] = full
    m.mdns["192.168.178.42"] = {"hosts": set(), "inst": {}, "services": {"_http._tcp"}, "txt": {}, "ports": {}}
    shown = {d["mac"]: d for d in m.snapshot(now + 8, lan.load_store(), "", record=True)["devices"]}[mac]
    self.assertEqual(shown["services"], ["Web", *full[:7]])
    self.assertEqual(lan.load_store()["networks"][m.key]["devices"][mac]["services"], ["Web", *full[:7]])
    # Heard, then quiet past SLEEPING_KEEP: gone for this process. Pinned stays. A new process shows the stored row
    # again — the old `last` is not that timeout.
    m.neigh = {}
    m.seen[mac] = {"ip": "192.168.178.42", "t": now + 8 - lan.SLEEPING_KEEP - 1, "state": "idle", "since": now}
    m.seen[pin] = {"ip": "192.168.178.61", "t": now + 8 - lan.SLEEPING_KEEP - 1, "state": "idle", "since": now}
    left = {d["mac"] for d in m.snapshot(now + 8, lan.load_store(), "", record=False)["devices"]}
    self.assertNotIn(mac, left)
    self.assertIn(pin, left)
    fresh = fake_monitor()
    self.assertEqual((fresh.seen, fresh.mdns, fresh.ptr), ({}, {}, {}))
    back = {d["mac"]: d for d in fresh.snapshot(now + 8, lan.load_store(), "", record=False)["devices"]}
    self.assertEqual((back[mac]["name"], back[mac]["auto"], back[mac]["services"][0]), ("Shelf", "diskbox", "Web"))

  def test_vendor_oui_keeps_stored_kind(self):
    """04:e8:b9 is Intel, and that vendor rule is computer. A blank look must keep a saved tv."""
    lan.STORE.unlink(missing_ok=True)
    lan._oui = None  # an earlier test stubs the table; this one uses the real OUI file
    m = fake_monitor()
    self.assertEqual((m.seen, m.mdns, m.ptr), ({}, {}, {}))
    mac = "04:e8:b9:00:00:10"
    self.assertEqual(lan.classify("", set(), lan.vendor_of(mac)), "computer")
    now = time.time()
    with lan.store_tx() as st:
      st["networks"][m.key] = {"ssid": "Home", "trusted": int(now) - 80000, "seen": int(now) - 10000, "devices": {
        mac: {"auto": "Living Room", "kind": "tv", "model": "Bravia", "ip": "192.168.178.40",
          "first": int(now) - 80000, "last": int(now) - 10000}}}
    asleep = {d["mac"]: d for d in m.snapshot(now, lan.load_store(), "", record=True)["devices"]}[mac]
    self.assertEqual((asleep["kind"], asleep["group"], asleep["auto"], asleep["model"], asleep["state"]),
      ("tv", "media", "Living Room", "Bravia", "asleep"))
    self.assertEqual(lan.load_store()["networks"][m.key]["devices"][mac]["kind"], "tv")
    m.neigh = {"192.168.178.40": (mac, "REACHABLE")}
    m.snapshot(now + 1, lan.load_store(), "", record=True)  # online, too soon to record
    shown = {d["mac"]: d for d in m.snapshot(now + 8, lan.load_store(), "", record=True)["devices"]}[mac]
    self.assertEqual((shown["kind"], shown["group"], shown["auto"], shown["model"], shown["state"]),
      ("tv", "media", "Living Room", "Bravia", "online"))
    self.assertEqual(lan.load_store()["networks"][m.key]["devices"][mac]["kind"], "tv")


class Pings(unittest.TestCase):
  """Untrusted networks are never pinged; a trusted one once when the view opens and on Rescan, never periodically.
  Trust needs the router's MAC in the neighbour table."""
  def setUp(self):
    lan.STORE.unlink(missing_ok=True)
    self.real = lan.neighbours
    lan.neighbours = lambda iface: {"192.168.178.1": ("74:42:7f:00:00:01", "REACHABLE")}

  def tearDown(self):
    lan.neighbours = self.real

  def sweeps(self, trusted, ticks):
    m = fake_monitor()
    m.icmp, m.refresh_link, calls = object(), (lambda now: None), []
    m.sweep = lambda ips: calls.append(len(ips))
    with lan.store_tx() as st:
      st["networks"][m.key] = {"ssid": "Home", "trusted": int(time.time()) if trusted else 0, "devices": {}}
    for force in ticks:
      m.force = force
      m.tick(record=False)
    return calls

  def test_untrusted_never(self):
    self.assertEqual(self.sweeps(False, [False, True, False, True]), [])

  def test_mdns_only_host_gets_one_unicast_question(self):
    m = fake_monitor()
    m.udp, sent = object(), []
    m.send = lambda sock, pkt, addr: sent.append(addr)
    m.mdns = {"192.168.178.61": {}, "192.168.178.50": {}, "192.168.178.124": {}}  # a printer, a listed host, us
    m.neigh = {"192.168.178.50": ("d8:3a:dd:00:00:02", "REACHABLE")}
    m.nudge()
    m.nudge()  # once per host and network
    self.assertEqual(sent, [("192.168.178.61", 5353)])

  def test_trusted_on_open_and_rescan_only(self):
    self.assertEqual(self.sweeps(True, [False, False, False]), [253])  # the /24 minus us, once
    self.assertEqual(self.sweeps(True, [False, False, True]), [253, 253])

  def tick_once(self, neigh):
    lan.neighbours = lambda iface: neigh
    m = fake_monitor()
    m.icmp, m.refresh_link, calls = object(), (lambda now: None), []
    m.sweep = lambda ips: calls.append(1)
    with lan.store_tx() as st:
      st["networks"]["Home|74:42:7f:00:00:01"] = {"ssid": "Home", "trusted": int(time.time()), "devices": {}}
    snap = m.tick(record=False)
    return m, snap, calls

  def test_missing_router_mac_is_not_trusted(self):
    m, snap, calls = self.tick_once({})
    self.assertEqual(calls, [])
    self.assertEqual(m.key, "")
    self.assertFalse(snap["trusted"])
    self.assertFalse(snap["can_trust"])

  def test_stale_router_mac_keeps_the_network(self):
    m, snap, _calls = self.tick_once({"192.168.178.1": ("74:42:7f:00:00:01", "STALE")})
    self.assertEqual(m.key, "Home|74:42:7f:00:00:01")
    self.assertTrue(snap["can_trust"])


class Bind(unittest.TestCase):
  def test_new_iface_gets_fresh_sockets(self):
    """An unprivileged socket binds to a device once; a second bind (same iface too) is EPERM."""
    m = fake_monitor()
    m.net["iface"], m.bound = "lo", ""
    m.arm()
    old = m.udp
    if old is None:
      self.skipTest("SO_BINDTODEVICE refused")
    m.bound = ""
    m.arm()
    self.assertIsNotNone(m.udp)
    self.assertEqual(old.fileno(), -1)
    m.udp.close()
    if m.icmp:
      m.icmp.close()

  def test_failed_bind_opens_nothing(self):
    m = fake_monitor()
    m.net["iface"], m.bound = "nosuch0", ""
    m.arm()
    self.assertEqual((m.icmp, m.udp), (None, None))


class Live(unittest.TestCase):
  def test_once_json(self):
    out = subprocess.run([sys.executable, str(HERE / "asahi-lan"), "--once"], check=False, capture_output=True, text=True, timeout=30, env=os.environ)
    snap = json.loads(out.stdout)
    self.assertIn("devices", snap)
    if snap["active"]:
      for key in ("trusted", "can_trust", "vpn_blocked", "total", "view"):
        self.assertIn(key, snap)
      self.assertTrue(any(d["self"] for d in snap["devices"]))
    self.assertFalse(lan.STORE.exists() and json.loads(lan.STORE.read_text()).get("networks"), "--once must not record")


if __name__ == "__main__":
  unittest.main(verbosity=2)
