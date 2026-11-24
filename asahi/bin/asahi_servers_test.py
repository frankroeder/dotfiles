#!/usr/bin/env python3
"""asahi-servers: ss / systemctl-show parsing on fixtures, action argv + unit validation against a fake systemctl."""

import os
import subprocess
import sys
import tempfile
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path

sys.dont_write_bytecode = True  # no __pycache__ beside the scripts
SCRIPT = Path(__file__).resolve().parent / "asahi-servers"
loader = SourceFileLoader("asahi_servers", str(SCRIPT))
srv = module_from_spec(spec_from_loader(loader.name, loader))
loader.exec_module(srv)

FAILED = 0


def eq(got, expected, msg):
  global FAILED
  if got == expected:
    print(f"ok   {msg}")
  else:
    FAILED += 1
    print(f"FAIL  {msg} got={got!r} expected={expected!r}", file=sys.stderr)


USER = "/user.slice/user-1000.slice/user@1000.service"
SS = f"""\
udp UNCONN 0 0 127.0.0.1:323 0.0.0.0:* ino:1 sk:1 cgroup:/system.slice/chronyd.service <->
udp UNCONN 0 0 [::1]:323 [::]:* ino:2 sk:2 cgroup:/system.slice/chronyd.service v6only:1 <->
udp UNCONN 0 0 0.0.0.0:5355 0.0.0.0:* uid:193 ino:3 sk:3 cgroup:/system.slice/systemd-resolved.service <->
tcp LISTEN 0 4096 [::]:5355 [::]:* uid:193 ino:4 sk:4 cgroup:/system.slice/systemd-resolved.service v6only:1 <->
udp UNCONN 0 0 127.0.0.53%lo:53 0.0.0.0:* uid:193 ino:5 sk:5 cgroup:/system.slice/systemd-resolved.service <->
udp UNCONN 0 0 0.0.0.0:38190 0.0.0.0:* users:(("firefox-bin",pid=11,fd=3)) uid:1000 ino:6 sk:6 cgroup:{USER}/app.slice/app-ff.scope <->
udp UNCONN 0 0 192.168.1.5:3702 0.0.0.0:* users:(("wsdd",pid=12,fd=10)) uid:1000 ino:7 sk:7 cgroup:{USER}/session.slice/gvfs-daemon.service <->
tcp LISTEN 0 511 127.0.0.1:5173 0.0.0.0:* users:(("Web Content",pid=13,fd=20)) uid:1000 ino:8 sk:8 cgroup:{USER}/app.slice/app-x.scope <->
tcp LISTEN 0 4096 127.0.0.1:631 0.0.0.0:* ino:9 sk:9 cgroup:/system.slice/system-cups.slice/cups.service <->
udp UNCONN 0 0 0.0.0.0:51820 0.0.0.0:* ino:10 sk:10 <->
tcp LISTEN 0 4096 0.0.0.0:443 0.0.0.0:* ino:11 sk:11 cgroup:/system.slice/nginx.service <->
"""
rows = {(r["port"], r["process"] or r["unit"]): r for r in srv.parse_ss(SS, 32768, 60999)}
eq(sorted(rows), [(53, "systemd-resolved.service"), (323, "chronyd.service"), (443, "nginx.service"),
                  (631, "cups.service"), (3702, "wsdd"), (5173, "Web Content"), (5355, "systemd-resolved.service"),
                  (51820, "")], "rows: one per port + owner, own ephemeral UDP (firefox) dropped, kernel socket kept")
eq(rows[(323, "chronyd.service")]["addrs"], ["127.0.0.1", "::1"], "v4 + v6 merge into one row")
eq(rows[(323, "chronyd.service")]["local"], True, "loopback only = local")
eq(rows[(53, "systemd-resolved.service")]["local"], True, "%lo bound = local")
eq(rows[(5355, "systemd-resolved.service")]["protos"], ["udp", "tcp"], "tcp + udp on one port merge")
eq(rows[(5355, "systemd-resolved.service")]["addrs"], ["*"], "0.0.0.0 and [::] = all interfaces")
eq(rows[(3702, "wsdd")]["local"], False, "a LAN address = reachable")
eq((rows[(3702, "wsdd")]["scope"], rows[(3702, "wsdd")]["unit"]), ("user", "gvfs-daemon.service"), "user unit from the cgroup")
eq((rows[(631, "cups.service")]["scope"], rows[(631, "cups.service")]["pid"]), ("system", 0), "root socket: unit, no pid")
eq((rows[(5173, "Web Content")]["pid"], rows[(5173, "Web Content")]["unit"]), (13, ""), "app scope: process, no unit")
eq(rows[(5173, "Web Content")]["url"], "http://localhost:5173", "own TCP listener on loopback: Open")
eq(rows[(631, "cups.service")]["url"], "http://localhost:631", "root web port: Open")
eq(rows[(443, "nginx.service")]["url"], "https://localhost:443", "TLS port: https")
eq(rows[(5355, "systemd-resolved.service")]["url"], "", "root non-web port: no Open")
eq(rows[(3702, "wsdd")]["url"], "", "UDP: no Open")
eq([r["local"] for r in srv.parse_ss(SS, 32768, 60999)][:4], [False] * 4, "reachable rows first")
eq(srv.unit_of(USER + "/app.slice/app-ff.scope"), ("", ""), "user manager itself is no unit")
eq(srv.unit_of("/system.slice/foo.service/payload"), ("system", "foo.service"), "innermost service")

SHOW = """\
Id=wireplumber.service
Description=Multimedia <b>Service</b>
LoadState=loaded
ActiveState=active
SubState=running
ActiveEnterTimestamp=@1795550676
InactiveEnterTimestamp=@1795550000
MemoryCurrent=35307520

Id=nonexist.service
LoadState=not-found
ActiveState=inactive

Id=obex.service
Description=Bluetooth OBEX service
LoadState=loaded
ActiveState=failed
SubState=failed
ActiveEnterTimestamp=
InactiveEnterTimestamp=@1795551000
MemoryCurrent=[not set]

Id=x.service
LoadState=loaded
ActiveState=inactive
MemoryCurrent=18446744073709551615
"""
svc = srv.parse_show(SHOW, "user", {"wireplumber.service": [8080, 8080, 22]})
eq([s["unit"] for s in svc], ["wireplumber.service", "obex.service", "x.service"], "show: not-found units dropped")
eq((svc[0]["since"], svc[0]["memory"], svc[0]["ports"]), (1795550676, 35307520, [22, 8080]), "active: since entered, memory, ports")
eq(svc[0]["description"], "Multimedia <b>Service</b>", "description passed through raw (the pane shows it as PlainText)")
eq((svc[1]["active"], svc[1]["since"], svc[1]["memory"]), ("failed", 1795551000, 0), "failed: since it stopped, no memory")
eq((svc[2]["since"], svc[2]["memory"]), (0, 0), "no timestamp, infinity memory -> 0")

# ---- actions: argv to systemctl, never a shell; bad input never reaches it ----
tmp = Path(tempfile.mkdtemp(prefix="servers-test-"))
log = tmp / "argv"
(tmp / "systemctl").write_text(f'#!/bin/sh\nprintf "%s\\n" "$@" > {log}\nexit 3\n')
(tmp / "systemctl").chmod(0o755)
env = dict(os.environ, PATH=f"{tmp}:{os.environ['PATH']}")


def act(*args):
  log.unlink(missing_ok=True)
  code = subprocess.run([sys.executable, str(SCRIPT), *args], env=env, capture_output=True, check=False).returncode
  return code, log.read_text().split("\n")[:-1] if log.exists() else None


eq(act("stop", "user", "wireplumber.service"), (3, ["--user", "stop", "--", "wireplumber.service"]), "user stop, exit code passes")
eq(act("restart", "system", "cups.service"), (3, ["restart", "--", "cups.service"]), "system restart: no --user")
eq(act("start", "user", "dbus-:1.2-org.x@0.service"), (3, ["--user", "start", "--", "dbus-:1.2-org.x@0.service"]), "instance names pass")
for bad in [("stop", "user", "x;rm -rf ~.service"), ("stop", "user", "sshd"), ("enable", "user", "a.service"),
            ("stop", "root", "a.service"), ("stop", "user", "a.service\n")]:
  eq(act(*bad), (1, None), f"rejected before systemctl: {bad!r}")
for verb in ("stop", "restart"):
  eq(act(verb, "user", "speakerguardd-v2-graph.service"), (1, None), f"speaker protection: no {verb}")
eq(act("start", "system", "speakersafetyd.service"), (3, ["start", "--", "speakersafetyd.service"]), "speaker protection may start")

sys.exit(1 if FAILED else 0)
