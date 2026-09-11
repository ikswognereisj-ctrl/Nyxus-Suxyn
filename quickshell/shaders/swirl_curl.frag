#version 440
// Nyxus Suxyn — swirl sim, CURL pass.
//
// Verbatim port of design/swirl-live.html FRAG.curl. The reference computes
// the four neighbour coordinates in its vertex shader from `texelSize`; Qt
// Quick's ShaderEffect owns the vertex stage, so they are computed here
// instead. Same four fetches, same arithmetic.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 texel;          // xy = velocity texel size (1/w, 1/h)
};
layout(binding = 1) uniform sampler2D uVelocity;

void main() {
    vec2 uv = qt_TexCoord0;
    float L = texture(uVelocity, uv - vec2(texel.x, 0.0)).y;
    float R = texture(uVelocity, uv + vec2(texel.x, 0.0)).y;
    float T = texture(uVelocity, uv + vec2(0.0, texel.y)).x;
    float B = texture(uVelocity, uv - vec2(0.0, texel.y)).x;
    fragColor = vec4(0.5 * (R - L - T + B), 0.0, 0.0, 1.0);
}
