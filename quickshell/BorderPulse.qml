// Nyxus Suxyn — BorderPulse. Hyprland's own border, a slow glacier glow.
//
// Owner 11:29: forget music. Keep the glow around the borders. Slow fade
// lighter glacier → darker glacier. This is NOT a surface. It rewrites
// `general:col.active_border` and `decoration:shadow` through hyprctl.
//
// ── the three workload moods ─────────────────────────────────────────────
// calm  (< 35% CPU): ice — the same gradient nyxus-cometfire.conf
//                    declares, so an idle machine looks exactly like the
//                    static config and a dead shell changes nothing.
// busy  (35–75%):    the rose leaning violet — the sweep's cool middle.
// heavy (> 75%):     ember — plum pushed to coral/gold, the palette's only
//                    hot corner, which is what "working hard" should read as.
// Bands are entered with hysteresis (±5) so a load hovering at a boundary
// does not strobe the border between two moods.
//
// ── the glow ─────────────────────────────────────────────────────────────
// Owner 11:29: forget the music wiring. Keep the glow around the borders.
// Slow fade lighter glacier → darker glacier. No Beat, no angle steps, no
// 26 s borderangle orbit (`animation borderangle,0`). Rim stays 3 px.
// Light end is glacier[0]/[5] (calmStops, the cometfire contract). Dark
// end on the rim is glacier[4] `#4f7fa6` (4.41:1, legal state). Halo may
// use glacier[3] `#274b7a` (glow, not a 3:1 rim). Throttled ≥ updateMs.
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    // ── palette: three moods, stops as plain hex (no alpha suffix) ──────
    // calm MUST stay byte-identical to the winning config declaration's
    // col.active_border stops. The winner is nyxus-cometfire.conf, NOT
    // nyxus-hyprland-general.conf as this comment used to say: hyprland.conf
    // sources general first and cometfire afterwards, so cometfire lands.
    // These stops are written WITHOUT a leading `#`, which is why a repo
    // scan for hardcoded `"#rrggbb"` came back clean over the whole shell
    // and still missed this file.
    //
    // ⚠ THIS FILE IS THE LAST WORD ON SCREEN. `Component.onCompleted` calls
    // write() on every shell start, and `hyprctl keyword` overrides the config.
    // So whatever is here beats all six config copies. Editing only the .conf
    // files changes nothing you can see while the shell is running — that trap
    // is exactly how the defect below survived.
    //
    // ── WIP-777 · 2026-08-17 — THE FLOOR, AND A DRIFT THIS EXPOSED ─────────
    // The byte-identity rule above was BROKEN and had been since WIP-531
    // (2026-08-12). That task took the three near-whites out of the window rim
    // on the owner's own complaint ("that pink i dont want") — it changed the
    // six config copies and MISSED this file, which kept the pre-WIP-531
    // eight-stop palette: 2e0819 ffb3d9 5c0f38 d765a2 3d0a22 ff8fc7 891955
    // ae206c. Because this file wins, the pink the owner asked to remove was
    // still on screen for five days with every gate green. Nothing gated it.
    // Gate 21 in scripts/audit.sh now derives the winning config's stops and
    // asserts calmStops equals them, so the contract is checked, not promised.
    //
    // THE CONTRAST DEFECT, measured on theme/accent.json's ground token
    // (_tokens.edges.ground = void #020506). All three moods had the identical
    // shape — FOUR of eight stops under the 3:1 state floor, because the
    // design alternates dark/bright and every dark rung in this palette fails:
    //   calm  1.13 12.37 1.54 6.11 1.23 9.74 2.27 3.14   (4 FAIL)
    //   busy  1.10 10.11 1.42 4.85 1.15 8.22 1.74 3.24   (4 FAIL)
    //   heavy 1.16 14.29 1.75 8.32 1.28 10.08 2.78 5.29  (4 FAIL)
    // A focused-window ring is STATE (_tokens.edges.state: solid, hue-coded,
    // 3:1). The floor is enforced PER STOP, not on the average, because
    // `borderangle` rotates the sweep — a single edge shows only one band at a
    // time, so a dark stop means a genuinely invisible edge some of the time.
    //
    // ⚠ LADDER GAP. There is no dark rung in accent.json that clears 3:1 in
    // ANY hue family; the darkest passing colour in the whole palette is
    // #ae206c at 3.138:1, and nothing sits between 2.991:1 (teal_deep) and it.
    // So "alternate dark/bright" and ">=3:1" are mutually exclusive — the same
    // conflict _findings.teal_alpha_bisection proved for the alpha seams. Each
    // mood therefore alternates the two BRIGHTEST legal rungs of its own ramp
    // instead of dark against bright. Every mood keeps its hue identity and
    // every value below is an existing accent.json token — nothing invented.
    // (7 of the 24 old stops — ff8fc7, all six unique busy darks/brights, and
    // c46a1f — existed in NO token, ramp or string in accent.json at all.)
    //
    // Stop count drops 8 -> 6 so calm can satisfy the byte-identity rule
    // against the six-stop config declaration; write() maps over `stops` and
    // only indexes stops[1], which is still a bright rung, so nothing else
    // depends on the length.
    //
    // calm  — ice. Owner 08-19 chrome: glacier[0] focus / glacier[5] hover.
    //   7fe8ff = glacier[0] (_tokens.resolved.accent-interactive)    14.50:1
    //   b7e6f2 = glacier[5] (_tokens.resolved.accent-primary)        15.21:1
    readonly property var calmStops:  ["7fe8ff", "b7e6f2", "7fe8ff", "b7e6f2", "7fe8ff", "b7e6f2"]
    // busy  — ice leaning violet (load). Not leftover rose: the first stop
    // is the same glacier[0] as calm; the second is purple[0].
    //   7fe8ff = glacier[0]                                          14.50:1
    //   aa6ece = _ramps.purple[0] (_palette_fixed.violet_glow)         5.678:1
    readonly property var busyStops:  ["7fe8ff", "aa6ece", "7fe8ff", "aa6ece", "7fe8ff", "aa6ece"]
    // heavy — ember. The only two rungs of _ramps.gold that clear the floor
    // (gold[0] #50310b is 1.738:1). Luminance 0.158 vs 0.421, the widest
    // legal alternation any ramp in the palette offers:
    //   9b621b = _ramps.gold[1] (_palette_fixed.gold)                  4.048:1
    //   d8a464 = _ramps.gold[2] (_palette_fixed.gold_glow/rich_gold)   9.167:1
    readonly property var heavyStops: ["9b621b", "d8a464", "9b621b", "d8a464", "9b621b", "d8a464"]

    // ══ TRK-4173 · the look-aware rim · 2026-09-15 ════════════════════════
    // Owner, on a MAGMA desktop: "i dont see the borders glowing and
    // pulsating to the music".
    //
    // TWO separate faults, and the first one hid the second.
    //
    // 1. `BorderPulse {}` was commented out in shell.qml on 2026-09-08 by an
    //    audit whose note reads "drove app-window border/shadow to ice+plum
    //    on every beat". That note is accurate. It is also a description of
    //    a PALETTE bug, and the audit fixed it by deleting the behaviour the
    //    owner actually wanted instead of fixing the colours.
    //
    // 2. The palette bug itself, which is the interesting one. `calmStops`,
    //    `busyStops` and `heavyStops` above are NOT what this file paints.
    //    They are a contract declaration — gate 21 asserts calmStops equals
    //    the winning nyxus-cometfire.conf stops — and nothing reads them at
    //    runtime. `write()` carried its own inline hex literals: 7fe8ff,
    //    b7e6f2, 4f7fa6, 274b7a, aa6ece, d765a2. Glacier and plum, always,
    //    on every look. A first attempt at this fix made the arrays
    //    look-aware, deployed it, and changed exactly nothing on screen,
    //    which is how the dead arrays were found at all.
    //
    // So the literals move here, behind the look. Ratios are vs black and
    // were computed, not guessed; the ice column is measured from the old
    // literals so the magma column can be checked against it rather than
    // against a vibe:
    //
    //   role                ice       ratio    magma     ratio
    //   light A (focus)     7fe8ff    14.89    f7a83b    10.62
    //   light B (hover)     b7e6f2    15.61    ffd27a    14.75
    //   dark end (rim)      4f7fa6     4.92    b0653a     4.77
    //   halo deep (glow)    274b7a     2.37    6b2a15     1.97
    //   strike A            aa6ece     5.83    ff7847     8.03
    //   strike B            d765a2     6.27    ff9a3c     9.94
    //
    // `dark end` is the one that matters for the WIP-777 focus-contrast
    // floor, because the slow fade lands there and parks: 4.77 vs 4.92 is
    // the closest warm rung to glacier[4] and is comfortably over 3:1.
    // `halo deep` is deliberately under 3:1 in BOTH columns — it is a
    // shadow glow, never a rim state, exactly as the glacier note above
    // already says of 274b7a.
    //
    // light A is f7a83b rather than a paler gold at 14.89 on purpose: it is
    // the same gold Prefs.applyHyprLook() already writes as the MAGMA
    // active border, and a rim that pulses away from the look's own resting
    // colour and back is the entire point. Agreeing with applyHyprLook
    // matters more here than matching glacier's ratio digit for digit.
    readonly property bool _magma: Theme.lookMagma
    readonly property string cLightA:   root._magma ? "f7a83b" : "7fe8ff"
    readonly property string cLightB:   root._magma ? "ffd27a" : "b7e6f2"
    readonly property string cDarkEnd:  root._magma ? "b0653a" : "4f7fa6"
    readonly property string cHaloDeep: root._magma ? "6b2a15" : "274b7a"
    readonly property string cStrikeA:  root._magma ? "ff7847" : "aa6ece"
    readonly property string cStrikeB:  root._magma ? "ff9a3c" : "d765a2"

    // Hyprctl floor. 120 ms is enough for a 16 s glacier fade and is not
    // the old 50 ms beat writer.
    readonly property int updateMs: 120
    readonly property int fadeMs: 16000     // one light↔dark glacier cycle
    property bool _dirty: false
    property real iceT: 0                   // 0 light glacier … 1 darker

    // ══ THE STRIKE · 2026-08-31, at the owner's request ═══════════════════
    // The 11:29 ruling ("forget the music, keep the glow") took the beat OFF
    // this file, and it was the right call at the time: what it removed was a
    // 50 ms writer driven by a LEVEL, which drifts with loudness and reads as
    // flicker rather than rhythm. The owner's report on 2026-08-31 -- "ive
    // played music and i never seen anything really go to the beat" -- is the
    // other half of that: with the window rim off the beat, the most visible
    // edge on the screen was the one edge that never moved.
    //
    // What is different now: `Beat.kick` is struck by a PREDICTED beat from a
    // phase-locked tracker, not by whatever crossed a threshold. It fires on
    // the beat, once per beat, hardest on the downbeat, and it FALLS -- which
    // is the part an eye reads as rhythm.
    //
    // The slow glacier fade underneath is untouched. This rides on top of it,
    // and when nothing is playing `strike` is 0 and this file behaves exactly
    // as it did before -- a still ring with a slow glow. Idle stays STILL.
    //
    // Cost is unchanged: no new writer and no new timer. The existing 120 ms
    // fade timer already calls request() ~8x/s and now simply samples a value
    // that moves. The old 50 ms beat writer is NOT coming back.
    readonly property real strike: (Beat.enabled && Beat.hot) ? Beat.kick : 0

    // The active window carries the beat; everything else only breathes with
    // it. Every rim on screen striking at full depth stops reading as rhythm
    // and starts reading as a strobe -- and it fights you when you are trying
    // to work in one of those windows.
    readonly property real strikeInactive: strike * 0.28

    // ── the halo's RESTING state, read from the compositor ──────────────
    // Not hardcoded on purpose. Three files in this build declare a shadow
    // range (hyprland.conf says 36, nyxus-hyprland-general.conf says 18) and
    // the live session was running a fourth value again, so any constant
    // here would be wrong for somebody and would silently redefine the
    // resting look the moment the shell started. Read it once, restore to
    // exactly it. The defaults below are only the fallback for a compositor
    // that will not answer.
    property int  _restRange:    22
    property int  _restAlpha:    0x3a
    property int  _restAlphaIn:  0x33
    property string _restHex:    root.cLightB
    property string _restHexIn:  "000000"
    // Idle halo is glacier[5], not the compositor's leftover #1e03ad
    // (NYXUS purple). The slow fade mixes this toward glacier[3].

    // One hyprctl at startup, parsed in-process. `-j` gives the colour as a
    // 32-bit ARGB int, which is why this reads it rather than scraping.
    Process {
        id: shadowProbe
        running: true
        command: ["hyprctl", "-j", "getoption", "decoration:shadow:color"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    // ── WHY THIS IS NOT JUST `.int` ───────────── TRK-4175 ──
                    // It used to be, and it had silently stopped working.
                    // Once ANYTHING writes this option as a gradient — and
                    // every writer here does, `rgba(xxxxxxxx)` included —
                    // hyprctl reports it as {"custom": "88ae206c 0deg"} with
                    // no `int` field at all. `.int` was undefined, the
                    // typeof guard rejected it, and the fallback was used on
                    // every start. The probe was decoration.
                    //
                    // Verified 2026-09-15: `hyprctl -j getoption
                    // decoration:shadow:color` returned exactly
                    // {"option": ..., "custom": "88ae206c 0deg", "set": true}.
                    // So the custom form is read first and `.int` is kept as
                    // the path for a compositor that still answers that way.
                    let a = -1;
                    if (typeof j.custom === "string") {
                        const m = j.custom.trim().match(/^([0-9a-fA-F]{8})/);
                        if (m) a = parseInt(m[1].substring(0, 2), 16);
                    } else if (typeof j.int === "number" && j.int > 0) {
                        a = (j.int >>> 24) & 0xff;
                    }
                    // Do not take the compositor's RGB — it has been
                    // #1e03ad (NYXUS purple), and more recently magenta
                    // ae206c from nyxus-pulse.sh. The rest glow is the
                    // look's own colour, via cLightB.
                    if (a > 0) root._restAlpha = Math.max(0x18, Math.min(0x5a, a));
                } catch (e) { /* keep the fallback */ }
                rangeProbe.running = true;
            }
        }
    }
    Process {
        id: rangeProbe
        command: ["hyprctl", "-j", "getoption", "decoration:shadow:range"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text).int;
                    // ── THE RATCHET ───────────────────────────── TRK-4175 ──
                    // This probe reads the LIVE range so the owner's own
                    // resting value is honoured instead of hardcoded. The
                    // flaw: write() inflates that same live value every
                    // 120 ms, up to restRange * (1 + 0.18 + 0.55) = 1.73x.
                    // So a probe that runs while a PREVIOUS BorderPulse is
                    // still writing reads an inflated number and adopts it
                    // as the new resting range — and the next restart reads
                    // an inflation of THAT. It ratchets.
                    //
                    // Measured on 2026-09-15: hyprland.conf declares 22, and
                    // the live range after a reload cycle was 57–69. That is
                    // the 36–51 halo the 2026-09-08 audit objected to,
                    // arriving by accident rather than by design.
                    //
                    // The clamp is the fix. 28 is above any resting value
                    // the profile declares (22) with room for a deliberate
                    // bump, and below the band that provoked the complaint.
                    // A legitimately larger user setting is capped rather
                    // than obeyed, which is the right trade against a value
                    // that otherwise grows without limit.
                    if (typeof v === "number" && v > 0)
                        root._restRange = Math.max(8, Math.min(28, v));
                } catch (e) { /* keep the fallback */ }
            }
        }
    }

    // ── slow glacier fade (owner 11:29: keep the glow, no music) ─────────
    Timer {
        interval: root.updateMs
        repeat: true
        running: true
        onTriggered: {
            root.iceT = 0.5 + 0.5 * Math.sin(Date.now() * Math.PI * 2 / root.fadeMs);
            root.request();
        }
    }

    // ── the writer: one hyprctl, at most every updateMs ─────────────────
    function request(): void {
        if (throttle.running) { _dirty = true; return; }
        write();
        throttle.start();
    }
    Timer {
        id: throttle
        interval: root.updateMs
        onTriggered: if (root._dirty) { root._dirty = false; root.write(); throttle.start(); }
    }

    function write(): void {
        // Light glacier[0]/[5] → darker glacier[4] on the rim. Halo uses
        // glacier[5] → glacier[3] (glow, not a 3:1 state stop).
        const t = Math.max(0, Math.min(1, root.iceT));
        const k = Math.max(0, Math.min(1, root.strike));
        let a = mixHex(root.cLightA, root.cDarkEnd, t);
        let b = mixHex(root.cLightB, root.cDarkEnd, t);

        // THE STRIKE, on the rim. The glacier pair is pushed toward the
        // galaxy accent -- violet_glow #aa6ece into plum_glow #d765a2 -- so a
        // beat reads as the palette's own colour arriving, not as a flash of
        // some new hue. Capped at 0.72 so the rim never fully leaves glacier:
        // the WIP-777 focus-contrast floor lives in these stops, and a rim
        // that abandons them stops saying "this window has focus" on the beat.
        if (k > 0.001) {
            a = mixHex(a, root.cStrikeA, k * 0.72);
            b = mixHex(b, root.cStrikeB, k * 0.72);
        }

        let parts = [];
        for (let i = 0; i < 6; i++)
            parts.push("rgba(" + (i % 2 === 0 ? a : b) + "ff)");

        const aHi = Math.min(0x55, Math.round(0x33 * (1 + t * 0.35))).toString(16).padStart(2, "0");
        const aLo = Math.min(0x44, Math.round(0x26 * (1 + t * 0.35))).toString(16).padStart(2, "0");
        // Unfocused windows breathe rather than strike (see strikeInactive).
        const ki = Math.max(0, Math.min(1, root.strikeInactive));
        const inParts = "rgba(" + mixHex(mixHex(root.cDarkEnd, root.cHaloDeep, t), root.cStrikeA, ki) + aHi + ") rgba("
                      + mixHex(mixHex(root.cHaloDeep, root.cDarkEnd, t), root.cStrikeA, ki) + aLo + ")";

        // THE HALO BLOOM. The shadow is the widest, softest thing the rim
        // owns, so pushing its range and alpha on the beat is what makes the
        // edge look like it is breathing rather than just changing colour.
        // This is the term you see from across the room.
        const shRange = Math.round(root._restRange * (1 + t * 0.18 + k * 0.55));
        const shA = Math.min(0xcc, Math.round(root._restAlpha * (1 + t * 0.55 + k * 1.30)))
                        .toString(16).padStart(2, "0");
        const shIn = Math.min(0x66, Math.round(root._restAlphaIn * (1 + t * 0.40 + ki * 0.60)))
                        .toString(16).padStart(2, "0");
        const shCol = mixHex(mixHex(root.cLightB, root.cHaloDeep, t), root.cStrikeB, k * 0.65);
        const shColIn = mixHex(root.cDarkEnd, root.cHaloDeep, t);

        Quickshell.execDetached(["hyprctl", "--batch",
            "keyword general:col.active_border " + parts.join(" ") + " 45deg ; "
          + "keyword general:col.inactive_border " + inParts + " 135deg ; "
          // ── border_size: 1, which is what the profile actually declares ──
          // WIP-779: this line forced 3 while `nyxus-hyprland-general.conf`
          // and `hyprland.conf` BOTH declare 1, under a comment in this file
          // claiming "both say 3". They do not. Because a `hyprctl keyword`
          // beats a config and this writer runs every `updateMs` (120 ms),
          // the 3 px rim on screen was this line overriding the profile
          // roughly eight times a second — which is also why setting the
          // value live with `hyprctl` appears to work and reads back 3.
          //
          // The 3 px had a REASON and the reason has expired: general.conf
          // records it as "the smallest width where the bands survive the
          // short edges of a tiled window", which is about the ROTATING
          // sweep. The owner turned that off on 2026-08-19 ("Idle is STILL
          // — do not fake a pulse with nothing playing"), and a still ring
          // has no bands to lose.
          //
          // ── border_size: 2, and it MUST match hyprland.conf ────────────
          // WIP-779 corrected this from 3 to 1 because the profile declared
          // 1 and this writer was overriding it eight times a second — a
          // real finding, and the note above about the rotating sweep no
          // longer needing 3 px still stands.
          //
          // TRK-4175, 2026-09-15: 1 px went too far the other way. The
          // owner asked to see the pulse working and could not, and a 1 px
          // line is not visible as a pulse from a seating distance no
          // matter how correct its contrast is. 2 px is the compromise:
          // wide enough to read as a moving rim, narrower than the 3 px
          // that WIP-779 rightly called unjustified.
          //
          // ⚠ hyprland.conf's `general { border_size = 2 }` must agree with
          // this number. If they differ, the rim visibly flickers between
          // the two widths at updateMs, because the config wins whenever
          // Hyprland reloads and this line wins 120 ms later.
          //
          // ⚠ This changes WIDTH ONLY. `col.active_border`'s stops are the
          // WIP-777 focus-contrast floor — enforced PER STOP, per look, in
          // the TRK-4173 table near the top of this file — and they are
          // untouched above.
          + "keyword general:border_size 2 ; "
          + "keyword decoration:rounding_power 2 ; "
          + "keyword animation borderangle,0 ; "
          + "keyword decoration:shadow:range " + shRange + " ; "
          + "keyword decoration:shadow:color rgba(" + shCol + shA + ") ; "
          + "keyword decoration:shadow:color_inactive rgba(" + shColIn + shIn + ")"]);
    }

    // Mix two "rrggbb" hexes by t (0..1). Light glacier t=0; darker t=1.
    function mixHex(a: string, b: string, t: real): string {
        const u = Math.max(0, Math.min(1, t));
        const parse = h => [parseInt(h.substr(0, 2), 16), parseInt(h.substr(2, 2), 16), parseInt(h.substr(4, 2), 16)];
        const A = parse(a), B = parse(b);
        const f = i => Math.round(A[i] + (B[i] - A[i]) * u).toString(16).padStart(2, "0");
        return f(0) + f(1) + f(2);
    }

    // On shell start: paint the glacier glow once, then the fade timer
    // keeps it moving. rounding_power 2 so the rim meets at the corners.
    Component.onCompleted: {
        write();
    }
}
