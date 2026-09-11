pragma Singleton
// Nyxus Suxyn — the shell's view of the user's settings.
//
// NYXUS Settings (the GTK control center) owns ~/.config/nyxus/settings.json
// and every setting there has real UI — nothing in this build is configured
// from a terminal. This singleton is the SHELL side of that contract: it
// watches the same file and re-reads it the moment Settings saves, so a
// toggle in the control center applies to the running shell instantly, no
// restart, no IPC.
//
// READ-ONLY by design: the settings app is the single writer. Never call
// writeAdapter() here — the adapter only declares the keys the shell cares
// about, and writing back would strip every other section's settings.
//
// Defaults below are the shipped experience for a fresh HOME where the file
// (or a key) does not exist yet.
import Quickshell
import Quickshell.Io
import "SettingsSchema.js" as Schema
import QtQuick

Singleton {
    id: prefs

    // ── living paint (Swirl.qml; Settings → Appearance → Living paint) ──
    readonly property bool swirlEnabled: adapter.swirl_enabled
    readonly property real swirlIntensity: adapter.swirl_intensity
    readonly property bool swirlMusic: adapter.swirl_music
    // TRK-3711 · the bar's music visualiser. Its OWN key, on the owner's
    // ruling of 2026-09-01 ("yes it will need its own setting") after he saw
    // it riding `swirl_music`.
    //
    // ⚠ IT IS NOT INDEPENDENT OF `swirlMusic`, AND THE PAGE SAYS SO. The
    // spectrum arrives on `nyxus-beat-engine`'s frames, and `Beat.enabled`
    // — which starts that engine at all — is `swirlMusic`. So FOLLOW MUSIC
    // off means no engine, no frames, no spectrum, whatever this key says.
    // This key decides whether the BAR TURNS OVER; that one decides whether
    // the machine is listening. Two questions, two keys, one of them a
    // parent — which is why the control is drawn under FOLLOW MUSIC and
    // reads as unavailable when it is off, rather than lying about what it
    // controls.
    readonly property bool barSpectrum: adapter.bar_spectrum
    // TRK-3812 · SYNCED LYRICS, and the ONLY thing in this shell that can put
    // a request on the wire on its own. The name says NETWORK on purpose:
    // what the owner consents to when he flips it is that the artist, the
    // title and the length of whatever is playing are sent to lrclib.net.
    // Nothing else — no album, no identity, no history.
    //
    // ⛔ SHIPS FALSE, and the default is the consent. `nyxus-lyrics` reads
    // this same key for itself before it opens a socket, so a shell bug
    // cannot make a request the owner did not ask for.
    readonly property bool lyricsOnline: adapter.lyrics_online === true

    // TRK-3817 · the tape. See the adapter block below for why armed-ness is
    // deliberately NOT one of these.
    readonly property string tapeFormat:
        adapter.tape_format === "mp3" ? "mp3" : "flac"
    readonly property string tapeSource:
        adapter.tape_source === "output" ? "output" : "player"
    readonly property int tapeMinSeconds:
        Math.max(5, Math.min(600, adapter.tape_min_seconds))
    // Owner 2026-08-20: one dye (ice + wallpaper purple). Leftover
    // rose|magma|violet in settings.json must not keep a retired ramp on
    // screen. The JSON key still exists so old files parse; the shell
    // always wears glacier. Motion: "ambient" or "interactive". Off is
    // swirl_enabled, the master switch.
    readonly property string swirlLayer: "glacier"
    readonly property string swirlMotion: adapter.swirl_motion

    // ── THE FROST (Frost.qml; Settings ▸ Windowing ▸ Unfocused windows) ──
    // Every window you are not looking at, blurred so its text cannot be read
    // while its shape stays legible — the owner's original ask, which
    // `nyxus-idle-glass.sh` answered with transparency instead. See
    // Frost.qml's header for why this cannot be a compositor setting and what
    // it costs.
    readonly property bool frostEnabled: adapter.frost_enabled
    // The pane's own tint over the blur, 0..1. Clamped rather than coerced
    // through the schema for the reason `lockEarthSize` gives: a schema rule
    // means bumping TABLE.current, and a hand-edited settings.json must not be
    // able to put a black sheet over every unfocused window.
    readonly property real frostStrength:
        Math.max(0, Math.min(1, adapter.frost_strength))

    // ── the control paint (SwirlChip.qml; Settings → Appearance) ────────
    // `swirlControls` scopes the paint inside toggles, switches and buttons
    // ONLY. The bar, the seam and the power menu never read it — turning it
    // off must not take the horizon with it, which is the whole point of
    // having a second switch rather than making people choose.
    readonly property bool swirlControls: adapter.swirl_controls
    // Motion scale for that paint, coerced because a hand-edited settings.json
    // must not be able to stop the field dead or launch it. 0 would freeze a
    // control mid-fold and read as the frozen-frame defect TRK-2989 was; the
    // ceiling is the bar's own rate, above which a chip is faster than the
    // surface it is quoting.
    readonly property real swirlControlSpeed:
        Schema.coerce("swirl_control_speed", adapter.swirl_control_speed)

    // Pointer trail (Overlay dots, not a veil). Retired for users
    // (TRK-3070): Settings and the wizard no longer offer it; default
    // stays false so shell.qml's Variants model stays empty. Do not
    // rename this key — PointerTrail.qml still reads it.
    // "match" follows the one dye. Retired layer names coerce to match.
    readonly property bool pointerTrailEnabled: adapter.pointer_trail_enabled
    readonly property string pointerTrailLayer: Schema.coerce("pointer_trail_layer", adapter.pointer_trail_layer)

    // Now-playing card that sits on the bar (MediaCrest.qml). Not Bar.qml.
    readonly property bool mediaBarPop: adapter.media_bar_pop

    // ── interface sounds (TRK-3005 / TRK-1087) ──────────────────────────
    // Sys.playSound only. Hyprland `nyxus-sound login` does not read these.
    // UI fader is a second multiplier on the helper (--ui-gain), never the
    // PipeWire sink, so a YouTube tab stays loud when clicks sit at 40%.
    readonly property bool uiSounds: adapter.ui_sounds !== false
    readonly property real uiSoundVolume: {
        var v = adapter.ui_sound_volume;
        if (typeof v !== "number" || v !== v)
            return 0.40;
        return Math.max(0, Math.min(1, v));
    }
    // TRK-1087 — per-event mute. Off means Sys.playSound returns.
    // Unlock shares lock. Hyprland `nyxus-sound lock|unlock` is unchanged.
    readonly property bool uiSoundPress: adapter.ui_sound_press !== false
    readonly property bool uiSoundNotify: adapter.ui_sound_notify !== false
    readonly property bool uiSoundKnock: adapter.ui_sound_knock !== false
    readonly property bool uiSoundLock: adapter.ui_sound_lock !== false

    // ── THE ROOMS (TRK-1700..1703; Settings ▸ System ▸ Rooms) ──
    // Off = Rooms.qml answers the binds with "off" and nyxus-house reads the
    // same key, so the keys do nothing and no surface is built at all.
    readonly property bool stationEnabled: adapter.station_enabled
    readonly property bool stationPlate: adapter.station_plate
    // the little map: "off" never shows it, "auto" shows it as you move and
    // fades it, "pinned" leaves it up. Anything else reads as "auto".
    readonly property string stationMap: (["off", "auto", "pinned"].indexOf(adapter.station_map) >= 0)
                                         ? adapter.station_map : "auto"
    readonly property string stationMapCorner: (["bottom-right", "bottom-left", "top-right", "top-left"]
                                                .indexOf(adapter.station_map_corner) >= 0)
                                               ? adapter.station_map_corner : "bottom-right"
    // how long the map stays up after you stop moving, in ms (600..8000)
    readonly property int stationMapFade: Math.max(600, Math.min(8000, adapter.station_map_fade))

    // ── THE EARTH ON THE LOCK (owner ask, 2026-08-23) ────────────────────
    // Coerced HERE rather than in SettingsSchema.js on purpose: a schema
    // migration means bumping `TABLE.current`, and several lanes are in this
    // tree at once — two of them bumping the same integer is a merge conflict
    // in the one file that decides how everybody's settings are read. Inline
    // coercion is still an accepted pattern (see stationMap above) and it
    // needs no version at all.
    //
    // Every one of these is defensive because settings.json is a plain text
    // file a person can hand-edit: a bad `side` must not blank the lock, and a
    // hand-typed size must not put the planet through the password field.
    readonly property bool lockEarthOn: adapter.lock_earth_on
    // The ceiling is 0.95, down from 1.60. At 1.30 the globe is 1404 px across
    // on a 1080 px panel and gets cut off top and bottom — the owner:
    // "it gets cut out of the background its so big". Clamping rather than
    // migrating means a settings.json still holding 1.30 is simply pulled back
    // into range on read, with no schema version to bump.
    // ⚠ SNAPPED, not merely clamped, and the two are not the same thing.
    // Clamping alone pulled a stale 1.30 to 0.95 here while the settings page
    // snapped the same value to its nearest OFFERED size, 0.90 — so the page
    // would show one size selected and the lock would quietly draw another.
    // That is the same defect as the on/off defaults disagreeing, which cost
    // the owner two trips to his lock screen. One rule, in both places: the
    // value in force is always one of the three you can pick.
    readonly property real lockEarthSize: {
        const raw = Math.max(0.30, Math.min(0.95, adapter.lock_earth_size));
        const opts = [0.55, 0.72, 0.90];
        let best = opts[0];
        for (let i = 1; i < opts.length; i++)
            if (Math.abs(opts[i] - raw) < Math.abs(best - raw)) best = opts[i];
        return best;
    }
    readonly property string lockEarthSide: (["left", "centre", "right"]
                                             .indexOf(adapter.lock_earth_side) >= 0)
                                            ? adapter.lock_earth_side : "left"
    // The three sides as a fraction across the screen. `Lock.qml` moves the
    // clock and login to the opposite side from this, so they can never land
    // on top of the planet.
    readonly property real lockEarthCentreX: lockEarthSide === "centre" ? 0.50
                                           : lockEarthSide === "right"  ? 0.70 : 0.30
    readonly property bool lockEarthMarker: adapter.lock_earth_marker
    readonly property bool lockEarthBolts: adapter.lock_earth_bolts

    // Three scenes. "ocular" arrived 2026-09-05 as an ADDITION — the owner's
    // ruling was "get both over to it and make sure the earth is saved as well
    // i diont want it delterd", and a third enum value is how the second half
    // of that is kept structurally rather than by anyone's memory: choosing the
    // constellation does not disable, hide or degrade the Earth, it simply
    // does not draw it, and "earthrise" is still one tap away in Settings.
    // ⚠ Anything added here must also be added to SetPageScreenlock's options,
    // or the setting can hold a value the UI cannot show or undo.
    // ⚠ TRK-3744 — THE UNSET SCENE IS THEME-DEPENDENT, AND IT HAS TO BE
    // COMPUTED HERE, NOT DECLARED ON THE ADAPTER.
    //
    // `lock_scene` is the one key whose "unset" answer is not a constant: on
    // the alien mark the lock opens on the Ocular, on NYXUS it opens on the
    // orbit view the owner kept ("i dont like it like that just put it back to
    // how it was" — earthrise is a pick, never the default). A JsonAdapter
    // property cannot express that, so the adapter's default is `""` — a value
    // deliberately OUTSIDE the accepted set — and the else branch below is what
    // answers for an absent key.
    //
    // Until 2026-09-06 the adapter default was `"sky"`, which IS an accepted
    // value, so this else branch could never run for a fresh install and the
    // theme rule was dead code. `SetPageScreenlock.qml` computed the theme rule
    // anyway, so on the alien mark the page showed "The Ocular" selected while
    // the lock actually drew the orbit view — the page and the shell in two
    // different states, with no error anywhere. `scripts/verify-settings-
    // wiring.py` check 7 now fails on exactly that shape: a computed default on
    // one side and an already-accepted adapter default on the other.
    //
    // Keep this expression and SetPageScreenlock's `sceneFallback` answering
    // the same set. The gate compares them; do not rely on this sentence.
    readonly property string lockScene: (["sky", "earthrise", "ocular"]
                                         .indexOf(adapter.lock_scene) >= 0)
                                        ? adapter.lock_scene
                                        : (markTheme === "alien" ? "ocular"
                                                                 : "sky")

    // ── THE THEME ────────────────────────────────────────────────────────
    // Both themes ship in one build; NYXUS is the default, so an unset key and
    // a settings file written before this existed both land on the neutral
    // build. Validated inline the way lockScene is.
    readonly property string markTheme: (["nyxus", "alien"]
                                         .indexOf(adapter.mark_theme) >= 0)
                                        ? adapter.mark_theme : "nyxus"

    // ── THE CHAMFER ──────────────────────────────────────────────────────
    // Cut corners instead of round, in px along each edge. 0 IS THE SHIPPED
    // LOOK AND THE DEFAULT. Panels are cut, controls stay round. Clamped
    // rather than trusted; the shaders clamp to the half-extent as well.
    readonly property int panelChamfer:
        Math.max(0, Math.min(32, adapter.panel_chamfer))
    readonly property bool lockMoonOn: adapter.lock_moon_on
    readonly property real lockMoonScale: Math.max(0.5, Math.min(2.0, adapter.lock_moon_scale))

    // WIP-700 — does the paint say anything about the MACHINE? Warmer as the
    // load average climbs, back to the layer's own colour at rest, and one
    // slow swell when a Hemera scan finishes. `PaintMood.qml` owns the
    // behaviour and its header owns the reasoning.
    //
    // Default TRUE, against this repo's usual "a feature that costs cycles
    // forever ships switched off" instinct (WIP-132), and the exception is
    // argued rather than assumed: WIP-132's rule is about COST, and the cost
    // here is one 30-second read of `/proc/loadavg` — no subprocess, no
    // wake-up of its own, and only while a paint surface is already mapped
    // and stepping its solver. It is also the owner's own headline ask, and
    // a headline feature that ships off is a feature nobody sees.
    //
    // OFF MEANS OFF: with this false, `PaintMood` runs no timer, holds no
    // file watch, and hands back `Theme.paintRamp` unchanged — the paint is
    // exactly what it was before the behaviour existed. Gate 13q37 proves
    // that by running the real singleton with the key false.
    readonly property bool swirlReactive: adapter.swirl_reactive

    // ── WIP-880 · which MATERIAL the paint is made of ────────────────────
    // Owner pick, 2026-08-18, off the thirteen-treatment variety pass
    // (docs/BRIEF_AGENT_PB_2026-08-17.md): *"black shadow to me is the
    // closest to what i already have in the look but with it being black …
    // if it were dark a little better … plus i have to see it live on my bar
    // to really see what it looks like, it may be different."*
    //
    // That last clause is why this is a KEY and not a repaint. He has picked
    // a treatment; he has NOT retired the one he has, and the standing veto
    // is *"SWIRLS DONT GET TOUCHED THEY ALWAYS STAY."* So the default below
    // is the paint that shipped yesterday, unchanged for every account, and
    // the black is one string away in either direction.
    //
    //   "paint"            the living paint, today's shipped material  ← default
    //   "shadow"           black shadow, glow 12 — a step darker than rendered
    //   "shadow-dim"       glow  9 — ≈ the study's "dim glow", verdict BLACK
    //   "shadow-darkest"   glow  6
    //   "shadow-rendered"  glow 15 — ≈ the artifact specimen he chose, kept
    //                      reachable so the darker steps have an anchor
    //
    // The glow numbers are BELOW the study's by design, not by transcription
    // error: the shader reads the dye field's mean where the study used its
    // median, which under-occludes by a measured 1.17×. `Swirl.qml` carries
    // the whole derivation and the predicted level for every rung.
    //
    // `Swirl.qml` is the authority on what each string means and falls back
    // to the shipped paint on anything it does not recognise — a typo dims
    // nothing and breaks nothing, it just leaves the bar as it was.
    //
    // Settings ▸ Appearance ▸ Living paint writes this (WIP-881).
    // paint | shadow | shadow-dim | shadow-darkest. Default paint.
    readonly property string swirlMode: adapter.swirl_mode

    // ── starlight (Starlight.qml; the RR headliner — WIP-204) ──────────
    readonly property bool starlightEnabled: adapter.starlight_enabled
    readonly property real starlightDensity: adapter.starlight_density
    readonly property bool starlightShooting: adapter.starlight_shooting
    readonly property bool starlightNebula: adapter.starlight_nebula

    // ── companion (Companion.qml; the streetwear alien on the desktop) ──
    // OFF by default: a desktop pet is a taste, not a default, and the owner
    // turns it on from Settings. The 3D Godot build it replaces is in
    // companion-3d/ and is not wired to anything (see Companion.qml's header).
    readonly property bool companionEnabled: adapter.companion_enabled

    // ── clock (WIP-103; Settings → Time & Language) ────────────────────
    // The shell READS these. Settings writes them, per the single-writer rule
    // above — which is also why the clock surface offers "Time settings ›"
    // rather than a format switch of its own: two writers to one fact is the
    // drift WIP-108 exists to prevent, and it would cost the other sections
    // of settings.json on every save.
    readonly property bool clock24h: adapter.clock_24h
    readonly property bool clockShowSeconds: adapter.clock_seconds
    readonly property string clockTimeZone: adapter.clock_timezone

    // ── TRK-3728 · THE ONE TIME FORMAT, BECAUSE "h:mm" IS NOT 12-HOUR ──────
    //
    // Owner, after toggling it and watching nothing happen: "i cant even chage
    // the 24hr to 12hr format ... i dont see the time change to 12hr format or
    // seconds i did both and still nothing".
    //
    // The setting wrote correctly, Prefs read it correctly, and every clock
    // branched on it correctly. The BRANCH ITSELF was wrong. Nine sites wrote
    //
    //     Prefs.clock24h ? "HH:mm" : "h:mm"
    //
    // and Qt's `h` means 0-23 UNLESS an AM/PM marker appears in the same format
    // string. There is none, so both arms render a 24-hour clock and the only
    // thing the toggle ever changed was a leading zero. Measured with the same
    // Qt that draws these clocks (docs/proof/audit-0901/fmt-check.py):
    //
    //     23:28   HH:mm    -> 23:28
    //     23:28   h:mm     -> 23:28      <- the "12-hour" arm
    //     23:28   h:mm AP  -> 11:28 PM
    //     09:05   h:mm     -> 9:05       <- the entire observable difference
    //
    // It lives HERE and not in nine files for the reason CLAUDE.md gives: a
    // second copy of a rule is how the rules drift. This one had nine, and all
    // nine were wrong in the same way, which is what a copied rule buys you.
    // Anything that draws a wall-clock time reads `Prefs.timeFmt`.
    //
    // Not for durations or timestamps-in-logs: those want a fixed 24-hour
    // shape and must keep their own literal.
    readonly property string timeFmt: clock24h ? "HH:mm" : "h:mm AP"

    // The seconds form is spelled out rather than composed. Callers used to
    // build it as `timeFmt + ":ss"`, which was harmless while the 12-hour arm
    // was "h:mm" and becomes "h:mm AP:ss" the moment the arm is correct —
    // seconds stranded on the far side of the meridiem. The marker has to stay
    // last, so the two shapes are written out and neither is derived.
    readonly property string timeFmtSeconds: clock24h ? "HH:mm:ss" : "h:mm:ss AP"

    // The NUMERALS ONLY — no meridiem marker, ever. For the one kind of
    // surface that draws "PM" itself, as its own separate, smaller piece of
    // type: the desk clock chip (Widgets.qml `wClock`) sets the hour at
    // `tJumbo` 64 px and stacks the marker beside it at `tMicro` 9.
    //
    // ⚠ TRK-3907. That chip used to draw `timeFmt` at 64 px, which in the
    // 12-hour arm is "h:mm AP" — so it painted the marker twice, once three
    // rungs too large, and "11:28 PM" in 64 px Orbitron is ~360 px inside a
    // 276 px content box. The overrun is what put the stray "PM" and the
    // seconds on the wallpaper. A caller that wants the marker in the string
    // wants `timeFmt`; this exists so the other kind never has to strip it
    // with a local branch, which is the nine-copies defect one line up.
    //
    // WARNING: A FUNCTION, AND IT CANNOT BE A FORMAT STRING. The obvious
    // spelling is `clock24h ? "HH:mm" : "h:mm"` and it is WRONG -- measured
    // on the owner's desktop at 21:44, where it printed "21:44" beside a
    // small "PM". In Qt's date format, `h` means hour 0..23 UNLESS an AP/ap
    // marker also appears in the same string, in which case it means 1..12.
    // So deleting the marker silently re-points the hour token at the
    // 24-hour clock -- the one edit that looks like it only removes text.
    // Qt has no token for "12-hour hour, no marker", so the 12-hour arm is
    // arithmetic and the 24-hour arm stays a format string.
    function timeBare(d) {
        if (clock24h)
            return Qt.formatTime(d, "HH:mm");
        var h = d.getHours() % 12;
        if (h === 0)
            h = 12;
        var m = d.getMinutes();
        return h + ":" + (m < 10 ? "0" + m : m);
    }

    // ── desktop widgets (WIP-140 §4; Settings → Personalization
    // → Desktop widgets) ────────────────────────────────────────────────
    // Ease of Access (TRK-1220/1221; Settings > Ease of Access > Accessibility).
    // reduced_motion: every animated host reads it (13r40). font_scale is the
    // GTK Settings > Accessibility key (0.85-1.40, one fact one spelling, WIP-108),
    // held to that range by the schema table. high_contrast is forwarded to
    // libadwaita apps through gsettings by SetPageAccess.
    readonly property bool reducedMotion: adapter.reduced_motion
    readonly property real textScale: Schema.coerce("font_scale", adapter.font_scale)
    readonly property bool highContrast: adapter.high_contrast

    // Master on. TRK-2994: Clock / Vitals / Sticky / Calendar / Weather
    // ship ON so a fresh boot shows the WIP-140 five. Now Playing is the
    // optional sixth and ships OFF — Widgets.qml also hides it with no
    // MPRIS, but an OFF default keeps the count at five, not six empty.
    // Settings owns the writes; the shell reads.
    readonly property bool widgetsEnabled: adapter.widgets_enabled
    function widgetOn(slug)  { return adapter["widget_" + slug] === true; }
    // Named adapter reads (not `adapter["widget_"+slug+"_x"]`) so a QML
    // binding that calls widgetX() actually tracks the JsonAdapter. Bracket
    // lookup does not subscribe, which is why FileView could load new x
    // values and the reused PanelWindows (reload(false)) stayed put.
    function widgetX(slug) {
        if (slug === "clock")      return adapter.widget_clock_x;
        if (slug === "vitals")     return adapter.widget_vitals_x;
        if (slug === "sticky")     return adapter.widget_sticky_x;
        if (slug === "calendar")   return adapter.widget_calendar_x;
        if (slug === "weather")    return adapter.widget_weather_x;
        if (slug === "nowplaying") return adapter.widget_nowplaying_x;
        var v = adapter["widget_" + slug + "_x"];
        return v === undefined ? 64 : v;
    }
    function widgetY(slug) {
        if (slug === "clock")      return adapter.widget_clock_y;
        if (slug === "vitals")     return adapter.widget_vitals_y;
        if (slug === "sticky")     return adapter.widget_sticky_y;
        if (slug === "calendar")   return adapter.widget_calendar_y;
        if (slug === "weather")    return adapter.widget_weather_y;
        if (slug === "nowplaying") return adapter.widget_nowplaying_y;
        var v = adapter["widget_" + slug + "_y"];
        return v === undefined ? 120 : v;
    }
    function widgetPlaced(slug) {
        if (slug === "clock")      return adapter.widget_clock_placed === true;
        if (slug === "vitals")     return adapter.widget_vitals_placed === true;
        if (slug === "sticky")     return adapter.widget_sticky_placed === true;
        if (slug === "calendar")   return adapter.widget_calendar_placed === true;
        if (slug === "weather")    return adapter.widget_weather_placed === true;
        if (slug === "nowplaying") return adapter.widget_nowplaying_placed === true;
        return adapter["widget_" + slug + "_placed"] === true;
    }

    // ── WHERE THE WIDGET BOARD STARTS · one copy of the arithmetic ──────
    // TRK-3646. `Widgets.qml` has always derived the board's left edge from
    // these keys: the smallest configured X, less the group `boardShift` that
    // slides the whole two-column board back onto a narrow screen (an
    // independent per-chip clamp is forbidden there — it stacks clock and
    // calendar on the same x). `SkyForeground.qml` needs the SAME number, to
    // cap its wl_surface so it cannot reach a chip.
    //
    // So the arithmetic moved HERE and `Widgets.qml` reads it back, rather
    // than a second copy living in the new file. A second copy of a ceiling is
    // how audit item 24's seam rule nearly lost its runner: two declarations,
    // one runner, and the shipped picture failed a rule the repository already
    // knew.
    //
    // `widgetIconReserved` is Widgets.qml's ICON_RESERVED (grid_x 16 + ICON_W
    // 96 + pad 24) — the first desktop-icon column the board may not slide
    // over. The +300+48 in `widgetBoardRight` is the widest chip plus the
    // right margin, and both stay exactly the numbers Widgets.qml shipped:
    // this is a MOVE, not a retune.
    readonly property int widgetIconReserved: 136
    function widgetLeftMin() {
        return Math.min(widgetX("clock"), widgetX("vitals"),
                        widgetX("sticky"), widgetX("calendar"),
                        widgetX("weather"), widgetX("nowplaying"));
    }
    function widgetBoardRight() {
        return Math.max(widgetX("clock"), widgetX("vitals"),
                        widgetX("sticky"), widgetX("calendar"),
                        widgetX("weather"), widgetX("nowplaying")) + 300 + 48;
    }
    function widgetBoardShift(screenW) {
        var right = widgetBoardRight();
        var raw = Math.max(0, right - (screenW > 0 ? screenW : right));
        return Math.min(raw, Math.max(0, widgetLeftMin() - widgetIconReserved));
    }
    // The x of the leftmost chip CARD, after the group shift. A NEGATIVE
    // answer means "there is no widget board on this screen" — the caller must
    // read that as no keep-out at all, and `widgetsEnabled` is the only thing
    // that can say so.
    function widgetBoardLeft(screenW) {
        if (!widgetsEnabled)
            return -1;
        return widgetLeftMin() - widgetBoardShift(screenW);
    }
    // Card Y of the highest chip, then the bloom pad above it — that is
    // the top of the chip's wl_surface, which is the keep-out SkyForeground
    // has to clear. Heights are the painted card, not the window.
    function widgetBoardTop() {
        if (!widgetsEnabled)
            return -1;
        return Math.max(0, Math.min(
            widgetY("clock"), widgetY("vitals"), widgetY("sticky"),
            widgetY("calendar"), widgetY("weather"), widgetY("nowplaying")
        ) - Theme.bloomPad);
    }
    function widgetCardH(slug) {
        if (slug === "vitals")     return 560;
        if (slug === "clock")      return 220;
        if (slug === "calendar")   return 280;
        if (slug === "weather")    return 160;
        if (slug === "sticky")     return 300;
        if (slug === "nowplaying") return 220;
        return 280;
    }
    function widgetBoardBottom() {
        if (!widgetsEnabled)
            return -1;
        return Math.max(
            widgetY("clock")      + widgetCardH("clock"),
            widgetY("vitals")     + widgetCardH("vitals"),
            widgetY("sticky")     + widgetCardH("sticky"),
            widgetY("calendar")   + widgetCardH("calendar"),
            widgetY("weather")    + widgetCardH("weather"),
            widgetY("nowplaying") + widgetCardH("nowplaying")
        ) + Theme.bloomPad;
    }

    // ── Start Menu style (WIP-187/WIP-199; Settings → Appearance) ───────
    // LIVE since WIP-199: Launcher.qml branches on this. "daily" is the
    // shipped default (the command deck), "classic" is the Atrium fallback.
    // "orbit" still has no QML port and renders as Daily — the nearest
    // implemented style; Launcher.qml states this where it decides it.
    readonly property string launcherStyle: adapter.launcher_style

    // ── desktop ground source (WIP-555) ─────────────────────────────────
    // shell.qml's `voyageSky` picks Starlight vs Starlight Voyage and stays
    // the owner's call, default unchanged by this. This is the escape
    // hatch on TOP of that: 19 wallpapers ship and Wallpaper Studio exists
    // to browse them, but with a sky selected they were never reachable —
    // applying one wrote wallpaper.conf and nothing on screen changed. Any
    // sky is a Bottom-layer surface; the wallpaper is Background, one layer
    // further down, so a live sky always wins the pixel regardless of what
    // wallpaper.conf names. Owner 08-20: keep Starlight. Fresh accounts
    // default to "headliner". Voyage stays a pick. Settings → Background
    // and Appearance write the key.
    readonly property bool skyWantsWallpaper: adapter.sky_mode === "wallpaper"

    // ── the Starlight Headliner (owner commission, 2026-08-17) ───────────
    // A THIRD value on the SAME key rather than a new one, and that is the
    // whole persistence story: `sky_mode` already means "which thing owns the
    // ground", the file below is already watched live, and Settings is
    // already its single writer. So the owner's "set that as my background
    // and have it live after reboots" needs no exec-once, no systemd unit and
    // no wallpaper daemon — the choice is one string in
    // ~/.config/nyxus/settings.json and the shell that reads it is already
    // autostarted (hyprland.conf: `exec-once = ... nyxus-shell-supervisor qs`).
    //
    // Mutually exclusive with both skies by construction, because shell.qml's
    // three Variants take their models from the same expression: an empty
    // model instantiates nothing, so there is never a second full-screen
    // shader alive to be composited under the first.
    //
    // Reversible in one word, live, with no restart: set it back to "voyage"
    // and the 3D sky returns; set it to "wallpaper" and the rotation's still
    // is on screen in the same frame, because nothing was ever stopped.
    readonly property bool skyWantsHeadliner: adapter.sky_mode === "headliner"

    // ── THE LAYERED WALL (owner commission, 2026-09-01) ──────────────────
    // TRK-3646. "i was hoping to do say the planet moon or astrouid in layers
    // to match the build so like there was a piece of the exact layer in the
    // background image if makes sense" — the literal reading, which is the one
    // he picked: ONE picture cut in two, the far half on `WlrLayer.Background`
    // and the near half on `WlrLayer.Bottom`, with his widget chips threaded
    // between them. `SkyForeground.qml` is the near half.
    //
    // A FOURTH value on the SAME one-of-N key, for the reason the third one
    // was: `sky_mode` already means "which thing owns the ground", the file is
    // already watched live, Settings is already its single writer, and mutual
    // exclusion is then a fact of one expression rather than four booleans
    // that can all be true at once. A layered wall and an opaque Headliner sky
    // are alternatives, not an addition — the Headliner IS the picture (its
    // own header says so) and would simply hide the far half.
    //
    // Ships OFF: the shipped default is still "headliner", so nothing changes
    // for anybody until the owner picks this by name.
    readonly property bool skyWantsLayered: adapter.sky_mode === "layered"

    // Which layered wall. A PATH PREFIX, not a filename, because the mode is
    // defined by a PAIR: `<base>-bg.png` (opaque far half) and `<base>-fg.png`
    // (alpha near half). Naming the prefix once is what stops the two halves
    // being configured out of register with each other.
    //
    // Any keep-set still can be layered. Pair files live at
    // ~/.local/share/nyxus/walls/<slug>-bg.png and -fg.png; picking that
    // picture writes this prefix (the directory plus slug) and sky_mode=layered.
    // Without both files it is sky_mode=wallpaper and the still.
    //
    // Default "" — configured-by-nobody paints nothing, so turning the mode on
    // with no art selected is an empty ground and never a black screen with a
    // mystery in it. Plain `string` throughout: see SkyForeground.qml's note on
    // why a `url` here would make the empty branch unreachable (TRK-3607).
    // A relative or non-file base returns "" rather than a half-resolved URL —
    // an unresolvable path must read as "nothing configured", not as an Image
    // error the user has to interpret.
    readonly property string layeredWallBase: adapter.layered_wall_base
    function layeredWallHalf(suffix) {
        var b = layeredWallBase;
        if (!b || b.length < 2)
            return "";
        if (b.indexOf("file://") === 0)
            return b + suffix;
        if (b.charAt(0) !== "/")
            return "";
        return "file://" + b + suffix;
    }
    readonly property string layeredWallBg: layeredWallHalf("-bg.png")
    readonly property string layeredWallFg: layeredWallHalf("-fg.png")

    // ── the idle chain (owner commission, 2026-08-17) ────────────────────
    // "set a screensaver as well that really works and then goes to login
    // after so long after that as well."
    //
    // These are NOT new keys. `nyxus_settings.py` has owned
    // `power.saver_on` / `power.saver_secs` / `power.lock_secs` since the
    // hypridle generator was written, Settings ▸ Power and Settings ▸
    // Screensaver both already write them, and the file below is already
    // watched live. So the shell's screensaver is configured by the sliders
    // that exist, in the file that already survives reboots, and the single-
    // writer rule is not bent — this side still only reads.
    //
    // ⚠ A NESTED JsonObject, because the file is nested. The python side
    // writes `{"power": {...}}` and has since long before this; a flat
    // `power_saver_secs` here would have been a SECOND spelling of a fact
    // that already has one, which is the drift WIP-108 exists to prevent.
    //
    // The defaults are `HYPRIDLE_DEFAULTS`', value for value, and that
    // agreement is not decorative: with no settings.json at all, the shell
    // must reach the screensaver at the same moment hypridle would have.
    readonly property bool  saverEnabled: adapter.power.saver_on !== 0
    readonly property int   saverSecs:    Math.max(15, adapter.power.saver_secs)
    readonly property int   lockSecs:     adapter.power.lock_secs

    // Is the chain coherent? A lock timer at or below the saver timer means
    // the screensaver would be replaced by the lock in the same breath, or
    // never appear at all. The shell does not silently repair that (the
    // sliders belong to Settings and repairing it here would fight the
    // writer) — it reports it, and `Screensaver.qml` shows the sky anyway,
    // because a screensaver that refuses to appear is the bug we are fixing.
    readonly property bool idleChainOrdered: lockSecs <= 0 || lockSecs > saverSecs

    FileView {
        path: Quickshell.env("HOME") + "/.config/nyxus/settings.json"
        watchChanges: true
        onFileChanged: reload()
        // A fresh install has no settings.json until the first save; that is
        // not an error, the defaults above are the design.
        printErrors: false

        JsonAdapter {
            id: adapter
            property bool swirl_enabled: true
            property real swirl_intensity: 1.0
            property bool swirl_music: true
            property bool bar_spectrum: true
            // TRK-3812 — synced lyrics. FALSE is the shipped consent; see
            // `lyricsOnline` above and Settings ▸ Appearance ▸ SYNCED LYRICS.
            property bool lyrics_online: false
            property string swirl_layer: "glacier"
            property string swirl_motion: "ambient"
            // TRK-3361/3362/3398 · the control paint, 2026-08-28.
            //
            // OFF by default, on the owner's ruling after seeing it on his own
            // TTY1: "lets take the swirls out of the buttons and toggles."
            // It matches what the geometry already said — a 21 px switch track
            // cannot hold a filament with dark either side of it, so at that
            // size the paint reads as a smudge rather than as the bar.
            //
            // THE MACHINERY STAYS. SwirlChip, its hosts and both keys are
            // intact, so this is one switch away rather than a rebuild, and a
            // surface with room for it (a Station deck, a lock screen) can
            // still opt in. Deleting it would have thrown away the one thing
            // that makes the decision reversible.
            //
            // `swirl_control_speed` keeps its 0.55 default, so anything that
            // turns the paint back on gets the pace tuned for a control rather
            // than the bar's — see SwirlChip.qml for why those differ.
            property bool swirl_controls: false
            property real swirl_control_speed: 0.55
            // Retired (TRK-3070): always off for users. Key kept so
            // PointerTrail.qml still compiles; shell.qml skips the overlay.
            property bool pointer_trail_enabled: false
            property string pointer_trail_layer: "match"
            property bool media_bar_pop: true
            // ── TRK-3817 · THE TAPE's OPTIONS ────────────────────────────
            // ⚠ ARMED-NESS IS NOT HERE, ON PURPOSE. It lives in
            // ~/.config/nyxus/tape.json (TapeState.qml) whose single writer
            // is `nyxus-tape`, because the arm control is on the BAR and a
            // bar that wrote settings.json would break this file's own rule
            // that Settings is the single writer. Only the tape's OPTIONS —
            // which are ordinary preferences, set in Settings ▸ Sound — are
            // keys here.
            //
            // `tape_format` FLAC by default: the stream is already lossy so
            // FLAC buys no fidelity over it, but the capture happened once in
            // real time and cannot be repeated, and FLAC → MP3 is always
            // available later while MP3 → FLAC undoes nothing.
            //
            // `tape_source` "player" = the monitor of the sink the player is
            // actually feeding (resolved at arm time, not hardcoded), which on
            // a machine running EasyEffects is the clean pre-effects music and
            // nothing else. "output" = the default sink's monitor, literally
            // what left the speakers, effects and other apps included.
            property string tape_format: "flac"
            property string tape_source: "player"
            // The advert floor. Measured adverts on the owner's session were
            // 36.3 s, 42.6 s and 15.0 s; songs were 165-276 s. Nothing
            // Chromium publishes separates a LONG advert from a short song,
            // so this is the honest bound rather than a promise.
            property int tape_min_seconds: 60
            // TRK-3005 — shell UI sounds, not media sink volume.
            property bool ui_sounds: true
            property real ui_sound_volume: 0.40
            property bool ui_sound_press: true
            property bool ui_sound_notify: true
            property bool ui_sound_knock: true
            property bool ui_sound_lock: true
            // TRK-1700 — THE ROOMS ship ON: this is the owner's headline ask
            // and a navigation feature nobody switches on is a navigation
            // feature nobody has. The toggle stays, and OFF still costs
            // nothing: shell.qml's LazyLoader never builds the HUD, the
            // Rooms singleton is never constructed, the shard declares no
            // workspace and no layer rule, and nyxus-house exits 0 with a
            // note on every dispatching verb.
            property bool station_enabled: true
            property bool station_plate: true
            property string station_map: "auto"
            property string station_map_corner: "bottom-right"

            // ── THE EARTH ON THE LOCK (owner ask, 2026-08-23) ────────────
            // ⛔ SHIPS OFF, AND THIS IS NOT TIMIDITY.
            //
            // It shipped ON for about twenty minutes on 2026-08-23. In that
            // window the owner's lock screen threw a Hyprland error and he had
            // to REBOOT to get back into his own machine. That is the exact
            // failure this build has a written rule about, in hyprlock.conf's
            // header and in nyxus-lock-guard's: "A lock screen has one job and
            // it is not decoration: it has to let the owner back in."
            //
            // The cause is not proven. Hyprland and Quickshell both log to
            // tmpfs, the reboot wiped both, and there was no coredump, so the
            // evidence went with it. The strongest suspect is in LockEarth
            // itself and is documented there: two of its four samplers are fed
            // by satellite JPEGs that can be absent, mid-refresh or failed, and
            // LiveWall.qml already records that Qt mishandles a ShaderEffect
            // whose sampler never became valid. That hazard is now fixed. It is
            // still only a suspect.
            //
            // So the default returns to the lock the owner had before, and the
            // Earth stays one switch away in Settings ▸ Lock screen, where its
            // preview is proven and costs nothing. Turn it back ON here only
            // once a lock cycle has been survived deliberately, from a session
            // with a TTY escape ready:
            //     Ctrl+Alt+F2 → log in → nyxus-lock-guard --release
            //
            // OFF costs nothing: LockEarth's `visible` goes false, its timers
            // stop, and the lock is exactly the starfield it always was.
            //
            // `lock_earth_size` is the globe's DIAMETER as a fraction of the
            // screen's short edge. He kept all three of the sizes he was shown
            // and picked the middle one.
            // Owner 08-27: Earth is the lock. 08-24 shipped false after an
            // unexplained lock crash (TRK-2948). Samplers are now always
            // backed by shipped textures. Default ON; lock-guard still
            // falls back to hyprlock if this surface fails to answer.
            property bool   lock_earth_on: true
            property real   lock_earth_size: 0.72

            // ── THE MOON (owner ask, 2026-08-24) ─────────────────────────
            // ⚠ SHIPS OFF. It was built to his ask and he then looked at it on
            // his own lock screen and ruled against it twice: "put it back to
            // how it was", and then plainly — "the moon is still on the locked
            // screen with earth so fix that". The Earth is the picture; a
            // second body beside it is clutter on a surface whose job is to
            // take a password.
            //
            // It is not deleted. Every piece of it is real and proved — the
            // ephemeris hits a known new moon and a known full moon, the phase
            // is a lit sphere rather than a drawn crescent, and it reddens by
            // computed airmass. It is one switch away in Settings for anyone
            // who wants it, and OFF it draws nothing and runs no timer.
            property bool   lock_moon_on: false
            property real   lock_moon_scale: 1.0

            // ── THE SCENE (owner ask, 2026-08-24) ────────────────────────
            // "sky"       — you are in orbit: Earth in the star field, the
            //               Moon where it really is in the sky tonight.
            // "earthrise" — you are standing ON the Moon: lunar ground across
            //               the bottom, Earth hanging above it, still turning.
            //               The owner brought four reference photographs of
            //               exactly this and said it was the one.
            // ⚠ "sky" is the shipped scene. Earthrise was built to the
            // owner's reference photographs and he looked at it on hardware
            // and said no: "i dont like it like that just put it back to how
            // it was". It stays available as a choice because it works and
            // costs nothing switched off, but the default is the orbit view he
            // kept.
            // ⚠ "" ON PURPOSE, and it must stay outside ["sky","earthrise",
            // "ocular"]. See `lockScene` above: the shipped scene depends on
            // the mark theme, so "unset" has to reach the computation there
            // rather than being answered here. An accepted value in this slot
            // makes that computation unreachable and puts the page and the
            // shell in different states (TRK-3744).
            property string lock_scene: ""
            property string mark_theme: "nyxus"
            property int panel_chamfer: 0
            property string lock_earth_side: "left"
            property bool   lock_earth_marker: true
            property bool   lock_earth_bolts: true
            property int station_map_fade: 2200
            property bool swirl_reactive: true
            // WIP-880 — "paint" is the shipped material and the default does
            // not move. See the long note above for the other four values.
            property string swirl_mode: "paint"
            // The RR Starlight headliner over the wallpaper — ON by default:
            // the owner asked for it by name, and the layer costs one 25 fps
            // procedural pass only while enabled.
            // ── THE FROST (Frost.qml; Settings ▸ Windowing) ──────────────
            // OFF by default and that is not timidity. Turning it on turns
            // `decoration:blur:enabled` back on with it, which is a real GPU
            // pass the owner explicitly switched off on 2026-08-12 — so it
            // ships costing nothing until he asks for it. `frost_strength` is
            // the pane's own tint, NOT the blur radius: the radius is a
            // compositor global and cannot be varied per layer surface.
            property bool frost_enabled: false
            property real frost_strength: 0.5
            property bool starlight_enabled: true
            property bool companion_enabled: false
            property real starlight_density: 1.0
            property bool starlight_shooting: true
            property bool starlight_nebula: true
            // Empty timezone means "follow the system", which is what a fresh
            // install should do — not a guess at where the machine is.
            property bool clock_24h: false
            property bool clock_seconds: false
            property string clock_timezone: ""

            // desktop widgets — master switch plus one flag and a position
            // pair per chip. Positions staggered so enabling several does
            // not stack them.
            property bool widgets_enabled: true
            // TRK-1220 Ease of Access (reader above; SetPageAccess writes)
            property bool reduced_motion: false
            property real font_scale: 1.0
            property bool high_contrast: false
            property bool widget_clock: true
            property int  widget_clock_x: 1232
            property int  widget_clock_y: 120
            property bool widget_clock_placed: false
            property bool widget_vitals: true
            property int  widget_vitals_x: 1232
            property int  widget_vitals_y: 312
            property bool widget_vitals_placed: false
            // TRK-3231: the note is the third card of the RIGHT column now
            // (Calendar → Weather → NOTE), not the third of the left one.
            // Under Clock + SYSTEM it was the card that ran into the bar,
            // and the space it moved into was empty. These are floors, not
            // positions — Widgets.qml stacks under the card above and lifts
            // the whole column clear of the chrome zone.
            property bool widget_sticky: true
            property int  widget_sticky_x: 1556
            property int  widget_sticky_y: 604
            property bool widget_sticky_placed: false
            property bool widget_calendar: true
            property int  widget_calendar_x: 1556
            property int  widget_calendar_y: 120
            property bool widget_calendar_placed: false
            property bool widget_weather: true
            property int  widget_weather_x: 1556
            property int  widget_weather_y: 456
            property bool widget_weather_placed: false
            // optional sixth: ships OFF so a no-MPRIS boot is five chips,
            // not an empty transport card (Widgets.qml also requires
            // MediaSource.present before it paints).
            property bool widget_nowplaying: false
            property int  widget_nowplaying_x: 1556
            property int  widget_nowplaying_y: 818
            property bool widget_nowplaying_placed: false

            // "daily" is the shipped default since WIP-199; "classic" keeps
            // the Atrium for anyone who prefers it
            property string launcher_style: "daily"

            // Owner 08-20: keep Starlight. "headliner" is the shipped
            // ground (WIP-874). "voyage" is the 3D sky pick. "wallpaper"
            // hands the Bottom layer back to wallpaper.conf.
            property string sky_mode: "headliner"

            // TRK-3646 — the layered wall's PAIR, named by its shared prefix:
            // `<base>-bg.png` on Background, `<base>-fg.png` on Bottom. Empty
            // is what a fresh install has, and `sky_mode: "layered"` with this
            // empty paints nothing rather than guessing at somebody's art.
            property string layered_wall_base: ""

            // The idle chain, mirroring `nyxus_settings.py`'s
            // HYPRIDLE_DEFAULTS exactly — 5 minutes to the screensaver,
            // 10 to the lock. `saver_on` is an INT and not a bool because
            // that is what the python writes (`int(...)`), and a JSON 0
            // arriving at a QML bool is a coercion this file should not be
            // relying on to be right.
            property JsonObject power: JsonObject {
                property int saver_on:   1
                property int saver_secs: 300
                property int lock_secs:  600
            }
        }
    }
}
