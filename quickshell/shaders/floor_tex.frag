#version 440
// Top-down carpet for the 3D floor plane. Same locked diamond checker.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 uRes;
    float uTime;
};

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 g = uv * 14.0;
    vec2 id = floor(g);
    vec2 f = fract(g);
    float chk = mod(id.x + id.y, 2.0);
    vec3 black = vec3(0.02, 0.02, 0.03);
    vec3 lite  = vec3(0.11, 0.11, 0.13);
    vec3 col = mix(black, lite, chk);
    float dia = abs(f.x - 0.5) + abs(f.y - 0.5);
    float ring = smoothstep(0.46, 0.40, dia) * smoothstep(0.28, 0.34, dia);
    vec3 pink = vec3(1.00, 0.10, 0.32);
    vec3 blue = vec3(0.18, 0.38, 1.00);
    col += mix(pink, blue, mod(id.x, 2.0)) * ring * 0.9;
    float spec = pow(max(0.0, 1.0 - abs(f.y - 0.3)), 10.0);
    col += vec3(0.55, 0.18, 0.32) * spec * 0.45;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
