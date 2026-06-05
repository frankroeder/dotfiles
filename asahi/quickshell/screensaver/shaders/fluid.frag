#version 440

// Domain-warped fBm — looks like slow-moving ink in water. Two cascaded
// warp passes give the swirls a "fluid" feel rather than the static
// veining of single-pass noise. Theme accent picks out high-density
// regions; seal pools in the trailing wakes.

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

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i),               hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = mat2(1.6, 1.2, -1.2, 1.6) * p;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0 * 2.0 - 1.0;
    uv.x *= iResolution.x / max(iResolution.y, 1.0);
    uv *= 1.4;

    float t = iTime * 0.12;

    vec2 q = vec2(fbm(uv + t),
                  fbm(uv + vec2(5.2, 1.3) - t));

    vec2 r = vec2(fbm(uv + 2.0 * q + vec2(1.7, 9.2) + 1.5 * t),
                  fbm(uv + 2.0 * q + vec2(8.3, 2.8) - 1.5 * t));

    float f = fbm(uv + 2.5 * r);

    float density = clamp(f * f * 1.65, 0.0, 1.0);
    float wake    = clamp(length(r) * 0.85, 0.0, 1.0);
    float haze    = clamp(dot(q, q) * 0.55, 0.0, 0.45);

    vec3 col = mix(colPaper.rgb, colAccent.rgb, density);
    col = mix(col, colSeal.rgb, wake * 0.65);
    col = mix(col, colInk.rgb,  haze);

    // Soft vignette so the panel edges fade into paper.
    float vig = smoothstep(1.35, 0.55, length(uv));
    col = mix(colPaper.rgb, col, 0.30 + 0.70 * vig);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
