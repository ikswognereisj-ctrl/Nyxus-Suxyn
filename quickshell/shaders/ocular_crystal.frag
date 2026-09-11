#version 440
// NYXUS Suxyn — OCULAR MARK, etched crystal. Owner ruling 2026-09-05.
//
// The mark as a SOLID, not a picture of one: a 3-D signed distance field
// ray-marched per fragment, with the form written inside the block as points
// of light the way a laser sub-surface engraving sits in glass.
//
// Identity (owner 2026-09-10): dialed-back clear ice. Same studio / etch /
// look-through. Less internal sparkle so a 52 px gem still reads as a stone
// you look through, not a fog of dots. Shape stays the TILE, never the head.
//
// The geometry is NOT modelled. `uSdf` is baked from the mark's own artwork:
//   R = signed 2-D distance of the silhouette, 0.5 = the outline, < 0.5 inside
//   G = dome height, HIGH byte        B = dome height, LOW byte
//   A = 255, ALWAYS   -> height = G + B/255
// Height is 16-bit on purpose: at 8 bits the normals band into concentric
// rings, which is invisible on a matte body and glaring on a reflective one.
//
// ⚠ ALPHA IS NOT A FREE CHANNEL, and this cost us a bug. The first cut packed
// the height's low byte into A. Qt's image loader PREMULTIPLIES rgb by alpha,
// so the distance field was silently scaled to ~22% of its value, map() then
// reported "inside" everywhere and the mark rendered as an opaque box. It is
// not fixable in the shader either: A is legitimately 0 outside the head,
// which is exactly where the distance still has to be readable. So A is
// pinned to 255 (premultiply becomes the identity) and the eye mask moved to
// its own texture. Caught by the pre-release audit seat on the real GPU.
//
// Ported from prism_gl.js (WebGL2). Compile with shell/shaders/build.sh, the
// same qsb path the swirl shaders take. ⚠ Shader edits render only after a
// shell RESTART — reloads never flush compiled pipelines.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float uT;        // seconds, for the slow idle drift
    vec2  uPtr;      // view angle, -1..1. Leave at 0,0 for a still mark.
    vec2  uRes;      // item size in px
    float uDrift;    // 0 = hold the pose (login screen), 1 = let it turn
    // ⚠ std140: a vec3 must start on a 16-byte boundary. uDrift ends at 92,
    // so the float goes HERE to fill to 96 and uEyeCol lands aligned. The
    // reverse order leaves a silent 4-byte hole and the floats read garbage.
    float uEyeBoost; // gain on the eyes. 1.0 = at rest.
    vec3  uEyeCol;   // the eyes carry auth state. (0,0,0) = use the default.
};
layout(binding = 1) uniform sampler2D uSdf;
layout(binding = 2) uniform sampler2D uEyes;

const float THICK = 0.42;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec3 p){
    vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
    float n = i.x + i.y * 57.0 + i.z * 113.0;
    return mix(mix(mix(fract(sin(n)*43758.5),        fract(sin(n+1.0)*43758.5),  f.x),
                   mix(fract(sin(n+57.0)*43758.5),   fract(sin(n+58.0)*43758.5), f.x), f.y),
               mix(mix(fract(sin(n+113.0)*43758.5),  fract(sin(n+114.0)*43758.5),f.x),
                   mix(fract(sin(n+170.0)*43758.5),  fract(sin(n+171.0)*43758.5),f.x), f.y), f.z);
}

vec3 sampleSdf(vec2 xy){
    vec2 uv = vec2(xy.x * 0.5 + 0.5, 0.5 - xy.y * 0.5);
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec3(1.0, 0.0, 0.0);
    vec4 t = texture(uSdf, uv);
    return vec3((t.r - 0.5) * 2.0, t.g + t.b / 255.0, 0.0);
}

// App mark, mapped into the face of the stone. Dark plate pixels of the
// Nyxus SVG ground are dropped so only the coloured glyph/arc lives in
// the crystal — one object, not an icon stuck on a tile.
vec4 sampleMark(vec2 xy){
    vec2 uv = vec2(xy.x * 0.5 + 0.5, 0.5 - xy.y * 0.5);
    // 0.64: enough of the coloured arc/glyph to fill the face, still
    // cropping the dark Nyxus plate corners.
    uv = (uv - vec2(0.5)) / 0.64 + vec2(0.5);
    if (any(lessThan(uv, vec2(0.02))) || any(greaterThan(uv, vec2(0.98))))
        return vec4(0.0);
    return texture(uEyes, uv);
}
float map(vec3 p){
    vec3 t = sampleSdf(p.xy);
    return max(t.x, abs(p.z) - (THICK * t.y + 0.012));
}
vec3 nrm(vec3 p){
    vec2 e = vec2(0.0035, 0.0);
    return normalize(vec3(map(p+e.xyy) - map(p-e.xyy),
                          map(p+e.yxy) - map(p-e.yxy),
                          map(p+e.yyx) - map(p-e.yyx)));
}
mat3 rotY(float a){ float c=cos(a), s=sin(a); return mat3(c,0,-s, 0,1,0, s,0,c); }
mat3 rotX(float a){ float c=cos(a), s=sin(a); return mat3(1,0,0, 0,c,s, 0,-s,c); }

// A dark studio. No procedural starfield: a grid-aligned hash in DIRECTION
// space draws a dashed quadrilateral straight through the refraction.
vec3 env(vec3 d){
    float k = pow(max(dot(d, normalize(vec3(-0.45, 0.62, 0.55))), 0.0),  5.0);
    float r = pow(max(dot(d, normalize(vec3( 0.70,-0.25,-0.45))), 0.0),  3.0);
    float w = pow(max(dot(d, normalize(vec3( 0.25, 0.85,-0.40))), 0.0), 12.0);
    float f = pow(max(dot(d, normalize(vec3( 0.15,-0.85, 0.30))), 0.0), 24.0);
    vec3 c = vec3(0.045, 0.085, 0.115);
    c += vec3(0.78, 0.93, 1.00) * k * 3.4;
    c += vec3(0.16, 0.46, 0.72) * r * 2.2;
    c += vec3(1.00, 0.76, 0.44) * w * 1.7;
    c += vec3(0.35, 0.62, 0.85) * f * 0.9;
    c += vec3(0.05, 0.10, 0.16) * (0.5 + 0.5 * d.y);
    return c;
}

bool march(vec3 ro, vec3 rd, out vec3 hp){
    float t = 0.0;
    for (int i = 0; i < 128; i++){
        hp = ro + rd * t;
        float d = map(hp);
        if (d < 0.0016) return true;
        t += max(d * 0.85, 0.0016);
        if (t > 5.0) break;
    }
    return false;
}
vec3 marchOut(vec3 ro, vec3 rd){
    float t = 0.004;
    for (int i = 0; i < 96; i++){
        vec3 p = ro + rd * t;
        if (map(p) > 0.0) return p;
        t += 0.010;
        if (t > 3.0) break;
    }
    return ro + rd * t;
}

void main(){
    vec2 uv = vec2(qt_TexCoord0.x * 2.0 - 1.0, 1.0 - qt_TexCoord0.y * 2.0);
    uv.x *= uRes.x / max(uRes.y, 1.0);

    vec2 ptr = uPtr + uDrift * vec2(sin(uT * 0.30) * 0.62, cos(uT * 0.23) * 0.40);
    mat3 Ri = rotX(ptr.y * 0.62) * rotY(-ptr.x * 0.85);

    vec3 ro = Ri * vec3(0.0, 0.0, 2.6);
    vec3 rd = Ri * normalize(vec3(uv * 0.46, -1.0));

    vec3 hp;
    if (!march(ro, rd, hp)) { fragColor = vec4(0.0); return; }

    vec3 N = nrm(hp);
    float fres = pow(1.0 - clamp(dot(N, -rd), 0.0, 1.0), 4.0);

    vec3 rr = refract(rd, N, 0.95);
    vec3 xp = marchOut(hp, rr);
    float path = length(xp - hp);

    // Identity "dialed back": more studio through the volume, less murk.
    vec3 col = env(normalize(rr)) * 0.70 * exp(-path * 0.10);

    // Laser etch is a THIN sheet under the face — not a fog of dots.
    // 12 samples, tight shell. Sparkle stays a hint, not the material.
    float acc = 0.0;
    for (int i = 0; i < 12; i++){
        vec3 sp = mix(hp, xp, float(i) / 11.0);
        float shell = 1.0 - smoothstep(0.0, 0.10,
                        abs(sampleSdf(sp.xy).x) + abs(abs(sp.z) - 0.16) * 2.4);
        acc += smoothstep(0.88, 0.998, noise(sp * 38.0)) * shell;
    }
    col += vec3(0.82, 0.95, 1.00) * acc * 0.12;
    col += vec3(0.60, 0.84, 1.00) * pow(max(1.0 - abs(sampleSdf(hp.xy).x) * 7.0, 0.0), 3.0) * 0.18;
    col += env(reflect(rd, N)) * (0.08 + 0.90 * fres);

    float eb = uEyeBoost > 0.001 ? uEyeBoost : 1.0;
    vec4  ic = sampleMark(hp.xy);
    float lum = dot(ic.rgb, vec3(0.22, 0.67, 0.11));
    vec3  chroma = ic.rgb - vec3(lum);
    float sat = length(chroma);
    // Drop the dead Nyxus plate (#071318, no chroma). Keep the pale
    // glyph, the coloured arc, AND the per-app bloom in the centre —
    // that bloom is the colour of the icon, and ice was eating it.
    float ink = ic.a * max(smoothstep(0.05, 0.18, lum),
                           smoothstep(0.025, 0.09, sat));
    vec3 core = clamp(ic.rgb + chroma * 1.6, 0.0, 1.25) * (0.90 + 0.20 * eb);
    col = mix(col, core, ink * 0.94);
    col += core * ink * fres * 0.28;

    col = 1.0 - exp(-col * 1.65);
    col = pow(max(col, 0.0), vec3(0.94));
    float a = clamp(max(col.r, max(col.g, col.b)) * 1.7, 0.0, 1.0);
    fragColor = vec4(col * a, a) * qt_Opacity;   // premultiplied
}
