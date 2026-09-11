// Nyxus Suxyn — the lock screen's weather, as a live layer.
//
// Two jobs, and they are deliberately in one file because they must never
// disagree: this drives `shaders/lockweather.frag` (what you SEE — the rain,
// the sun, the snow) and it publishes the same reading as text (what you READ
// — "Light rain · 12°C"). A version where the picture says snow and the label
// says rain is worse than no picture at all.
//
// ── where the data comes from ────────────────────────────────────────────
// `nyxus-lock-weather`, unchanged, which already owns the network side: one
// keyless wttr.in fetch, serve-stale for 30 minutes, cached under
// ~/.cache/nyxus/lockweather/. This file is a READER of that cache and a
// kicker of its refresh; it is not a second weather client, and adding one
// would mean two answers to the same question.
//
// The cache is read by ONE `sh -c` every 60 s — six tiny files in one spawn.
// Not per-frame, not per-field: the lock screen's whole reason for existing in
// Quickshell instead of hyprlock is that motion here is an animated PROPERTY,
// not a process. See the header of `shaders/lockweather.frag`.
//
// ── dayness is a ramp, not a switch ──────────────────────────────────────
// `nyxus-lock-weather daypart` answers day/night as a hard boolean because a
// pre-rendered PNG has to pick one. Here it does not: real sunrise and sunset
// come out of the same cache, and `dayness` crosses between them over 50
// minutes. That twilight is most of what sells the sky as real, and it costs
// one lerp.
//
// ⚠ NAMING TRAP, paid for once already: a ShaderEffect binds its properties to
// the uniform block BY NAME. The block member is `wx`, so the property must be
// `wx`, so the root object here cannot also be `wx` — hence `weather`. A
// collision does not error; it produces a silently black layer.
import Quickshell.Io
import QtQuick

Item {
    id: weather

    // ── what the cache says ──────────────────────────────────────────────
    property string cond: ""        // clear partly clouds fog rain snow storm
    property string big:  ""        // " 12°"   (glyph + temperature)
    property string line: ""        // "Light rain · 12°C"
    property string sub:  ""        // "feels 10° · ↑14° ↓8° · Boston"
    property int sunriseMin: 420    // 07:00 — used only until the cache lands
    property int sunsetMin: 1140    // 19:00
    readonly property bool hasData: weather.cond !== ""

    // Master fade, so the whole sky can be brought up with the lock rather
    // than appearing fully formed the instant the surface maps.
    property real master: 1.0

    // ── live, or driven ──────────────────────────────────────────────────
    // `false` stops this object reading the cache or kicking a refresh, which
    // leaves `cond`, `dayness` and the rest as plain writable properties. That
    // is how the sky gets PROVED: six of these side by side, forced to six
    // conditions, is a picture of the whole weather set in one frame — a thing
    // you cannot otherwise see without waiting for it to snow.
    // It is also what a Settings preview would want. Nothing in the shipped
    // lock sets it: `Lock.qml` leaves it true.
    property bool live: true

    // ── READING is not DRAWING (2026-08-23) ──────────────────────────────
    // Every timer below used to be gated on `visible`, which conflated two
    // different questions: "should this object keep the weather cache fresh"
    // and "should this object paint a sky". That was the whole reason the lock
    // screen showed no weather for weeks — `Lock.qml` instantiated this with
    // `visible: false` because the Earth layer draws the sky now, and the
    // timers went with it, so `cond` never left "" and every reader fell
    // through to its no-data branch.
    //
    // So the two are separate. `active` runs the clock; `visible` paints.
    // It defaults to `visible` so nothing that already used this file changes
    // behaviour.
    property bool active: visible

    // ── dayness ──────────────────────────────────────────────────────────
    property int nowMin: 0
    readonly property real dayness: {
        const n = weather.nowMin, sr = weather.sunriseMin, ss = weather.sunsetMin;
        const ramp = 50;                       // minutes of twilight each side
        if (n < sr - ramp || n > ss + ramp) return 0.0;
        if (n > sr + ramp && n < ss - ramp)    return 1.0;
        if (n <= sr + ramp)
            return Math.max(0.0, Math.min(1.0, (n - (sr - ramp)) / (2 * ramp)));
        return Math.max(0.0, Math.min(1.0, ((ss + ramp) - n) / (2 * ramp)));
    }
    readonly property bool isDay: weather.dayness >= 0.5

    // ── condition → the shader's numbers ─────────────────────────────────
    // The index order is frozen in lockweather.frag's C_* constants. Anything
    // the cache can hold that is not one of the seven falls to "clear", which
    // is the quiet sky — an unknown code must never invent a storm.
    readonly property int condIndex: {
        switch (weather.cond) {
        case "clear":  return 0;
        case "partly": return 1;
        case "clouds": return 2;
        case "fog":    return 3;
        case "rain":   return 4;
        case "snow":   return 5;
        case "storm":  return 6;
        default:       return 0;
        }
    }
    readonly property real cloudAmount: {
        switch (weather.cond) {
        case "partly": return 0.45;
        case "clouds": return 0.95;
        case "rain":   return 0.80;
        case "storm":  return 1.00;
        // 0.85, not the 0.70 this started at: snow falls out of an overcast
        // sky, and at 0.70 the star volume stayed bright enough that "snow ·
        // night" and "clear · night" were the same picture with extra dots.
        case "snow":   return 0.85;
        case "fog":    return 0.30;
        default:       return 0.0;
        }
    }
    readonly property real fogAmount: weather.cond === "fog" ? 1.0 : 0.0
    readonly property real intensity: weather.cond === "storm" ? 1.15 : 1.0
    readonly property real wind: weather.cond === "storm" ? 0.55 : 0.22

    // ── how much of the star volume survives ─────────────────────────────
    // Two things put the stars out, and the second one was missing in the
    // first cut: DAY, and CLOUD.
    //
    // Without the cloud term a rainy night rendered as rain falling in front of
    // a perfectly clear galaxy — which is exactly what it looked like in the
    // 08-10 proof grid, and it is the single thing that made the wet scenes
    // read as an effect pasted over a wallpaper rather than as weather. An
    // overcast sky has no stars in it. Cloud takes three quarters of them at
    // full cover, which leaves the deck lit from behind rather than black.
    readonly property real starDim:
        (1.0 - weather.dayness * 0.92) * (1.0 - weather.cloudAmount * 0.78)

    // ── the strike ───────────────────────────────────────────────────────
    // Driven here, not hashed in the shader, so `flash` can be animated on
    // demand and the bolt and the sheet-flash are guaranteed to be one event.
    property real flash: 0.0

    // `live` gates this too, so that "driven" means driven all the way down: a
    // preview that wants a strike animates `flash` itself and gets it on the
    // frame it asked for, instead of waiting out a random 3.5–9 s timer. That
    // is the difference between proving the bolt and hoping to photograph it.
    Timer {
        id: stormClock
        running: weather.active && weather.live && weather.cond === "storm"
        repeat: true
        interval: 4000
        onTriggered: {
            strike.restart();
            stormClock.interval = 3500 + Math.random() * 5500;
        }
    }
    SequentialAnimation {
        id: strike
        NumberAnimation { target: weather; property: "flash"; to: 1.0;  duration: 45 }
        NumberAnimation { target: weather; property: "flash"; to: 0.12; duration: 90 }
        NumberAnimation { target: weather; property: "flash"; to: 0.85; duration: 55 }
        NumberAnimation { target: weather; property: "flash"; to: 0.0;  duration: 320 }
    }

    // ── reading the cache ────────────────────────────────────────────────
    // One spawn, six files, 60 s apart. `printf '\n'` after each rather than
    // `echo` of the contents, so an empty field still produces its own line and
    // the indices below cannot slide.
    Process {
        id: readCache
        command: ["sh", "-c",
            "d=$HOME/.cache/nyxus/lockweather; " +
            "for f in cond big line sub sunrise sunset; do " +
            "  cat \"$d/$f\" 2>/dev/null; printf '\\n'; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.split("\n");
                weather.cond = (p[0] || "").trim();
                weather.big  = (p[1] || "").trim();
                weather.line = (p[2] || "").trim();
                weather.sub  = (p[3] || "").trim();
                const sr = parseInt((p[4] || "").trim(), 10);
                const ss = parseInt((p[5] || "").trim(), 10);
                if (!isNaN(sr)) weather.sunriseMin = sr;
                if (!isNaN(ss)) weather.sunsetMin = ss;
            }
        }
    }

    // The refresh itself stays in the script that owns the network. Fifteen
    // minutes against its own 30-minute serve-stale window means the reading is
    // never more than half an hour old while the screen is locked, and the
    // fetch can never block anything here — it is a detached process whose
    // output this file does not even read.
    Process { id: kickUpdate; command: ["nyxus-lock-weather", "update"] }

    Timer {
        running: weather.active && weather.live
        interval: 60000; repeat: true; triggeredOnStart: true
        onTriggered: {
            readCache.running = true;
            const d = new Date();
            weather.nowMin = d.getHours() * 60 + d.getMinutes();
        }
    }
    Timer {
        running: weather.active && weather.live
        interval: 900000; repeat: true; triggeredOnStart: true
        onTriggered: kickUpdate.running = true
    }

    // ── the frame clock is GONE (owner ruling 2026-08-12) ────────────────
    // It was:
    //
    //     FrameAnimation { id: tick; running: weather.visible }
    //
    // and the comment above it argued that a FrameAnimation is cheaper than a
    // 16 ms Timer because it rides the render thread's own frame signal rather
    // than waking the GPU on a schedule of its own. That is true and it is
    // beside the point: riding the frame signal on a 144 Hz panel means
    // redrawing a full-screen fragment shader 144 times a second. Together
    // with `Lock.qml`'s star layer that was TWO live full-screen shaders on
    // the lock surface.
    //
    // The owner measured the cost on his own hardware and ruled it out:
    // "it's a live image and it's too much, it lags my system." A login or
    // lock screen that stutters is worse than one that is merely pretty, and
    // this is the surface that has to accept a password.
    //
    // So: a FIXED time constant. The shader draws one frame of the same art
    // and then stops costing anything. Weather still CHANGES — `condIndex`,
    // `dayness`, `intensity`, `wind` and the sunrise/sunset maths are all
    // still live and still update on their own (much slower) timers, so the
    // sky still knows it is raining and still knows it is night. What it no
    // longer does is animate between frames.
    //
    // ⚠ `shell/shaders/lockweather.frag` is UNTOUCHED — the GLSL and the
    // shader chain are Agent B's lane. This is only the QML clock that drove
    // it. If B wants a different frame, this constant is the whole knob.
    readonly property real stillTime: 137.0

    // The storm flash animation below is deliberately LEFT ALONE: it is not a
    // background, it runs only during a storm, and it is four short property
    // animations rather than a per-frame redraw of a full-screen shader.

    // ── the sky ──────────────────────────────────────────────────────────
    ShaderEffect {
        id: sky
        anchors.fill: parent
        blending: true

        // Bound BY NAME, member for member with lockweather.frag's block.
        property vector4d geom: Qt.vector4d(width, height,
                                            weather.stillTime, weather.master)
        property vector4d wx:   Qt.vector4d(weather.condIndex, weather.dayness,
                                            weather.intensity, weather.wind)
        property vector4d fx:   Qt.vector4d(weather.flash, weather.fogAmount,
                                            weather.cloudAmount, weather.starDim)

        fragmentShader: Qt.resolvedUrl("shaders/lockweather.frag.qsb")
    }
}
