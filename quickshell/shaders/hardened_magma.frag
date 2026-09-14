#version 440
// MAGMA look — same TILE SDF as ocular_crystal, different MATERIAL.
// Hardened magma: dark cooled crust, ember living in the cracks.
// Not a PNG. Ray-marched stone, mark etched in the face.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float uT;
    vec2  uPtr;
    vec2  uRes;
    float uDrift;
    float uEyeBoost;
    vec3  uEyeCol;
    float uMarkMode;
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
float fbm(vec3 p){
    float a = 0.5, s = 0.0;
    for (int i = 0; i < 5; i++){
        s += a * noise(p);
        p *= 2.07;
        a *= 0.52;
    }
    return s;
}

vec3 sampleSdf(vec2 xy){
    vec2 uv = vec2(xy.x * 0.5 + 0.5, 0.5 - xy.y * 0.5);
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec3(1.0, 0.0, 0.0);
    vec4 t = texture(uSdf, uv);
    return vec3((t.r - 0.5) * 2.0, t.g + t.b / 255.0, 0.0);
}
vec4 sampleMark(vec2 xy){
    vec2 uv = vec2(xy.x * 0.5 + 0.5, 0.5 - xy.y * 0.5);
    // App icons carry margins: sample their centre window so the glyph
    // fills the etch. Brand art (uMarkMode 1, the sigil) is drawn to fill
    // its canvas ring-to-ring, so it is sampled nearly whole — cropping
    // it to the icon window cuts the crescent and meander off.
    float win = mix(0.56, 0.92, uMarkMode);
    uv = (uv - vec2(0.5)) / win + vec2(0.5);
    if (any(lessThan(uv, vec2(0.02))) || any(greaterThan(uv, vec2(0.98))))
        return vec4(0.0);
    return texture(uEyes, uv);
}
float markInk(vec2 xy){
    // Occupancy of the icon silhouette. Alpha, not luminance — a dark
    // glyph still owns the face, so lava/white cannot fill it.
    return sampleMark(xy).a;
}
float markDilate(vec2 xy, float r){
    float m = 0.0;
    for (int i = 0; i < 12; i++){
        float a = float(i) * 0.5235987756;
        vec2 d = vec2(cos(a), sin(a));
        m = max(m, markInk(xy + d * r));
        m = max(m, markInk(xy + d * (r * 0.50)));
    }
    return m;
}
float map(vec3 p){
    vec3 t = sampleSdf(p.xy);
    float d = max(t.x, abs(p.z) - (THICK * t.y + 0.02));
    d += (fbm(p * 9.0) - 0.5) * 0.05;
    return d;
}
vec3 nrm(vec3 p){
    vec2 e = vec2(0.0035, 0.0);
    return normalize(vec3(map(p+e.xyy) - map(p-e.xyy),
                          map(p+e.yxy) - map(p-e.yxy),
                          map(p+e.yyx) - map(p-e.yyx)));
}
mat3 rotY(float a){ float c=cos(a), s=sin(a); return mat3(c,0,-s, 0,1,0, s,0,c); }
mat3 rotX(float a){ float c=cos(a), s=sin(a); return mat3(1,0,0, 0,c,s, 0,-s,c); }

vec3 env(vec3 d){
    float k = pow(max(dot(d, normalize(vec3(-0.35, 0.55, 0.60))), 0.0),  6.0);
    float r = pow(max(dot(d, normalize(vec3( 0.75,-0.15,-0.40))), 0.0),  4.0);
    float w = pow(max(dot(d, normalize(vec3( 0.10, 0.90,-0.20))), 0.0), 16.0);
    vec3 c = vec3(0.035, 0.018, 0.010);
    c += vec3(1.00, 0.38, 0.08) * k * 2.4;
    c += vec3(0.55, 0.12, 0.04) * r * 1.6;
    c += vec3(1.00, 0.72, 0.32) * w * 1.1;
    c += vec3(0.08, 0.03, 0.01) * (0.4 + 0.6 * d.y);
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
    // Faceted volcanic glass — the cubes in the MAGMA icon language.
    vec3 Nf = normalize(round(N * 4.0) / 4.0);
    N = normalize(mix(N, Nf, 0.82));
    float ndl = clamp(dot(N, normalize(vec3(-0.35, 0.78, 0.52))), 0.0, 1.0);
    float spec = pow(max(dot(reflect(-normalize(vec3(-0.35, 0.78, 0.52)), N), -rd), 0.0), 48.0);
    float fres = pow(1.0 - clamp(dot(N, -rd), 0.0, 1.0), 2.4);

    // Owner read 2026-09-14: the icon language was wearing the gold end
    // and reading YELLOW next to the bar's ember/rusted magma. Every hot
    // value here sits on the red-orange rung of the ladder instead.
    vec3 ember = (length(uEyeCol) > 0.05) ? uEyeCol : vec3(1.00, 0.32, 0.05);
    vec3 lava  = vec3(1.00, 0.31, 0.045);

    vec3 crust = vec3(0.018, 0.010, 0.009);
    crust += vec3(0.05, 0.022, 0.016) * noise(hp * 10.0);
    crust *= 0.14 + 0.86 * ndl;
    crust += vec3(0.50, 0.48, 0.46) * spec * 0.10;

    float n1 = fbm(hp * 4.8);
    float n2 = fbm(hp * 12.0 + 8.0);
    float crack = pow(max(1.0 - abs(n1 - 0.48) * 4.8, 0.0), 8.0);
    crack += pow(max(1.0 - abs(n2 - 0.50) * 6.2, 0.0), 12.0) * 0.7;
    crack = clamp(crack, 0.0, 1.0);

    // The etch needs a clean face to read against. Calm the crust and
    // close the cracks in the centre window of the tile — a cooled,
    // polished recess the glyph is cut into — and leave the living
    // crust to the stone's rim where it belongs.
    float etchZone = 1.0 - smoothstep(0.30, 0.58, max(abs(hp.x), abs(hp.y)));
    crust = mix(crust, vec3(0.016, 0.009, 0.008) * (0.14 + 0.86 * ndl),
                etchZone * 0.80);
    crack *= (1.0 - 0.85 * etchZone);

    // ── the etched mark ─────────────────────────────────────────────
    // Same construction as the glacier crystal (ocular_crystal.frag):
    // the mark is ETCHED, not pasted — the icon's dead plate is dropped
    // by luminance/chroma gates so the stone shows through, and only the
    // glyph and the per-app colour bloom ride on the face. The MAGMA
    // half of the pair: the gate math is identical, the light it glows
    // with is ember.
    float eb  = uEyeBoost > 0.001 ? uEyeBoost : 1.0;
    vec4  ic  = sampleMark(hp.xy);
    float lum = dot(ic.rgb, vec3(0.22, 0.67, 0.11));
    vec3  chroma = ic.rgb - vec3(lum);
    float sat = length(chroma);
    // uMarkMode 0: app icon — drop the dead plate, keep glyph + bloom.
    // uMarkMode 1: verbatim mark (the sigil) — its matte black IS the
    // art, so alpha alone carries it and the halo is not gated away.
    float gate = max(smoothstep(0.05, 0.18, lum),
                     smoothstep(0.025, 0.09, sat));
    float ink = ic.a * mix(gate, 1.0, uMarkMode);
    float dil = markDilate(hp.xy, 0.155);
    float outline = clamp(dil - ic.a, 0.0, 1.0)
                  * mix(smoothstep(0.02, 0.10, lum + sat), 1.0, uMarkMode);

    vec3 col = crust;
    float rock = 1.0 - max(ink, outline);
    col += lava * crack * 2.1 * rock;
    // Hot cracks: a hard boost through this tonemap saturates G up to R
    // and reads YELLOW. Lower ratio, lower gain — stays orange.
    col += vec3(1.0, 0.34, 0.06) * pow(crack, 2.4) * 2.2 * rock;
    col += env(reflect(rd, N)) * (0.02 + 0.10 * fres) * vec3(1.0, 0.38, 0.10);

    float rim = pow(max(1.0 - abs(sampleSdf(hp.xy).x) * 3.4, 0.0), 2.0);
    // Hot metal on the cube edge — the pale-ice line was the glacier read.
    vec3 rimHot = vec3(1.00, 0.40, 0.10);
    col += rimHot * rim * 1.35;

    // The glyph keeps its own chroma where it runs WARM; where it runs
    // cold (the NYXUS-Dark palette's ice/plum/violet all carry b > r)
    // it is re-hued onto the ember ladder by luminance, so no glacier
    // colour survives onto the magma stone. Verbatim marks (the sigil)
    // skip all of it — brand art stays as drawn.
    // b > g catches the whole cold band — ice, violet, AND plum/magenta
    // (plum carries red but always carries more blue than green). True
    // warms (red/orange/gold/green) have b <= g and keep their hue.
    // Cold pixels skip the chroma boost entirely: the boost would shove
    // their blue past 1.0 where it survives the tonemap. They ride the
    // ember ladder by luminance instead — fully, not as a tint.
    // Tight window: even near-white ice highlights (#edf1ff, b barely
    // over g) re-hue fully onto the ladder — no sage survivors.
    float coolness = smoothstep(-0.005, 0.06, ic.b - ic.g);
    vec3 boosted  = clamp(ic.rgb + chroma * 1.6, 0.0, 1.25);
    vec3 ladder   = mix(vec3(0.30, 0.05, 0.02), vec3(1.00, 0.70, 0.40),
                        smoothstep(0.06, 0.80, lum));
    vec3 coreEtch = mix(boosted, ladder, coolness) * (0.90 + 0.20 * eb);
    // Verbatim marks get a small lift so the art's whites stay white and
    // its matte black still parts from the crust after the ~10×
    // downsampling the bar size forces.
    vec3 core = mix(coreEtch,
                    ic.rgb * (1.02 + 0.20 * eb) + vec3(0.030) * ic.a,
                    uMarkMode);
    col = mix(col, core, ink * 0.94);
    col += core * ink * fres * 0.28;
    // Ember halo hugging the silhouette, so the etch reads lit from below.
    col += ember * outline * 0.55;

    col = 1.0 - exp(-col * 1.40);
    col = pow(max(col, 0.0), vec3(0.86));

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
