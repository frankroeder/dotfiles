#version 440

// DOOM PSX-style fire, stateless approximation. A real DOOM fire feeds
// the bottom row with hot pixels and lets a cooling+drift rule march the
// flames upward via per-frame state. We don't have a feedback buffer in
// the simple shader path, so this builds the same visual using
// multi-octave domain-warped noise heated from the bottom — same
// energy distribution, no per-frame state.
//
// The y-axis cools dramatically toward the top; horizontal turbulence
// gives the licking edges; per-row time offset keeps the flames moving.

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
    float a = 0.55;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = mat2(1.6, 1.2, -1.2, 1.6) * p;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    // Map to coords where y=0 is the bottom (hot) and y=1 is the top (cold).
    float yFromBottom = 1.0 - uv.y;
    float aspect = iResolution.x / max(iResolution.y, 1.0);

    float t = iTime;

    // Coordinates for the noise field. Time scrolls the field upward
    // (so flames appear to rise) plus a horizontal jitter that warps the
    // licks. Higher rows get more horizontal warp so the tongues fan out.
    vec2 base = vec2(uv.x * aspect * 3.0, uv.y * 5.0 - t * 1.4);

    // First-pass warp.
    vec2 warp = vec2(fbm(base + vec2(0.0, 0.0)),
                     fbm(base + vec2(5.2, 2.3))) * 0.45;
    warp *= 0.4 + yFromBottom * 1.4;   // more chaos higher up

    // Heat field: hot at bottom, eaten away by the warped noise.
    float n = fbm(base + warp);
    // A bottom-heavy heat profile: 1.0 at bottom, falls toward top.
    float heat = pow(yFromBottom, 1.6);
    // The flame body lives where the noise survives the heat cutoff.
    float flame = clamp(heat * 1.6 - (1.0 - n) * 1.2, 0.0, 1.0);

    // Crackle: an extra band of high-frequency noise that adds sparks
    // near the leading edge of the flames.
    float crackle = fbm(base * 2.8 + vec2(0.0, t * 4.0));
    flame = max(flame, smoothstep(0.78, 0.95, crackle) * heat * 0.7);

    // Embers fade to nothing very near the top.
    flame *= smoothstep(0.05, 0.25, yFromBottom);

    // Theme palette ramp. Bottom-most flames are seal-hot, mid is
    // accent, top is inkish — mirrors the red->yellow->white classic
    // fire palette, mapped onto the theme.
    vec3 col = colPaper.rgb * 0.06;
    col = mix(col, colSeal.rgb * 0.45, smoothstep(0.05, 0.30, flame));
    col = mix(col, colSeal.rgb,        smoothstep(0.30, 0.55, flame));
    col = mix(col, colAccent.rgb,      smoothstep(0.55, 0.78, flame));
    col = mix(col, colInk.rgb,         smoothstep(0.85, 0.98, flame));

    // Floor bloom: bottom edge gets a constant warm glow even where the
    // flames thin out.
    float floor_ = smoothstep(0.12, 0.0, yFromBottom);
    col += colSeal.rgb * floor_ * 0.45;

    // CRT scanlines + vignette to nail the cabinet feel.
    float scan = 0.92 + 0.08 * sin(uv.y * iResolution.y * 3.14159);
    col *= scan;
    float vig = smoothstep(1.35, 0.55, length((uv - 0.5) * 1.6));
    col *= 0.55 + 0.45 * vig;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
