// Nyxus Suxyn — the Earth, as a layer over the lock screen's starfield.
//
// Owner ask, 2026-08-23. He kept the wallpaper he loves and asked for a real
// planet inside it: "add this layer to the already there background image",
// turned to where he actually is, lit by the real sun, wearing the real
// weather, "as real as possible".
//
// This file is the CLOCK and the DATA. `shaders/lockearth.frag` is the
// picture. The split matters, because the whole safety story lives here:
//
// ── WHY THIS IS NOT A FRAME CLOCK ────────────────────────────────────────
// The owner ruled on 2026-08-12, having measured it on his own hardware:
// "it's a live image and it's too much, it lags my system." That killed the
// previous sky's FrameAnimation, which redrew a full-screen shader 144 times
// a second on his panel.
//
// So `live` is FALSE by default and this draws on a ONE MINUTE timer. A
// ShaderEffect only re-renders when one of its uniforms changes, so between
// ticks this layer costs the GPU exactly nothing. The sun still moves, the
// clouds still arrive, the terminator still crosses his house — they step
// rather than glide, and at a minute a step nobody can see the difference on
// a lock screen.
//
// `live: true` exists for the settings preview and for anyone whose machine
// can afford it. It is capped at 30 fps and it is never the default.
//
// ⛔ NOTHING HERE MAY SPAWN A PROCESS ON A SHORT TIMER. That is the defect
// that cost this build a hard reset once already (hyprlock.conf, LK-02): two
// labels running subprocesses every 50 ms starved the event loop until the
// password field drew but would not accept input. The only processes this
// file starts are one `cat` of six tiny cache files, every ten minutes, and
// one detached refresh it never waits on.
//
// ── DEGRADING ────────────────────────────────────────────────────────────
// Every input is optional and the fallbacks are stacked, because this draws on
// the surface that has to let him back in:
//   · no satellite frames  -> a clean Earth, no clouds. Still correct, still lit.
//   · no cached lat/lon    -> the compiled-in default below.
//   · no textures at all   -> `visible` goes false and the lock is exactly the
//                            starfield it is today.
//   · shader fails to load -> Qt draws nothing; the Image underneath is intact.
//
// © 2026 JOSEPH A. SIERENGOWSKI · NYX-J5W-2026-SIERENGOWSKI-LOCKED

import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: earth

    // ── where he is ──────────────────────────────────────────────────────
    // Overwritten from the cache that `nyxus-lock-weather` fills. The default
    // is only what the first frame shows before that read lands.
    property real lat: 42.511
    property real lon: -83.616

    // ── the look, all of it settings-driven ──────────────────────────────
    // `sizeFrac` is the globe's DIAMETER as a fraction of the screen's short
    // edge. The three the owner kept: 0.62 / 0.92 / 1.30.
    property real sizeFrac: 0.92
    property real centreX:  0.30      // 0..1 across the screen
    property real centreY:  0.50
    property bool lightning: true
    property real exposure: 1.04
    property real markerStrength: 0.55

    // ── motion ───────────────────────────────────────────────────────────
    // See the header. False is the shipped value and the owner's ruling.
    property bool live: false

    // Master fade, so the planet can come up with the lock rather than
    // appearing fully formed the instant the surface maps.
    property real master: 1.0

    // ── time ─────────────────────────────────────────────────────────────
    property real tSec: 0
    property real nowMin: 0

    readonly property bool hasBase: dayImg.status === Image.Ready
                                 && nightImg.status === Image.Ready
    visible: earth.hasBase && earth.master > 0.001
    opacity: earth.master

    // ── the sun, for real ────────────────────────────────────────────────
    // Solar declination from the day of the year and the hour angle from UTC.
    // No ephemeris, no network: this is the same arithmetic a sundial does,
    // and it is right to well under a degree, which is far finer than a
    // terminator drawn 1200 px wide can show.
    //
    // ⚠ THE DEPENDENCY ON `nowMin` IS LOAD-BEARING. Read it before deleting it.
    //
    // A QML binding re-evaluates only when a property it READ during its last
    // evaluation changes. `new Date()` is not a property. Without the line
    // below this block computed the sun ONCE, when the lock surface was
    // instantiated, and then never again — the minute timer ticked, `nowMin`
    // and `tSec` moved, the shader redrew, and it redrew the same terminator
    // every time. The header of this file promises "the sun still moves, the
    // clouds still arrive, the terminator still crosses his house". It did not.
    // Lock the screen at dusk, come back after midnight, and the daylight was
    // still exactly where you left it.
    //
    // Owner, 2026-09-01: "its suppose to move and show like real life clouds
    // its moving closer to night or day whatever". Correct, and it is what this
    // file always said it did. Touching `nowMin` here is what makes it true.
    readonly property var sunVec: {
        const tick = earth.nowMin;   // ← dependency; do not remove (see above)
        const d = new Date();
        const start = Date.UTC(d.getUTCFullYear(), 0, 0);
        const doy = Math.floor((Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate())
                                - start) / 86400000);
        const decl = -23.44 * Math.PI / 180 * Math.cos(2 * Math.PI * (doy + 10) / 365.24);
        const utcH = d.getUTCHours() + d.getUTCMinutes() / 60 + d.getUTCSeconds() / 3600;
        let sub = (180 - utcH * 15) * Math.PI / 180;
        while (sub >  Math.PI) sub -= 2 * Math.PI;
        while (sub < -Math.PI) sub += 2 * Math.PI;
        return Qt.vector4d(Math.cos(decl) * Math.sin(sub),
                           Math.sin(decl),
                           Math.cos(decl) * Math.cos(sub), 0.0);
    }

    // ── where the sun is ON SCREEN ───────────────────────────────────────
    // The owner, looking at the Moon drawn beside the planet: "isnt the moon
    // in the wrong place for it to be dark where its dark on earth?"
    //
    // He was right, and it was a frame-of-reference error. The Earth here is
    // seen FROM SPACE and lit by the real sun. The Moon's terminator was being
    // tilted for an observer standing in his garden — the bright-limb position
    // angle minus the parallactic angle, which is the correct answer to a
    // different question. Two frames in one picture, so the Moon could show its
    // lit side pointing somewhere the Earth's own daylight said was impossible.
    //
    // There is one sun in the sky and it lights both. This is its direction in
    // VIEW space — the shader's camera rotation, inverted — so LockMoon can
    // point its bright limb at the same sun that draws the terminator two
    // hundred pixels away. The illuminated FRACTION is still tonight's real
    // phase; only the roll is made consistent.
    readonly property var sunView: {
        const s = earth.sunVec;
        const la = earth.lat * Math.PI / 180, lo = earth.lon * Math.PI / 180;
        const cl = Math.cos(la), sl = Math.sin(la);
        const co = Math.cos(lo), so = Math.sin(lo);
        // inverse of Ry(lon) * Rx(-lat)
        const ax = s.x * co - s.z * so;
        const ay = s.y;
        const az = s.x * so + s.z * co;
        return Qt.vector3d(ax, ay * cl - az * sl, ay * sl + az * cl);
    }
    // Angle of the sun from screen-up, for anything that needs to face it.
    readonly property real sunScreenAngle:
        Math.atan2(earth.sunView.x, earth.sunView.y)

    // ── the textures ─────────────────────────────────────────────────────
    // The two that ship are the planet. The two from the cache are the
    // weather, and either may be absent without consequence.
    Image {
        id: dayImg
        source: Qt.resolvedUrl("textures/earth-day.jpg")
        visible: false; asynchronous: true; cache: true
    }
    Image {
        id: nightImg
        source: Qt.resolvedUrl("textures/earth-night.jpg")
        visible: false; asynchronous: true; cache: true
    }
    // ⛔ A SAMPLER MUST NEVER BE LEFT POINTING AT A FILE THAT ISN'T THERE.
    //
    // `LiveWall.qml` already records what Qt does with a ShaderEffect whose
    // sampler never became valid, and the two below are the only sources here
    // that can legitimately be absent: the satellite frames live in a cache, so
    // they are missing on a fresh install, missing before the first fetch
    // finishes, and briefly replaced on every refresh.
    //
    // On 2026-08-23 the owner's lock screen threw a Hyprland error and cost him
    // a reboot. The cause was never proven — the logs are on tmpfs and went
    // with the restart — but an unbacked sampler on the one surface that has to
    // let him back in is not something to leave standing on a maybe.
    //
    // So every sampler is ALWAYS backed by a real image: if the cache file is
    // not loadable, the source falls back to a texture that ships with the
    // build. The shader never reads it, because `haveGeo` / `haveIr` go to zero
    // in exactly that case and both lookups are gated on them. The fallback is
    // there to keep the binding valid, not to be looked at.
    // ── AND WHY EACH FEED IS BACKED BY *TWO* IMAGES ───────────────────────
    // The frames used to be loaded once per lock and never refreshed. The note
    // that used to sit further down explained why: a reload helper had been
    // written, was wrong (it assigned the geo url into the infrared sampler,
    // pointing it at a regional frame in the wrong projection), and was removed
    // rather than repaired. Re-pointing a sampler the shader is actively
    // reading is the same class of risk as an unbacked one.
    //
    // But "never refresh" is not a fix, it is the bug the owner reported on
    // 2026-09-01: "its suppose to move and show like real life clouds ... if a
    // storm rolls i its suppose to show that exact look of things". Lock the
    // screen while a storm is coming in and it never arrived on the globe.
    //
    // Both things are true at once, so the answer is not to choose between
    // them. Each feed gets TWO Images. The shader samples one; a refresh is
    // loaded into the OTHER, which nothing is reading, and the pair is swapped
    // only once the new frame has actually reached Ready AND came from the
    // cache rather than the stand-in. A failed or half-loaded refresh changes
    // nothing on screen — the old good frame stays up. The sampler the shader
    // holds is valid at every instant, including during the swap.
    component SatFrame: Image {
        // True only while this frame is showing real cached satellite imagery.
        // A frame that fell back to the shipped stand-in is "backed" but not
        // "had", and must never be swapped in or counted as cloud data.
        property bool onCache: true
        readonly property bool live: status === Image.Ready && onCache
        visible: false
        asynchronous: true
        cache: false            // the file changes under us; never re-use
    }

    readonly property url geoUrl:
        "file://" + Quickshell.env("HOME") + "/.cache/nyxus/lockearth/geo.jpg"
    readonly property url irUrl:
        "file://" + Quickshell.env("HOME") + "/.cache/nyxus/lockearth/ir.jpg"
    readonly property url standIn: Qt.resolvedUrl("textures/earth-night.jpg")

    // Which half of each pair the shader is currently reading.
    property bool geoUseA: true
    property bool irUseA: true

    readonly property SatFrame geoImg:  earth.geoUseA ? geoA : geoB
    readonly property SatFrame geoSpare: earth.geoUseA ? geoB : geoA
    readonly property SatFrame irImg:   earth.irUseA ? irA : irB
    readonly property SatFrame irSpare:  earth.irUseA ? irB : irA

    // GOES-East GeoColor over the Americas: the only source that reliably sees
    // LOW cloud. On 2026-08-23 it was the one that agreed with the owner that
    // it was raining on him.
    SatFrame {
        id: geoA
        source: earth.geoUrl
        onStatusChanged: {
            if (status === Image.Error && onCache) { onCache = false; source = earth.standIn; }
            else if (status === Image.Ready && onCache && !earth.geoUseA) earth.geoUseA = true;
        }
    }
    SatFrame {
        id: geoB
        onStatusChanged: {
            if (status === Image.Error && onCache) { onCache = false; source = earth.standIn; }
            else if (status === Image.Ready && onCache && earth.geoUseA) earth.geoUseA = false;
        }
    }
    // ⚠ THIS MUST BE A SatFrame, AND IT WAS AN `Image` FOR ONE DAY. TRK-3724.
    //
    // Its three siblings are SatFrames; this one alone was declared `Image`.
    // A bare Image defaults to `visible: true`, so the raw 4096x2048 infrared
    // mosaic was PAINTED ONTO THE LOCK SCREEN at full size — the owner's
    // "messed up earth", a flat rainbow map behind a correct globe.
    //
    // The same typo broke the shader silently. `irImg` is declared
    // `readonly property SatFrame`, so while the pair was on the A side that
    // reference did not type-match: `haveIr` could not be read from it, the
    // infrared uniform went to zero, and the cloud depth the owner asked for
    // was gone at exactly the moment the frame finally downloaded.
    //
    // It hid until 2026-09-01 because ir.jpg never landed before TRK-3703
    // lifted the timeout. A frame that never arrives is never drawn, so the
    // wrong element type cost nothing until the fetch started working. The
    // class of defect: a type that only matters once the data shows up.
    SatFrame {
        id: irA
        // Clean infrared, all three geostationary satellites. Works at 3am
        // exactly as well as at noon, and its brightness IS cloud-top height.
        source: earth.irUrl
        onStatusChanged: {
            if (status === Image.Error && onCache) { onCache = false; source = earth.standIn; }
            else if (status === Image.Ready && onCache && !earth.irUseA) earth.irUseA = true;
        }
    }
    SatFrame {
        id: irB
        onStatusChanged: {
            if (status === Image.Error && onCache) { onCache = false; source = earth.standIn; }
            else if (status === Image.Ready && onCache && earth.irUseA) earth.irUseA = false;
        }
    }

    // Load the newest cache file into whichever half of each pair the shader is
    // NOT reading. Clearing the source first is what forces Qt to go back to
    // disk: the path has not changed, only the bytes behind it, and without the
    // clear an identical url is a no-op even with `cache: false`. Doing that to
    // the spare is safe precisely because nothing samples it; doing it to the
    // live one is the mistake this design exists to avoid.
    //
    // A spare that already fell back to the stand-in has `onCache` false and
    // would never be swapped in, so give it a fresh chance at the real file.
    function refreshFrames() {
        geoSpare.onCache = true;
        geoSpare.source = "";
        geoSpare.source = earth.geoUrl;
        irSpare.onCache = true;
        irSpare.source = "";
        irSpare.source = earth.irUrl;
    }

    // "have" means the CACHE loaded, not merely that the sampler is backed.
    readonly property real haveGeo: earth.geoImg.live ? 1.0 : 0.0
    readonly property real haveIr:  earth.irImg.live ? 1.0 : 0.0

    // The bounding box the geo frame was fetched over, and the satellite's
    // station. Both are baked by the fetcher; if they ever change, they change
    // in one place there and here together.
    readonly property real geoLonMin: -155.0
    readonly property real geoLonMax:   -5.0
    readonly property real geoLatMin:  -65.0
    readonly property real geoLatMax:   75.0
    readonly property real geoSubLon:  -75.2

    // ── reading where he is ──────────────────────────────────────────────
    // One spawn, two files, every ten minutes. Same cache and same shape as
    // LockWeather's read, deliberately: two readers of one cache, never two
    // clients of one API.
    Process {
        id: readGeo
        command: ["sh", "-c",
            "d=$HOME/.cache/nyxus/lockweather; " +
            "for f in lat lon; do cat \"$d/$f\" 2>/dev/null; printf '\\n'; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.split("\n");
                const la = parseFloat((p[0] || "").trim());
                const lo = parseFloat((p[1] || "").trim());
                if (!isNaN(la) && la >= -90  && la <= 90)  earth.lat = la;
                if (!isNaN(lo) && lo >= -180 && lo <= 180) earth.lon = lo;
            }
        }
    }

    // The fetch lives in the script that owns the network. Detached, and this
    // file does not read its output or wait on it — it cannot delay a lock.
    Process { id: kick; command: ["nyxus-lock-weather", "earth"] }

    // ── the clock ────────────────────────────────────────────────────────
    Timer {
        running: earth.visible
        interval: 60000; repeat: true; triggeredOnStart: true
        onTriggered: {
            const d = new Date();
            earth.nowMin = d.getHours() * 60 + d.getMinutes();
            earth.tSec = Date.now() / 1000;      // nudges the uniform -> one redraw
        }
    }
    Timer {
        running: earth.visible
        interval: 600000; repeat: true; triggeredOnStart: true
        onTriggered: {
            readGeo.running = true;
            // Pick up whatever the LAST kick fetched, then kick again. The
            // fetch is detached and this file never waits on it, so the frame
            // that lands on screen is one cycle behind the network — ten
            // minutes, against satellite imagery that is itself published
            // around forty minutes late. Waiting on the fetch to shorten that
            // would put network latency on the lock surface, which is the one
            // thing this file is not allowed to do.
            earth.refreshFrames();
            kick.running = true;
        }
    }

    // Only ever running when someone has explicitly asked for motion.
    Timer {
        running: earth.visible && earth.live
        interval: 33; repeat: true
        onTriggered: earth.tSec = Date.now() / 1000
    }

    // The frames ARE reloaded now — see `refreshFrames` and the double-buffer
    // note above. The earlier helper that was removed from here failed because
    // it re-pointed a sampler the shader was reading, and it put the geo url
    // into the infrared sampler while doing it. Loading into the spare half of
    // a pair avoids the first mistake; the second was only ever a typo, and
    // `refreshFrames` names each url beside its own target so it reads wrong
    // if it is ever wrong again. `nyxus-lock-weather earth` still writes
    // atomically, so what is loaded is always a whole file.

    // ── the planet ───────────────────────────────────────────────────────
    ShaderEffect {
        anchors.fill: parent
        blending: true              // it is a LAYER: his starfield shows through
        fragmentShader: Qt.resolvedUrl("shaders/lockearth.frag.qsb")

        // Names match the uniform block in lockearth.frag member for member.
        // Qt binds by name and a typo here is an invisible layer, not an error.
        property variant dayTex:   dayImg
        property variant nightTex: nightImg
        property variant geoTex:   geoImg
        property variant irTex:    irImg

        readonly property real radius: Math.min(width, height) * earth.sizeFrac * 0.5

        property vector4d uRes:   Qt.vector4d(width, height,
                                              width * earth.centreX, height * earth.centreY)
        property vector4d uGlobe: Qt.vector4d(radius, earth.tSec,
                                              earth.lightning ? 1.0 : 0.0, earth.exposure)
        property vector4d uSun:   earth.sunVec
        property vector4d uGeo:   Qt.vector4d(earth.lat * Math.PI / 180,
                                              earth.lon * Math.PI / 180,
                                              earth.lat * Math.PI / 180,
                                              earth.lon * Math.PI / 180)
        property vector4d uBox:   Qt.vector4d(earth.geoLonMin * Math.PI / 180,
                                              earth.geoLonMax * Math.PI / 180,
                                              earth.geoLatMin * Math.PI / 180,
                                              earth.geoLatMax * Math.PI / 180)
        property vector4d uOpt:   Qt.vector4d(earth.geoSubLon * Math.PI / 180,
                                              earth.markerStrength,
                                              earth.haveGeo, earth.haveIr)
    }
}
