#version 440
// Nyxus Suxyn — stained-glass core for launcher tiles.
// Icon alpha is the pane. Hover lights glacier[0] through the crystal plate.
// Rebuild: bash ~/.config/quickshell/shaders/build.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;   // rgb = core hue · a = hover 0..1
    vec4 mouse;  // xy 0..1 inside the tile · z time · w unused
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 src = texture(source, uv);
    float mask = clamp(src.a, 0.0, 1.0);
    if (mask < 0.02) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 m = mouse.xy;
    float d = distance(uv, m);
    float hover = clamp(tint.a, 0.0, 1.0);
    float glow = exp(-d * 7.0) * hover;
    vec3 ice = vec3(0.498, 0.910, 1.000); // glacier[0] #7fe8ff — hover light only
    vec3 body = mix(tint.rgb, ice, glow * 0.55);
    float ca = (uv.x - 0.5) * 0.018 * hover;
    vec4 shift = texture(source, uv + vec2(ca, 0.0));
    body = mix(body, shift.rgb * tint.rgb, 0.22 * hover);
    float glass = 0.42 + 0.38 * hover + glow * 0.35;
    fragColor = vec4(body * mask * glass, mask * (0.55 + 0.40 * hover)) * qt_Opacity;
}
