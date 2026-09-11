#version 440
// Nyxus Suxyn — swirl sim, DIVERGENCE pass.
//
// Verbatim port of design/swirl-live.html FRAG.divergence, including the
// free-slip boundary reflection (the `if (vL.x < 0.0) L = -C.x` block); the
// neighbour coordinates it tests are reconstructed here because Qt Quick owns
// the vertex stage.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 texel;          // xy = velocity texel size
};
layout(binding = 1) uniform sampler2D uVelocity;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 vL = uv - vec2(texel.x, 0.0);
    vec2 vR = uv + vec2(texel.x, 0.0);
    vec2 vT = uv + vec2(0.0, texel.y);
    vec2 vB = uv - vec2(0.0, texel.y);

    float L = texture(uVelocity, vL).x;
    float R = texture(uVelocity, vR).x;
    float T = texture(uVelocity, vT).y;
    float B = texture(uVelocity, vB).y;
    vec2 C = texture(uVelocity, uv).xy;
    if (vL.x < 0.0) { L = -C.x; }
    if (vR.x > 1.0) { R = -C.x; }
    if (vT.y > 1.0) { T = -C.y; }
    if (vB.y < 0.0) { B = -C.y; }

    fragColor = vec4(0.5 * (R - L + T - B), 0.0, 0.0, 1.0);
}
