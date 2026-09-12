#!/usr/bin/env bash
# Nyxus Suxyn — which Pulse/PipeWire sink Beat.qml's cava must tap.
#
# Prints three lines: sink name, then 0 or 1 (is anything actually playing),
# then route state (`ok`, `paused`, `muted`, `unavailable`).
# Falls back to the default sink for the unused conf. Never the microphone.
# Never a hardcoded device name.
#
# With two args (template, live-conf), also writes a cava profile whose
# [input] source is that sink so Beat does not follow a silent HDMI
# default while music plays on Headphones.
#
# Why this exists: cava `source = auto` follows the DEFAULT sink. On this
# machine that has been an idle NVIDIA HDMI device while music played on
# Headphones / EasyEffects — Beat heard silence, the rims did not move,
# and a fake idle pulse was the only thing left to look at.
#
# Why playing is not "any sink-input": Chromium keeps an uncorked AudioService
# stream after you leave a tab, and EasyEffects will maximise that hiss into
# a fake beat. Owner 11:14/11:17: rims still moving with "nothing playing".
# Measured 11:21: the visible window was a Google Search tab, but MPRIS was
# Playing "Bad Boyz" / Shyne and the position was advancing — a background
# tab. A leftover stream with MPRIS Paused/Stopped is NOT playback; a game
# or mpv sink-input still is, even with no MPRIS.
set -euo pipefail

default=$(pactl get-default-sink 2>/dev/null || true)

# Python parses the long sink-input list (cork/mute/volume) and MPRIS.
# Prints: sink<TAB>0|1<TAB>state
map=$(python3 - "$default" <<'PY'
import re, subprocess, sys

default = sys.argv[1] if len(sys.argv) > 1 else ""
BROWSERS = ("chromium", "chrome", "firefox", "brave", "vivaldi", "librewolf")
FILTER = ("easyeffects", "jamesdsp", "jdsp", "ladspa")

def run(cmd, timeout=0.6):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.stdout or ""
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ""

def sink_map():
    names, states, order = {}, {}, []
    for line in run(["pactl", "list", "short", "sinks"]).splitlines():
        p = line.split("\t")
        if len(p) >= 2:
            names[p[0]] = p[1]
            order.append(p[1])
            if len(p) >= 5:
                states[p[1]] = p[4]
    mutes = {}
    for block in re.split(r"\n(?=Sink #)", run(["pactl", "list", "sinks"])):
        m = re.search(r"^\s*Name:\s*([^\n]+)", block, re.M)
        if not m:
            continue
        mute = re.search(r"^\s*Mute:\s*(yes|no)", block, re.M)
        mutes[m.group(1).strip()] = (mute.group(1) == "yes") if mute else False
    return names, states, mutes, order

def sink_available(name: str, states: dict) -> bool:
    state = (states.get(name) or "").strip().upper()
    return name != "" and state not in ("UNLINKED",)

def is_browser(blob: str) -> bool:
    b = blob.lower()
    return any(x in b for x in BROWSERS)

def is_filter(name: str) -> bool:
    n = (name or "").lower()
    return any(x in n for x in FILTER)

names, states, mutes, _sink_order = sink_map()
text = run(["pactl", "list", "sink-inputs"])
other = False
browser = False
chosen = None
for block in re.split(r"\n(?=Sink Input #)", text):
    if "Sink Input #" not in block:
        continue
    if re.search(r"Corked:\s*yes", block):
        continue
    if re.search(r"^\s*Mute:\s*yes", block, re.M):
        continue
    vols = [int(x) for x in re.findall(r"/\s*(\d+)%", block)]
    if vols and max(vols) == 0:
        continue
    m = re.search(r"Sink:\s*(\d+)", block)
    if not m:
        continue
    name = names.get(m.group(1))
    if not name:
        continue
    app = re.search(r'application\.name = "([^"]*)"', block)
    binary = re.search(r'application\.process\.binary = "([^"]*)"', block)
    blob = f"{app.group(1) if app else ''} {binary.group(1) if binary else ''}"
    br = is_browser(blob)
    if br:
        browser = True
    else:
        other = True
        chosen = name
    if chosen is None:
        chosen = name

mpris_playing = False
has_browser_mpris = False
st = run(["/usr/bin/playerctl", "-a", "status"], timeout=0.5)
if any(line.strip() == "Playing" for line in st.splitlines()):
    mpris_playing = True
lst = run(["/usr/bin/playerctl", "-l"], timeout=0.4).lower()
has_browser_mpris = any(x in lst for x in BROWSERS)

# Games / mpv / etc. always count. Browsers count when MPRIS says Playing,
# or when Chromium never exported MPRIS (older YouTube). A leftover
# AudioService stream with Paused/Stopped must not arm the ear.
playing = 1 if (other or mpris_playing or (browser and not has_browser_mpris)) else 0

sink = chosen or default
if playing and sink and is_filter(sink) and default and not is_filter(default):
    # EasyEffects monitor hiss is not the hear path. Headphones/default is.
    sink = default

if not sink and sink_available(default, states):
    sink = default

state = "ok"
if not sink:
    state = "unavailable"
elif mutes.get(sink, False):
    state = "muted"
    playing = 0
elif not sink_available(sink, states):
    state = "unavailable"
    playing = 0
elif not playing:
    state = "paused"

if not sink:
    sys.stderr.write("nyxus-beat-tap: no sink\n")
    sys.exit(1)
sys.stdout.write(f"{sink}\t{playing}\t{state}\n")
PY
)

sink=${map%%$'\t'*}
rest=${map#*$'\t'}
playing=${rest%%$'\t'*}
state=${rest##*$'\t'}

if [[ -z ${sink:-} ]]; then
    echo "nyxus-beat-tap: no sink" >&2
    exit 1
fi

if [[ $# -eq 2 ]]; then
    template=$1
    live=$2
    if [[ ! -f $template ]]; then
        echo "nyxus-beat-tap: missing template $template" >&2
        exit 1
    fi
    mkdir -p "$(dirname "$live")"
    tmp=${live}.tmp
    # Drop a committed [input] block, then pin pulse to the playing sink.
    awk '
        BEGIN { skip = 0 }
        /^\[input\]/ { skip = 1; next }
        /^\[/ && skip { skip = 0 }
        skip { next }
        { print }
    ' "$template" > "$tmp"
    printf '\n[input]\nmethod = pulse\nsource = %s\n' "$sink" >> "$tmp"
    mv "$tmp" "$live"
fi

printf '%s\n%s\n%s\n' "$sink" "$playing" "${state:-ok}"
