#version 440

// Slow rotating plasma — interlocking sine sheets plus a roaming radial
// pump. Three theme colours stratified by the plasma scalar so the same
// shader stays on-palette under any Asahi theme.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
    vec4 colPaper;
    vec4 colInk;
    vec4 colAccent;
    vec4 colSeal;
};

void main() {
    vec2 uv = qt_TexCoord0 * 2.0 - 1.0;
    uv.x *= iResolution.x / max(iResolution.y, 1.0);

    float t = iTime * 0.28;

    // Three planar sheets at coprime frequencies + one moving radial well.
    float v = 0.0;
    v += sin(uv.x * 3.1 + t * 1.0);
    v += sin(uv.y * 2.7 - t * 1.3 + 0.6);
    v += sin((uv.x + uv.y) * 2.1 + t * 0.8);

    vec2 c = vec2(0.55 * sin(t * 0.5), 0.45 * cos(t * 0.42));
    v += sin(length(uv - c) * 4.3 + t * 1.1);

    v = v * 0.25 + 0.5;
    float v2 = clamp(v, 0.0, 1.0);

    // Soft contour band — rim where the plasma sits mid-value.
    float band = 1.0 - smoothstep(0.05, 0.20, abs(v2 - 0.5));

    vec3 a = colPaper.rgb;
    vec3 b = colAccent.rgb;
    vec3 c2 = colSeal.rgb;

    vec3 col = mix(a, b, smoothstep(0.18, 0.62, v2));
    col = mix(col, c2, smoothstep(0.55, 0.92, v2));
    col += band * colInk.rgb * 0.07;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
