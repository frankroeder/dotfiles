#!/usr/bin/env python3
"""asahi-lan: DNS / mDNS parsing, naming + kind rules, store commands, NEW flags, the ping / nudge policy.
No network traffic except the read-only --once run; the store lives in a scratch XDG_STATE_HOME."""
import importlib.machinery
import importlib.util
import json
import os
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
  m.msock = None
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

  def test_address_taken_over_drops_old_names(self):
    m = fake_monitor()
    m.ptr["192.168.178.50"] = ("raspberrypi.fritz.box", 0)
    m.neigh = {"192.168.178.50": ("aa:00:00:00:00:99", "REACHABLE")}  # someone else holds .50 now
    d = m.device("d8:3a:dd:00:00:02", {"ip": "192.168.178.50", "t": time.time() - 600, "state": "asleep"}, {"auto": "pi"}, time.time(), "")
    self.assertEqual(d["name"], "pi")


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
    m.handle("{broken")
    d = self.net()["devices"]
    self.assertEqual(list(d), ["d8:3a:dd:00:00:02"])
    self.assertEqual((d["d8:3a:dd:00:00:02"]["name"], d["d8:3a:dd:00:00:02"]["pinned"]), ("Pi hole", True))
    st = lan.load_store()
    self.assertEqual(st["view"], {"mode": "type", "collapsed": ["office"]})
    self.assertEqual(oct(lan.STORE.stat().st_mode & 0o777), "0o600")
    m.handle("untrust")
    self.assertEqual(self.net()["trusted"], 0)

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

  def test_untrusted_meanwhile_flags_nothing(self):
    self.m.trusted = True  # stale: the pane untrusted after this tick read the store
    self.assertIsNone(self.record(0)[1])


class Pings(unittest.TestCase):
  """Untrusted networks are never pinged; a trusted one once when the view opens and on Rescan, never periodically."""
  def setUp(self):
    lan.STORE.unlink(missing_ok=True)
    self.real = lan.neighbours
    lan.neighbours = lambda iface: {}

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
