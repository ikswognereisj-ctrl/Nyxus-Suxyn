#version 440
// Nyxus Suxyn — THE EARTH ON THE LOCK SCREEN.
//
// The owner's ask, 2026-08-23: keep the starfield he already loves, and put a
// real Earth in it — turned so his own coordinates face him, lit by the actual
// sun for the actual minute, wearing the actual weather.
//
//   "add this layer to the already there background image"
//
// So this shader NEVER SAMPLES THE WALLPAPER. It writes premultiplied alpha and
// is composited over `lock-still.png` by the scene graph. The starfield is not
// re-encoded, not graded, not touched: outside the globe and its air, this
// shader's alpha is zero and his picture is his picture, bit for bit. That is
// also why the pinned `lock-still.png` path and md5 do not move.
//
// ── WHAT IS REAL HERE ────────────────────────────────────────────────────
// Everything. Nothing on this globe is decorative:
//   · surface + city lights  NASA Blue Marble / Black Marble, shipped.
//   · which way it faces     his latitude and longitude, which the weather
//                            fetch already downloads and now caches.
//   · the daylight line      solar declination and hour angle.
//   · the clouds             GOES GeoColor for his hemisphere and a global
//                            clean-infrared composite for the rest, both
//                            fetched by nyxus-lock-weather into a serve-stale
//                            cache. Missing frames degrade, never block.
//   · cloud HEIGHT           infrared brightness is really cloud-top
//                            temperature, and temperature is height. It is
//                            what casts the shadows and leans the tall storms
//                            out over the limb.
//   · lightning              fired only where the infrared says there is deep
//                            convection right now.
//
// ── THE THREE CORRECTIONS THAT COST THE MOST TO FIND ─────────────────────
// Measured 2026-08-23 against physical truth, not taste. Each one produced a
// picture that looked plausible and was wrong:
//
//   1. ICE IS NOT WEATHER. Snow and ice are cold (so infrared calls them high
//      cloud) and bright and neutral (so every visible-light test calls them
//      cloud too). The whole Arctic rendered as permanent overcast. The
//      surface is the tie-breaker: where Blue Marble is already white, the
//      brightness is ground.
//   2. THE CLEAR-SKY BASELINE RISES WITH LATITUDE. The surface itself gets
//      colder toward the poles, so a clear Canada reads as solid overcast on a
//      tropical threshold. `latAdj` is the correction a forecaster makes by
//      eye.
//   3. STORMS ARE THE RED END, NOT ANY COLOUR. The clean-IR enhancement ramps
//      grey -> green -> yellow -> red -> magenta as the top gets colder. Keying
//      "storm" on saturation alone called 19% of the planet a thunderstorm.
//      Keyed on hue it lands at ~2%, which is roughly the real number.
//
// ⛔ The lock screen's one job is to let the owner back in. This draws on a
// timer, not per frame — see LockEarth.qml. Nothing here may become a reason
// the password field stops accepting input.
//
// © 2026 JOSEPH A. SIERENGOWSKI · NYX-J5W-2026-SIERENGOWSKI-LOCKED

layout(location = 0) in  vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec4  uRes;      // xy = item size px      zw = globe centre px
    vec4  uGlobe;    // x  = radius px         y = time s   z = lightning  w = exposure
    vec4  uSun;      // xyz = unit vector to the sun (earth-fixed frame)
    vec4  uGeo;      // xy = camera lat, lon (rad)   zw = marker lat, lon (rad)
    vec4  uBox;      // GeoColor bbox: lonMin, lonMax, latMin, latMax (rad)
    vec4  uOpt;      // x = geo subsat lon (rad)  y = markerStrength  z = haveGeo  w = haveIr
};

layout(binding = 1) uniform sampler2D dayTex;
layout(binding = 2) uniform sampler2D nightTex;
layout(binding = 3) uniform sampler2D geoTex;   // GOES GeoColor, regional
layout(binding = 4) uniform sampler2D irTex;    // clean infrared, global

const float PI = 3.14159265359;

vec3 dirFromLatLon(float la, float lo){
    return vec3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo));
}
float lum(vec3 c){ return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
float satOf(vec3 c){
    float mx = max(max(c.r, c.g), c.b), mn = min(min(c.r, c.g), c.b);
    return mx > 0.001 ? (mx - mn) / mx : 0.0;
}
vec2 uvOf(vec3 w){
    return vec2(atan(w.x, w.z) / (2.0 * PI) + 0.5,
                0.5 - asin(clamp(w.y, -1.0, 1.0)) / PI);
}
float hash13(vec3 p){
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
vec3 aces(vec3 x){
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

// ── the weather, straight off the satellites ─────────────────────────────
// Returns (opacity, cloud-top height, deep convection). `lit` comes from the
// sun angle this shader already computes, and the GeoColor thresholds ride it,
// because GeoColor is itself day/night imagery: the same cloud reads ~0.7 at
// noon and ~0.3 at 3am.
vec3 weatherAt(vec3 w, float lit){
    vec2  uv  = uvOf(w);
    float lat = asin(clamp(w.y, -1.0, 1.0));
    float lon = atan(w.x, w.z);

    float cloud = 0.0, height = 0.0, storm = 0.0;

    if (uOpt.w > 0.5){
        vec3  ir = texture(irTex, uv).rgb;
        float mx = max(max(ir.r, ir.g), ir.b);
        if (mx > 0.02){                                   // 0 = outside every disc
            float l = (ir.r + ir.g + ir.b) / 3.0;
            float s = satOf(ir);
            float latAdj = 0.26 * smoothstep(35.0, 72.0, abs(degrees(lat)));
            float warm   = clamp((ir.r - ir.g) / max(ir.r, 0.001), 0.0, 1.0);
            storm  = clamp(smoothstep(0.30, 0.62, s) * smoothstep(0.10, 0.45, warm), 0.0, 1.0);
            cloud  = clamp(smoothstep(0.30 + latAdj, 0.72 + latAdj, l)
                         + smoothstep(0.25, 0.60, s), 0.0, 1.0);
            height = clamp(max(smoothstep(0.28 + latAdj, 0.85 + latAdj, l), storm), 0.0, 1.0);
        }
    }

    // GeoColor sees low stratus that infrared cannot — the deck that was
    // raining on the owner while every other source called it dry.
    if (uOpt.z > 0.5){
        float vis = dot(w, dirFromLatLon(0.0, uOpt.x));
        float e   = smoothstep(0.150, 0.62, vis)                  // the satellite's own horizon
                  * smoothstep(0.0, 0.09, lon - uBox.x) * smoothstep(0.0, 0.09, uBox.y - lon)
                  * smoothstep(0.0, 0.09, lat - uBox.z) * smoothstep(0.0, 0.09, uBox.w - lat);
        if (e > 0.001){
            vec3  g  = texture(geoTex, vec2((lon - uBox.x) / (uBox.y - uBox.x),
                                            (uBox.w - lat) / (uBox.w - uBox.z))).rgb;
            float mn = min(min(g.r, g.g), g.b);
            float a  = smoothstep(mix(0.13, 0.50, lit), mix(0.36, 0.80, lit), mn);
            a *= 1.0 - smoothstep(0.22, 0.48, satOf(g));    // a city is not a cloud
            cloud  = max(cloud, a * e);
            height = max(height, a * e * 0.35);
        }
    }
    return vec3(cloud, height, storm);
}

void main(){
    vec2  frag = qt_TexCoord0 * uRes.xy;
    // ⚠ Y IS FLIPPED HERE ON PURPOSE, AND IT IS NOT COSMETIC.
    // This shader was proven in a browser first, where gl_FragCoord.y counts
    // UPWARD from the bottom. `qt_TexCoord0.y` counts DOWNWARD from the top.
    // Ported straight across, +p.y therefore pointed at the SOUTH pole while
    // the maths below treats it as north, and the whole planet rendered
    // upside down — correct continents, correct terminator, correct weather,
    // hanging the wrong way up. The owner spotted it on hardware before any
    // test did, because every automated check here compares the render to
    // itself and a mirrored globe is self-consistent.
    vec2  p    = vec2(frag.x - uRes.z, uRes.w - frag.y) / uGlobe.x;
    float r2   = dot(p, p);
    float T    = uGlobe.y;
    vec3  air  = vec3(0.28, 0.55, 0.95);

    vec3  col = vec3(0.0);
    float a   = 0.0;

    if (r2 < 1.0){
        float z = sqrt(1.0 - r2);
        vec3  n = vec3(p, z);

        // Ry(lon) * Rx(-lat): the owner's coordinates dead centre, north up
        float cl = cos(uGeo.x), sl = sin(uGeo.x);
        vec3  q  = vec3(n.x, n.y * cl + n.z * sl, n.z * cl - n.y * sl);
        float co = cos(uGeo.y), so = sin(uGeo.y);
        vec3  w  = vec3(q.x * co + q.z * so, q.y, -q.x * so + q.z * co);

        vec2  uv    = uvOf(w);
        vec3  day   = texture(dayTex,   uv).rgb;
        vec3  night = texture(nightTex, uv).rgb;

        float ndl  = dot(w, uSun.xyz);
        float lit  = smoothstep(-0.10, 0.17, ndl);
        float dusk = smoothstep(-0.24, 0.05, ndl) * (1.0 - smoothstep(0.01, 0.33, ndl));

        // ── terrain, lit off the texture's own gradient ───────────────────
        vec2  tx  = 1.0 / vec2(textureSize(dayTex, 0));
        float lon = atan(w.x, w.z);
        float hL = lum(texture(dayTex, uv - vec2(tx.x, 0.0)).rgb);
        float hR = lum(texture(dayTex, uv + vec2(tx.x, 0.0)).rgb);
        float hD = lum(texture(dayTex, uv - vec2(0.0, tx.y)).rgb);
        float hU = lum(texture(dayTex, uv + vec2(0.0, tx.y)).rgb);
        vec3  east  = normalize(vec3(cos(lon), 0.0, -sin(lon)));
        vec3  north = cross(w, east);
        vec3  bump  = normalize(w - (east * (hR - hL) + north * (hU - hD)) * 2.4);
        float relief = mix(1.0, clamp(dot(bump, uSun.xyz) / max(ndl, 0.06), 0.55, 1.5),
                           0.55 * smoothstep(0.0, 0.35, ndl));

        // ── the deck, which has altitude ──────────────────────────────────
        // PARALLAX, AND THE FRAME IT HAS TO BE IN.  TRK-3710.
        //
        // The deck is sampled at a point displaced TOWARD THE CAMERA by its
        // own height, which is what makes a tall cloud sit above the ground
        // instead of being painted onto it. The displacement therefore has to
        // point along the view axis, and this line used to point it along the
        // world Z axis — the fixed direction of lat 0, lon 0, off the coast
        // of Ghana. That is the view axis only for an owner living there.
        //
        // MEASURED (docs/proof/lockdepth-0901/axisprobe.py, arithmetic on this
        // very expression, no render involved): at his 42.5N 83.6W the two
        // axes are 85.3 degrees apart, and the shipped one displaces every
        // pixel of the disc by a FLAT 0.527 of maximum — the same amount at
        // the middle as at the limb. A flat profile is the signature of a
        // sideways slide, not of parallax. Real parallax goes to zero where
        // you are looking straight down at the deck and peaks at the limb,
        // and the camera axis below measures 0.088 -> 0.207 -> 0.348 -> 0.511
        // -> 0.723 from disc centre outward, which is that curve.
        //
        // The camera axis in this shader's world frame is what n = (0,0,1)
        // becomes after the two rotations below, and that works out to the
        // camera's own sub-point. Same expression as `home`.
        vec3  wx0 = weatherAt(w, lit);
        vec3  wC  = normalize(w + dirFromLatLon(uGeo.x, uGeo.y) * wx0.g * 0.0750);
        vec3  wx  = weatherAt(wC, lit);
        float ch = wx.g;
        float storm = wx.b;

        float ice   = smoothstep(0.50, 0.78, min(min(day.r, day.g), day.b));
        float cloud = smoothstep(0.18, 0.66, wx.r * (1.0 - 0.85 * ice));
        storm *= 1.0 - 0.90 * ice;

        // shadow: length grows with height AND with how low the sun sits
        vec3  sTan = normalize(uSun.xyz - w * ndl);
        vec3  wxS  = weatherAt(normalize(wC - sTan * (0.0050 + 0.1150 * ch)
                                              / clamp(abs(ndl) + 0.18, 0.18, 1.0)), lit);
        float shadow = 1.0 - 0.780 * wxS.r * smoothstep(0.02, 0.30, wxS.g + 0.12)
                              * smoothstep(-0.02, 0.28, ndl) * (1.0 - cloud * 0.55);

        // THE PUFF IS A FINITE DIFFERENCE, SO ITS BASELINE IS A NOISE FILTER.
        // TRK-3709. The two samples used to sit 0.006 rad apart, which at the
        // shipped globe size is about two and a half texels of a 4096x2048
        // infrared frame — so raising the gain amplified SENSOR NOISE exactly
        // as hard as it amplified cloud structure, and the sweep's strongest
        // renders broke into salt-and-pepper. Widening the baseline to 0.010
        // and scaling the gain down by the same ratio (6.0 -> 4.8 was the
        // ship-equivalent; the depth pass then took it back up) leaves the
        // response to a real slope unchanged and averages the noise away.
        // Measured across the sweep: same contrast, puffSD 18.23 -> 18.03,
        // and the terminator gradient falls 5.39 -> 5.19.
        float puff = clamp((weatherAt(normalize(wC + sTan * 0.0100), lit).g
                          - weatherAt(normalize(wC - sTan * 0.0100), lit).g) * 4.80, -0.720, 0.950);

        // ── surface ───────────────────────────────────────────────────────
        vec3 surf = day * (0.055 + 1.06 * lit) * relief * shadow;
        surf = mix(surf, surf * vec3(1.26, 0.86, 0.63), dusk * 0.62);

        float water = smoothstep(0.04, 0.16, day.b - day.r)
                    * (1.0 - smoothstep(0.22, 0.40, lum(day)));
        surf += vec3(1.0, 0.95, 0.86)
              * pow(max(dot(w, normalize(uSun.xyz + vec3(0.0, 0.0, 1.0))), 0.0), 90.0)
              * water * 0.85 * smoothstep(0.0, 0.2, ndl) * (1.0 - cloud);

        // Black Marble carries a faint terrain base between the cities, and
        // multiplied up for the lights that base became a purple wash over
        // every dark continent. Measured: the base plateaus at 0.329 and real
        // cities are the top ~1%. Cutting at 0.28 keeps only light.
        vec3  lights   = max(night - vec3(0.28), vec3(0.0)) * 1.9;
        float nightAmt = pow(1.0 - lit, 2.2);
        surf += lights * vec3(1.0, 0.80, 0.52) * nightAmt * 2.2 * (1.0 - cloud * 0.88);

        // ── the deck itself ───────────────────────────────────────────────
        // A higher, colder top is a THICKER top, and a thicker top is
        // brighter — so the one term here that adds light is the one that
        // gives back part of what the deeper shadows cost the daylit
        // hemisphere. Measured: it is the only lever in the sweep that raises
        // contrast (+1.08 L) while raising mean lightness rather than
        // lowering it, and the black floor moves 0.98 -> 1.00, still BELOW
        // the 1.02 that ships. Nothing here is allowed to lift that floor.
        vec3 cloudCol = vec3(0.055 + 1.0 * lit) * (1.0 + puff * 0.800) * (1.0 + 0.180 * ch);
        cloudCol = mix(cloudCol, cloudCol * vec3(1.28, 0.84, 0.62), dusk * 0.85);
        cloudCol += vec3(1.0, 0.80, 0.52) * lum(lights) * nightAmt * 0.9;
        cloudCol *= 1.0 + storm * 0.22 * lit;
        surf = mix(surf, cloudCol, cloud * 0.93);

        // ── lightning ─────────────────────────────────────────────────────
        // What you see of a storm from orbit at night is not rain: it is the
        // deck lighting up from inside. Cells are hashed off their own
        // position so a system crackles instead of blinking in unison.
        if (uGlobe.z > 0.5 && storm > 0.18){
            vec3  cell = floor(wC * 210.0);
            float seed = hash13(cell);
            float rate = 0.55 + seed * 1.7;
            float ph   = fract(T * rate + seed * 37.0);
            float fl   = (exp(-ph * 26.0) + 0.55 * exp(-abs(ph - 0.07) * 60.0))
                       * step(0.55, hash13(cell + vec3(floor(T * rate))));
            float vis  = fl * storm * smoothstep(0.10, 0.42, cloud) * (1.0 - lit * 0.82);
            surf += vec3(0.80, 0.88, 1.0) * vis * 2.6;
            surf += vec3(0.55, 0.68, 1.0) * vis * cloud * 0.9;
        }

        // ── limb, then the air over the top of it ─────────────────────────
        surf *= 0.52 + 0.48 * smoothstep(0.0, 0.45, z);
        surf += mix(air, vec3(1.0, 0.52, 0.24), dusk * 0.75)
              * pow(1.0 - z, 3.2) * (0.30 + 1.05 * smoothstep(-0.18, 0.5, ndl));

        vec3  home = dirFromLatLon(uGeo.z, uGeo.w);
        float dm   = distance(w, home);
        surf += vec3(0.72, 0.92, 1.0)
              * (smoothstep(0.055, 0.043, dm) - smoothstep(0.036, 0.024, dm))
              * uOpt.y * step(0.0, dot(w, home));

        col = surf;
        a   = 1.0;
    }

    // the air outside the disc, weighted to the sunlit side. This is the ONLY
    // place the shader writes over the owner's starfield, and it is a glow.
    float halo = exp(-max(r2 - 1.0, 0.0) * 30.0) * (1.0 - step(r2, 1.0));
    if (halo > 0.0){
        float face = smoothstep(-0.40, 0.55, dot(normalize(vec3(p, 0.001)), uSun.xyz));
        float ha   = halo * (0.10 + 0.80 * face);
        col += air * ha;
        a    = max(a, ha);
    }

    col = aces(col * uGlobe.w);
    col += (fract(sin(dot(frag, vec2(12.9898, 78.233)) + T) * 43758.5453) - 0.5) / 255.0;

    fragColor = vec4(col * a, a) * qt_Opacity;
}
