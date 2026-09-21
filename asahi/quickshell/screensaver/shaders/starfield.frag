#version 440

// Hyperspace warp: 20 star layers zooming from center. Ported from hyprsaver (MIT, Mara Vexa).

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

const int NUM_LAYERS = 20;
const float SPEED = 0.36;

vec3 palette(float t) {
    t = fract(t);
    float x = t * 2.0;
    if (x < 1.0) return mix(colAccent.rgb, colSeal.rgb, x);
    return mix(colSeal.rgb, colInk.rgb, x - 1.0);
}

float Hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec2 Hash22(vec2 p) {
    float n = Hash21(p);
    return vec2(n, Hash21(p + n));
}

mat2 Rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

vec3 StarLayer(vec2 uv, float trans, float cycleId, float layerIdx) {
    vec3 col = vec3(0.0);
    float scaleNow = mix(20.0, 0.15, trans);
    vec2 uvRot = uv * Rot(layerIdx * 2.3999);
    vec2 scaled = uvRot * scaleNow + layerIdx * 31.416;
    vec2 cellId = floor(scaled);
    vec2 gv = fract(scaled) - 0.5;

    float n = Hash21(cellId + cycleId * 127.1);
    vec2 starPos = (Hash22(cellId + cycleId * 311.7) - 0.5) * 0.7;
    vec2 worldGrid = cellId + vec2(0.5) + starPos - vec2(layerIdx * 31.416);
    float spawnR = length(worldGrid) / 20.0;
    if (n > 0.36 || spawnR < 0.06) return col;

    vec2 delta = gv - starPos;
    float sizeHash = fract(n * 345.67);
    float starSize = 0.0195 + sizeHash * 0.03;
    float att = 1.0 - smoothstep(starSize * 0.85, starSize, length(delta));
    float hue = fract(n * 789.01);
    float trailFade = smoothstep(0.0, 0.08, trans);
    float dt = 0.018;
    float s1 = mix(20.0, 0.15, max(trans - dt, 0.0));
    vec2 td1 = delta + uvRot * (s1 - scaleNow);
    float att1 = (1.0 - smoothstep(starSize * 0.85, starSize, length(td1))) * trailFade;
    float s2 = mix(20.0, 0.15, max(trans - dt * 2.0, 0.0));
    vec2 td2 = delta + uvRot * (s2 - scaleNow);
    float att2 = (1.0 - smoothstep(starSize * 0.85, starSize, length(td2))) * trailFade;
    vec3 c = palette(hue);
    col += c * att + c * att1 * 0.65 + c * att2 * 0.35;
    return col;
}

void main() {
    vec2 uv = (qt_TexCoord0 * iResolution - 0.5 * iResolution) / max(iResolution.y, 1.0);
    vec3 col = colPaper.rgb * 0.10;
    float t = iTime * SPEED;
    for (int i = 0; i < NUM_LAYERS; i++) {
        float fi = float(i) / float(NUM_LAYERS);
        float layerTime = t + fi;
        float trans = fract(layerTime);
        float cycleId = floor(layerTime);
        float fade = smoothstep(0.0, 0.1, trans) * smoothstep(1.0, 0.92, trans);
        col += StarLayer(uv, trans, cycleId, fi * float(NUM_LAYERS)) * trans * fade;
    }
    col = col / (col + 0.8);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
