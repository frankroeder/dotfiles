#version 440

// Launcher backdrop: a dim wash with one soft accent glow that drifts
// slowly behind the card. Premultiplied output over the blurred desktop.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
    vec4 colDim;
    vec4 colA;
    vec4 colB;
    vec4 colC;
};

float blob(vec2 p, vec2 c, float r) {
    float d = length(p - c);
    return exp(-d * d / (r * r));
}

void main() {
    vec2 p = qt_TexCoord0 * 2.0 - 1.0;
    p.x *= iResolution.x / max(iResolution.y, 1.0);
    float t = iTime * 0.08;

    vec2 ca = vec2(0.25 * sin(t), -0.55 + 0.10 * cos(t * 0.7));
    vec2 cb = vec2(0.9 * cos(t * 0.6), 0.8);

    vec3 glow = colA.rgb * blob(p, ca, 0.9) * 0.22
              + colB.rgb * blob(p, cb, 0.8) * 0.14;

    vec3 rgb = colDim.rgb * colDim.a + glow;
    float a = colDim.a + 0.25 * length(glow);
    fragColor = vec4(rgb, min(a, 1.0)) * qt_Opacity;
}
