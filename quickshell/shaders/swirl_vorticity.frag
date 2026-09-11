#version 440
// Nyxus Suxyn — swirl sim, VORTICITY CONFINEMENT pass.
//
// Verbatim port of design/swirl-live.html FRAG.vorticity. This is the pass
// that makes the paint curl into spirals and filaments instead of drifting as
// smooth bands — the single biggest reason the earlier analytic-flow port read
// as "too smooth" against the reference.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float curl;          // reference: 50 (bar), 30–32 (small panels)
    float dt;
    vec4 texel;          // xy = velocity texel size
};
layout(binding = 1) uniform sampler2D uVelocity;
layout(binding = 2) uniform sampler2D uCurl;

void main() {
    vec2 uv = qt_TexCoord0;
    float L = texture(uCurl, uv - vec2(texel.x, 0.0)).x;
    float R = texture(uCurl, uv + vec2(texel.x, 0.0)).x;
    float T = texture(uCurl, uv + vec2(0.0, texel.y)).x;
    float B = texture(uCurl, uv - vec2(0.0, texel.y)).x;
    float C = texture(uCurl, uv).x;

    vec2 force = 0.5 * vec2(abs(T) - abs(B), abs(R) - abs(L));
    force /= length(force) + 0.0001;
    force *= curl * C;
    force.y *= -1.0;

    vec2 velocity = texture(uVelocity, uv).xy + force * dt;
    fragColor = vec4(clamp(velocity, -1000.0, 1000.0), 0.0, 1.0);
}
