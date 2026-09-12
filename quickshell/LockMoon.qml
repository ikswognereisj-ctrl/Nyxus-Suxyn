// Nyxus Suxyn — the Moon, where it actually is, wearing tonight's actual phase.
//
// Owner ask, 2026-08-23/24: a moon in the lock's sky, "very very detailed ...
// down to the craters", with the real phase — "crescent or half ... exactly
// how it is in that exact night" — and the big orange one when it happens.
//
// This file is the EPHEMERIS and the PLACEMENT. `shaders/lockmoon.frag` is the
// picture, and its header explains why the phase is lighting rather than a
// drawn shape.
//
// ── THE ARITHMETIC, AND HOW IT WAS CHECKED ───────────────────────────────
// Low-precision lunar and solar positions (Meeus, the abridged series). Good
// to a few tenths of a degree, which is far finer than a disc a few hundred
// pixels across can express, and it needs no ephemeris file, no network and no
// dependency.
//
// It was checked against two dates nobody can argue with, before any of it was
// drawn:
//     2000-01-06 18:14 UTC, a known NEW moon  -> elongation 359.4 deg, lit 0.000
//     2000-01-21 04:40 UTC, a known FULL moon -> elongation 180.7 deg, lit 1.000
// Both land. A phase engine that cannot hit a known new moon is not worth
// rendering, and this is the cheapest possible way to find that out.
//
// ── WHY THE ORANGE MOON IS NOT GUESSWORK ─────────────────────────────────
// The huge orange moon low over the trees is atmospheric extinction: near the
// horizon you look through many airmasses, which scatter blue away and dim the
// whole disc. Airmass is a function of ALTITUDE, and altitude is exactly
// computable for this person at this minute — so the reddening happens on the
// nights it really happens, without anyone predicting anything. The "huge" part
// is the Moon illusion, which is in the eye and not in the sky, so it is not
// simulated; what IS simulated is the real size change, because the Moon is
// genuinely about 14% wider at perigee than apogee.
//
// ── WHERE IT SITS, AND WHY NOT SIMPLY WHERE IT IS ────────────────────────
// Owner: "if i did that it wouldnt be over lapping where the login part is
// right". Correct, and it is enforced rather than hoped for. The Moon's HEIGHT
// on screen is its real altitude — a low moon sits low, which is also when it
// goes orange, so the two agree. Its horizontal place comes from its real
// azimuth but is mapped into the picture side only: the band the clock and
// login do not occupy. So it can never land on the password field at any Earth
// size or side. Below the horizon it is not drawn at all, because it is not
// there.
//
// © 2026 JOSEPH A. SIERENGOWSKI · NYX-J5W-2026-SIERENGOWSKI-LOCKED

import Quickshell
import QtQuick

Item {
    id: moon

    // ── where the observer is ────────────────────────────────────────────
    // Generic stand-in (0,0), not a real location; the real fixup lands from
    // the weather cache before the first frame.
    property real lat: 0.0
    property real lon: 0.0

    // ── the band this may occupy, in fractions of width ──────────────────
    // Set by Lock.qml from the slab's own geometry, so the text column is a
    // no-go area by construction rather than by luck.
    property real bandLo: 0.02
    property real bandHi: 0.55

    property real sizeScale: 1.0        // user taste, on top of the real size

    // ── which way the sun is, on screen ──────────────────────────────────
    // When the Earth is drawn beside this, the two must agree about where the
    // sun is — see LockEarth.sunView for why. Lock.qml hands that angle in.
    // Left unset (NaN) this falls back to the ground observer's own
    // bright-limb tilt, which is the right answer when there is no planet in
    // frame to contradict it.
    property real sunAngle: NaN
    readonly property bool sunAngleGiven: !isNaN(moon.sunAngle)
    property bool live: false
    property real master: 1.0

    // ── the clock ────────────────────────────────────────────────────────
    property real epoch: 0              // ms; nudged to force a redraw

    // ── driven, for proving it ───────────────────────────────────────────
    // `true` stops the timers below touching `epoch`, so a probe or a settings
    // preview can set the moment and get that moment. Without this the object
    // overwrites any externally-set epoch on its very first tick, which looks
    // exactly like a broken override: two runs eighteen hours apart reported
    // the same altitude, because both were quietly showing "now". Nothing in
    // the shipped lock sets it.
    property bool driven: false

    readonly property bool hasTex: texColour.status === Image.Ready
                                && texHeight.status === Image.Ready

    // ── the ephemeris ────────────────────────────────────────────────────
    readonly property var sky: {
        const D2R = Math.PI / 180, R2D = 180 / Math.PI;
        const now = new Date(moon.epoch > 0 ? moon.epoch : Date.now());
        // Julian day
        const y = now.getUTCFullYear(), mo = now.getUTCMonth() + 1;
        const dd = now.getUTCDate()
                 + (now.getUTCHours() + now.getUTCMinutes() / 60
                    + now.getUTCSeconds() / 3600) / 24;
        const a0 = Math.floor((14 - mo) / 12);
        const yy = y + 4800 - a0, mm = mo + 12 * a0 - 3;
        const jdn = Math.floor(dd) + Math.floor((153 * mm + 2) / 5) + 365 * yy
                  + Math.floor(yy / 4) - Math.floor(yy / 100) + Math.floor(yy / 400) - 32045;
        const d = (jdn - 0.5 + (dd - Math.floor(dd))) - 2451545.0;

        // sun
        const L = (280.460 + 0.9856474 * d) % 360;
        const g = ((357.528 + 0.9856003 * d) % 360) * D2R;
        const lamS = ((L + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)) % 360 + 360) % 360;

        // moon
        const Lm = (218.316 + 13.176396 * d) % 360;
        const M  = ((134.963 + 13.064993 * d) % 360) * D2R;
        const F  = ((93.272 + 13.229350 * d) % 360) * D2R;
        const lamM = ((Lm + 6.289 * Math.sin(M)) % 360 + 360) % 360;
        const betM = 5.128 * Math.sin(F);
        const dist = 385001 - 20905 * Math.cos(M);          // km

        // phase
        let elong = ((lamM - lamS) % 360 + 360) % 360;
        const k = (1 - Math.cos(elong * D2R)) / 2;           // illuminated fraction
        const phaseAngle = Math.acos(Math.max(-1, Math.min(1, 2 * k - 1)));

        // to equatorial
        const eps = (23.4393 - 3.563e-7 * d) * D2R;
        function eq(lam, bet) {
            const l = lam * D2R, b = bet * D2R;
            const ra = Math.atan2(Math.sin(l) * Math.cos(eps) - Math.tan(b) * Math.sin(eps),
                                  Math.cos(l));
            const de = Math.asin(Math.sin(b) * Math.cos(eps)
                               + Math.cos(b) * Math.sin(eps) * Math.sin(l));
            return { ra: ra, dec: de };
        }
        const em = eq(lamM, betM), es = eq(lamS, 0);

        // local sidereal time -> hour angle -> alt/az
        const gmst = ((280.46061837 + 360.98564736629 * d) % 360 + 360) % 360;
        const lst = (gmst + moon.lon) * D2R;
        const H = lst - em.ra;
        const phi = moon.lat * D2R;
        const alt = Math.asin(Math.sin(phi) * Math.sin(em.dec)
                            + Math.cos(phi) * Math.cos(em.dec) * Math.cos(H));
        const az = Math.atan2(-Math.sin(H),
                              Math.tan(em.dec) * Math.cos(phi) - Math.sin(phi) * Math.cos(H));

        // bright limb position angle, and the parallactic angle that turns it
        // into an angle from the zenith — i.e. from "up" on the screen.
        const dra = es.ra - em.ra;
        const chi = Math.atan2(Math.cos(es.dec) * Math.sin(dra),
                               Math.sin(es.dec) * Math.cos(em.dec)
                             - Math.cos(es.dec) * Math.sin(em.dec) * Math.cos(dra));
        const q = Math.atan2(Math.sin(H),
                             Math.tan(phi) * Math.cos(em.dec) - Math.sin(em.dec) * Math.cos(H));
        const tilt = chi - q;

        // airmass (Kasten-Young), and what it does to the light
        const altDeg = alt * R2D;
        const amRaw = 1.0 / (Math.sin(alt) + 0.50572 * Math.pow(Math.max(altDeg, -1) + 6.07995, -1.6364));
        const am = Math.max(1.0, Math.min(38.0, amRaw));

        return {
            alt: alt, altDeg: altDeg, az: az, dist: dist,
            lit: k, phaseAngle: phaseAngle, tilt: tilt,
            elong: elong, airmass: am,
            waxing: elong < 180
        };
    }

    // ── what the air does to it ──────────────────────────────────────────
    // Extinction per airmass, roughly Rayleigh: blue suffers most. At the
    // zenith this is a whisper; two degrees up it is the orange one.
    readonly property color tint: {
        const am = moon.sky.airmass;
        const r = Math.exp(-0.100 * (am - 1.0));
        const g = Math.exp(-0.165 * (am - 1.0));
        const b = Math.exp(-0.310 * (am - 1.0));
        return Qt.rgba(Math.max(r, 0.25), Math.max(g, 0.10), Math.max(b, 0.04), 1.0);
    }
    readonly property real dimming: Math.max(0.18, Math.exp(-0.16 * (moon.sky.airmass - 1.0)))

    // Real apparent size: 384400 km is the mean, so perigee genuinely swells it.
    readonly property real apparent: 384400 / Math.max(1.0, moon.sky.dist)

    readonly property bool up: moon.sky.altDeg > -1.0
    visible: moon.hasTex && moon.up && moon.master > 0.001
    opacity: moon.master

    // ── placement ────────────────────────────────────────────────────────
    // Height is real altitude. Horizontal is real azimuth, folded into the
    // band the text does not use.
    readonly property real cx: {
        // azimuth 0 = north, +east. Map the visible half-sky across the band.
        const t = (Math.sin(moon.sky.az) + 1) / 2;
        return moon.bandLo + t * Math.max(0.0, moon.bandHi - moon.bandLo);
    }
    readonly property real cy: {
        // horizon at 0.90 of the height, zenith at 0.10
        const f = Math.max(0, Math.min(1, moon.sky.altDeg / 90));
        return 0.90 - f * 0.80;
    }

    Image {
        id: texColour
        source: Qt.resolvedUrl("textures/moon-color.jpg")
        visible: false; asynchronous: true; cache: true
    }
    Image {
        id: texHeight
        source: Qt.resolvedUrl("textures/moon-height.jpg")
        visible: false; asynchronous: true; cache: true
    }

    // One tick a minute. The Moon moves about half a degree an hour; a minute
    // is already far finer than anyone can see on a lock screen, and between
    // ticks this layer costs the GPU nothing.
    Timer {
        running: moon.visible && !moon.driven
        interval: 60000; repeat: true; triggeredOnStart: true
        onTriggered: moon.epoch = Date.now()
    }
    Timer {
        running: moon.visible && moon.live && !moon.driven
        interval: 33; repeat: true
        onTriggered: moon.epoch = Date.now()
    }

    ShaderEffect {
        anchors.fill: parent
        blending: true
        fragmentShader: Qt.resolvedUrl("shaders/lockmoon.frag.qsb")

        property variant moonTex: texColour
        property variant moonHgt: texHeight

        // 0.052 of the short edge is a moon that reads as a moon on a lock
        // screen. It is then modulated by the REAL apparent size, so perigee
        // is genuinely bigger and apogee genuinely smaller.
        readonly property real rad:
            Math.min(width, height) * 0.052 * moon.apparent * moon.sizeScale

        property vector4d uRes:  Qt.vector4d(width, height,
                                             width * moon.cx, height * moon.cy)
        property vector4d uGeom: Qt.vector4d(rad, 0.9,
                                             0.030 * (1.0 - moon.sky.lit), moon.dimming)
        // The sun's direction in view space. phaseAngle 0 is full (sun behind
        // the viewer), 180 is new. `tilt` rolls the terminator to the angle it
        // really has in this sky.
        readonly property real roll: moon.sunAngleGiven ? moon.sunAngle : moon.sky.tilt
        property vector4d uSun: Qt.vector4d(
            Math.sin(moon.sky.phaseAngle) * Math.sin(roll),
            Math.sin(moon.sky.phaseAngle) * Math.cos(roll),
            Math.cos(moon.sky.phaseAngle), 0.0)
        property vector4d uTint: Qt.vector4d(moon.tint.r, moon.tint.g, moon.tint.b, 0.04)
    }
}
