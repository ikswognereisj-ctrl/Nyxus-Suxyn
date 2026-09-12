#!/usr/bin/env bash
set -uo pipefail
# ============================================================
#  NYXUS PULSE — audio-reactive prism halo (rev r1 · 2026-07-07)
#
#  The focused window's violet shadow bloom thumps with whatever
#  is playing: a dedicated cava instance taps the PipeWire monitor
#  (~/.config/nyxus/pulse-cava.conf, 20fps, 2 bars = L/R), this
#  daemon maps the loudest channel (0-7) to shadow alpha + radius
#  and applies both in one `hyprctl --batch` call.
#
#  Zero idle cost: cava's sleep_timer stops frames when audio is
#  silent, and hyprctl only fires when the level BUCKET changes.
#  Attack is instant, decay is 1 level/frame — thump, then breathe.
#
#  usage: nyxus-pulse.sh start|stop|toggle|status|run
#  SUPER+ALT+P toggles (nyxus-hyprland-flair.conf); autostarted
#  from hyprland.conf. Stock halo is restored on any exit.
#
# ============================================================

# Runtime state policy (WIP-544): short-lived daemon state belongs under
# XDG_RUNTIME_DIR when present, with TMPDIR and /tmp as safe fallbacks.
RUNTIME_ROOT="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
PIDFILE="${RUNTIME_ROOT%/}/.nyxus-pulse.pid"
FIFO="${RUNTIME_ROOT%/}/.nyxus-pulse.fifo"
CFG="$HOME/.config/nyxus/pulse-cava.conf"

# ACCENT-AWARE (rev r2): the halo hue is read from the LIVE compositor,
# not hardcoded — nyxus-apply-accent / accent-from-wallpaper can re-skin
# the desktop at any time and the pulse follows. The stock rgb+alpha are
# re-read at daemon start and again at the start of every burst that
# begins from silence, so an accent change lands on the next beat.
STOCK_RGB="ae206c"     # overwritten by read_stock() before first apply
# 2026-08-08: skel carried "3727e6" -- a PRE-ROSE hex that survived the
# palette sweep because this file is not on any gate's scan path -- and NS
# carried "521e72", in-palette but a generation behind the ring it is
# standing in for. read_stock() overwrites all three below before the first
# apply; they only show if that read fails, which is also the path restore()
# runs on.
#
# 2026-08-18: all three were STILL WRONG, measured against the config this
# comment names. The fallback said 891654/3a/42; the shipped chain resolves to
# ae206c/3d/18. Last writer wins across three files and the whole chain was
# checked rather than the one that looked right:
#   hyprland.conf:497            range 36  color rgba(1e03ad3a)   (pre-rose)
#   nyxus-hyprland-general.conf  range 18  color rgba(ae206c3d)   sourced @1027
#   nyxus-cometfire.conf         --        color rgba(ae206c3d)   sourced @1083
# And 891654 is not a palette member at all: theme/accent.json names it once,
# in `_border_unified`, as the value the 2026-08-09 sweep REPLACED with
# #891955. So the failure path restored a colour the build had retired.
STOCK_ALPHA="3d"
STOCK_RANGE=18

read_stock() {
    # decoration:shadow:color int is AARRGGBB
    local hex
    hex=$(printf '%08x' "$(hyprctl getoption decoration:shadow:color -j 2>/dev/null \
        | jq -r '.int // empty' 2>/dev/null)" 2>/dev/null) || return 0
    if [ "${#hex}" = 8 ]; then
        STOCK_ALPHA=${hex:0:2}
        STOCK_RGB=${hex:2:6}
    fi
    STOCK_RANGE=$(hyprctl getoption decoration:shadow:range -j 2>/dev/null \
        | jq -r '.int // 18' 2>/dev/null) || STOCK_RANGE=18
}

restore() {
    hyprctl --batch \
        "keyword decoration:shadow:color rgba(${STOCK_RGB}${STOCK_ALPHA}) ; keyword decoration:shadow:range $STOCK_RANGE" \
        >/dev/null 2>&1
}

run() {
    # per-level shadow alpha + bloom radius (index = cava level 0-7).
    # This ramp is the EFFECT, not the resting halo: level 0 is 3a/42, and the
    # shipped resting halo is 3d/18 (nyxus-hyprland-general.conf, last writer
    # on range; nyxus-cometfire.conf on colour). It used to say level 0
    # "mirrors the stock halo" and that was never true of range. What returns
    # the desktop to rest is restore(), from the values read_stock() read off
    # the live compositor -- never this array. Whether the ramp should START
    # at the resting halo is a visual question and is filed, not decided here.
    local alpha=(3a 46 52 5e 6a 78 88 99)
    local range=(42 46 50 55 60 66 72 80)
    local cur=0 last=-1 target c
    local cavapid=""

    read_stock

    echo $$ >"$PIDFILE"

    if [ "${NYXUS_PULSE_TEST:-0}" = 1 ]; then
        # test harness: frames come from stdin, no restore on exit so
        # the applied values can be inspected after EOF
        trap 'rm -f "$PIDFILE"' EXIT
    else
        rm -f "$FIFO"; mkfifo "$FIFO"
        cava -p "$CFG" >"$FIFO" &
        cavapid=$!
        trap 'kill "$cavapid" 2>/dev/null; restore; rm -f "$PIDFILE" "$FIFO"' EXIT
        exec <"$FIFO"
    fi

    while IFS= read -r line; do
        # frame like "3;5;" — take the loudest channel
        target=0
        for c in ${line//;/ }; do
            case "$c" in *[!0-9]*|'') continue ;; esac
            [ "$c" -gt "$target" ] && target=$c
        done
        [ "$target" -gt 7 ] && target=7

        # burst starting from silence: pick up the current accent first,
        # so a wallpaper/accent re-skin is honored on the next beat
        if [ "$cur" -eq 0 ] && [ "$target" -gt 0 ] && [ "${NYXUS_PULSE_TEST:-0}" != 1 ]; then
            read_stock
        fi

        # instant attack, 1-level-per-frame decay
        if [ "$target" -gt "$cur" ]; then
            cur=$target
        elif [ "$cur" -gt 0 ]; then
            cur=$((cur - 1))
        fi

        if [ "$cur" -ne "$last" ]; then
            hyprctl --batch \
                "keyword decoration:shadow:color rgba(${STOCK_RGB}${alpha[cur]}) ; keyword decoration:shadow:range ${range[cur]}" \
                >/dev/null 2>&1
            last=$cur
        fi
    done
}

running() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

case "${1:-toggle}" in
    run)    run ;;
    start)
        running && exit 0
        command -v cava >/dev/null || { notify-send -u critical "NYXUS Pulse" "cava is not installed"; exit 1; }
        setsid "$0" run >/dev/null 2>&1 &
        ;;
    stop)
        running && kill "$(cat "$PIDFILE")" 2>/dev/null
        ;;
    toggle)
        if running; then
            "$0" stop
            notify-send -u low -t 2000 "◤ ♪ ◥ NYXUS PULSE" "halo static" 2>/dev/null
        else
            "$0" start
            notify-send -u low -t 2000 "◤ ♪ ◥ NYXUS PULSE" "halo is listening" 2>/dev/null
        fi
        ;;
    status)
        running && echo "pulse: running ($(cat "$PIDFILE"))" || echo "pulse: stopped"
        ;;
esac
