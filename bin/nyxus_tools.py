"""nyxus_tools — things the brain can DO, instead of things it has to know.

── THE IDEA, AND WHY IT BEATS A BIGGER MODEL FOR THIS JOB ─────────────────
A model that must KNOW your disk usage has to be retrained when the disk fills.
A model that can RUN `df` is never wrong about it. Almost everything that makes
an assistant feel capable on a real machine is this: not more parameters, but
the ability to go and look.

That is also the honest answer to "can I load part of its brain when I need it".
Tools are exactly that, and they cost nothing to train, never go stale, and are
correct by construction.

── ⚠ THE SECURITY LINE, WHICH IS THE WHOLE DESIGN ────────────────────────
A local model deciding what to run on the owner's machine is a genuine risk, and
the risk is not hypothetical: the model reads FILES and LOGS, and a log line is
attacker-controllable text. If a tool could run arbitrary commands, anything
that could get a string into a log it later read would have a path to execution.

So this is not a shell. It is a FIXED SET of named, read-only operations with
NO free-text command anywhere:

  · The model may only choose a tool NAME from this file and supply arguments
    that are validated per tool.
  · No tool takes a shell string. Every one runs a fixed argv list.
  · No tool writes, deletes, installs, or touches the network.
  · Paths are confined to a small allowlist of directories, and `..` is rejected
    after resolution, not before.

Adding a tool that takes a command is the one change that would break this, and
it should not be made.
"""
import json
import os
import subprocess

# Read-only roots. Anything outside these is refused even if a path resolves
# there through a symlink, because resolution happens BEFORE the check.
READABLE = [
    os.path.expanduser("~/.config"),
    os.path.expanduser("~/.local/share/nyxus-brain"),
    os.path.expanduser("~/nyxus-brain-corpus"),
    "/etc/jett",
    "/var/log/jett",
]

TIMEOUT = 10


def _run(argv):
    """Fixed argv, never a shell string. shell=True with model-supplied text is
    the whole vulnerability this file exists to avoid."""
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=TIMEOUT)
        out = (p.stdout or "") + (p.stderr or "")
        return out.strip()[:4000] or "(no output)"
    except subprocess.TimeoutExpired:
        return f"(timed out after {TIMEOUT}s)"
    except FileNotFoundError:
        return f"(command not available: {argv[0]})"
    except Exception as e:
        return f"(failed: {e})"


def _safe_path(p):
    real = os.path.realpath(os.path.expanduser(p))
    for root in READABLE:
        if real == root or real.startswith(root + os.sep):
            return real
    return None


# ── the tools ──────────────────────────────────────────────────────────────

def disk_usage(_=None):
    return _run(["df", "-h", "/", os.path.expanduser("~")])


def memory(_=None):
    return _run(["free", "-h"])


def top_processes(_=None):
    return _run(["ps", "-eo", "pcpu,pmem,comm", "--sort=-pcpu"])[:1500]


def service_status(args):
    name = (args or {}).get("name", "")
    # Unit names only. This is the check that stops "jett; rm -rf /" being a
    # unit name, and it is why the argv form above is not enough on its own.
    if not name or not all(c.isalnum() or c in "-_.@" for c in name):
        return "(refused: not a valid unit name)"
    return _run(["systemctl", "is-active", name]) + " / " + _run(["systemctl", "is-enabled", name])


def gpu(_=None):
    return _run(["nvidia-smi", "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu",
                 "--format=csv,noheader"])


def uptime(_=None):
    return _run(["uptime"])


def read_file(args):
    p = (args or {}).get("path", "")
    real = _safe_path(p)
    if not real:
        return f"(refused: {p} is outside the readable roots)"
    if not os.path.isfile(real):
        return f"(not a file: {real})"
    if os.path.getsize(real) > 200_000:
        return f"(too large: {os.path.getsize(real)} bytes)"
    with open(real, "r", encoding="utf-8", errors="replace") as f:
        return f.read()[:6000]


def list_dir(args):
    p = (args or {}).get("path", "")
    real = _safe_path(p)
    if not real:
        return f"(refused: {p} is outside the readable roots)"
    if not os.path.isdir(real):
        return f"(not a directory: {real})"
    return "\n".join(sorted(os.listdir(real))[:200])


def jett_recent(_=None):
    """The last few Jett verdicts — the question he actually asks most."""
    log = "/var/log/jett/quarantine.log"
    alt = "/var/jett/quarantine/quarantine.log"
    path = log if os.path.exists(log) else alt
    if not os.path.exists(path):
        return "(no jett log readable)"
    try:
        return _run(["tail", "-15", path])
    except Exception as e:
        return f"(failed: {e})"


TOOLS = {
    "disk_usage": (disk_usage, "Free and used disk space.", {}),
    "memory": (memory, "RAM usage.", {}),
    "top_processes": (top_processes, "Processes by CPU.", {}),
    "gpu": (gpu, "GPU utilisation, memory and temperature.", {}),
    "uptime": (uptime, "Uptime and load average.", {}),
    "service_status": (service_status, "Whether a systemd unit is active/enabled.",
                       {"name": "unit name, e.g. jett-daemon"}),
    "read_file": (read_file, "Read a config file under the allowed roots.",
                  {"path": "absolute or ~ path"}),
    "list_dir": (list_dir, "List a directory under the allowed roots.",
                 {"path": "absolute or ~ path"}),
    "jett_recent": (jett_recent, "The most recent Jett verdicts.", {}),
}


def describe():
    lines = []
    for name, (_fn, doc, params) in TOOLS.items():
        arg = ("  args: " + json.dumps(params)) if params else "  args: none"
        lines.append(f"- {name}: {doc}\n{arg}")
    return "\n".join(lines)


def call(name, args):
    entry = TOOLS.get(name)
    if not entry:
        return f"(no such tool: {name})"
    fn = entry[0]
    try:
        return fn(args)
    except Exception as e:
        return f"(tool error: {e})"
