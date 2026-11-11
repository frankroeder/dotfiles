#!/usr/bin/env python3
"""asahi-touchid-monitor: who asked for Touch ID (classify) on fake process tables, and /proc parsing on a fake tree.

Run: uv run --no-project python asahi/bin/asahi_touchid_monitor_test.py
"""
import importlib.machinery
import importlib.util
import os
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
loader = importlib.machinery.SourceFileLoader("tim", os.path.join(HERE, "asahi-touchid-monitor"))
spec = importlib.util.spec_from_loader("tim", loader)
tim = importlib.util.module_from_spec(spec)
loader.exec_module(tim)

UID = 1000
fails = 0


def check(name, got, want):
    global fails
    if got == want:
        print("ok  ", name)
    else:
        fails += 1
        print("FAIL", name, "got", repr(got), "want", repr(want))


def p(pid, ppid, comm, argv, ruid=UID, start=100.0):
    return {"pid": pid, "ppid": ppid, "comm": comm, "argv": argv, "ruid": ruid, "start": start}


base = [p(1, 0, "systemd", ["/usr/lib/systemd/systemd"], ruid=0), p(500, 1, "ghostty", ["ghostty"]),
        p(501, 500, "zsh", ["-zsh"]), p(90, 1, "aurora-fidod", ["/usr/bin/python3", "-I", "/usr/libexec/aurora-fido/aurora-fidod"], ruid=0)]
clients = [{"pid": 500, "class": "com.mitchellh.ghostty", "address": "0xaaa", "focusHistoryID": 3},
           {"pid": 500, "class": "com.mitchellh.ghostty", "address": "0xbbb", "focusHistoryID": 0}]

# sudo in a terminal: command without options, the terminal's focused window.
r = tim.classify(base + [p(600, 501, "sudo", ["sudo", "-u", "root", "-E", "/usr/bin/dnf", "upgrade", "-y"], start=200)],
                 UID, clients, 210)
check("sudo kind", r["kind"], "sudo")
check("sudo detail", r["detail"], "dnf upgrade -y")
check("sudo app", (r["app"], r["address"]), ("Ghostty", "0xbbb"))
check("sudo not suppressed", r["suppress"], False)
check("sudo -i", tim.sudo_command(["sudo", "-i"]), "root shell")
check("sudo --", tim.sudo_command(["sudo", "--", "-weird"]), "-weird")
# Another user's sudo is not ours.
r = tim.classify(base + [p(600, 1, "sudo", ["sudo", "ls"], ruid=1001)], UID, clients, 210)
check("foreign sudo ignored", r["kind"], "fido")
# Lock screen and polkit card draw their own prompt.
check("hyprlock suppressed", tim.classify(base + [p(700, 1, "hyprlock", ["hyprlock"])], UID, clients, 1)["suppress"], True)
check("polkit suppressed", tim.classify(base + [p(701, 1, "polkit-agent-he", ["/usr/lib/polkit-1/polkit-agent-helper-1"], ruid=0)],
                                        UID, clients, 1)["kind"], "polkit")
# FIDO: newest recent ssh / git names the request; an old one does not.
r = tim.classify(base + [p(800, 501, "git", ["/usr/bin/git", "push"], start=150),
                         p(801, 800, "ssh", ["/usr/bin/ssh", "git@github.com", "git-receive-pack"], start=151)],
                 UID, clients, 160)
check("fido ssh title", r["title"], "SSH security key")
check("fido ssh detail", r["detail"], "ssh git@github.com git-receive-pack")
check("fido ssh window", r["address"], "0xbbb")
r = tim.classify(base + [p(800, 501, "ssh", ["ssh", "host1"], start=150), p(802, 1, "ssh", [], start=155)], UID, clients, 160)
check("fido skips a zombie ssh", r["detail"], "ssh host1")
r = tim.classify(base + [p(801, 501, "ssh", ["ssh", "host"], start=10)], UID, clients, 1000)
check("fido stale ssh = passkey", r["title"], "Passkey")
# Nothing known: generic, shown.
r = tim.classify([p(1, 0, "systemd", ["systemd"], ruid=0)], UID, [], 1)
check("other", (r["kind"], r["suppress"]), ("other", False))
# Control characters never reach the card.
check("clean", tim.clean("a\x1b[31mb\u202ec"), "a [31mb c")
check("clean cut", len(tim.clean("x" * 500)), 120)

# /proc parsing: comm with spaces and parentheses, uid from status.
with tempfile.TemporaryDirectory() as root:
    d = os.path.join(root, "42")
    os.makedirs(d)
    fields = " ".join(["S", "7"] + ["0"] * 17 + ["12345"] + ["0"] * 10)
    open(os.path.join(d, "stat"), "w").write(f"42 (we(ird) name) {fields}\n")
    open(os.path.join(d, "status"), "w").write("Name:\tx\nUid:\t1000\t0\t0\t0\n")
    open(os.path.join(d, "cmdline"), "wb").write(b"sudo\0ls\0")
    os.makedirs(os.path.join(root, "self"))
    procs = tim.read_procs(root)
    check("proc parse", (procs[0]["comm"], procs[0]["ppid"], procs[0]["ruid"], procs[0]["argv"]),
          ("we(ird) name", 7, 1000, ["sudo", "ls"]))
    check("proc start", procs[0]["start"], 12345 / os.sysconf("SC_CLK_TCK"))

raise SystemExit(1 if fails else 0)
