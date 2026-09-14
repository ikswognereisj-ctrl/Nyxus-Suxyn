// NYXUS Daily Driver — Quickshell shell entry point.
//
// This is the file `qs` loads (default config, ~/.config/quickshell/shell.qml).
// It brings up the three shell surfaces the approved mockups define
// (docs/assets/daily-driver/): the bottom taskbar, the Start menu and the
// quick-settings / notification flyout. Each is its own PanelWindow; this root
// just instantiates them once and exposes the keybind IPC.
//
// Framework choice and rationale: docs/SHELL_FRAMEWORK_EVALUATION_2026-08-02.md
// (Quickshell — in Arch `extra`, hot-reloads, no AUR). Palette: Theme.qml.
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    id: shellRoot

    // ── WHICH SKY ────────────────────────────────────────────────────────
    // false — STARLIGHT: the Rolls-Royce headliner, a flat field of fibre
    //         points over the wallpaper.
    // true  — STARLIGHT VOYAGE: the 3D raymarched deep-space view, drifting,
    //         with the ringed planet and its two moons (`Starlight3D.qml`).
    //         This is what ships today.
    //
    // One line, because the two are alternatives and never an addition — two
    // skies at once is two full-screen shader passes for one visible result.
    // TRUE since 2026-08-10 — the owner made the call, looking at it: "i want
    // it to just show the one the new one we just built". Turning this on also
    // turns STARLIGHT off (the two Variants below take opposite models), so
    // there is exactly one sky on screen and never two composited.
    //
    // TRK-3121 — Display ▸ Voyage writes `voyage_enabled`. Hardcoding true
    // made that switch a JSON-only placebo. Default stays true so a Voyage
    // background still instantiates this Variant; `Starlight3D.skyEnabled`
    // is what actually maps the window. Headliner (the shipped sky_mode)
    // never reaches this Variant.
    readonly property bool voyageSky: SettingsStore.boolValue("voyage_enabled", true)

    // ── WIP-555: REACH — a way OFF whichever sky, back to the wallpaper ──
    // 19 wallpapers ship and Wallpaper Studio exists to browse them, but
    // with a sky on, applying one wrote wallpaper.conf and nothing visible
    // happened: a sky sits on the Bottom layer, the wallpaper is one layer
    // further down on Background, so the sky always wins the pixel. This is
    // the escape hatch, live and reversible (`Prefs.qml` watches
    // settings.json, no shell restart) — NOT a change to the default above.
    // Settings → Wallpaper Studio and the Apply button in the dedicated app
    // are the writers; this is read-only, same contract as every other
    // `Prefs.*` consumer in this file.
    readonly property bool skyWantsWallpaper: Prefs.skyWantsWallpaper

    // ── THE STARLIGHT HEADLINER (owner commission, 2026-08-17) ──────────
    // `sky_mode: "headliner"` — the RR fibre ceiling as hard points on true
    // black. A THIRD alternative on the same one-of-N choice, so it is
    // mutually exclusive with both skies and with the wallpaper by
    // construction: the four models below are branches of one expression and
    // exactly one of them is ever non-empty. Two full-screen shaders at once
    // is two passes for one visible result, which is the reason `voyageSky`
    // was one line rather than two switches, and the reason this is one value
    // rather than a fourth boolean.
    readonly property bool skyWantsHeadliner: Prefs.skyWantsHeadliner

    // ── THE LAYERED WALL (owner commission, 2026-09-01 · TRK-3646) ───────
    // `sky_mode: "layered"` — ONE picture cut in two across the compositor's
    // real layers, so his widget chips sit INSIDE the scene:
    //
    //   Bottom       widget chips  +  `SkyForeground` (the -fg plate)
    //   Background   `LiveWall`    showing the -bg plate
    //
    // A FOURTH branch of the same one-of-N expression the three above are
    // branches of, so it is mutually exclusive with both skies and with the
    // plain wallpaper by construction — see the guards on the Starlight /
    // Starlight3D models below, which this value had to be added to or the
    // 3D sky would have come up UNDER the layered ground and paid for a
    // raymarch nobody can see.
    //
    // OFF until the owner picks it: `sky_mode` still defaults to "headliner",
    // and `layered_wall_base` still defaults to "", so this needs two
    // deliberate settings before one surface exists. Any keep-set still with
    // both ~/.local/share/nyxus/walls/<slug>-{bg,fg}.png is layered when
    // picked (SetPageBackground writes the prefix); not only nebula-veil.
    readonly property bool layeredSky: Prefs.skyWantsLayered
                                       && Prefs.layeredWallBg !== ""
    // MAGMA world: Starlight (Headliner) is the stars. The lava planet is
    // only the near plate. Never a photo of stars, never a flattened
    // composite of the two.
    readonly property bool magmaPlanet: Prefs.lookSet === "magma"
                                        && Prefs.layeredWallFg !== ""

    // ── THE LIVING WALLPAPER ─────────────────────────────────────────────
    // His own galaxy picture with the swirls inside the band stirred by the
    // cursor, exactly the way the taskbar's paint is — `LiveWall.qml`.
    //
    // OFF, and the empty model means nothing is INSTANTIATED rather than
    // instantiated-and-hidden: no window, no surface, no solver, and no way
    // for it to affect a running shell until this word changes. That is
    // deliberate — it was written in the same breath as the owner saying the
    // 3D sky cost him too much, so it starts costing nothing.
    //
    // TRK-3121 — Display ▸ Living wallpaper. Ships OFF (same as this
    // hardcoded false was). The switch default on that page was true, which
    // lied. Default here is false so a fresh settings.json does not turn a
    // full-screen shader on.
    readonly property bool livingWallpaper: SettingsStore.boolValue("livewall_enabled", false)

    // ── THE FROST, per screen ────────────────────────────────────────────
    // Every window you are not looking at, blurred so you cannot read it while
    // its shape stays legible — the owner's original ask, which
    // `nyxus-idle-glass.sh` answered with transparency instead. See
    // `Frost.qml`'s header for why this cannot be a compositor setting.
    //
    // ⚠ DECLARED BEFORE THE BAR, and that is load-bearing rather than tidy.
    // wlr-layer-shell stacks same-level surfaces in the order the client
    // creates them, and both of these live on `Top`, so a surface declared
    // later lands ABOVE one declared earlier. The bar must be above the frost:
    // it is where windows are not, but a maximised window's rect can reach the
    // bar's edge, and a frost pane over the taskbar would be the `WIP-783`
    // defect again — a surface something else quietly painted over, with
    // nothing in any file saying which of the two was on top. This says it.
    //
    // The window is not mapped at all while the setting is off (`visible` is
    // bound to it), so an unused frost costs no surface and no blur region —
    // and `HyprApply` leaves the compositor's blur pass switched off with it.
    Variants {
        model: Quickshell.screens
        Frost {
            required property var modelData
            screen: modelData
        }
    }

    // The taskbar exists for every screen the compositor reports. On a single
    // monitor this is one bar; on more it is one per screen, which is what a
    // taskbar should do.
    Variants {
        model: Quickshell.screens
        Bar {
            required property var modelData
            screen: modelData
        }
    }

    // THE FLOOR — multiplex lobby on HDMI (and every screen in arcadeMode).
    // Transparent Top so Headliner + MAGMA planet stay the room. ES must
    // not cover this.
    Variants {
        model: Quickshell.screens
        Floor {
            required property var modelData
            screen: modelData
        }
    }

    // ── the Frame · ON HOLD on the owner's instruction, 2026-08-09 ──────
    // The focused window held in a channel of the same living paint the
    // horizon seam runs. On the 08-09 hardware boot it read as "a grey
    // border with faint swirls that go around once, and it lags behind the
    // window when I move it" — the lag is WIP-117's polling (lastIpcObject
    // does not stream), and the grey channel sat OVER Hyprland's own rose
    // border so the build's real border was invisible. The owner's call:
    // "put the borders with the swirls on hold and just keep the original
    // borders from hyprland and make sure they still pulsate to music …
    // and change color based on the work load."
    //
    // `Frame.qml` and B's work in it are LEFT ON DISK, not deleted — same
    // precedent as the Spill below: reinstating it is this block back.
    // What replaces it is BorderPulse (right below): Hyprland's own
    // col.active_border, driven live from Beat + Sys.
    // Variants {
    //     model: Quickshell.screens
    //     Frame {
    //         required property var modelData
    //         screen: modelData
    //     }
    // }

    // STARLIGHT (WIP-204) — the RR headliner, per screen: a bottom-layer
    // field of fibre-optic stars lighting the wallpaper, ported from
    // design/starlight-live.html. Owner: "as real as looking at the one."
    // An empty model instantiates nothing, so exactly one of these two is ever
    // alive — no Loader, and no `visible: false` window still holding a layer
    // surface and a shader.
    // THE STARLIGHT HEADLINER (owner commission, 2026-08-17), per screen.
    //
    // ⚠ DECLARED FIRST among the ground surfaces, and that is load-bearing
    // rather than tidy. wlr-layer-shell stacks same-level surfaces in the
    // order the client creates them, so a surface declared later in this file
    // lands ABOVE one declared earlier. The desktop-icon surface
    // (`nyxus-desktop`) and the three widget chips also live on Bottom, and
    // both are meant to be over the ground, not under it. Creating this first
    // puts it at the bottom of Bottom, where a ground belongs. `WIP-783` is
    // why this is written down: a full-screen Bottom-layer surface that
    // something else quietly painted over cost 96% of the wallpaper, and
    // nothing in any file said which of the two was on top.
    Variants {
        model: (shellRoot.skyWantsHeadliner || shellRoot.magmaPlanet)
               ? Quickshell.screens : []
        Headliner {
            required property var modelData
            screen: modelData
        }
    }

    // THE LAYERED WALL · the NEAR half, per screen (TRK-3646).
    //
    // ⚠ DECLARED HERE, FIRST AMONG THE `Bottom` SURFACES, and that is the
    // third of this feature's three guarantees rather than a matter of taste.
    // wlr-layer-shell stacks same-level surfaces in the order the client
    // creates them, and `BarSeam`, the `nyxus-desktop` icon surface and the
    // six widget chips are all on `Bottom` too. Creating this one first puts
    // it at the bottom of that level, under every one of them — so even if the
    // art file and the geometry cap both failed, the map order would still
    // keep it off the chips. The other two guarantees (a transparent -fg plate,
    // and a wl_surface capped at the widget board's left edge) are in
    // `SkyForeground.qml`'s header, with the measurement that made them
    // necessary: `Widgets.qml:470-495`, card contrast 178.57 -> 128.96 with a
    // sky on the chips' own level.
    Variants {
        model: (shellRoot.layeredSky || shellRoot.magmaPlanet)
               ? Quickshell.screens : []
        SkyForeground {
            required property var modelData
            screen: modelData
            artEnabled: true
            artwork: Prefs.layeredWallFg
            // The keep-out, derived live from the SAME arithmetic that places
            // the chips (`Prefs.widgetBoardLeft`, moved there from
            // `Widgets.qml` by this change so there is one copy of it). A
            // negative answer means widgets are off and there is nothing to
            // keep out of, which is the full-screen case.
            keepOutLeft: Prefs.widgetBoardLeft(modelData ? modelData.width : 0)
            keepOutTop: Prefs.widgetBoardTop()
            keepOutBottom: Prefs.widgetBoardBottom()
        }
    }

    // TRK-3085 · Owner 00:44: swirls under the glass, not in the same
    // surface. Empty mask, no zone. The Top bar stays the glass + icons.
    //
    // This used to read "AFTER Headliner (same Bottom stack — later is
    // above)", and that is no longer how it is held: TRK-3605 moved every sky
    // surface down to `WlrLayer.Background`, so this seam sits above the sky
    // because it is on a HIGHER LAYER, not because it happens to map later.
    // The ordering it wanted is now a fact rather than a race.
    Variants {
        model: Quickshell.screens
        BarSeam {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: (shellRoot.skyWantsWallpaper || shellRoot.skyWantsHeadliner
                || shellRoot.layeredSky) ? []
             : (shellRoot.voyageSky ? [] : Quickshell.screens)
        Starlight {
            required property var modelData
            screen: modelData
        }
    }

    // THE COMPANION — the streetwear alien, on the desktop (Companion.qml).
    // One per screen, gated by `Prefs.companionEnabled` (off by default). It
    // maps on `WlrLayer.Bottom` like the widget chips, so windows cover it, and
    // its input mask is the sprite's box alone so it never eats a desktop
    // click. Replaces the unwired Godot `companion-3d/` overlay — the owner's
    // 2026-09-05 verdict on that was "it didnt work good or look good at all".
    Variants {
        model: Prefs.companionEnabled ? Quickshell.screens : []
        Companion {
            required property var modelData
            screen: modelData
        }
    }

    // STARLIGHT VOYAGE — the 3D sky. Same bottom layer, same never-a-click
    // surface; the difference is that this one is a volume you drift through.
    // Notes on the cursor tilt and the battery/fullscreen throttle are at the
    // top of Starlight3D.qml.
    Variants {
        model: (shellRoot.skyWantsWallpaper || shellRoot.skyWantsHeadliner
                || shellRoot.layeredSky) ? []
             : (shellRoot.voyageSky ? Quickshell.screens : [])
        Starlight3D {
            required property var modelData
            screen: modelData
            // Instantiated only when sky_mode is Voyage and the Display
            // switch is on. The type default is still false (Iris Xe cost);
            // this instance is the Settings wire. Tracking defaults 0 so
            // parallax stays off until the slider leaves Still.
            skyEnabled: !(SettingsStore.boolValue("voyage_battery_pause", true)
                          && Sys.hasBattery && !Sys.batteryCharging)
            parallax: SettingsStore.numberValue("voyage_tracking", 0) > 0.01
            parallaxAmount: SettingsStore.numberValue("voyage_tracking", 0)
            driftSpeed: SettingsStore.numberValue("voyage_speed", 1.0)
        }
    }

    // The living wallpaper, per screen. Empty model = nothing exists.
    //
    // ── AND THE LAYERED WALL'S FAR HALF RIDES THE SAME SURFACE (TRK-3646) ─
    // `sky_mode: "layered"` needs an opaque `-bg` plate on `WlrLayer.Background`.
    // This IS the shell's Background wallpaper surface — it already anchors
    // full-screen on that layer, already binds a path, already handles a
    // missing file honestly, and already costs a plain `Image` when nothing is
    // stirring. Adding a second Background surface for the layered mode would
    // have been two wallpapers on one layer with nothing in either file saying
    // which was on top, which is the `WIP-783` shape exactly. So the model
    // gains a second reason to be non-empty and the picture gains a branch.
    //
    // `interactive` follows `livingWallpaper` ALONE, not this. Stirring is the
    // one thing in this build that gives up `mask: Region {}` and claims an
    // input region (LiveWall's own "THE ONE REAL TRADE"), and a layered wall
    // has not asked for that — with the living wallpaper off, the far half is
    // a still plate with an empty mask, and the solver never wakes.
    Variants {
        model: (shellRoot.livingWallpaper
                || (shellRoot.layeredSky && !shellRoot.magmaPlanet))
             ? Quickshell.screens : []
        LiveWall {
            required property var modelData
            screen: modelData
            wallEnabled: true
            interactive: shellRoot.livingWallpaper
            displacePx: 45.0 * SettingsStore.numberValue("livewall_strength", 1.0)
            flowGain: 70.0 * SettingsStore.numberValue("livewall_strength", 1.0)
            // TRK-3607 (LIVEBIND): bind the stirred picture to the wallpaper the
            // user actually picked. `~/.config/nyxus/wallpaper.conf`'s
            // `WALLPAPER_PATH` is the one file the rest of the live shell already
            // treats as "the current wallpaper" — `nyxus-set-wallpaper` (the
            // Background page's own backend) writes it, swaybg reads it, and
            // SkyBehind.qml already FileView-watches this exact path this exact
            // way for `sky_mode: "wallpaper"`. `theme/wallpaper.json` is a second,
            // richer format (favorites/brightness/schedule) but no live shell.qml
            // consumer reads it reactively, so it is not the source of truth here
            // — wallpaper.conf is. Empty/unreadable parse falls back to
            // LiveWall's own known-good default; a chosen-but-deleted file is
            // handled inside LiveWall.qml itself (`wallpaperBroken`).
            // NOTE: `wallUrl` below is deliberately a plain `string`, not
            // `url`. A `url`-typed QML property compared with strict `!==`
            // against a JS string literal never equals it (QUrl vs. string
            // as JS values), so `wallConf.wallUrl !== ""` was ALWAYS true —
            // the empty/missing-file branch was silently unreachable and the
            // Image got handed an empty source (rendered nothing, PanelWindow
            // black behind it) instead of falling back. Caught in this seat's
            // own caged capture: an empty-conf seed painted solid black, not
            // the fallback default. String comparison first, url coercion
            // happens for free where `wallpaper: ...` assigns into the
            // url-typed property below.
            // TRK-3646: in layered mode the far half is the `-bg` plate and
            // NOT wallpaper.conf — the two halves have to come from one pair
            // or they will not register. `shellRoot.layeredSky` already
            // requires a non-empty base, so this branch never resolves empty.
            wallpaper: shellRoot.layeredSky
                       ? Prefs.layeredWallBg
                       : (wallConf.wallUrl !== "" ? wallConf.wallUrl : fallbackWallpaper)
            FileView {
                id: wallConf
                path: (Quickshell.env("HOME") || "") + "/.config/nyxus/wallpaper.conf"
                watchChanges: true
                printErrors: false
                property string wallUrl: ""
                onFileChanged: reload()
                onLoaded: wallUrl = wallConf._toUrl(wallConf._parse(text()))
                onLoadFailed: wallUrl = ""
                function _parse(raw) {
                    var lines = String(raw).split("\n");
                    for (var i = 0; i < lines.length; i++) {
                        var ln = lines[i];
                        if (ln.indexOf("WALLPAPER_PATH=") === 0) {
                            var p = ln.substring(15);
                            if (p.charAt(0) === "\"" && p.charAt(p.length - 1) === "\"")
                                p = p.substring(1, p.length - 1);
                            return p;
                        }
                    }
                    return "";
                }
                function _toUrl(p) {
                    if (!p || p.length < 2)
                        return "";
                    if (p.indexOf("file:") === 0)
                        return p;
                    return "file://" + p;
                }
            }
        }
    }

    // The border, alive (2026-08-09). Hyprland's own rose border is the
    // border again; this non-visual singleton driver pulses its brightness
    // with the music (Beat) and shifts its colour with the workload
    // (Sys.cpuPercent). No window, no layer surface, no cost when idle.
    // BorderPulse {}   // audit 2026-09-08: drove app-window border/shadow to ice+plum on every beat; widgets have a fixed 45% glacier rim, so app windows get the same (hyprland.conf).

    // ── the Spill · REMOVED on the owner's instruction, 2026-08-05 ──────
    // HORIZON §5.35 argued this was bias lighting for an operating system —
    // the glow the Line throws up onto the wallpaper, "most of what 'how they
    // almost glow' means in practice".
    //
    // It never read that way on a screen. The owner asked "what is the point
    // of the thing above the task bar" twice, unprompted, months apart; agent
    // B measured it painting a flat milky slab over the bottom 130 px of the
    // wallpaper and corrected two real bugs in it (WIP-13); agent G masked its
    // hard cut-off edge and was told "the spill goes for now" mid-task. The
    // instruction this time was explicit: get rid of the swirls above the bar.
    //
    // `Spill.qml` and B's work in it are LEFT ON DISK, not deleted — this is
    // one line, and reinstating it is the same line back. What is gone is the
    // second `nyxus-spill` layer surface, which also means one fewer live
    // Swirl at rest: WIP-8 counted exactly two, and this was one of them.
    // Spill {}

    // The Start menu is a single, edge-docked surface, so it is not
    // per-screen — one instance, shown on the focused output by the
    // compositor.
    //
    // ── the Flyout · UNLOADED, WIP-127 phase 2 ──────────────────────────
    // Every section it held now lives in SidePanel, and SidePanel answers
    // the same Bus traffic (openFlyoutAt / toggleFlyout / flyoutOpen), so
    // every caller still works. The line is commented rather than the file
    // deleted so that reverting the migration commit restores a working
    // flyout; the FILE is removed in the commit after this one, per the
    // spec's §5 sequencing — a revert must never leave neither surface.
    // Flyout {}
    Launcher {}
    Clock {}
    UsbDock {}
    PowerMenu {}
    TaskView {}
    Toasts {}
    // Volume / mic / brightness OSD. Self-driving: Pipewire for volume+mic,
    // udev+brightnessctl for the backlight. No hyprland.conf edit — the keys
    // already change the values; this surface reads them. See Osd.qml.
    Osd {}

    // TRK-1700..1702 — THE ROOMS: your workspaces as a 2-D grid you walk with
    // CTRL+ALT+arrows, the little map (SUPER+ALT+M), the arrival nameplate,
    // and the carry key (SUPER+G). The fast path is `qs ipc call house …`,
    // one batched hyprctl per move.
    // DEFAULT ON (the owner's headline ask) — but the switch is real and OFF
    // costs nothing: this LazyLoader never builds the HUD, so the Rooms
    // singleton is never constructed, no map or plate window exists, and the
    // `house` IPC target is absent. The shard's binds then fall back to
    // nyxus-house, which also exits 0 with a note while the pref is off, and
    // the shard declares no workspace and no layer rule at all, so a desktop
    // with the Rooms switched off is the desktop that was there before.
    LazyLoader {
        active: Prefs.stationEnabled
        Station {}
    }
    // Pointer trail (2026-08-20). Empty model = no Overlay and the
    // hyprctl loop in PointerCursor stays stopped. Not a veil (WIP-783).
    Variants {
        model: Prefs.pointerTrailEnabled ? Quickshell.screens : []
        PointerTrail {
            required property var modelData
            screen: modelData
        }
    }

    // Now-playing card above the bar centre. Dock it and the Gauge Crest
    // holds the compact line (same slot as a notice). Off in Appearance.
    MediaCrest {}
    RecordHud {}

    // The emoji & symbol picker (WIP-704 · GAP-B7 · GAP-923). One instance,
    // like the Launcher: a single edge-less overlay the compositor centres,
    // shown on the focused output.
    //
    // Declared rather than Loader-wrapped for the same reason `Settings` is:
    // a PanelWindow with `visible: false` holds no layer surface, no buffer
    // and no frames, and the picker owns NO timer — see EmojiPicker.qml's
    // header. A Loader would only move where the same object is built.
    //
    // ⚠ Deliberately NOT rofi. `rofi-emoji` is packaged and unreferenced, and
    // `WIP-557` is the row that says a second unthemed rofi surface is the
    // defect, not the fix.
    EmojiPicker {}

    // The desktop widgets (WIP-140 §4). Off by default; Prefs gates every
    // chip, so with no settings.json this is dormant — no windows mapped,
    // no timers running.
    Widgets {}

    // The Rail (WIP-127). One instance: a single edge-docked surface like the
    // Launcher and the Flyout, shown on the focused output.
    SidePanel { id: sideRail }

    // The context menu (WIP-126). One instance, not per-screen: only one menu
    // can be open at a time by definition, and `Menu` carries which screen the
    // click came from.
    //
    // Declaration order does NOT decide what covers what here — these are
    // separate wlr-layer-shell surfaces, and the COMPOSITOR stacks them by
    // `WlrLayershell.layer`. ContextMenu is on Overlay and SidePanel on Top,
    // so the menu is above the panel no matter where either line sits in this
    // file. Written down because the QML instinct is to reorder these two and
    // expect it to change something; it would not.
    ContextMenu {}

    // Keybinds live in Hyprland and reach the running shell through this one
    // handler: `qs ipc call nyxus launcher` etc. The daily edition binds
    // Super, Super+A and Super+N to these (see build-iso.sh daily block).
    // ── MASTER SETTINGS ─────────────────────────────────────────────────
    // The control center, in the shell's own glass. One instance: a single
    // application window, not per-screen, and not a layer surface — see the
    // header of `Settings.qml` for why a control center is a FloatingWindow
    // and everything else here is not.
    //
    // Declared here rather than behind a Loader because a FloatingWindow costs
    // nothing while `visible` is false: no surface, no buffer, no frames. The
    // Loader would only move where the same object is built.
    Settings {}
    Condition {}
    Notes {}
    Calculator {}
    Media {}
    Files {}
    Store {}
    Reader {}
    CalendarApp {}
    Viewer {}
    Archive {}
    Weather {}
    ClockApp {}
    Screenshot {}
    Help {}
    Brain {}
    Hardware {}
    Sysmon {}

    // ── the two settings singletons that must be ALIVE, not merely present ──
    // A QML singleton is constructed on FIRST USE. Both of these do their work
    // whether or not anybody opens Settings, so if the only references to them
    // were inside `Settings.qml` they would come into existence the first time
    // the window opened and not a moment sooner — the USB toast would never
    // fire until you had been to the USB page, and your pointer speed would
    // not be applied at login.
    //
    // `Component.onCompleted` touching each one is what brings them up with
    // the shell. It costs nothing: HyprApply pushes one hyprctl batch, and
    // UsbWatch runs `lsblk` once and then opens a udev stream that is idle
    // until the kernel says something — and only if the user has left one of
    // its two switches on.
    //
    // BatteryWatch (GAP-933) is the third and it is the clearest case of the
    // trap: its whole job is to warn you before the machine dies, and left
    // untouched here it would not exist until somebody opened Settings ▸
    // Notifications — i.e. it would warn nobody, ever, while its switch sat
    // there defaulting ON. It owns no timer and no subprocess; touching it
    // reads two properties UPower is already publishing.
    Item {
        visible: false
        Component.onCompleted: {
            HyprApply.apply();
            UsbWatch.refresh();
            BatteryWatch.start();
            LinkWatch.start();
            RecordWatch.start();
            UpdateWatch.start();
        }
    }

    // TRK-1273 — the timing-budget watchdog (`shell/Perf.qml`): stalls,
    // sampled frames and timed IPC to ~/.local/state/nyxus/perf.log. One
    // line, outside every window (the WIP-245 crash rule).
    Perf { id: perfWatch }

    IpcHandler {
        target: "nyxus"
        // TRK-1270 — `qs ipc call nyxus ping` → `pong`. The smoke probe's
        // readiness door. A STRING, not void, because `qs ipc call` exits 0
        // even when the target does not exist (see the `lock` handler).
        function ping(): string { return perfWatch.time("ping", function () { return "pong"; }); }
        // Soft reload without killing this process. `qs kill` is forbidden
        // on the look-seat (HANDOFF preview ruling). false = keep windows.
        // Never Quickshell.reload(true) from this handler: it stacks a second
        // shell tree (3 bars / 3 widget boards) instead of replacing.
        function reload(): string { Quickshell.reload(false); return "reloading"; }
        function launcher(): void { Bus.toggleLauncher(); }
        function condition(): void { Bus.toggleCondition(); }
        function flyout(): void { Bus.toggleFlyout(); }
        // TRK-2400 — `qs ipc call nyxus flyoutAt sound`. The flyout shows ONE
        // section at a time and the rail is the switcher, so `flyout` alone
        // could only ever open Quick: nine of the ten sections were
        // unreachable from a script and therefore unphotographable in a
        // nested-preview run. That is precisely how a surface ships without
        // anyone having looked at it. `Bus.openFlyoutAt` already exists and
        // already carries the alias map; this is the door to it.
        function flyoutAt(section: string): void { Bus.openFlyoutAt(section); }
        // TRK-2987 — `qs ipc call nyxus flyoutGeom`. `win` is the mapped
        // PanelWindow (`winH`), not the 996 exclusive-zone leftover. The
        // CARD is `panelH`. `body=MAX` means the Flickable cast missed and
        // the card clamped to `panelCap` (failure direction is the ceiling,
        // never a stub).
        function flyoutGeom(): string {
            return "win=" + sideRail.height
                 + " cap=" + sideRail.panelCap
                 + " h=" + sideRail.panelH
                 + " chrome=" + sideRail.panelChrome
                 + " body=" + (sideRail.bodyNatural > 1e6 ? "MAX" : Math.round(sideRail.bodyNatural))
                 + " key=" + sideRail.activeKey
                 + " exp=" + (sideRail.expanded ? "1" : "0");
        }
        function power(): void { Bus.togglePower(); }
        function taskview(): void { Bus.toggleTaskView(); }
        // The clock surface is the fifth overlay and was the only one with no
        // IPC door, so the one thing a person can only reach by CLICKING the
        // bar clock was also the one thing no nested-preview run could ever
        // photograph — which is part of why `WIP-640(c)` (it opened in the
        // wrong corner and had no month grid) survived two live walks. One
        // line, the same `Bus.toggle*` shape as its four neighbours.
        function clock(): void { Bus.toggleClock(); }
        // WIP-704 — Super+. `qs ipc call nyxus emoji`. Same `Bus.toggle*`
        // shape as its five neighbours, so the picker is reachable from a
        // keybind, from a nested-preview run and from a script without any
        // one of those being a special case.
        function emoji(): void { Bus.toggleEmoji(); }
        function closeAll(): void { Bus.closeAll(); }
        // Super+M. No title-bar minimize control. Click the Row icon to raise.
        function minimize(): void { Tasks.minimizeActive(); }

        // `qs ipc call nyxus settings` opens Home; `settingsAt <key>` opens a
        // subject. The key is the SAME one `nyxus-settings <key>` takes, which
        // is what lets the sixteen existing deep links in the shell move over
        // one at a time instead of all at once.
        function settings(): void { Bus.toggleSettings(); }
        function settingsAt(key: string): void { Bus.openSettings(key); }
        function notes(): string { Bus.openNotes(); return "notes"; }
        function calculator(): string { Bus.openCalculator(); return "calculator"; }
        function media(): string { Bus.openMedia(); return "media"; }
        function files(): string { Bus.openFiles(); return "files"; }
        function store(): string { Bus.openStore(); return "store"; }
        function reader(): string { Bus.openReader(); return "reader"; }
        function calendar(): string { Bus.openCalendar(); return "calendar"; }
        function viewer(): string { Bus.openViewer(); return "viewer"; }
        function archive(): string { Bus.openArchive(); return "archive"; }
        function weather(): string { Bus.openWeather(); return "weather"; }
        function clockapp(): string { Bus.openClockApp(); return "clock"; }
        function screenshot(): string { Bus.openScreenshot(); return "screenshot"; }
        function help(): string { Bus.openHelp(); return "help"; }
        function brain(): string { Bus.openBrain(); return "brain"; }
        function hardware(): string { Bus.openHardware(); return "hardware"; }
        function sysmon(): string { Bus.openSysmon(); return "sysmon"; }
    }

    // ── THE LOCK SCREEN ──────────────────────────────────────────────────
    // The animated lock surface (`Lock.qml`). It is INERT until something
    // calls `engage` — declaring it costs a PAM context and nothing else, and
    // it cannot lock the session on its own.
    //
    // Nothing in this build talks to it directly except `nyxus-lock-guard`,
    // which is still the single choke point for every lock route (Super+L,
    // hypridle's timer, before-sleep, the desktop menu) and still refuses to
    // lock an account with no password — the WIP-114 trap that cost the owner
    // a session. The guard PRE-FLIGHTS `ready` below and falls back to
    // `hyprlock` if this handler does not answer, so a shell that failed to
    // load costs the eye candy and never the session.
    Lock { id: nyxLock }

    // ── THE SCREENSAVER (owner commission, 2026-08-17) ───────────────────
    // "set a screensaver as well that really works and then goes to login
    // after so long after that as well."
    //
    // Declared AFTER `Lock` and directly beside it because they are two stages
    // of one chain, not two features: idle → this → (further idle) → the lock
    // above. It costs nothing until it engages — with `shown` false its
    // `Variants` model is empty, so there is no window, no layer surface and no
    // shader, the same construction the four skies use.
    //
    // ⚠ IT DOES NOT LOCK, and it must not learn how. `nyxus-lock-guard` is
    // still the single choke point for every lock route, and hypridle's own
    // `lock_secs` listener is what hands over to it. See Screensaver.qml for
    // why splitting the chain across the two is the safe arrangement.
    Screensaver {
        // The one wire between the two stages. With the lock up the saver
        // stands down: it could never obscure a session-lock surface anyway,
        // but left alone it would sit underneath it stepping a 25 Hz twinkle
        // for the whole time the machine was locked, and nothing would take it
        // down — the saver hides on INPUT, and the lock arriving is not input.
        blocked: nyxLock.locked
    }

    IpcHandler {
        target: "lock"

        // ⚠ EVERY function here returns a STRING, and that is not decoration.
        // `qs ipc call` exits 0 even when the target does not exist — it prints
        // "Target not found." and reports success. Measured 2026-08-10:
        //
        //     $ qs ipc call lock release   # with no shell running
        //     Target not found.
        //     $ echo $?
        //     0
        //
        // So the guard cannot use the exit status to tell "the lock engaged"
        // from "there is no lock". It has to match the OUTPUT, which means
        // every call needs a distinctive one — including the ones that would
        // naturally have been `void`.
        function ready(): string { return "ready"; }
        function engage(): string { nyxLock.engage(); return "engaged"; }

        // The documented way back in from a TTY WITHOUT killing this process.
        // Under ext-session-lock a lock client that dies leaves the compositor
        // locked with no surface at all, so `pkill` is the wrong instinct here
        // and this is the right one. HANDOFF.md's escape hatch points at it.
        function release(): string { nyxLock.release(); return "released"; }

        function state(): string { return nyxLock.locked ? "locked" : "open"; }
    }
}
