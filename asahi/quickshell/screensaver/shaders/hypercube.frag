#version 440

// Rotating 4D tesseract, projected wireframe. Ported from hyprsaver (MIT, Mara Vexa).

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

vec4 rotXw(vec4 v, float a) {
    float c = cos(a), s = sin(a);
    return vec4(c * v.x - s * v.w, v.y, v.z, s * v.x + c * v.w);
}

vec4 rotYz(vec4 v, float a) {
    float c = cos(a), s = sin(a);
    return vec4(v.x, c * v.y - s * v.z, s * v.y + c * v.z, v.w);
}

float segDist(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    vec2 pa = p - a;
    float t = clamp(dot(pa, ab) / max(dot(ab, ab), 1e-8), 0.0, 1.0);
    return length(pa - ab * t);
}

void main() {
    vec2 uv = (qt_TexCoord0 * iResolution - 0.5 * iResolution) / max(iResolution.y, 1.0);
    float ta = iTime * 0.5;
    float tb = iTime * 0.3090169944;

    vec2 pt[16];
    float wd[16];
    for (int i = 0; i < 16; i++) {
        vec4 v = vec4(
            ((i & 1) != 0) ? 1.0 : -1.0,
            ((i & 2) != 0) ? 1.0 : -1.0,
            ((i & 4) != 0) ? 1.0 : -1.0,
            ((i & 8) != 0) ? 1.0 : -1.0);
        v = rotYz(rotXw(v, ta), tb);
        wd[i] = v.w;
        vec3 p3 = v.xyz / (v.w + 2.0);
        pt[i] = p3.xy / (p3.z + 2.5) * 0.45;
    }

    vec3 col = vec3(0.0);
    for (int dim = 0; dim < 4; dim++) {
        int bit = 1 << dim;
        for (int i = 0; i < 16; i++) {
            if ((i & bit) != 0) continue;
            int j = i + bit;
            float d = segDist(uv, pt[i], pt[j]);
            float tRaw = fract((wd[i] + wd[j]) * 0.15 + 0.5 + ta * 0.01);
            float tComp = mix(tRaw, tRaw * 0.5 + 0.25, 0.6);
            float tSmooth = 0.5 + 0.5 * sin(tComp * 3.14159 - 1.5708);
            float intensity = 1.0 - smoothstep(0.003, 0.006, d);
            col += intensity * palette(tSmooth);
        }
    }
    col = col / (1.0 + col);
    col = max(colPaper.rgb * 0.14, col);
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
