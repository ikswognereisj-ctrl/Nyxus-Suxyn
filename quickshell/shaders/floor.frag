#version 440
// THE FLOOR — 80s multiplex INTERIOR. Opaque. Glossy black/pink checker,
// neon diamond inlays, blue coves. MAGMA stays on the laptop; this is the TV.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 uRes;
    float uTime;
    float uYaw;
    float uWalk;
    vec4 sweep0;
    vec4 sweep1;
    vec4 sweep2;
    vec4 sweep3;
    vec4 sweep4;
};

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float sdDiamond(vec2 p, float s) {
    p = abs(p);
    return (p.x + p.y) - s;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = uRes.x / max(uRes.y, 1.0);
    float horizon = 0.46;
    vec3 pink = vec3(1.00, 0.10, 0.32);
    vec3 red  = vec3(1.00, 0.16, 0.18);
    vec3 blue = vec3(0.18, 0.38, 1.00);
    vec3 cyan = vec3(0.10, 0.85, 1.00);
    vec3 col;

    if (uv.y < horizon) {
        // Dark multiplex ceiling.
        col = vec3(0.035, 0.032, 0.05);
        float cy = (horizon - uv.y) / max(horizon, 0.001);
        float x = uv.x + uYaw * 0.04;

        // Blue cove ribs.
        float cove = 0.0;
        cove = max(cove, smoothstep(0.035, 0.0, abs(cy - 0.22)));
        cove = max(cove, smoothstep(0.030, 0.0, abs(cy - 0.48)));
        cove = max(cove, smoothstep(0.025, 0.0, abs(cy - 0.72)));
        col += blue * cove * 0.55 * (0.6 + 0.4 * sin(x * 14.0 + uTime * 0.4));

        // Hanging neon diamonds (the ref).
        vec2 c0 = vec2(0.28 + uYaw * 0.03, 0.14);
        vec2 c1 = vec2(0.50, 0.10);
        vec2 c2 = vec2(0.72 - uYaw * 0.03, 0.15);
        vec2 p0 = (uv - c0) * vec2(aspect, 1.6);
        vec2 p1 = (uv - c1) * vec2(aspect, 1.6);
        vec2 p2 = (uv - c2) * vec2(aspect, 1.6);
        float d0 = abs(sdDiamond(p0, 0.11));
        float d1 = abs(sdDiamond(p1, 0.09));
        float d2 = abs(sdDiamond(p2, 0.11));
        float dia = smoothstep(0.018, 0.0, d0) + smoothstep(0.016, 0.0, d1) + smoothstep(0.018, 0.0, d2);
        col += mix(red, pink, 0.5 + 0.5 * sin(uTime * 0.7)) * dia * 1.15;

        // Back wall just above horizon — blue wash.
        float wall = smoothstep(0.00, 0.10, cy) * smoothstep(0.28, 0.12, cy);
        col = mix(col, vec3(0.06, 0.07, 0.16) + blue * 0.12, wall);
    } else {
        float z = (uv.y - horizon) / max(1.0 - horizon, 0.001);
        z = clamp(z, 0.0, 1.0);
        float persp = z * z * 0.38 + z * 0.62;
        float x = (uv.x - 0.5) / max(persp, 0.05) + uYaw * 0.22;
        float depth = (1.0 / max(persp, 0.05)) + uWalk * 4.5;
        vec2 g = vec2(x * 4.6, depth * 0.65);
        vec2 id = floor(g);
        vec2 f = fract(g);
        vec2 b = abs(f - 0.5);
        float chk = mod(id.x + id.y, 2.0);

        vec3 black = vec3(0.02, 0.02, 0.03);
        vec3 lite  = vec3(0.12, 0.12, 0.14);
        col = mix(black, lite, chk);

        // Neon diamond inlay on the tiles (pink/red + blue).
        float dia = abs(f.x - 0.5) + abs(f.y - 0.5);
        float ring = smoothstep(0.46, 0.40, dia) * smoothstep(0.28, 0.34, dia);
        vec3 inlay = mix(pink, blue, mod(id.x + id.y * 0.5, 2.0));
        col += inlay * ring * (0.75 + 0.25 * chk);

        // Gloss — wet multiplex floor.
        float spec = pow(max(0.0, 1.0 - abs(f.y - 0.28)), 12.0);
        col += vec3(0.55, 0.20, 0.35) * spec * 0.65 * (0.4 + 0.6 * chk);
        // Fake ceiling diamond reflection.
        float refl = pow(max(0.0, 1.0 - persp), 2.2) * 0.18;
        col += mix(red, blue, uv.x) * refl;

        float fog = smoothstep(0.0, 0.22, persp);
        col = mix(vec3(0.05, 0.04, 0.08), col, fog);
    }

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
