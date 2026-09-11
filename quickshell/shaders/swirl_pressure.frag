#version 440
// Nyxus Suxyn — swirl sim, PRESSURE (Jacobi) pass.
//
// Verbatim port of design/swirl-live.html FRAG.pressure. Swirl.qml instantiates
// this `pressureIterations` times (reference: 22) as a straight chain of
// ShaderEffectSource layers, which Qt updates in scene-graph order inside one
// frame — the same ping-pong the reference does with two FBOs.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 texel;          // xy = velocity texel size
};
layout(binding = 1) uniform sampler2D uPressure;
layout(binding = 2) uniform sampler2D uDivergence;

void main() {
    vec2 uv = qt_TexCoord0;
    float L = texture(uPressure, uv - vec2(texel.x, 0.0)).x;
    float R = texture(uPressure, uv + vec2(texel.x, 0.0)).x;
    float T = texture(uPressure, uv + vec2(0.0, texel.y)).x;
    float B = texture(uPressure, uv - vec2(0.0, texel.y)).x;
    float divergence = texture(uDivergence, uv).x;
    fragColor = vec4((L + R + B + T - divergence) * 0.25, 0.0, 0.0, 1.0);
}
