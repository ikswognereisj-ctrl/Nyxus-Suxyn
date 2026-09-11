#version 440
// Nyxus Suxyn — swirl sim, CLEAR pass.
//
// Verbatim port of design/swirl-live.html FRAG.clear. Used once per frame to
// warm-start the pressure solve from 0.8 × last frame's solution, which is
// what lets 22 Jacobi iterations converge on a field this smooth.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float value;         // reference: pressure = 0.8
};
layout(binding = 1) uniform sampler2D uTexture;

void main() {
    fragColor = value * texture(uTexture, qt_TexCoord0);
}
