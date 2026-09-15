#!/usr/bin/env bash
# NYXUS desktop context menu.
# Usage:
#   nyxus-context-menu.sh act <action> [arg]
#                                    -> DO a thing. Draws nothing at all.
#   nyxus-context-menu.sh main       -> top-level right-click menu
#   nyxus-context-menu.sh wallpaper  -> wallpaper picker submenu
#   nyxus-context-menu.sh display    -> display-arrange submenu
#   nyxus-context-menu.sh sort       -> icon sort submenu (used by T2+)
#   nyxus-context-menu.sh icon PATH  -> the menu for one desktop icon
#   nyxus-context-menu.sh dismiss    -> close any open menus / launcher
#
# Front-end: rofi -dmenu, glacier ice chrome (08-20 DD). Falls back to wofi
# if rofi is missing. Falls back to a notify-send error if neither.
# Files in-app right-click IS this file in `icon` mode — nyxus_files.py
# `_spawn_icon_menu` execs it with no GTK Popover. The old "bigger tab" was
# rofi's inputbar (prompt + search entry) in galaxy violet.
#
# ── WIP-557 · THIS FILE IS THE FALLBACK, NOT THE DESKTOP'S MENU ──────────
#
# rofi is a different toolkit drawing a different menu, and no amount of
# -theme-str makes it Nyxus Glass. The owner said so repeatedly -- "the odd
# one that didnt belong and wasnt themed" -- and he was right every time.
# WIP-126 built shell/ContextMenu.qml to replace it and recorded that this
# script would stay only "as the fallback for when the shell is not
# running". That is now true, and until 2026-08-12 it was not: nothing ever
# asked the QML surface for a desktop menu, so `main` below was the ONLY
# thing a right-click on the wallpaper ever reached.
#
# nyxus_desktop.py now pre-flights `qs ipc call menu ready` and only spawns
# this script when the shell does not answer. So:
#
#   * `act` is the action layer. BOTH front ends call it, which is why the
#     QML menu does not reimplement "New Folder 2" or the IPC poke -- one
#     answer to each question, in one place.
#   * The interactive modes below are what you get with no shell. Do not
#     wire a new caller straight to them; call `act`, or ask the shell.
set -euo pipefail

MODE="${1:-main}"
LOG="${HOME}/.cache/nyxus/context-menu.log"
mkdir -p "$(dirname "$LOG")"
exec 2>>"$LOG"
echo "--- $(date -Iseconds) mode=$MODE ---" >&2

# 2026-08-20 (DD): glacier ice, not galaxy violet. The Files right-click
# "bigger tab" was this prompt+entry bar in #521e72 on near-black. Ice
# tokens match Media/Files chrome: hover #b7e6f2 / focus #7fe8ff / seam
# #4f7fa6 / peak #eefcff. Magma stays off the chrome — only a real
# destructive confirm (zenity Delete) is magma-adjacent.
ICE="#7fe8ff"
HOVER="#b7e6f2"
SEAM="#4f7fa6"
INK="rgba(2, 5, 6, 0.90)"
INK2="rgba(7, 19, 24, 0.92)"
TXT="#eefcff"
DIM="${HOVER}"

_have() { command -v "$1" >/dev/null 2>&1; }

# ---------- where the menu opens ----------
# A context menu belongs AT THE POINTER. rofi centres its window by default,
# which is why this read as "its own separate window" rather than as a menu
# belonging to the click that summoned it (owner, 2026-08-06). rofi has no
# native at-cursor mode, so anchor it by hand: take the pointer from the
# compositor, pin the window's north-west corner to the screen's north-west,
# and offset by the pointer position.
#
# Clamping matters. Right-click near the right or bottom edge and an unclamped
# menu opens half off-screen, which is worse than centred. MENU_W/MENU_H below
# must stay in agreement with `window { width }` and the listview line count.
MENU_W=280
MENU_H=380
MENU_LINES=12

_cursor_theme_str() {
  local pos x y sw sh
  # hyprctl cursorpos prints "x, y". If it is unavailable (no compositor, a
  # different session) fall back to centring rather than guessing a corner.
  pos=$(hyprctl cursorpos 2>/dev/null) || { printf 'window { location: center; }'; return; }
  x=${pos%%,*}; y=${pos##*, }
  [[ "$x" =~ ^[0-9]+$ && "$y" =~ ^[0-9]+$ ]] || { printf 'window { location: center; }'; return; }

  # Focused monitor's logical size, so this is correct on a scaled or
  # multi-head setup instead of assuming 1920x1080.
  read -r sw sh < <(hyprctl -j monitors 2>/dev/null \
    | python3 -c 'import json,sys
try:
    ms = json.load(sys.stdin)
    m = next((m for m in ms if m.get("focused")), ms[0])
    print(int(m["width"] / (m.get("scale") or 1)), int(m["height"] / (m.get("scale") or 1)))
except Exception:
    print(1920, 1080)' 2>/dev/null) || { sw=1920; sh=1080; }

  (( x + MENU_W > sw )) && x=$(( sw - MENU_W - 8 ))
  (( y + MENU_H > sh )) && y=$(( sh - MENU_H - 8 ))
  (( x < 0 )) && x=0
  (( y < 0 )) && y=0
  printf 'window { location: north west; anchor: north west; x-offset: %dpx; y-offset: %dpx; }' "$x" "$y"
}

# ---------- frontend ----------
_menu() {
  # $1 = prompt, $2 = pick (default, no search entry) or search.
  # pick is a context menu: hiding `entry` is what removes the "bigger tab".
  local prompt="$1" kind="${2:-pick}" bar
  if [[ "${kind}" == "search" ]]; then
    bar="
        inputbar { padding: 6px 10px; children: [ prompt, entry ];
                   background-color: ${INK2}; border-radius: 6px;
                   border: 1px; border-color: ${SEAM};
                   margin: 0 0 6px 0; }
        prompt { text-color: ${ICE}; padding: 0 6px 0 0; }
        entry { placeholder-color: ${DIM}; text-color: ${TXT}; }"
  else
    bar="
        inputbar { padding: 4px 10px; children: [ prompt ];
                   background-color: ${INK2}; border-radius: 6px;
                   border: 1px; border-color: ${SEAM};
                   margin: 0 0 6px 0; }
        prompt { text-color: ${ICE}; padding: 0; }"
  fi
  if _have rofi; then
    rofi -dmenu -i -no-custom -p "$prompt" \
      -theme-str "
        * { background-color: ${INK}; text-color: ${TXT};
            font: \"Inter 11\"; }
        window { width: ${MENU_W}px; padding: 6px; border: 1px;
                 border-color: ${SEAM}; border-radius: 10px; }
        mainbox { children: [ inputbar, listview ]; }
        ${bar}
        listview { lines: ${MENU_LINES}; spacing: 1px; scrollbar: false; }
        element { padding: 7px 10px; border-radius: 5px; }
        element selected {
            background-color: rgba(127, 232, 255, 0.18);
            border: 0 0 0 2px; border-color: ${ICE};
            text-color: ${TXT}; }
        element-text { background-color: inherit; text-color: inherit; }
      " -theme-str "$(_cursor_theme_str)" 2>>"$LOG"
  elif _have wofi; then
    wofi --dmenu --prompt "$prompt" --width 280 --height 360
  else
    notify-send -u critical "Nyxus Files" \
      "Install 'rofi' or 'wofi' to use the right-click menu."
    return 127
  fi
}

# ---------- helpers ----------
_term() {
  # Ghostty is THE terminal (DC / TRK-953). Skip leftover nyxus-terminal.py
  # — it still exists on PATH and would swallow this row. No kitty.
  for t in ghostty; do
    if _have "$t"; then "$t" "$@" & return; fi
  done
  notify-send "Nyxus" "No terminal found"
}

_term_in() {
  # Open a terminal whose cwd is $1. Ghostty only (TRK-3001), never kitty.
  # `--working-directory` beats `(cd && ghostty &)`: Ghostty's default is
  # `working-directory = inherit`, but a GUI-spawned `&` is not a reliable cwd.
  local dir="$1"
  [[ -n "$dir" && -d "$dir" ]] || { notify-send "NYXUS" "No directory for the terminal"; return 1; }
  if _have ghostty; then
    ghostty --working-directory="$dir" &
    return
  fi
  notify-send "Nyxus" "Ghostty is not installed"
}

_files_app() {
  # nautilus was dropped from packages 08-20 (PKG-6). Do not exec it.
  if _have nyxus-files; then nyxus-files "$@" &
  elif _have thunar; then thunar "$@" &
  elif _have dolphin; then dolphin "$@" &
  else _term -- "$(command -v lf || command -v ranger || echo bash)" "$@"; fi
}

_settings() {
  # 08-19: QML Settings.qml is THE Settings (WIP-599 superseded). PATH
  # `nyxus-settings` on this host is NYXUS Panel. Deep-link through qs.
  local key; key="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  if _have qs; then
    if [[ -n "$key" ]]; then qs ipc call qmlsettings at "$key" &
    else qs ipc call qmlsettings engage &
    fi
    return
  fi
  notify-send "Nyxus" "Settings (qs) is not running"
}

_uniq_path() {
  # Suggest "name", "name 2", "name 3"... in $1 dir for base $2
  local dir="$1" base="$2" i=1 candidate
  candidate="$dir/$base"
  while [[ -e "$candidate" ]]; do
    i=$((i+1)); candidate="$dir/$base $i"
  done
  printf '%s' "$candidate"
}

_dismiss() {
  pkill -x rofi 2>/dev/null || true
  pkill -x wofi 2>/dev/null || true
  pkill -f nyxus_launcher.py 2>/dev/null || true
  exit 0
}

# ---------- actions (no UI: `act` mode, and the menus below) -------------
# Everything the menu can DO lives here, so the rofi rows and the Quickshell
# rows perform the identical thing. A row that only launches a program is not
# here -- the QML menu launches those directly, because wrapping `exec
# nyxus-settings display` in a shell round-trip would be ceremony, not reuse.
_act_new_folder() {
  local desk="${HOME}/Desktop"; mkdir -p "$desk"
  local p; p="$(_uniq_path "$desk" "New Folder")"
  mkdir -p "$p" && _ipc_send "REFRESH"
}

_act_new_text_file() {
  local desk="${HOME}/Desktop"; mkdir -p "$desk"
  local p; p="$(_uniq_path "$desk" "New Text Document.txt")"
  : > "$p" && _ipc_send "REFRESH"
}

_act_open_terminal() {
  # No arg → Desktop (wallpaper menu / QML `act open-terminal`). A path →
  # that directory, or the file's parent (GAP-910, Files icon menu).
  local dir="${1:-}"
  if [[ -z "$dir" ]]; then
    dir="${HOME}/Desktop"; mkdir -p "$dir"
  elif [[ -d "$dir" ]]; then
    :
  elif [[ -e "$dir" ]]; then
    dir="$(dirname -- "$dir")"
  else
    notify-send "NYXUS" "Nothing to open a terminal in"; return 1
  fi
  _term_in "$dir"
}

_act_open_files() {
  local desk="${HOME}/Desktop"; mkdir -p "$desk"
  _files_app "$desk"
}

_desktop_py() {
  if [[ -f /opt/nyxus/desktop/nyxus_desktop.py ]]; then
    printf '%s' /opt/nyxus/desktop/nyxus_desktop.py
  else
    printf '%s' "$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/nyxus_desktop.py"
  fi
}

_act_recents() {
  local sock="${XDG_RUNTIME_DIR:-/tmp}/nyxus-desktop.sock"
  if [[ -S "$sock" ]]; then
    _ipc_send "RECENTS"
    return 0
  fi
  python3 "$(_desktop_py)" recents &
}

_act_usb() {
  local sock="${XDG_RUNTIME_DIR:-/tmp}/nyxus-desktop.sock"
  if [[ -S "$sock" ]]; then
    _ipc_send "USB"
    return 0
  fi
  python3 "$(_desktop_py)" usb &
}

# GAP-910 · Open as root. Confirmation first (Delete uses zenity --question;
# Previous versions uses a pick). Never pkexec a raw shell — gvfs `admin://`
# elevates through polkit (gvfsd-admin is in the `gvfs` package we already
# ship). gio is the same binary Files uses for trash.
_act_open_root() {
  local target="${1:-}"
  if [[ -z "$target" || ! -e "$target" ]]; then
    notify-send "NYXUS" "Nothing to open as root"; return 1
  fi
  local confirm
  if _have zenity; then
    confirm=$(zenity --question --title="Open as root" \
                --text="Open $(basename -- "$target") as root?" \
                && echo yes || echo no)
  else
    confirm=$(_menu "Open as root" <<'EOF'
 Open as root
 Cancel
EOF
    )
    case "$confirm" in *"Cancel"*|"") confirm=no ;; *) confirm=yes ;; esac
  fi
  [[ "$confirm" == "yes" ]] || { notify-send "NYXUS" "Cancelled"; return 0; }
  if ! _have gio; then
    notify-send "NYXUS" "gio is missing; will not open a raw root shell."
    return 1
  fi
  local uri
  uri=$(python3 -c 'import pathlib,sys
u = pathlib.Path(sys.argv[1]).resolve().as_uri()
print("admin" + u[4:] if u.startswith("file") else u)' "$target") || true
  if [[ -z "${uri:-}" ]]; then
    notify-send "NYXUS" "Could not open as root"; return 1
  fi
  gio open "$uri" >/dev/null 2>&1 &
}

# GAP-910 · Copy file (the file itself, not the path string — that is Copy
# path). One MIME on the Wayland clipboard: GTK's copied-files protocol.
# Files Ctrl+V reads this MIME (GDK, then wl-paste). In-app clipboard_paths
# is only the fallback when that clipboard is empty.
_act_copy_file() {
  local target="${1:-}"
  if [[ -z "$target" || ! -e "$target" ]]; then
    notify-send "NYXUS" "Nothing to copy"; return 1
  fi
  local uri
  uri=$(python3 -c 'import pathlib,sys
print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$target") || true
  if [[ -z "${uri:-}" ]]; then
    notify-send "NYXUS" "Could not copy"; return 1
  fi
  if _have wl-copy; then
    printf 'copy\n%s\n' "$uri" | wl-copy --type x-special/gnome-copied-files
  elif _have xclip; then
    printf 'copy\n%s\n' "$uri" | xclip -selection clipboard \
      -t x-special/gnome-copied-files
  else
    notify-send "NYXUS" "No clipboard tool"; return 1
  fi
  notify-send "NYXUS" "File copied"
}

# $1 = one of name|kind|mtime|size|grid|auto. Writes the icon state the
# desktop layer reads, then asks it to re-lay-out.
_act_sort() {
  local key="${1:-name}"
  case "$key" in
    name|kind|mtime|size|grid|auto) : ;;
    *) notify-send "NYXUS" "Unknown sort: $key"; return 2 ;;
  esac
  python3 - "$key" <<'PY' 2>/dev/null || true
import json,sys,os,pathlib
p=pathlib.Path(os.path.expanduser("~/.config/nyxus/desktop-icons.json"))
p.parent.mkdir(parents=True, exist_ok=True)
data={}
if p.exists():
    try: data=json.loads(p.read_text())
    except Exception: data={}
key = sys.argv[1]
if key == "grid":
    data["snap_to_grid"] = not bool(data.get("snap_to_grid", False))
elif key == "auto":
    data.pop("positions", None)
    data["sort"] = data.get("sort", "name")
else:
    data["sort"] = key
    data.pop("positions", None)
p.write_text(json.dumps(data, indent=2))
PY
  _ipc_send "REFRESH"
  notify-send "NYXUS" "Sort: $key"
}

# The dispatcher for `act`. Unknown actions EXIT NON-ZERO rather than
# shrugging: the QML menu is the main caller now, and a row that silently
# does nothing is the defect class this whole item is about.
# WIP-654 · "Scan with Hemera" — the right-click half of the scan suite.
#
# It goes through the ONE engine that also runs the weekly timer scan, so
# the answer to "what does a scan do to my file" never depends on which door
# was used: a finding is ISOLATED into the locked vault with its exec bits
# stripped, and then the machine stops and asks. This menu entry can no more
# delete a file than the timer can — see nyxus-hemera's own header and gate
# 13q29.
_act_scan() {
  local target="${1:-}"
  if [[ -z "$target" || ! -e "$target" ]]; then
    notify-send "NYXUS" "Nothing to scan"; return 1
  fi
  if ! _have nyxus-hemera; then
    notify-send "NYXUS" "Hemera scan engine is not installed"; return 1
  fi
  # The engine sends its own three volumes of notification (quiet on start,
  # normal on a clean finish, CRITICAL on a finding, with a Review button
  # that opens Settings ▸ Security), so nothing is said here and the menu
  # gets out of the way immediately.
  nyxus-hemera scan path "$target" >/dev/null 2>&1 &
}

# GAP-937 · "Set as wallpaper" from a file's right-click menu.
#
# ⚠ WHICH MENU, 2026-08-22 (TRK-1510): the DESKTOP ICON surface now has a
# QML mode (`ContextMenu.qml` `iconEntries`) that calls THIS action through
# `act wallpaper`. The empty-desktop menu (`desktopEntries`) still must not
# grow the row — that would put "Set as wallpaper" on a click that has no
# file. Files still execs this script in `icon` mode with no shell
# pre-flight (`nyxus_files.py:_spawn_icon_menu`, TRK-1513).
#
# ⚠ AND IT DOES NOT BUILD A SECOND WALLPAPER PATH. `_set_wallpaper` below is
# the route the wallpaper submenu already uses — persist through the shared
# setter `nyxus-set-wallpaper.sh`, then hot-swap the live desktop over the
# IPC socket. It is called through `act`, per this file's own header rule:
# one answer to each question, in one place.
_act_wallpaper() {
  local target="${1:-}"
  if [[ -z "$target" || ! -f "$target" ]]; then
    notify-send "NYXUS" "Nothing to set as wallpaper"; return 1
  fi
  # An image, or nothing. Handing a PDF to the wallpaper setter would
  # persist a path the compositor cannot draw, and the desktop would come
  # back after the next login with no wallpaper at all — which reads as
  # "the wallpaper system is broken" rather than "that was not a picture".
  local mime; mime="$(file -b --mime-type -- "$target" 2>/dev/null || echo "")"
  case "$mime" in
    image/*) : ;;
    *) notify-send "NYXUS" "Not an image: $(basename "$target")"; return 1 ;;
  esac
  _set_wallpaper "$target"
}

# TRK-1510 · icon rows that used to live only inside `_icon_menu`. The QML
# icon menu calls these through `act`; the rofi fallback does too. One
# answer each, in one place.
_act_open() {
  local target="${1:-}"
  if [[ -z "$target" || ! -e "$target" ]]; then
    notify-send "NYXUS" "Nothing to open"; return 1
  fi
  xdg-open "$target" >/dev/null 2>&1 &
}

_act_open_with() {
  local target="${1:-}"
  if [[ -z "$target" || ! -e "$target" ]]; then
    notify-send "NYXUS" "Nothing to open"; return 1
  fi
  local app uri
  shopt -s nullglob
  local files=( /usr/share/applications/*.desktop \
                "$HOME"/.local/share/applications/*.desktop )
  shopt -u nullglob
  if (( ${#files[@]} == 0 )); then
    notify-send "NYXUS" "No applications found"; return 0
  fi
  app=$(printf '%s\n' "${files[@]}" \
        | xargs -n1 basename \
        | sed 's/\.desktop$//' \
        | sort -u | _menu "Open with" search) || true
  [[ -z "${app:-}" ]] && return 0
  uri="file://$(realpath -- "$target" | sed 's| |%20|g')"
  if _have gio; then
    gio launch "/usr/share/applications/${app}.desktop" "$uri" \
      >/dev/null 2>&1 \
      || gio launch "$HOME/.local/share/applications/${app}.desktop" "$uri" \
      >/dev/null 2>&1 \
      || gtk-launch "$app" "$uri" >/dev/null 2>&1 &
  else
    gtk-launch "$app" "$uri" >/dev/null 2>&1 &
  fi
}

_act_open_folder() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    notify-send "NYXUS" "Nothing to open"; return 1
  fi
  _files_app "$(dirname -- "$target")"
}

_act_copy_path() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    notify-send "NYXUS" "Nothing to copy"; return 1
  fi
  if _have wl-copy; then printf '%s' "$target" | wl-copy
  elif _have xclip; then printf '%s' "$target" | xclip -selection clipboard
  else notify-send "NYXUS" "No clipboard tool"; return 1; fi
  notify-send "NYXUS" "Path copied"
}

_act_rename() {
  local target="${1:-}"
  if [[ -z "$target" || ! -e "$target" ]]; then
    notify-send "NYXUS" "Nothing to rename"; return 1
  fi
  local newname
  newname=$(_have zenity && zenity --entry --title="Rename" \
              --text="New name for $(basename "$target"):" \
              --entry-text="$(basename "$target")" 2>/dev/null \
            || printf '')
  [[ -z "$newname" || "$newname" == "$(basename "$target")" ]] && return 0
  mv -n -- "$target" "$(dirname "$target")/$newname" \
    && notify-send "NYXUS" "Renamed to $newname" \
    || notify-send "NYXUS" "Rename failed"
}

_act_trash() {
  local target="${1:-}"
  if [[ -z "$target" || ! -e "$target" ]]; then
    notify-send "NYXUS" "Nothing to trash"; return 1
  fi
  if _have gio; then gio trash -- "$target" \
    && notify-send "NYXUS" "Moved to Trash" \
    || notify-send "NYXUS" "Trash failed"
  else
    notify-send "NYXUS" "gio not installed; cannot trash safely"
    return 1
  fi
}

_act_delete() {
  local target="${1:-}"
  if [[ -z "$target" || ! -e "$target" ]]; then
    notify-send "NYXUS" "Nothing to delete"; return 1
  fi
  local confirm
  confirm=$(_have zenity && zenity --question --title="Delete" \
              --text="Permanently delete $(basename "$target")?" \
              && echo yes || echo no)
  [[ "$confirm" == "yes" ]] && rm -rf -- "$target" \
    && notify-send "NYXUS" "Deleted" \
    || notify-send "NYXUS" "Delete cancelled or failed"
}

_act_properties() {
  local target="${1:-}"
  if [[ -z "$target" || ! -e "$target" ]]; then
    notify-send "NYXUS" "Nothing to inspect"; return 1
  fi
  _settings Storage
  notify-send "NYXUS" "$(basename "$target")
$(stat -c 'Size: %s bytes
Modified: %y
Owner: %U:%G
Mode: %A' "$target" 2>/dev/null)"
}

_act() {
  local action="${1:-}"; shift || true
  case "$action" in
    new-folder)     _act_new_folder ;;
    new-text-file)  _act_new_text_file ;;
    open-terminal)  _act_open_terminal "${1:-}" ;;
    open-files)     _act_open_files ;;
    open-root)      _act_open_root "${1:-}" ;;
    copy-file)      _act_copy_file "${1:-}" ;;
    refresh)        _ipc_send "RELOAD" ;;
    recents)        _act_recents ;;
    usb)            _act_usb ;;
    scan)           _act_scan "${1:-}" ;;
    wallpaper)      _act_wallpaper "${1:-}" ;;
    sort)           _act_sort "${1:-name}" ;;
    open)           _act_open "${1:-}" ;;
    open-with)      _act_open_with "${1:-}" ;;
    open-folder)    _act_open_folder "${1:-}" ;;
    copy-path)      _act_copy_path "${1:-}" ;;
    prev-versions)  _prev_versions "${1:-}" ;;
    rename)         _act_rename "${1:-}" ;;
    trash)          _act_trash "${1:-}" ;;
    delete)         _act_delete "${1:-}" ;;
    properties)     _act_properties "${1:-}" ;;
    *)              echo "unknown action: ${action:-<empty>}" >&2
                    notify-send "NYXUS" "Unknown desktop action: ${action:-<empty>}"
                    exit 2 ;;
  esac
}

# ---------- menus ----------
_main_menu() {
  local choice
  MENU_LINES=14
  MENU_H=440
  choice=$(_menu "Desktop" <<'EOF'
 New folder
 New text file
 Open in terminal
 Open Files
 Recents
 Eject USB
 Change wallpaper…
 Display settings
 Personalize…
 Sort icons…
 Refresh desktop
 System info
 Lock screen
 Power…
EOF
)
  [[ -z "${choice:-}" ]] && exit 0

  local desk="${HOME}/Desktop"; mkdir -p "$desk"
  case "$choice" in
    *"New folder")
      _act_new_folder
      ;;
    *"New text file")
      _act_new_text_file
      ;;
    *"Open in terminal")
      _act_open_terminal
      ;;
    *"Open Files")
      _act_open_files
      ;;
    *"Recents")
      _act_recents
      ;;
    *"Eject USB")
      _act_usb
      ;;
    *"Change wallpaper"*)
      exec "$0" wallpaper
      ;;
    *"Display settings")
      _settings Display
      ;;
    *"Personalize"*)
      _settings Appearance
      ;;
    *"Sort icons"*)
      exec "$0" sort
      ;;
    *"Refresh desktop")
      _ipc_send "RELOAD"
      ;;
    *"System info")
      _settings About
      ;;
    *"Lock screen")
      # WIP-114: never lock an account with no password -- the guard checks
      # and explains instead of trapping the owner outside his own session.
      if _have nyxus-lock-guard; then nyxus-lock-guard &
      elif _have hyprlock; then hyprlock &
      elif _have swaylock; then swaylock &
      else loginctl lock-session; fi
      ;;
    *"Power"*)
      if _have nyxus_powermenu.py; then python3 "$(command -v nyxus_powermenu.py)" &
      elif [[ -x "${HOME}/.local/bin/nyxus_powermenu.py" ]]; then
        python3 "${HOME}/.local/bin/nyxus_powermenu.py" &
      else
        # inline mini power menu
        local p
        p=$(_menu "Power" <<'PEOF'
 Suspend
 Hibernate
 Reboot
 Shutdown
 Log out
PEOF
)
        case "$p" in
          *Suspend)   systemctl suspend ;;
          *Hibernate) systemctl hibernate ;;
          *Reboot)    systemctl reboot ;;
          *Shutdown)  systemctl poweroff ;;
          *"Log out") hyprctl dispatch exit 2>/dev/null || loginctl terminate-session "${XDG_SESSION_ID:-}" ;;
        esac
      fi
      ;;
  esac
}

_wallpaper_menu() {
  local walls_dir="${HOME}/.config/hypr/walls"
  [[ -d "$walls_dir" ]] || walls_dir="${HOME}/Pictures/Wallpapers"
  [[ -d "$walls_dir" ]] || { notify-send "NYXUS" "No wallpapers dir"; exit 1; }
  local list
  list=$(find "$walls_dir" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    -printf '%f\n' | sort)
  list=$'Browse files…\nOpen Appearance settings…\n'"$list"
  list=$'Open Wallpaper Studio…\n'"$list"
  local pick
  pick=$(printf '%s' "$list" | _menu "Wallpaper" search)
  [[ -z "${pick:-}" ]] && exit 0
  case "$pick" in
    "Open Wallpaper Studio"*)
      if _have nyxus; then
        nyxus wallpaper_studio &
      elif _have nyxus-wallpaper-studio; then
        nyxus-wallpaper-studio &
      else
        _settings Appearance
      fi
      ;;
    "Browse files"*)
      local f
      f=$(_have zenity && zenity --file-selection --title="Pick wallpaper" \
            --file-filter='Images | *.png *.jpg *.jpeg *.webp' 2>/dev/null || true)
      [[ -z "$f" ]] && exit 0
      _set_wallpaper "$f"
      ;;
    "Open Appearance"*)
      _settings Appearance
      ;;
    *)
      _set_wallpaper "$walls_dir/$pick"
      ;;
  esac
}

# Send a line over the desktop IPC socket. $1 = command, $2 = optional arg.
# Path is passed via env var to a python helper so filenames with quotes,
# spaces, or non-ASCII characters cannot break the call or inject code.
_ipc_send() {
  local cmd="$1" arg="${2:-}"
  local sock="${XDG_RUNTIME_DIR:-/tmp}/nyxus-desktop.sock"
  [[ -S "$sock" ]] || return 0
  if _have ncat; then
    if [[ -n "$arg" ]]; then printf '%s %s\n' "$cmd" "$arg"; else printf '%s\n' "$cmd"; fi \
      | ncat -U "$sock" >/dev/null 2>&1 || true
  elif _have socat; then
    if [[ -n "$arg" ]]; then printf '%s %s\n' "$cmd" "$arg"; else printf '%s\n' "$cmd"; fi \
      | socat - "UNIX-CONNECT:$sock" >/dev/null 2>&1 || true
  else
    NYXUS_IPC_SOCK="$sock" NYXUS_IPC_CMD="$cmd" NYXUS_IPC_ARG="$arg" \
      python3 -c '
import os, socket
sock = os.environ["NYXUS_IPC_SOCK"]
cmd  = os.environ["NYXUS_IPC_CMD"]
arg  = os.environ.get("NYXUS_IPC_ARG", "")
payload = (cmd + (" " + arg if arg else "") + "\n").encode("utf-8")
s = socket.socket(socket.AF_UNIX)
s.connect(sock)
s.sendall(payload)
s.close()
' >/dev/null 2>&1 || true
  fi
}

_set_wallpaper() {
  local path="$1"
  [[ -f "$path" ]] || { notify-send "NYXUS" "Not a file: $path"; exit 1; }
  # 1. Persist via shared setter (single source of truth on disk)
  if _have nyxus-set-wallpaper.sh; then
    nyxus-set-wallpaper.sh "$path" >/dev/null 2>&1 || true
  fi
  # 2. Hot-swap on the live desktop via safe IPC (no shell interpolation)
  _ipc_send "WALLPAPER" "$path"
  notify-send -i preferences-desktop-wallpaper "NYXUS" "Wallpaper updated"
}

_sort_menu() {
  local choice
  choice=$(_menu "Sort" <<'EOF'
 By name
 By kind
 By date modified
 By size
 Snap to grid
 Auto-arrange
EOF
)
  [[ -z "${choice:-}" ]] && exit 0
  # T2 will read this state from ~/.config/nyxus/desktop-icons.json
  local key="name"
  case "$choice" in
    *kind) key="kind" ;;
    *date*) key="mtime" ;;
    *size) key="size" ;;
    *"Snap to grid") key="grid" ;;
    *"Auto-arrange") key="auto" ;;
  esac
  _act_sort "$key"
}

# GAP-915 — restore a file from a snapper snapshot. Lists versions in pick
# mode (no search entry — that is the "bigger tab" ice already hid). Restores
# beside the live file as `<name>.restored-<num>` so the current copy is never
# overwritten by a silent click.
_prev_versions() {
  local target="$1"
  local real cfg sub rel snapdir num date snap rows n choice dest
  if ! _have snapper; then
    notify-send "NYXUS" "Previous versions need Snapper, which is not on this machine."
    return 0
  fi
  real=$(realpath -- "$target" 2>/dev/null) || real="$target"
  cfg=""; sub=""; local best=0 f s
  for f in /etc/snapper/configs/*; do
    [[ -f "$f" ]] || continue
    s=$(awk -F= '/^SUBVOLUME=/{gsub(/["'\'']/, "", $2); print $2; exit}' "$f")
    [[ -n "$s" ]] || continue
    case "$real" in
      "$s"|"$s"/*)
        if (( ${#s} >= best )); then
          best=${#s}; cfg=$(basename "$f"); sub="$s"
        fi
        ;;
    esac
  done
  if [[ -z "$cfg" || -z "$sub" ]]; then
    notify-send "NYXUS" "No snapshot covers this file."
    return 0
  fi
  rel="${real#"$sub"}"
  [[ "$rel" == /* ]] || rel="/$rel"
  snapdir="$sub/.snapshots"
  [[ -d "$snapdir" ]] || snapdir="/.snapshots"
  rows=""; n=0
  while IFS= read -r line; do
    num=$(awk '{print $1}' <<<"$line")
    [[ "$num" =~ ^[0-9]+$ ]] || continue
    [[ "$num" == "0" ]] && continue
    snap="$snapdir/$num/snapshot$rel"
    [[ -e "$snap" ]] || continue
    date=$(awk '{for(i=2;i<=NF;i++) printf (i>2?" ":"") $i}' <<<"$line")
    rows+=" ${num}  ${date}"$'\n'
    n=$((n+1))
  done < <(snapper --no-headers -c "$cfg" list 2>/dev/null || true)
  if (( n == 0 )); then
    notify-send "NYXUS" "No previous versions of $(basename "$target")."
    return 0
  fi
  choice=$(printf '%s' "$rows" | _menu "Previous versions")
  [[ -z "${choice:-}" ]] && return 0
  num=$(awk '{print $1}' <<<"$choice")
  [[ "$num" =~ ^[0-9]+$ ]] || return 0
  snap="$snapdir/$num/snapshot$rel"
  dest="${real}.restored-${num}"
  [[ -e "$dest" ]] && dest="${real}.restored-${num}-$$"
  cp -a -- "$snap" "$dest" \
    && notify-send "NYXUS" "Restored to $(basename "$dest")" \
    || notify-send "NYXUS" "Restore failed"
}

_icon_menu() {
  # $1 = path of the icon that was right-clicked
  local target="${1:-}"
  if [[ -z "$target" || ! -e "$target" ]]; then
    notify-send "NYXUS" "Icon path missing: ${target:-<empty>}"
    exit 1
  fi
  # GAP-937: "Set as wallpaper" appears only for an image, and it is built
  # here rather than shown-and-refused because an entry that is always
  # visible and works on one file in ten teaches people it is broken.
  # GAP-910 adds three rows (Open in terminal / Open as root / Copy file).
  # `_menu` default is 12 lines; this surface raises MENU_LINES so the extra
  # rows are not clipped (scrollbar is off).
  local rows extra=""
  if [[ "$(file -b --mime-type -- "$target" 2>/dev/null || echo "")" == image/* ]]; then
    extra=$' Set as wallpaper\n'
  fi
  rows=$' Open\n Open with…\n Open containing folder\n Open in terminal\n Open as root\n Copy path\n Copy file\n Previous versions\n'
  rows+="$extra"
  rows+=$' Rename…\n Scan with Hemera\n Move to Trash\n Delete permanently\n Properties'

  local choice
  MENU_H=560
  MENU_LINES=16
  choice=$(printf '%s\n' "$rows" | _menu "$(basename "$target")")
  [[ -z "${choice:-}" ]] && exit 0
  case "$choice" in
    *"Open with"*)
      _act open-with "$target"
      ;;
    *"Open containing folder")
      _act open-folder "$target"
      ;;
    *"Open in terminal")
      _act open-terminal "$target"
      ;;
    *"Open as root")
      _act open-root "$target"
      ;;
    *"Open"$'\n'*|*"Open")
      _act open "$target"
      ;;
    *"Copy path")
      _act copy-path "$target"
      ;;
    *"Copy file")
      _act copy-file "$target"
      ;;
    *"Previous versions"*)
      _act prev-versions "$target"
      ;;
    *"Rename"*)
      _act rename "$target"
      ;;
    *"Set as wallpaper")
      _act wallpaper "$target"
      ;;
    *"Scan with Hemera")
      _act scan "$target"
      ;;
    *"Move to Trash")
      _act trash "$target"
      ;;
    *"Delete permanently")
      _act delete "$target"
      ;;
    *"Properties")
      _act properties "$target"
      ;;
  esac
}

case "$MODE" in
  act)       _act "${2:-}" "${3:-}" ;;
  main)      _main_menu ;;
  wallpaper) _wallpaper_menu ;;
  sort)      _sort_menu ;;
  display)   _settings Display ;;
  icon)      _icon_menu "${2:-}" ;;
  dismiss)   _dismiss ;;
  *)         echo "unknown mode: $MODE" >&2; exit 2 ;;
esac
