#version 440
// Nyxus Suxyn — swirl sim, ADVECTION pass (semi-Lagrangian backtrace).
//
// Verbatim port of design/swirl-live.html FRAG.advection.
//
// ⚠ `texel` is the VELOCITY texel size for BOTH the velocity and the dye
// advection. That is not a copy/paste slip, it is the reference: `_step` sets
// `P.advection.u.texelSize` once from `v.texelX/texelY` and then re-binds only
// uVelocity / uSource / dissipation for the dye pass (swirl-live.html lines
// 752–763). Dye therefore travels further per unit velocity than its own
// resolution would imply, and undoing that quirk visibly slows the paint.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float dt;
    float dissipation;   // reference: 0.16 velocity, 0.34 dye
    vec4 texel;          // xy = VELOCITY texel size (see note above)
};
layout(binding = 1) uniform sampler2D uVelocity;
layout(binding = 2) uniform sampler2D uSource;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 coord = uv - dt * texture(uVelocity, uv).xy * texel.xy;
    fragColor = texture(uSource, coord) / (1.0 + dissipation * dt);
}
