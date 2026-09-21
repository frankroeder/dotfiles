#version 440

// Grid of drifting fireflies, 9-neighbour Gaussian. Ported from hyprsaver (MIT, Mara Vexa).

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

const vec2 GRID = vec2(20.0, 12.0);
const float FALLOFF_K = 120.0;
const float TAU = 6.283185307;

vec3 palette(float t) {
    t = fract(t);
    float x = t * 2.0;
    if (x < 1.0) return mix(colAccent.rgb, colSeal.rgb, x);
    return mix(colSeal.rgb, colInk.rgb, x - 1.0);
}

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 cell = uv * GRID;
    vec2 cellId = floor(cell);
    vec2 cellFrac = fract(cell);
    float t = iTime;
    vec3 acc = vec3(0.0);

    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            vec2 nid = cellId + vec2(float(dx), float(dy));
            float h = hash21(nid);
            float h2 = hash21(nid + vec2(17.3, 5.7));
            float hPal = hash21(nid + vec2(17.3, 31.7));
            vec2 offset = 0.35 * vec2(
                sin(t * (0.3 + 0.3 * h) + h * TAU),
                cos(t * (0.2 + 0.4 * h2) + h2 * TAU * 1.3));
            vec2 pos = vec2(float(dx), float(dy)) + 0.5 + offset;
            vec2 d = cellFrac - pos;
            float pulse = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * (0.3 + 0.5 * h) + h * TAU));
            vec3 c = palette(fract(h + t * 0.05 + hPal));
            acc += c * pulse * exp(-dot(d, d) * FALLOFF_K);
        }
    }

    vec3 col = colPaper.rgb * 0.10 + acc;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
