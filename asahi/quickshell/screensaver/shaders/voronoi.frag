#version 440

// Animated Voronoi cells on Lissajous site paths. Ported from hyprsaver (MIT, Mara Vexa).

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

vec3 palette(float t) {
    t = clamp(t, 0.0, 1.0);
    float x = t * 2.0;
    if (x < 1.0) return mix(colAccent.rgb, colSeal.rgb, x);
    return mix(colSeal.rgb, colInk.rgb, x - 1.0);
}

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453123);
}

// x = dist, y = id, z = unused, w = edge (1 away from border)
vec4 voronoi(vec2 p, float t, float cellSize) {
    vec2 ip = floor(p / cellSize);
    vec2 fp = fract(p / cellSize);
    float d1 = 1e9, d2 = 1e9, id = 0.0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            vec2 n = vec2(float(dx), float(dy));
            vec2 cell = ip + n;
            vec2 seed = hash2(cell);
            vec2 site = n + 0.5 + 0.45 * vec2(
                sin(t * (0.5 + seed.x * 0.8) + seed.x * 6.28318),
                cos(t * (0.5 + seed.y * 0.8) + seed.y * 6.28318));
            vec2 diff = fp - site;
            float d = dot(diff, diff);
            if (d < d1) { d2 = d1; d1 = d; id = seed.x; }
            else if (d < d2) { d2 = d; }
        }
    }
    float dist = sqrt(d1) * cellSize;
    float edge = smoothstep(0.0, 0.05, sqrt(d2) - sqrt(d1));
    return vec4(dist, id, 0.0, edge);
}

void main() {
    vec2 uv = (qt_TexCoord0 * iResolution - 0.5 * iResolution) / max(iResolution.y, 1.0);
    float t = iTime * 0.18;

    vec4 lg = voronoi(uv, t * 0.7, 0.22);
    vec4 sm = voronoi(uv, t * 1.3, 0.09);

    float tLg = abs(fract(lg.y + iTime * 0.05) * 2.0 - 1.0);
    float tSm = abs(fract(sm.y * 3.1 + sm.x * 0.8 + iTime * 0.08) * 2.0 - 1.0);
    vec3 col = mix(palette(tLg) * 0.5, palette(tSm), 0.6);

    vec3 edgeCol = palette(abs(fract(iTime * 0.04 + 0.3) * 2.0 - 1.0));
    col = mix(col, edgeCol * 1.4, (1.0 - sm.w) * 0.5);
    col = mix(col, edgeCol * 0.8, (1.0 - lg.w) * 0.25);
    col *= 0.6 + 0.4 * smoothstep(0.0, 0.072, sm.x);

    float vig = clamp(1.0 - dot(uv, uv) * 0.7, 0.0, 1.0);
    col = mix(colPaper.rgb, col, vig);
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
