#version 440
// Small Start gem — ocular_crystal's STUDIO (env / fresnel / ice), as a
// rounded tile you can turn with the mouse. No ray-march: that .qsb
// compiled and then ShaderEffect refused to deserialize it (same trap as
// crystal_etch.frag). Analytical cabochon, same look through on uPtr.
// Colourless body; uTint only on the fresnel. Compile: shaders/build.sh.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float uT;
    vec2  uPtr;
    vec2  uRes;
    float uHover;
    float uOn;
    vec4  uTint;
};

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

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float sdRoundBox(vec2 p, vec2 b, float r){
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main(){
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uRes.x / max(uRes.y, 1.0);

    float hv = clamp(uHover, 0.0, 1.0);
    float on = clamp(uOn, 0.0, 1.0);
    vec2 ptr = uPtr * (0.40 + 0.55 * hv);

    // Turn the slab: parallax the surface so the view looks through it.
    p -= ptr * 0.22;
    float d = sdRoundBox(p, vec2(0.72, 0.72), 0.22);
    float disc = 1.0 - smoothstep(0.00, 0.035, d);
    if (disc < 0.01) {
        fragColor = vec4(0.0);
        return;
    }

    float z = sqrt(max(0.0, 1.0 - min(dot(p, p), 1.0))) * 0.85;
    vec3 N = normalize(vec3(p, z + 0.12));
    vec3 V = normalize(vec3(-ptr.x, -ptr.y, 1.15));
    float fres = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 4.0);

    vec3 rd = -V;
    vec3 rr = refract(rd, N, 0.95);
    vec3 col = env(normalize(rr)) * 0.52;

    float spark = hash(uv * 36.0 + vec2(uT * 0.11));
    col += vec3(0.82, 0.95, 1.00) * spark * (0.10 + 0.16 * hv);
    col += env(reflect(rd, N)) * (0.05 + 0.85 * fres);

    vec3 edge = uTint.rgb;
    if (edge.r + edge.g + edge.b < 0.001)
        edge = vec3(0.72, 0.90, 0.95);
    // Colour sits on the crystal, not in it: a wash when latched, a
    // brighter fresnel when you turn it.
    col += edge * (0.10 + 0.20 * on + 0.14 * hv);
    col += edge * fres * (0.35 + 0.50 * hv + 0.20 * on);
    col += edge * pow(max(1.0 - abs(d) * 9.0, 0.0), 3.0) * 0.40;

    col = 1.0 - exp(-col * 2.15);
    col = pow(max(col, 0.0), vec3(0.92));
    float a = clamp(max(col.r, max(col.g, col.b)) * 1.9, 0.0, 1.0) * disc;
    fragColor = vec4(col * a, a) * qt_Opacity;
}
