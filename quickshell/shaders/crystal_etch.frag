#version 440
// Same studio glass as ocular_crystal.frag (the etched alien head).
// A circular cabochon; the app icon is the sub-surface etch.
// env() / etch ice / tonemap copied from the mark. Compile: shaders/build.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;   // rgb = glass body tint · a = hover 0..1
    vec4 mouse;  // xy 0..1 · z time seconds · w unused
};

layout(binding = 1) uniform sampler2D source;

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

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * 2.0 - 1.0;
    float r = length(p);
    float disc = 1.0 - smoothstep(0.86, 1.0, r);
    if (disc < 0.01) {
        fragColor = vec4(0.0);
        return;
    }

    vec4 src = texture(source, uv);
    float etch = clamp(src.a, 0.0, 1.0);
    float hover = clamp(tint.a, 0.0, 1.0);

    vec2 ptr = (mouse.xy - 0.5) * (0.35 + 0.40 * hover);
    vec3 V = normalize(vec3(-ptr.x, -ptr.y, 1.0));
    float z = sqrt(max(0.0, 1.0 - r * r));
    vec3 N = normalize(vec3(p, z + 0.12));
    float fres = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 4.0);

    vec3 rd = -V;
    vec3 rr = refract(rd, N, 0.95);
    vec3 col = env(normalize(rr)) * 0.52;
    col *= mix(vec3(1.0), tint.rgb, 0.28);

    // Sub-surface etch: the icon sits in a shell under the face, ice points
    // of light the way the alien mark is laser-engraved in the crystal.
    float spark = hash(uv * 48.0 + vec2(mouse.z * 0.04));
    float shell = etch * (0.55 + 0.45 * hover);
    col += vec3(0.82, 0.95, 1.00) * shell * (0.38 + 0.22 * spark);
    col += src.rgb * etch * 0.22;
    col += vec3(0.60, 0.84, 1.00) * pow(max(1.0 - abs(r - 0.78) * 8.0, 0.0), 3.0) * 0.45;
    col += env(reflect(rd, N)) * (0.05 + 0.85 * fres);
    col += vec3(0.78, 0.93, 1.00) * hover * fres * 0.35;

    col = 1.0 - exp(-col * 2.15);
    col = pow(max(col, 0.0), vec3(0.92));
    float a = clamp(max(col.r, max(col.g, col.b)) * 1.9, 0.0, 1.0) * disc;
    fragColor = vec4(col * a, a) * qt_Opacity;
}
