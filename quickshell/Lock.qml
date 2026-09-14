// Nyxus Suxyn — THE LOCK SCREEN.
//
// A `WlSessionLock`: the compositor's own ext-session-lock surface, drawn by
// this shell, authenticating through PAM. It replaces hyprlock as the lock the
// user SEES. It does not replace hyprlock as the lock the system FALLS BACK
// TO — see the safety section below, and `nyxus-lock-guard`.
//
// ── why this exists ──────────────────────────────────────────────────────
// The lock screen had a living sky already: 116 pre-rendered PNGs stepped by
// `hyprlock.conf`'s `background { reload_cmd }`. It was stepped at exactly
// 1000 ms because that file carries a hard rule, learned by locking the owner
// out of his own machine on 2026-08-02, that nothing in it may poll faster.
//
// One frame per second is a slideshow. `hyprlock.conf`'s own header already
// named where real motion belongs — "the Quickshell lock surface
// (WlSessionLock), where it is an animated property rather than a process
// spawn per frame" — and nobody had built it. This is that surface.
//
// ── safety, which is the whole reason this file is careful ───────────────
// This build has a real lockout in its history (WIP-114): the owner skipped
// the password step in the welcome wizard, then hit the lock screen, and
// `pam_unix` rejects an empty password — so the account could be locked and
// never unlocked. A hard reset was the only way back. Four things stand
// between this file and a repeat:
//
//   1. `nyxus-lock-guard` is still the ONLY thing that starts a lock, on every
//      route, and it still refuses to lock an account with no password. This
//      file does not lock anything on its own — `engage()` is called by the
//      guard, after that check, or not at all.
//   2. The guard PRE-FLIGHTS this surface over IPC before it commits. If this
//      file failed to load — a typo, a missing type in qmldir, a bad .qsb —
//      the IPC call fails, and the guard runs `hyprlock` instead, exactly as
//      the build has always done. A broken redesign costs the eye candy, not
//      the session.
//   3. `locked` is set only from `engage()`, and cleared only by a PAM Success
//      or an explicit `release()`. There is no path where a rendering error
//      sets it.
//   4. `release()` is on the shell's IPC handler, so the documented TTY
//      recovery works WITHOUT killing this client. That matters more here than
//      it did for hyprlock: under ext-session-lock a lock client that DIES
//      leaves the compositor locked with no surface at all, by protocol
//      design. `nyxus-lock-guard --release` is the safe way out, and it is
//      what HANDOFF.md's escape hatch now points at.
//
// ── the 2026-08-17 redesign · what moved and what did not ────────────────
// This surface is the one the user SEES: `nyxus-lock-guard`'s pre-flight
// (`qs ipc call lock ready`) picks this engine whenever the shell answers, and
// on this machine it answers — so `hyprlock.conf` is the floor, not the face.
// A redesign that stopped at `hyprlock.conf` would change nothing anybody
// looks at.
//
// ⛔ THREE THINGS DO NOT MOVE, by owner instruction: "keep the weather widget,
//    the clock and the date layout as they are." So the whole of `worldCell`
//    below — the clock, the date, the spacer and the weather cluster — is
//    UNTOUCHED, and the slab's width, height, padding and cell split are
//    untouched WITH it, because changing any of those would relocate all three
//    even though their own properties never changed. Everything redesigned in
//    this pass is on the other side of the seam, in the chrome, or in the
//    material.
//
// ── chrome, 2026-08-19 ───────────────────────────────────────────────────
// The photograph is the ground. Chrome is two glacier rungs on the
// Login hairline (focus / hover / rest). Owner 2026-08-19: key accents
// on this surface are glacier/ice, not rose. Rest is glacier[0] at
// full alpha — glass idle 0.22 vanishes on this nebula. No GlassEdge,
// no Pane shader, no sweepAt divider. Clock / date / weather stay in
// worldCell; the field shares the clock digits' vertical centre.
// "Login" is the empty-state of the field (a child Text, same pattern as
// Settings search). Not placeholderTextColor — that property does not
// exist on TextInput and made Type Lock unavailable. The 17:52 still set
// a caption that stayed beside the password; this copy hides when you type.
//
// ── PAM ──────────────────────────────────────────────────────────────────
// Deliberately the SAME stack hyprlock uses — `/etc/pam.d/hyprlock`, which
// ships fprintd → howdy → system-auth, all sufficient. A second pam.d file for
// a second lock screen is two stacks that must be kept in step, and PAM files
// are exactly the kind of thing that gets edited once and drifts. One lock
// stack, two clients.
//
// ── the root is an Item, and that is not an accident ─────────────────────
// `WlSessionLock`'s default property is `surface`. A `Timer` or a `PamContext`
// declared as its child would be assigned to `surface` — a QQmlComponent —
// rather than parented alongside it. So the shared, once-only objects (the
// PAM conversation, the clock) live on a plain Item, and only the Component
// hangs off the lock. One PAM context for the session, not one per monitor,
// which on a two-screen desk would be two conversations answering one prompt.
//
// ── and the pragma is not an accident either ─────────────────────────────
// `surface:` is a Component, and everything in it — the clock, the PAM state,
// the user's name — lives on the Item OUTSIDE it. Without this pragma those
// reads resolve through the dynamic scope chain at runtime: they work, but the
// linter reports every one as an unqualified access, and a real typo would be
// indistinguishable from the sixteen false ones. Bound binds each surface to
// its creation context, which is exactly the relationship this file wants, and
// turns the linter back into a gate that can see this file.
// (A comment whose first word after the slashes is the linter's own name is
//  read as a lint DIRECTIVE — hence the wording above. Learned here, 08-10.)
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick

Item {
    id: lock

    // ── the honest lock state ────────────────────────────────────────────
    // `secure`, NOT `locked`. Measured on this machine 2026-08-10: setting
    // `WlSessionLock.locked = true` locks the compositor (`hyprctl locked`
    // flips to true) but reading the property straight back still returns
    // FALSE — it does not read back what you wrote. `secure` is the property
    // that actually tracks the protocol: it went true while the session was
    // locked and false the moment it was released, every time.
    //
    // This is not cosmetic. `state` over IPC is what nyxus-lock-guard uses to
    // decide whether a lock is already up, and a lock that always reports
    // "open" would have had the guard firing engage() again on every route.
    readonly property bool locked: sessionLock.secure

    // ── THE EARTH (owner ask, 2026-08-23) ────────────────────────────────
    // Straight off Prefs, so Settings > Lock screen and the setup wizard are
    // the only things that decide any of this. `earthSize` is the globe's
    // diameter as a fraction of the screen's short edge; the owner kept all
    // three of the sizes he was shown and picked the middle one:
    //     0.62 previous · 0.92 double (his pick) · 1.30 cropped
    //
    // ⚠ AND THE OCULAR SCENE SUPPRESSES IT — WITHOUT UNSETTING HIS PREFERENCE.
    // `Prefs.lockEarthOn` is deliberately still read here rather than being
    // written to false when the scene changes. The Earth is not "off" in the
    // constellation scene, it is simply not in that sky; switch back to orbit
    // and his globe returns at his own size, side, marker and lightning
    // settings, untouched. Turning the scene into a setting that EDITS other
    // settings is how a preference silently disappears.
    readonly property bool showEarth:    Prefs.lockEarthOn && !lock.ocular
    // The Moon is independent of the Earth: it is a real object in the real
    // sky and it is worth having on its own, whether or not the planet is up.
    readonly property bool showMoon:     Prefs.lockMoonOn && !lock.earthrise
                                         && !lock.ocular

    // ── THE SCENE (owner ask, 2026-08-24) ────────────────────────────────
    // He brought four photographs of Earthrise and said that was the one:
    // "then we would be the moon and you be able to still see it and earth in
    // our view still rotating as it does". So the camera comes down onto the
    // lunar surface. The Earth layer is UNCHANGED — same globe, same live
    // weather, same rotation, still turned to his own coordinates — it simply
    // sits higher in the frame with ground beneath it.
    //
    // The Moon-as-a-disc stands down in this scene, because you are standing
    // on it.
    readonly property bool earthrise: Prefs.lockScene === "earthrise"

    // ── THE OCULAR (owner ruling, 2026-09-05) ────────────────────────────
    // His mark, drawn as a constellation in a live sky with aurora curtains
    // under it. A THIRD scene, not a replacement: see LockOcular.qml for why
    // that distinction is the ruling itself and not a design preference.
    //
    // This is the one scene that runs a live shader, which is why it is worth
    // naming the 08-12 STILLNESS RULING here rather than only in the new file.
    // That ruling banned a frame clock on the lock because TWO full-screen
    // shaders lagged. Scenes are mutually exclusive, so when this is up the
    // Earth is not drawn and the pair the ruling was about cannot coexist. If
    // that ever stops being true — if some future scene draws both — the
    // ruling applies again and this has to go still.
    readonly property bool ocular: Prefs.lockScene === "ocular"
    readonly property real earthSize:    Prefs.lockEarthSize
    readonly property real earthCentreX: Prefs.lockEarthCentreX

    // The clock and the login box sit on the OPPOSITE side from the planet, so
    // that choosing a bigger Earth can never push the password field under it.
    // Centre is the one case with nowhere to run: the text goes right and the
    // globe is behind it, which is legible because the planet's own limb
    // darkening is deepest at the edges.
    readonly property bool earthOnRight: Prefs.lockEarthSide === "right"

    // Intent, as opposed to fact. engage() sets it; the compositor decides
    // whether `locked` above follows. When they disagree, the guard falls back
    // to hyprlock — see nyxus-lock-guard.
    property bool engaged: false
    readonly property string userName: Quickshell.env("USER") || "user"

    // What the surface shows about the last attempt.
    property string authMessage: ""
    property bool authError: false
    property bool busy: false
    property string secret: ""

    function engage(): void {
        if (sessionLock.secure) return;
        lock.authMessage = "";
        lock.authError = false;
        lock.busy = false;
        lock.secret = "";
        lock.engaged = true;
        sessionLock.locked = true;
    }

    // The way out that does not involve killing this process. See safety 4.
    function release(): void {
        lock.authMessage = "";
        lock.authError = false;
        lock.busy = false;
        lock.secret = "";
        lock.engaged = false;
        sessionLock.locked = false;
    }

    function submit(): void {
        if (lock.busy || pam.active) return;
        if (lock.secret === "") return;
        lock.busy = true;
        lock.authError = false;
        lock.authMessage = "checking…";
        if (!pam.start()) {
            lock.busy = false;
            lock.authError = true;
            lock.authMessage = lock.stuckHint;
        }
    }

    // Said in two places, so it is written in one. If PAM cannot run, the user
    // is looking at a lock they cannot pass, and the only useful thing this
    // screen can do is name the recovery instead of blinking at them.
    readonly property string stuckHint:
        "auth unavailable — Ctrl+Alt+F2, then: nyxus-lock-guard --release"

    // ══ THE EDGE LADDERS ═════════════════════════════════════════════════
    // TWO glacier rungs (ice). Owner 2026-08-19: this surface's chrome is
    // glacier/ice only — drop rose. `_interface_source` still locks the
    // rest of the shell to rose; this file does not retoken Theme.qml.
    //
    //   focus  paintLayers.glacier[0]  #7fe8ff ice + 1 px outer contour
    //   hover  paintLayers.glacier[5]  #b7e6f2
    //   rest  same glacier[0] hairline — focus is the contour, not a second hue
    //
    // Hairline only. No StateEdge instance here: that type tints a fill on
    // hover (accent-deep at ~0.11), which on this photograph is a veil.
    // glacier[4] is the mid rung (never a fill here), unused.
    //
    // ⚠ 0.22 idle-seam alpha is for glass-on-glass. Measured on the live
    //   WlSessionLock still `12-lock-live-restyle-0819.png` (1920×1080, nested
    //   HEADLESS-2, 17:37): a 1 px rose[0]@0.22 over the galactic band
    //   (bed lum ~100–150) was not separable from the photograph — the Login
    //   crop missed the box. On this ground the resting edge is the
    //   interactive rung at full alpha. Chips stay at structural 0.07.
    readonly property color iceInteractive: Theme.paintLayers["glacier"][0]
    readonly property color icePrimary:     Theme.paintLayers["glacier"][5]
    // ⚠ A `property color`, and it HAS to be one — see below. glacier[4] is
    // the hairline rung: 1 px dividers and resting control edges, never a fill.
    //
    // `Theme.paintLayers` is a `var` holding a plain JS object, so
    // `paintLayers.glacier[4]` is the STRING "#4f7fa6". Assigning a string
    // straight to a `color` property coerces fine — but
    // `Theme.soften(c, a)` is `Qt.rgba(c.r, c.g, c.b, a)`, and `.r` on a
    // string is `undefined`, so softening the raw string yields
    // `rgba(0, 0, 0, a)`: a BLACK hairline, not an ice one.
    //
    // Not theory. The first cut of the login card wrote
    // `Theme.soften(Theme.lookSeam, 0.60)` for its internal
    // divider and the live capture measured that row at RGB (2, 2, 4) against
    // a card ground of (5, 6, 9) — darker than the surface it divides, where
    // the intended colour composites to (49, 78, 103). Routing the rung
    // through a `color` property first is what makes `soften` see a colour.
    readonly property color iceHairline:    Theme.lookSeam
    // TRK-3707 · the pale peak of the ramp, glacier[6]. The owner asked for
    // "some of that pal colors" on 2026-09-01, and this is the one place the
    // card spends it: a short hard tick on the head seam. Routed through a
    // `color` property for the same reason as every rung above it — see the
    // TRK-3670 note; a raw `paintLayers` subscript is a STRING and `soften`
    // reads `.r` off it as `undefined`, which renders black.
    readonly property color iceMark:        Theme.paintLayers["glacier"][6]
    // Magma is the failed-password family on the login card. Routed through
    // a `color` property for the same string-vs-colour reason as the ice
    // rungs: `paintLayers.magma[n]` is a hex string and `soften` reads `.r`
    // off it as `undefined`.
    readonly property color magmaInteractive: Theme.paintLayers["magma"][0]
    readonly property color magmaPrimary:     Theme.paintLayers["magma"][5]
    readonly property color seamStructural: Theme.soften(lock.iceInteractive, 0.07)
    readonly property color seamIdle:       lock.iceInteractive
    readonly property color stateHover:     lock.icePrimary
    readonly property color stateFocus:     lock.iceInteractive
    readonly property color stateInvalid:   Theme.danger

    PamContext {
        id: pam
        configDirectory: "/etc/pam.d"
        config: "hyprlock"
        user: lock.userName

        onPamMessage: {
            if (pam.responseRequired) {
                pam.respond(lock.secret);
            } else if (pam.message !== "") {
                lock.authMessage = pam.message;
                lock.authError = pam.messageIsError;
            }
        }

        onCompleted: (result) => {
            lock.busy = false;
            lock.secret = "";
            if (result === PamResult.Success) { lock.release(); return; }
            lock.authError = true;
            lock.authMessage = (result === PamResult.MaxTries)
                ? "too many attempts — wait, then try again"
                : "not recognised";
        }

        onError: (err) => {
            lock.busy = false;
            lock.secret = "";
            lock.authError = true;
            lock.authMessage = (err === PamError.StartFailed)
                ? lock.stuckHint : "authentication error";
        }
    }

    // One clock for every surface. Quickshell's own, so it wakes on the minute
    // rather than drifting a second at a time — and `enabled` follows the lock,
    // so nothing ticks while the screen is not locked.
    SystemClock {
        id: clockSource
        enabled: lock.locked
        precision: SystemClock.Seconds
    }

    // ── caps lock ────────────────────────────────────────────────────────
    // The commonest "my password stopped working". Read from the keyboard LED
    // in sysfs — a FILE, not a process: the path is resolved once when the lock
    // engages, and after that it is a 1 s reload of four bytes. Polling
    // `hyprctl devices` would have been a subprocess per second, which is the
    // shape of the 2026-08-02 lockout and is not going near a lock screen.
    property string capsPath: ""
    readonly property bool capsOn: capsFile.text().trim() === "1"

    Process {
        id: findCaps
        command: ["sh", "-c",
            "ls -1 /sys/class/leds/*capslock/brightness 2>/dev/null | head -1"]
        stdout: StdioCollector { onStreamFinished: lock.capsPath = text.trim() }
    }
    FileView {
        id: capsFile
        path: lock.capsPath
        blockLoading: false
        printErrors: false
    }
    Timer {
        running: lock.locked && lock.capsPath !== ""
        interval: 1000; repeat: true
        onTriggered: capsFile.reload()
    }

    // ── the machine's own name ───────────────────────────────────────────
    // For the login card's identity block. A FILE, not a process, for the
    // same reason caps lock is a file: `hyprlock.conf`'s hard rule — learned
    // by locking the owner out on 2026-08-02 — is that nothing on a lock
    // screen spawns per frame, and a hostname does not change while a screen
    // is locked. `blockLoading` on twelve bytes of /etc/hostname, read once
    // when the shell starts, is cheaper than the Process it replaces.
    readonly property string hostName: hostFile.text().trim()
    FileView {
        id: hostFile
        path: "/etc/hostname"
        blockLoading: true
        printErrors: false
    }

    // Initials for the login card's disc when there is no account picture.
    // Not a placeholder: it is the real login name, reduced. Copied verbatim
    // from `Settings.qml` so the lock and the account page can never disagree
    // about what a name reduces to — including its `.charAt(0)` rather than
    // a string index, which qmllint reads as a call on a missing property and
    // fails audit item 2 on.
    function initialsOf(name) {
        var t = String(name || "").trim();
        if (t === "")
            return "?";
        var parts = t.split(/[\s._-]+/);
        if (parts.length >= 2 && parts[0].length > 0 && parts[1].length > 0)
            return String(parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
        return String(t.charAt(0)).toUpperCase();
    }
    onLockedChanged: if (lock.locked && lock.capsPath === "") findCaps.running = true

    // ── the lock ─────────────────────────────────────────────────────────
    WlSessionLock {
        id: sessionLock
        locked: false

        surface: WlSessionLockSurface {
            id: surf

            // Opaque, and opaque on purpose: this is the floor the star volume
            // and the weather are ADDED to. A transparent lock surface would
            // show the desktop through the gaps in the sky — both a leak and
            // ugly.
            color: Theme.void_

            FocusScope {
                id: page
                anchors.fill: parent
                focus: true

                // ⚠ DO NOT BIND ANYTHING TO `surf.visible`. It CRASHES.
                //
                // Reading WlSessionLockSurface.visible while the surface
                // Component is still being created calls QWindow::isVisible()
                // on a window that does not exist yet, and the process dies
                // inside QQmlComponent::create — segfault, not a warning.
                // Proved on this machine 2026-08-10: the probe died the
                // instant `engage()` ran, with QWindow::isVisible() at frame 4
                // of the stack trace. In a shipped lock that is the worst
                // possible failure: the client dies during the lock, and
                // ext-session-lock is specified to KEEP the session locked
                // when its client disappears.
                //
                // `lock.locked` is the honest signal and it exists before any
                // surface does. `shown` is only for the entrance animation,
                // and it is SET, never bound.
                property bool shown: false

                // ── the sky ──────────────────────────────────────────────
                // Owner 2026-08-20: lock #1 wears the same Starlight still as
                // the session headliner / GRUB background.png (md5 1b7bf223),
                // not the 08-19 photograph and not a lockweather frame.
                // Filename stays lock-still.png (13uv). Clock, date and the
                // weather cluster in worldCell do not move. PreserveAspectCrop
                // so a taller or wider screen still fills.
                Rectangle {
                    anchors.fill: parent
                    color: Theme.void_
                    visible: lock.locked
                }
                Image {
                    id: skyFx
                    anchors.fill: parent
                    // The Ocular brings its own sky, so the still stands down
                    // rather than being drawn underneath where it would cost a
                    // full-screen texture nobody can see.
                    visible: lock.locked && !lock.ocular
                    source: Qt.resolvedUrl("lock-still.png")
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    // 08-12 stillness ruling: no live shader, no frame clock.
                    // A PNG cannot twinkle.
                }
                // The FrameAnimation that used to drive the old sky's `u_time`
                // is GONE, not merely stopped — a stopped frame clock left in
                // the file is an invitation to switch it back on without
                // reading why it was switched off.

                // ── THE OCULAR SCENE ─────────────────────────────────────
                // Its own live sky, aurora and constellation, all inside one
                // component. `active` is the whole cost control: it is false
                // whenever the lock is down or the scene is not chosen, and a
                // false `active` stops the frame clock, stops the aurora FBO
                // redrawing and stops 22 twinkle animations. An unlocked
                // desktop pays nothing for this existing.
                LockOcular {
                    id: ocularSky
                    anchors.fill: parent
                    visible: lock.locked && lock.ocular
                    active: lock.locked && lock.ocular
                }

                // ── THE LUNAR GROUND · EARTHRISE ─────────────────────────
                // Foreground, so it is declared AFTER the Earth further down —
                // Qt paints siblings in order and the ground is in front of a
                // planet a quarter of a million miles away.
                //
                // ⚠ see below: this block is positioned by declaration order.

                // ── THE MOON (owner ask, 2026-08-24) ─────────────────────
                // Tonight's real moon: real phase, real size, and the real
                // colour the air gives it when it is low. See LockMoon.qml.
                //
                // The band is handed in from the slab's own geometry, so the
                // owner's question — "if i did that it wouldnt be over lapping
                // where the login part is right" — is answered by construction
                // rather than by hoping. Whatever size or side the Earth is
                // set to, the Moon is confined to the picture side and the
                // password field is a no-go area.
                LockMoon {
                    id: theMoon
                    anchors.fill: parent
                    visible: lock.locked && lock.showMoon
                    lat: earth.lat
                    lon: earth.lon
                    // ── the band is FREE SKY, not merely "not the text" ──
                    // First cut used the whole picture side, and the Moon then
                    // drew a disc in the middle of the Pacific: the Earth fills
                    // most of that side at the larger sizes. Two corrections,
                    // and the first is simply the truth — this component is
                    // declared BEFORE LockEarth so the planet is IN FRONT of
                    // it. The Moon is a quarter of a million miles further
                    // away; when it passes behind the Earth it should be
                    // occluded, and now it is.
                    //
                    // Second, the band starts at the globe's limb rather than
                    // at the screen edge, so it prefers open sky and only tucks
                    // behind the planet when there is nowhere else to be. At
                    // the largest Earth that gap is narrow and the Moon will
                    // often be behind it — which is what would really happen.
                    readonly property real earthLimb:
                        lock.earthOnRight
                            ? lock.earthCentreX - stack.earthHalf
                            : lock.earthCentreX + stack.earthHalf
                    bandLo: lock.earthOnRight
                          ? (stack.x + stack.width) / width + 0.04
                          : (lock.showEarth ? earthLimb + 0.02 : 0.05)
                    bandHi: lock.earthOnRight
                          ? (lock.showEarth ? earthLimb - 0.02 : 0.95)
                          : stack.x / width - 0.04
                    sizeScale: Prefs.lockMoonScale
                    // One sun lights both. See LockEarth.sunView.
                    sunAngle: lock.showEarth ? earth.sunScreenAngle : NaN
                    live: false
                }

                // ── THE EARTH (owner ask, 2026-08-23) ────────────────────
                // A LAYER over the still above, never a replacement for it:
                // "add this layer to the already there background image". The
                // shader writes premultiplied alpha and is zero outside the
                // globe and its air, so `lock-still.png` is untouched — same
                // file, same pinned path, same md5.
                //
                // It does NOT reinstate the 08-12 frame clock. `live` is false,
                // so this redraws once a minute and costs the GPU nothing in
                // between. Measured on the owner's own panel at the full
                // 1920x1080: 144 FPS even when driven every frame, which is
                // his monitor's refresh rate. The lag ruling was about two
                // full-screen shaders at once; this is one globe.
                //
                // Every input degrades: no satellite frames -> a clean lit
                // Earth; no textures -> `visible` false and the lock is
                // exactly the starfield it is today.
                LockEarth {
                    id: earth
                    anchors.fill: parent
                    visible: lock.locked && lock.showEarth
                    sizeFrac: lock.earthrise ? Math.min(lock.earthSize, 0.34)
                                             : stack.earthFitSize
                    centreX:  lock.earthCentreX
                    // Above the horizon, where the photographs put it.
                    centreY:  lock.earthrise ? 0.30 : 0.50
                    markerStrength: Prefs.lockEarthMarker ? 0.55 : 0.0
                    lightning: Prefs.lockEarthBolts
                    live: false
                }

                // ── THE LUNAR GROUND · EARTHRISE ─────────────────────────
                // Declared AFTER the Earth on purpose: Qt paints siblings in
                // order, and the surface you are standing on is in front of a
                // planet a quarter of a million miles away.
                //
                // Lit by the SAME sun vector that draws the Earth's terminator
                // above it — one sun in one frame, which is the error the owner
                // caught in the first moon and the reason this is threaded
                // through rather than recomputed.
                LockGround {
                    id: moonGround
                    anchors.fill: parent
                    visible: lock.locked && lock.earthrise
                    sun: earth.sunView
                    // The Earth is a big light in this sky; without a little
                    // bounce the shadowed regolith goes dead black.
                    earthshine: 0.07
                }


                // ── the weather ──────────────────────────────────────────
                // ⚠ THIS WAS `visible: false`, AND THAT WAS THE WHOLE BUG.
                // Every timer inside LockWeather is gated on `weather.visible`,
                // so with it false the cache was never read, `cond` stayed
                // empty, `hasData` stayed false, and the cluster below fell
                // through to "weather arrives with the network" forever. The
                // network was never the problem: the cache was live and correct
                // the entire time. Found 2026-08-23.
                //
                // It stays a data source rather than a picture — the Earth
                // above draws the sky now — so `visible` stays false and its
                // own shader never renders. `active` is what runs the clock.
                LockWeather {
                    id: weather
                    anchors.fill: parent
                    visible: false
                    active: lock.locked
                }

                // No full-surface scrim. WIP-858 already measured that a
                // reading veil hides the ground (cast 32.82 → 45.67 with the
                // old wash). The password lives in the Login box; the
                // photograph is the picture.

                // ── the corner chips ─────────────────────────────────────
                // Two, not the eight the previous lock carried. Battery and
                // network are the two facts you want before deciding whether
                // to sit back down. Host, kernel and uptime are not.
                // Redesigned 2026-08-17. Three things were wrong with these and
                // all three were consistency laws rather than taste:
                //
                //   · they were sentence-case running text ("online", "94%")
                //     where law 7 wants the system's own voice — uppercase,
                //     tracked — for anything it says ABOUT ITSELF. The voice
                //     spec §0 rule 1 exempts exactly this case from sentence
                //     case: "uppercase Inter Display section labels — those are
                //     typographic, not textual."
                //   · they carried NO edge at all, so they read as two ghosts
                //     on the sky rather than as chips of the same glass. A chip
                //     boundary is a SEAM (`seams.structural._role` lists "card
                //     boundaries" by name), so it takes the quietest rung.
                //   · the network label was set in `fUi` and the battery in
                //     `fNum`, side by side at the same size — two faces for one
                //     row. Law 6 puts NUMBERS in mono; "ONLINE" is not a number.
                //     So the split stays, but it is now deliberate and the
                //     tracking makes them read as one row anyway.
                Row {
                    anchors { top: parent.top; right: parent.right; margins: Theme.s6 * 2 }
                    spacing: Theme.s5

                    // Hairline chips, no Pane. Pane runs pane.frag (rim + bloom)
                    // even at fill-alpha 0, which reads as a layout frame on
                    // the photograph. Low battery is the one state colour.
                    Rectangle {
                        visible: netText.text !== ""
                        width: netText.implicitWidth + Theme.s6 * 2
                        height: netText.implicitHeight + Theme.s5
                        radius: height / 2
                        color: "transparent"
                        border.width: 1
                        border.color: lock.seamStructural
                        Text {
                            id: netText
                            anchors.centerIn: parent
                            text: chrome.net.toUpperCase()
                            color: chrome.net === "offline" ? Theme.textDim : Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tLabel
                            font.weight: Theme.wLabel
                            font.letterSpacing: Theme.trackMicro
                        }
                    }
                    Rectangle {
                        visible: batText.text !== ""
                        width: batText.implicitWidth + Theme.s6 * 2
                        height: batText.implicitHeight + Theme.s5
                        radius: height / 2
                        color: "transparent"
                        border.width: 1
                        border.color: chrome.batteryLow ? lock.stateInvalid
                                                        : lock.seamStructural
                        Text {
                            id: batText
                            anchors.centerIn: parent
                            text: chrome.battery
                            color: chrome.batteryLow ? Theme.danger : Theme.textMuted
                            font.family: Theme.fNum
                            font.pixelSize: Theme.tLabel
                            font.letterSpacing: Theme.trackMicro
                        }
                    }
                }

                // Battery and network: one spawn a minute, pure reads. Both
                // render EMPTY on a desktop rather than lying about a battery
                // that is not there.
                QtObject {
                    id: chrome
                    property string battery: ""
                    property string net: ""
                    property bool batteryLow: false
                }
                Process {
                    id: chromeRead
                    command: ["sh", "-c",
                        "b=/sys/class/power_supply/BAT0; " +
                        "[ -d \"$b\" ] || b=/sys/class/power_supply/BAT1; " +
                        "if [ -r \"$b/capacity\" ]; then " +
                        "  printf '%s %s\\n' \"$(cat $b/capacity)\" \"$(cat $b/status 2>/dev/null)\"; " +
                        "else printf '\\n'; fi; " +
                        "ip route get 1.1.1.1 >/dev/null 2>&1 && printf 'online\\n' || printf 'offline\\n'"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            const p = text.split("\n");
                            const b = (p[0] || "").trim().split(" ");
                            if (b[0] && b[0] !== "") {
                                const pct = parseInt(b[0], 10);
                                // No emoji, by voice-spec §0 rule 2 — the ⚡
                                // that used to lead this string is a picture
                                // doing a word's job. `hyprlock.conf`'s battery
                                // label already spells it, so this matches it
                                // rather than inventing a second vocabulary.
                                chrome.battery = pct + "%"
                                    + (b[1] === "Charging" ? " · CHARGING" : "");
                                chrome.batteryLow = !isNaN(pct) && pct <= 15 && b[1] !== "Charging";
                            } else {
                                chrome.battery = "";
                            }
                            chrome.net = (p[1] || "").trim();
                        }
                    }
                }
                Timer {
                    running: lock.locked
                    interval: 60000; repeat: true; triggeredOnStart: true
                    onTriggered: chromeRead.running = true
                }

                // ── THE SLAB ─────────────────────────────────────────────
                // One wide pane split by a seam: the world on the left, you on
                // the right. This IS the design, and it is not the old one —
                // the previous lock was a column of centred labels with eight
                // corner widgets scattered around it.
                // ── the stack ────────────────────────────────────────────
                // The slab, then what is playing, then what came in. One
                // centred column so the three surfaces read as one object
                // rather than as widgets scattered on a photograph — which is
                // exactly what the owner rejected about the old lock.
                //
                // The entrance animation lives HERE, not on the slab, so the
                // whole column rises together. WIP-415.
                Column {
                    id: stack

                    // ── THE STACK IS WHAT MOVES, NOT THE SLAB ────────────
                    // This was `anchors.centerIn: parent` with a 960 cap, and
                    // that cap is why the first attempt at keeping the text off
                    // the planet failed on hardware. The slab was told to sit
                    // on the free side — but "the free side" was measured
                    // against THIS column, a 960-wide box parked in the middle
                    // of a 1920 screen. Moving the text to the right of a
                    // centred box still leaves it over a globe that reaches
                    // past the middle. The owner photographed the result: his
                    // clock sitting on the Earth's limb.
                    //
                    // So the geometry belongs here, in screen space, measured
                    // against the surface. Everything inside goes back to
                    // being a plain full-width child.
                    // ── THE LOGIN WINS THE ARGUMENT ──────────────────────
                    // Checked across three panel sizes and all nine size/side
                    // combinations: every one clears the globe except
                    // 1366x768 at Large + Centre, where the column's 360 px
                    // floor — the width a password field actually needs —
                    // forces it 54 px into the planet.
                    //
                    // Something has to give and it is not the password field.
                    // This caps the globe so the column always fits beside it:
                    // on a small panel the largest centred Earth comes out a
                    // little smaller rather than with a login sitting on it. At
                    // 1920x1080 and above nothing is capped and the chosen size
                    // is the size.
                    //
                    // ⚠ It lives HERE, not on the root. The root Item of this
                    // file is not sized to anything — it holds the
                    // WlSessionLock component and its width is 0 — so a cap
                    // written there silently never applies. Only the surface
                    // knows how big the screen is.
                    readonly property real earthNeed:
                        (360 + Theme.s6 * 7) / Math.max(page.width, 1)
                    readonly property real earthMaxHalf:
                        (Prefs.lockEarthSide === "centre" ? 0.5 : 0.7) - earthNeed
                    readonly property real earthFitSize: {
                        const px = Math.min(page.width, page.height);
                        if (px <= 0 || page.width <= 0) return lock.earthSize;
                        return Math.min(lock.earthSize,
                                        Math.max(0.25, earthMaxHalf * 2 * page.width / px));
                    }
                    readonly property real earthHalf:
                        (earthFitSize * 0.5 * Math.min(page.width, page.height)) / page.width
                    readonly property real freeFrac:
                        lock.earthOnRight ? (lock.earthCentreX - earthHalf)
                                          : (1.0 - (lock.earthCentreX + earthHalf))

                    anchors.verticalCenter: parent.verticalCenter
                    // In Earthrise the lunar ground owns the bottom third, so
                    // the column lifts clear of the horizon instead of standing
                    // in the regolith.
                    anchors.verticalCenterOffset: lock.earthrise ? -page.height * 0.12 : 0
                    anchors.horizontalCenter: lock.showEarth ? undefined : parent.horizontalCenter
                    anchors.left:  (lock.showEarth && lock.earthOnRight) ? parent.left : undefined
                    anchors.right: (lock.showEarth && !lock.earthOnRight) ? parent.right : undefined
                    anchors.leftMargin:  Theme.s6 * 2
                    anchors.rightMargin: Theme.s6 * 2

                    // The 0.42 cap RESERVES SKY. Without it the column expands
                    // to fill every pixel the globe leaves, and then the Moon
                    // has nowhere to be except behind the planet — a feature
                    // that is never visible is not a feature. 0.42 of the width
                    // still gives the login its full 360 px and leaves a strip
                    // of open sky between the limb and the text for the Moon to
                    // rise through.
                    width: lock.showEarth
                         ? Math.min(960, page.width * 0.42,
                                    Math.max(360, page.width * freeFrac - Theme.s6 * 5))
                         : Math.min(parent.width - Theme.s6 * 8, 960)
                    spacing: Theme.s5

                    // Comes up WITH the surface rather than snapping in. The
                    // old lock appeared between frames, which is part of why it
                    // read as a flash rather than a screen.
                    opacity: page.shown ? 1 : 0
                    scale: page.shown ? 1 : 0.985
                    Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    Behavior on scale   { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                Item {
                    id: slab

                    // ── STAY OFF THE PLANET (owner, 2026-08-23) ──────────
                    // "the login card and what not are on the earth image".
                    // They were: this slab spanned the whole width, and with
                    // the Earth on the left at Large the clock sat straight on
                    // top of it.
                    //
                    // The fix is deliberately the SMALLEST one that works. The
                    // slab keeps every child, every proportion and the login's
                    // alignment to the clock digits — the detail the owner
                    // ruled on in August — and simply gets narrower and moves
                    // to the side the planet is not on. Nothing inside changes,
                    // so with the Earth OFF this is bit-for-bit the lock he
                    // already had.
                    //
                    // The width is COMPUTED from where the globe's edge
                    // actually falls, not guessed, so it stays clear by itself
                    // when the size setting changes: Small leaves more room and
                    // the text simply gets it back. `earthEdge` is the globe's
                    // radius in screen-width units — the shader sizes the
                    // radius off the SHORT edge, which is why height comes into
                    // a horizontal measurement.
                    readonly property real earthEdge:
                        (lock.earthSize * 0.5 * Math.min(page.width, page.height)) / page.width
                    readonly property real freeSide:
                        lock.earthOnRight ? (lock.earthCentreX - earthEdge)
                                          : (1.0 - (lock.earthCentreX + earthEdge))

                    // The stack above already sits in the free space, so this
                    // is simply as wide as it is.
                    width: parent.width

                    // ── STACKED, NOT SIDE BY SIDE, WHEN THE EARTH IS ON ──
                    // Owner, on hardware: "the box where you put your password
                    // in at is almost not there now it's tiny". It was. Side by
                    // side, the login cell got 44% of an already narrow column
                    // — about 225 px at the largest Earth — and a password
                    // field is not a thing to shave. Stacked, both get the FULL
                    // column, which is the composition he approved in the web
                    // preview anyway. With the Earth off, nothing here changes.
                    //
                    // ⚠ DERIVED, not 470, since 2026-09-01. The old pair of
                    // constants split the slab 62/38, which gave the login
                    // cell 179 px — enough for a bare 44 px field and its two
                    // floating labels, and 68 px short of the card that
                    // replaced them. A fixed height would have clipped the
                    // owner's new login the moment it grew, and it would have
                    // gone on doing it silently. Now the clock block asks for
                    // exactly what it needs and the card asks for exactly what
                    // it needs, and the slab is the sum plus its three gaps.
                    // Nothing here can be out of date again.
                    //
                    // With the Earth OFF the two cells still sit side by side
                    // and 336 still holds the taller of them, so that path is
                    // bit-for-bit what it was.
                    height: lock.showEarth
                          ? Theme.s6 * 2 + worldCell.height
                            + Theme.s6 * 2 + youCell.height + Theme.s6 * 2
                          : 336

                    // Owner 2026-08-19: the photograph is the lock. A Pane
                    // here would still run pane.frag (rim + bloom) over the
                    // picture — the same class as a GlassEdge veil, even at
                    // fill alpha 0. Clock / date / weather stay in worldCell.
                    // No GlassEdge. No surfaceDeep.

                    // ── left cell · the world ────────────────────────────
                    Item {
                        id: worldCell
                        anchors {
                            left: parent.left
                            top: parent.top
                            // Stacked with the Earth on: the clock takes the
                            // top of the slab and the login gets the rest.
                            bottom: lock.showEarth ? undefined : parent.bottom
                        }
                        anchors.margins: Theme.s6 * 2
                        width: lock.showEarth ? parent.width - Theme.s6 * 4
                                              : parent.width * 0.56
                        // Its own content, not a fraction of the slab — the
                        // slab is now derived FROM this, so a fraction here
                        // would be a loop. `implicitHeight`, never `height`,
                        // for the same reason.
                        height: lock.showEarth ? worldCol.implicitHeight
                                               : undefined

                        Column {
                            id: worldCol
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            spacing: Theme.s4

                            Text {
                                id: clockFace
                                // TRK-3725 · honours the 12/24h setting. See
                                // Screensaver.qml: both big faces were hardcoded
                                // to 24-hour, so the Settings toggle looked dead
                                // on the two screens the owner actually stares at.
                                text: Qt.formatDateTime(clockSource.date,
                                                        Prefs.timeFmt)
                                color: Theme.text
                                // The build's one time face. Theme.qml's own
                                // role map names this exact string as fTech's
                                // home ("The BIG readouts only — a lock-screen
                                // clock"), and Bar.qml's clock records the
                                // ruling: all the build's timepieces speak
                                // with one voice. This was the last one still
                                // in the title face.
                                font.family: Theme.fTech
                                // Not a Theme token, on purpose: Theme's type
                                // scale tops out at 30 px because it describes
                                // shell CHROME. A lock clock is not chrome, and
                                // borrowing tDisplay for it would either wreck
                                // this screen or inflate the scale for every
                                // bar in the build.
                                font.pixelSize: 112

                                // ── only ever SHRINKS, and only with the Earth on
                                // Measured at 1920x1080: "22:27" in Orbitron at
                                // 112 px is 377 px wide. The column the text
                                // moves into to clear the planet is 410 px at
                                // the Large size, so 112 stands — but at
                                // Cropped the column falls to about 295 px and
                                // the clock would be cut off mid-digit.
                                //
                                // HorizontalFit steps the size down only when
                                // it will not fit, so at every size that has
                                // room this is byte-for-byte the 112 px face
                                // the owner ruled on, and with the Earth OFF
                                // the fit is not applied at all.
                                width: lock.showEarth ? worldCell.width - Theme.s6 * 2
                                                      : implicitWidth
                                fontSizeMode: lock.showEarth ? Text.HorizontalFit
                                                             : Text.FixedSize
                                minimumPixelSize: 64
                                font.weight: Font.DemiBold
                                // Orbitron is already wide; the title face's
                                // -3 crush was compensating for Inter Display's
                                // looseness at this size and would ligature
                                // Orbitron's digits into each other.
                                font.letterSpacing: 0
                            }
                            Text {
                                text: Qt.formatDateTime(clockSource.date, "dddd d MMMM").toLowerCase()
                                color: Theme.textMuted
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tTitle
                            }

                            Item { width: 1; height: Theme.s5 }

                            // The weather cluster reads the SAME object the sky
                            // is drawing from, so the picture and the words can
                            // never disagree.
                            Row {
                                spacing: Theme.s5
                                visible: weather.hasData
                                Text {
                                    text: weather.big
                                    color: Theme.text
                                    font.family: Theme.fNum
                                    font.pixelSize: 30
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.s1
                                    Text {
                                        text: weather.line
                                        color: Theme.textMuted
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tBody
                                    }
                                    Text {
                                        text: weather.sub
                                        color: Theme.textDim
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tCaption
                                    }
                                }
                            }
                            Text {
                                visible: !weather.hasData
                                text: qsTr("weather arrives with the network")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                            }
                        }
                    }

                    // No divider between clock and Login. A sweepAt gradient
                    // here was a second chrome language on the photograph
                    // (and a per-lock animation on the surface that has to
                    // take a password). The clock and the field share a
                    // horizon instead.

                    // ── right cell · you · THE LOGIN CARD ─────────────────
                    // Same furniture as the desktop cards: SetSlab's
                    // Theme.panelMid + swellGround + GlassEdge body 0 + 1 px
                    // glacier[4] seam. `body: 1` is WIP-259 (dark box).
                    // glacier[0] is a hairline, never a fill; glacier[5] is
                    // identity only; magma is a refused password only.
                    //
                    // ⚠ `level: 1`, NOT 2. Elevation 2 runs pane.frag's outer
                    // bloom (`Theme.e2Bloom`, 20 px) whose last stop is the
                    // signature sweep `#891955`. Weight comes from `lifted`.
                    //
                    // worldCell (clock / date / weather) stays bare on the
                    // sky. Only the thing that takes a password is an object.
                    Item {
                        id: youCell
                        anchors {
                            left: lock.showEarth ? parent.left : worldCell.right
                            right: parent.right
                            leftMargin: Theme.s6 * 2
                            rightMargin: Theme.s6 * 2
                        }
                        // The cell is the card plus the one reserved line
                        // under it. Stacked (Earth on) it
                        // hangs under the clock block; side by side (Earth off)
                        // it keeps the August ruling that the login shares the
                        // CLOCK DIGITS' vertical centre — not the column's,
                        // which would drop it half a clock too low.
                        height: card.height + Theme.s5 + 16
                        y: {
                            if (lock.showEarth)
                                return Math.round(worldCell.y + worldCell.height
                                                  + Theme.s6 * 2);
                            // Dependencies, not decoration: mapToItem is a
                            // function call and QML cannot see through it, so
                            // the values it depends on are read here to make
                            // this re-run after layout. Same trick the old
                            // fieldPane used, and the same reason.
                            const _ = clockFace.y + clockFace.height
                                    + worldCol.y + worldCell.height;
                            if (clockFace.height <= 0)
                                return Math.round((slab.height - youCell.height) / 2);
                            const mid = clockFace.mapToItem(slab, 0,
                                                            clockFace.height / 2);
                            return Math.round(Math.max(0,
                                Math.min(slab.height - youCell.height,
                                         mid.y - youCell.height / 2)));
                        }

                        SetSlab {
                            id: card
                            width: Math.min(youCell.width, 400)
                            height: cardCol.implicitHeight + Theme.s7 * 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            // ── TRK-3707 · SHARPER, and it is the corner ──
                            // Owner, 2026-09-01: "i need something stronger
                            // meaner cleaner and sharper". `Theme.r3` is 22 px
                            // — the pill radius this build spends on chips and
                            // capsules — and at 400 px wide it rounded the card
                            // into a lozenge. `r2` is 14, the radius every
                            // SetSlab in the product defaults to, so the login
                            // card now cuts the same corner as the Settings
                            // body, `SetCard` and the toasts instead of a
                            // softer one of its own. It also re-reads the
                            // nesting: 14 outside, `r1` 8 on the field and the
                            // action inside it, which is a legible ratio. 22
                            // outside and 8 inside was not.
                            cornerRadius: Theme.r2
                            level: 1
                            seam: true
                            // Focus is LIGHT. The whole card answers the
                            // caret, so the surface being typed into is the
                            // one that brightens.
                            lifted: pwd.activeFocus || fieldHover.containsMouse

                            // ── TRK-3707 · THE HEAD BAND ─────────────────
                            // STRONGER, and bought the way this build is
                            // allowed to buy it. The card was four rounded
                            // shapes of equal weight stacked in a column —
                            // disc row, hairline, field, action — so nothing
                            // on it dominated anything else. That flatness is
                            // what reads as plain.
                            //
                            // Depth here comes from LAYERING, never from
                            // brightness: the identity row now sits in a
                            // RECESS. `Theme.void_` #020506 is the build's
                            // deepest ground and it is DARKER than the slab
                            // it sits in, so the head is cut INTO the card
                            // rather than lit on top of it. The matte-black
                            // floor goes down, not up — the same reason the
                            // sigil work refused a brightness lift today.
                            // The account name gains contrast for free,
                            // because its bed got darker.
                            //
                            // Full-bleed, not inset: an inset plate would be
                            // a fifth rounded rectangle, which is the disease
                            // and not the cure. The clip is what squares the
                            // band's bottom corners while its top two still
                            // follow the card's — a rounded child extended
                            // past the clip is cheaper and exact, where two
                            // stacked translucent rectangles would
                            // double-darken their overlap.
                            Item {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                }
                                // The seam IS the band's floor, so the band is
                                // exactly as tall as the head content above it.
                                // Derived from the two live y values rather
                                // than a constant: a longer login name, a
                                // bigger disc or a changed gap all move it by
                                // themselves. A number here would go stale the
                                // first time anything above it changed, and it
                                // would go stale silently.
                                height: cardCol.y + headSeam.y
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.bottomMargin: -card.cornerRadius
                                    radius: card.cornerRadius
                                    color: Theme.soften(Theme.void_, 0.55)
                                }
                            }

                            Column {
                                id: cardCol
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: Theme.s7
                                    rightMargin: Theme.s7
                                }
                                spacing: Theme.s5

                                // ── who ──────────────────────────────────
                                // The identity block the rest of the build
                                // already uses (SetHubDock, Launcher, Settings
                                // Account): an ice disc carrying the account's
                                // initials, the login name, and the machine's
                                // own name under it. A lock screen that cannot
                                // say whose machine it is guarding is a login
                                // prompt; this one names him before he types.
                                //
                                // Initials, not `~/.face`. Every other host of
                                // this block draws the photo into a SQUARE and
                                // puts a rounded border over it, which at a
                                // 52 px disc would be a circle drawn on a
                                // rectangle. Masking it properly needs
                                // QtQuick.Effects, and a new import plus a
                                // MultiEffect layer is not something to add to
                                // a lock screen for an avatar. The initial is
                                // the same fallback those files already ship.
                                Row {
                                    width: parent.width
                                    spacing: Theme.s5

                                    Rectangle {
                                        id: faceDisc
                                        width: 52
                                        height: 52
                                        radius: 26
                                        anchors.verticalCenter: parent.verticalCenter
                                        // glacier[5] is identity. glacier[0]
                                        // is not a fill on this card.
                                        color: Theme.soften(lock.icePrimary, 0.18)
                                        border.width: 1
                                        border.color: Theme.soften(lock.iceHairline, 0.70)
                                        antialiasing: true

                                        Text {
                                            anchors.centerIn: parent
                                            text: lock.initialsOf(lock.userName)
                                            color: lock.icePrimary
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tTitle
                                            font.weight: Font.DemiBold
                                            renderType: Theme.textRender
                                            font.hintingPreference: Theme.textHint
                                        }
                                        StatusPip {
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 3
                                            kind: lock.authError ? "magma" : "ice"
                                            pulse: lock.busy || lock.authError
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - faceDisc.width - Theme.s5
                                        spacing: Theme.s1

                                        Text {
                                            width: parent.width
                                            text: lock.userName
                                            color: Theme.text
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tTitle
                                            font.weight: Font.DemiBold
                                            font.letterSpacing: Theme.trackTitle
                                            renderType: Theme.textRender
                                            font.hintingPreference: Theme.textHint
                                            elide: Text.ElideRight
                                        }
                                        // Hostname from /etc/hostname as a
                                        // FILE, not a process — same rule as
                                        // caps lock. Nothing on this surface
                                        // spawns per frame.
                                        Text {
                                            width: parent.width
                                            visible: lock.hostName !== ""
                                            text: lock.hostName.toUpperCase()
                                            color: Theme.textDim
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tMicro
                                            font.letterSpacing: Theme.trackMicro
                                            renderType: Theme.textRender
                                            font.hintingPreference: Theme.textHint
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                // The card's one internal seam. glacier[4] is
                                // the rung whose own token says hairlines
                                // only, never a fill — this is the role it
                                // exists for.
                                Rectangle {
                                    id: headSeam
                                    width: parent.width
                                    height: 1
                                    color: Theme.soften(lock.iceHairline, 0.60)

                                    // ── TRK-3707 · THE MARK ──────────────
                                    // The one bright thing on the card, and
                                    // the ONLY place it spends the pale end
                                    // of the ramp. 44 px of glacier[6]
                                    // #eefcff at 2 px, sitting ON the seam at
                                    // its left end, where the identity block
                                    // above it starts.
                                    //
                                    // MEANER is a hard edge, not more colour.
                                    // 44 x 2 = 88 px^2 on a card of roughly
                                    // 400 x 210 = 84,000, i.e. 0.10% of the
                                    // surface. It cannot lift the black floor
                                    // and it cannot cost the type any
                                    // legibility; what it does is give the
                                    // eye one deliberate, unmistakably
                                    // straight thing to land on.
                                    //
                                    // This is the card's SECOND accent site
                                    // and its last. The first is the field's
                                    // focus hairline. Nothing else on this
                                    // surface is allowed to be brighter than
                                    // its own text.
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 44
                                        height: 2
                                        color: lock.iceMark
                                        antialiasing: true
                                    }
                                }

                                // ── the field ────────────────────────────
                                // Hairline only. Rest is glacier[4]; focus is
                                // glacier[0] as a 1 px edge, never a fill.
                                // Magma is a refused password. 56 px / tTitle
                                // so the box stays readable when the Earth
                                // stacks the column.
                                Item {
                                    width: parent.width
                                    height: 56

                                    Rectangle {
                                        id: fieldPane
                                        anchors.fill: parent
                                        radius: Theme.r1
                                        color: Theme.soften(Theme.void_, 0.46)

                                        readonly property bool disabled: lock.busy
                                        readonly property bool invalid:  lock.authError
                                        readonly property bool hovered:  fieldHover.containsMouse
                                                                         && !fieldPane.disabled
                                        readonly property bool focused:  pwd.activeFocus
                                                                         && !fieldPane.disabled

                                        border.width: 1
                                        border.color: fieldPane.disabled ? lock.seamStructural
                                                    : fieldPane.invalid  ? lock.magmaPrimary
                                                    : fieldPane.focused  ? lock.stateFocus
                                                    : fieldPane.hovered  ? Theme.soften(lock.iceHairline, 0.90)
                                                                         : Theme.soften(lock.iceHairline, 0.65)
                                        Behavior on border.color {
                                            ColorAnimation { duration: Theme.durQuick }
                                        }

                                        MouseArea {
                                            id: fieldHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                        }

                                        // The alien glyph track, carried over
                                        // from the greeter so both screens
                                        // behave the same way. It only DRAWS —
                                        // the value stays in the real password
                                        // field below, and the glyphs are minted
                                        // at random per keystroke, never derived
                                        // from what was typed. See GlyphTrack.qml
                                        // for why that distinction is the whole
                                        // point rather than a detail.
                                        GlyphTrack {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: Theme.s6
                                            anchors.rightMargin: reveal.width + Theme.s6
                                            visible: !reveal.checked
                                            count: pwd.text.length
                                            alarmed: lock.authError
                                            glyphSize: Theme.tTitle
                                            glyphColor: pwd.activeFocus
                                                        ? Theme.text
                                                        : Theme.textDim
                                        }

                                        TextInput {
                                            id: pwd
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            anchors.leftMargin: Theme.s6
                                            anchors.rightMargin: reveal.width + Theme.s6
                                            verticalAlignment: TextInput.AlignVCenter
                                            echoMode: reveal.checked ? TextInput.Normal
                                                                     : TextInput.Password
                                            passwordCharacter: "•"
                                            // Transparent while the glyphs are
                                            // drawing; real colour when Show is
                                            // on, so that toggle still works.
                                            color: reveal.checked ? Theme.text
                                                                  : "transparent"
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tTitle
                                            font.hintingPreference: Theme.textHint
                                            renderType: Theme.textRender
                                            selectByMouse: true
                                            clip: true
                                            enabled: !lock.busy
                                            focus: true
                                            cursorVisible: pwd.activeFocus && !lock.busy
                                            cursorDelegate: Rectangle {
                                                width: 1
                                                color: lock.iceInteractive
                                            }

                                            // Empty-state copy. QtQuick.TextInput
                                            // has no placeholderTextColor (qs
                                            // 18:14: Type Lock unavailable).
                                            // Settings search uses the same
                                            // child Text; `color` is the valid
                                            // property.
                                            //
                                            // ⚠ STAYS "Login", and this was
                                            // changed to "Password" and put
                                            // back. With the card now naming
                                            // the account above the field,
                                            // "Password" is the better copy —
                                            // but `verify-profile` gate `13uv`
                                            // check 5 greps this file for the
                                            // literal string `"Login"`, and it
                                            // went RED on the rename. Changing
                                            // a shipped gate's assertion to
                                            // match a taste call of my own is
                                            // the failure `AGENTS.md` records
                                            // under "a gate must assert the
                                            // CURRENT ruling" — there is no
                                            // ruling here, only a preference.
                                            // If the owner wants "Password",
                                            // 13uv check 5 gets migrated to
                                            // assert the PROPERTY (an
                                            // empty-state child Text that
                                            // hides on `pwd.text.length === 0`)
                                            // instead of the word, and both
                                            // move together.
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: pwd.text.length === 0
                                                text: qsTr("Login")
                                                color: Theme.textMuted
                                                font.family: Theme.fUi
                                                font.pixelSize: Theme.tTitle
                                                renderType: Theme.textRender
                                                font.hintingPreference: Theme.textHint
                                            }

                                            onTextChanged: {
                                                lock.secret = text;
                                                if (lock.authError) {
                                                    lock.authError = false;
                                                    lock.authMessage = "";
                                                }
                                            }
                                            onAccepted: lock.submit()
                                        }

                                        Text {
                                            id: capsMark
                                            visible: lock.capsOn
                                            anchors {
                                                right: reveal.left
                                                rightMargin: Theme.s4
                                                verticalCenter: parent.verticalCenter
                                            }
                                            text: qsTr("CAPS")
                                            color: Theme.goldGlow
                                            font.family: Theme.fNum
                                            font.pixelSize: Theme.tCaption
                                            font.letterSpacing: Theme.trackMicro
                                            renderType: Theme.textRender
                                            font.hintingPreference: Theme.textHint
                                        }

                                        // Reveal is a word, not a second pill
                                        // inside the box. Colour only on
                                        // hover / focus / on — same two rungs
                                        // as TogglePill.
                                        Item {
                                            id: reveal
                                            property bool checked: false
                                            readonly property bool disabled: lock.busy
                                            readonly property bool hovered: revealArea.containsMouse
                                                                            && !reveal.disabled
                                            readonly property bool pressed: revealArea.pressed
                                                                            && !reveal.disabled
                                            readonly property bool focused: reveal.activeFocus
                                                                            && !reveal.disabled

                                            width: revealLabel.implicitWidth + Theme.s5 * 2
                                            height: 26
                                            anchors {
                                                right: parent.right
                                                rightMargin: Theme.s4
                                                verticalCenter: parent.verticalCenter
                                            }
                                            enabled: !reveal.disabled
                                            activeFocusOnTab: true

                                            function toggle(): void {
                                                if (reveal.disabled) return;
                                                reveal.checked = !reveal.checked;
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: Theme.r1
                                                color: "transparent"
                                                border.width: 1
                                                border.color: reveal.focused ? lock.stateFocus
                                                                             : "transparent"
                                            }

                                            Text {
                                                id: revealLabel
                                                anchors.centerIn: parent
                                                text: reveal.checked ? qsTr("hide")
                                                                     : qsTr("show")
                                                color: reveal.disabled ? Theme.textDim
                                                     : reveal.checked ? Theme.text
                                                     : (reveal.hovered || reveal.focused)
                                                       ? lock.stateFocus
                                                       : Theme.textMuted
                                                font.family: Theme.fUi
                                                font.pixelSize: Theme.tCaption
                                                renderType: Theme.textRender
                                                font.hintingPreference: Theme.textHint
                                                Behavior on color {
                                                    ColorAnimation { duration: Theme.durQuick }
                                                }
                                            }

                                            MouseArea {
                                                id: revealArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: !reveal.disabled
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    reveal.toggle();
                                                    pwd.forceActiveFocus();
                                                }
                                            }

                                            Keys.onPressed: (event) => {
                                                if (event.key === Qt.Key_Space
                                                    || event.key === Qt.Key_Return
                                                    || event.key === Qt.Key_Enter) {
                                                    reveal.toggle();
                                                    event.accepted = true;
                                                    return;
                                                }
                                                if (event.text.length === 1
                                                    && event.text.charCodeAt(0) >= 0x20) {
                                                    pwd.forceActiveFocus();
                                                    pwd.insert(pwd.length, event.text);
                                                    event.accepted = true;
                                                }
                                            }
                                        }
                                    }

                                    // Focus-visible outer contour: 1 px out,
                                    // glacier[0] hairline. Invalid is magma
                                    // so a refused password is a different
                                    // family, not a brighter ice.
                                    Rectangle {
                                        anchors.fill: fieldPane
                                        anchors.margins: -1
                                        radius: Theme.r1 + 1
                                        color: "transparent"
                                        visible: (fieldPane.focused || fieldPane.invalid)
                                                 && !fieldPane.disabled
                                        border.width: 1
                                        border.color: fieldPane.invalid
                                            ? Theme.soften(lock.magmaPrimary, 0.55)
                                            : Theme.soften(lock.stateFocus, 0.55)
                                    }
                                }

                                // ── the action ───────────────────────────
                                // Same rest as SetButton: void@0.34 + glacier[4]
                                // seam. Armed takes tokenAccentGround (the
                                // desktop primary), never a glacier[0] fill.
                                Item {
                                    id: unlockBtn
                                    width: parent.width
                                    height: 48
                                    activeFocusOnTab: true
                                    readonly property bool armed: lock.secret !== ""
                                                                  && !lock.busy
                                    readonly property bool hovered: unlockArea.containsMouse
                                                                    && unlockBtn.armed
                                    readonly property bool pressed: unlockArea.pressed
                                                                    && unlockBtn.armed

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.r1
                                        color: !unlockBtn.armed
                                                 ? Theme.soften(Theme.void_, 0.34)
                                             : unlockBtn.pressed
                                                 ? Theme.soften(Theme.tokenAccentDeep, 0.55)
                                                 : Theme.tokenAccentGround
                                        border.width: 1
                                        border.color: !unlockBtn.armed
                                                        ? Theme.soften(lock.iceHairline,
                                                                       0.65)
                                                    : (unlockBtn.hovered
                                                       || unlockBtn.activeFocus)
                                                        ? lock.stateFocus
                                                        : Theme.soften(lock.iceHairline,
                                                                       0.85)
                                        Behavior on color {
                                            ColorAnimation { duration: Theme.durQuick }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation { duration: Theme.durQuick }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: lock.busy ? qsTr("CHECKING")
                                                        : qsTr("UNLOCK")
                                        color: lock.busy ? Theme.textDim
                                             : unlockBtn.armed ? Theme.text
                                                               : Theme.textMuted
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tLabel
                                        font.weight: Theme.wLabel
                                        font.letterSpacing: Theme.trackMicro
                                        renderType: Theme.textRender
                                        font.hintingPreference: Theme.textHint
                                    }

                                    MouseArea {
                                        id: unlockArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: unlockBtn.armed
                                            ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (unlockBtn.armed) lock.submit();
                                            else pwd.forceActiveFocus();
                                        }
                                    }

                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Space
                                            || event.key === Qt.Key_Return
                                            || event.key === Qt.Key_Enter) {
                                            if (unlockBtn.armed) lock.submit();
                                            event.accepted = true;
                                            return;
                                        }
                                        if (event.text.length === 1
                                            && event.text.charCodeAt(0) >= 0x20) {
                                            pwd.forceActiveFocus();
                                            pwd.insert(pwd.length, event.text);
                                            event.accepted = true;
                                        }
                                    }
                                }

                            }
                        }

                        // ── what PAM said ────────────────────────────────
                        // OUTSIDE the card, and reserved. Both halves of that
                        // are deliberate.
                        //
                        // RESERVED, because a line that appears and disappears
                        // resizes the card — and this card's height feeds the
                        // slab's, so a refusal would reflow the whole column
                        // under the hands that are typing. Nothing on a lock
                        // screen may move while someone is entering a password.
                        //
                        // OUTSIDE, because reserving it INSIDE left 48 px of
                        // dead band under the button against 20 px of padding
                        // above the disc — measured on the first cut of this
                        // card. A card with one end twice as padded as the
                        // other does not read as strong, it reads as
                        // unfinished. Out here the card closes tight on its
                        // own content and the space is simply the gap before
                        // the notifications, which the column already has.
                        Item {
                            width: card.width
                            height: 16
                            anchors.top: card.bottom
                            anchors.topMargin: Theme.s5
                            anchors.horizontalCenter: card.horizontalCenter
                            Text {
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: lock.authMessage
                                color: lock.authError ? lock.magmaPrimary
                                                      : Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                renderType: Theme.textRender
                                font.hintingPreference: Theme.textHint
                            }
                        }
                    }
                }

                    // ── what is playing ──────────────────────────────────
                    // Seeing it is unconditional; CONTROLLING it pre-auth is a
                    // setting that ships OFF. LockMedia.qml carries the whole
                    // argument for why that split is where it is.
                    LockMedia {
                        id: lockMedia
                        width: parent.width
                        active: lock.locked
                        visible: hasMedia
                        // A Column gives a zero-height child no spacing only if
                        // it is invisible, so this must be `visible`, not an
                        // opacity fade — otherwise the gap stays behind when
                        // nothing is playing.
                        height: visible ? implicitHeight : 0
                    }

                    // ── what came in ─────────────────────────────────────
                    // Names without bodies by default. LockNotes.qml carries
                    // the reasoning and reads the two keys that already had a
                    // settings page and no reader.
                    // ── NOTIFICATIONS SIT UNDER THE LOGIN (owner, 2026-08-23)
                    // "the notification ... overlap the image so make them
                    // smaller and have them show up somewhere underneath the
                    // login area."
                    //
                    // They used to be `width: parent.width`, i.e. the full
                    // screen, so a toast arriving while the lock was up drew a
                    // band straight across the planet. Now they take the same
                    // column the clock and login occupy and align to its right
                    // edge, which is where the login box is — so a notification
                    // lands under the thing you are already looking at, and
                    // never on the picture.
                    //
                    // Capped at the login card's width as well as by the
                    // column, because on a wide screen "as wide as the column"
                    // is still a banner.
                    LockNotes {
                        id: lockNotes
                        // ── AND THEY LINE UP WITH IT (2026-09-01) ────────
                        // They were 420 px wide and pinned to the slab's RIGHT
                        // edge while the login sat centred in its own cell.
                        // Measured on `docs/proof/lock-0901/before-lock.png`
                        // (1920x1200): the password field runs x 1304..1665 and
                        // the notification stack x 1434..1855 — its left edge
                        // 130 px inboard of the field's, its right edge 190 px
                        // outboard. Nothing in that column shared an edge with
                        // anything else, and a column whose edges disagree is
                        // most of what reads as "off".
                        //
                        // The owner's instruction was that they "show up
                        // somewhere underneath the login area". Underneath
                        // means underneath, so these take the login card's OWN
                        // width and its OWN x — tracked, not repeated, so
                        // changing the card moves the notifications with it and
                        // no second number can go stale.
                        width: card.width
                        x: slab.x + youCell.x + card.x
                        active: lock.locked
                        visible: hasNotes
                        height: visible ? implicitHeight : 0
                    }
                }

                // The build's own voice, low and quiet — the one piece of the
                // old lock this screen keeps, because it is the only part of it
                // that was never chrome.
                Text {
                    anchors {
                        bottom: parent.bottom
                        horizontalCenter: parent.horizontalCenter
                        bottomMargin: Theme.s6 * 3
                    }
                    text: dailyLine.line
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.letterSpacing: Theme.trackMicro
                    opacity: 0.75
                }
                QtObject { id: dailyLine; property string line: "" }
                Process {
                    id: dailyRead
                    command: ["nyxus-lock-weather", "header"]
                    stdout: StdioCollector { onStreamFinished: dailyLine.line = text.trim() }
                }
                Timer {
                    running: lock.locked
                    interval: 600000; repeat: true; triggeredOnStart: true
                    onTriggered: dailyRead.running = true
                }

                // Start typing at a locked screen without hunting for the box.
                //
                // ⚠ TAB IS EXEMPT, and it has to be. This handler fires for keys
                //   the focused item declined, so before the exemption it
                //   yanked focus back to the password field on the very Tab that
                //   was trying to leave it — which is why the reveal control had
                //   no reachable focus-visible state and why adding one without
                //   touching this handler would have looked like it worked while
                //   being unreachable. `reveal` handles its own printable keys
                //   and hands them here, so no character is lost either way.
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                        return;
                    if (!pwd.activeFocus && !reveal.activeFocus)
                        pwd.forceActiveFocus();
                }

                Component.onCompleted: {
                    pwd.forceActiveFocus();
                    page.shown = true;
                }
            }
        }
    }
}
