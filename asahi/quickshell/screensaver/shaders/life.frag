#version 440

// Conway's Game of Life. Samples the previous frame from `prev` (a
// recursive ShaderEffectSource), counts the 8-neighbours, and applies
// B3/S23. Encodes state in the alpha channel so the visible RGB can
// carry full theme colour. Every `seedSec` seconds, the field is
// re-seeded with a random density of live cells — Life tends to settle
// into still-lifes and short oscillators, and the reseed keeps the
// motion going.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D prev;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
    vec4 colPaper;
    vec4 colInk;
    vec4 colAccent;
    vec4 colSeal;
    // Grid resolution (passed in from QML).
    vec2 gridSize;
    // Seconds per session within which Life evolves before a reseed.
    float seedSec;
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = qt_TexCoord0;

    // Snap to cell centre so neighbour sampling is exact regardless of
    // the downstream display resolution.
    vec2 cell = floor(uv * gridSize);
    vec2 cellCenter = (cell + 0.5) / gridSize;
    vec2 texel = 1.0 / gridSize;

    // Reseed window: first 4 frames of every `seedSec`. iTime resets to
    // zero whenever this shader becomes active in shell.qml.
    float sessionT = mod(iTime, seedSec);
    bool reseed = sessionT < 0.10;

    int next;
    if (reseed) {
        // Random seeding with ~22% density — gives a busy initial field
        // that produces gliders and oscillators within a few steps.
        float h = hash(cell + floor(iTime / seedSec) * 7.31);
        next = h < 0.22 ? 1 : 0;
    } else {
        // Read 8 neighbours. State lives in alpha.
        int n = 0;
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                if (i == 0 && j == 0) continue;
                vec2 ns = cellCenter + vec2(float(i), float(j)) * texel;
                // Wrap edges — toroidal world, classic Life screensaver.
                ns = fract(ns);
                if (texture(prev, ns).a > 0.5) n++;
            }
        }
        int self = texture(prev, cellCenter).a > 0.5 ? 1 : 0;
        // B3/S23: born if dead with exactly 3 neighbours; survives if
        // alive with 2 or 3.
        if (self == 1) next = (n == 2 || n == 3) ? 1 : 0;
        else           next = (n == 3) ? 1 : 0;
    }

    float alive = float(next);

    // Visual: alive cells use accent; dead cells use a dim paper tone.
    // Cells that just died (alive in prev, dead now) get a brief ghost
    // tint in seal to add a phosphor trail.
    int wasAlive = texture(prev, cellCenter).a > 0.5 ? 1 : 0;
    float ghost = (wasAlive == 1 && next == 0) ? 1.0 : 0.0;

    vec3 col = colPaper.rgb * 0.08;
    col = mix(col, colSeal.rgb * 0.45, ghost);
    col = mix(col, colAccent.rgb,      alive);

    // Slight grid line so the cells read as a pixel grid.
    vec2 cellUV = fract(uv * gridSize);
    float edge = smoothstep(0.06, 0.0, min(cellUV.x, 1.0 - cellUV.x))
               + smoothstep(0.06, 0.0, min(cellUV.y, 1.0 - cellUV.y));
    col -= edge * 0.018;

    // CRT scan + vignette so it matches the rest of the screensaver.
    float scan = 0.93 + 0.07 * sin(uv.y * iResolution.y * 1.45);
    col *= scan;
    float vig = smoothstep(1.30, 0.55, length((uv - 0.5) * 1.6));
    col *= 0.55 + 0.45 * vig;

    fragColor = vec4(col, alive);
}
