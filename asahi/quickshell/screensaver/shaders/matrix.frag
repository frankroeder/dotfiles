#version 440

// Digital rain. Vertical columns of small cells fall continuously; each
// cell renders a procedurally-generated 3x5 pixel-art block so the
// column reads as "data" even though there is no font texture sampled.
// Head cell is bright, tail fades upward; per-column speed and tail
// length are hashed off the column id so neighbouring columns desync.

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

float hash11(float n) {
    return fract(sin(n) * 43758.5453);
}
float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 frag = qt_TexCoord0 * iResolution;

    float cellW = 12.0;
    float cellH = 18.0;
    vec2 cellId = floor(frag / vec2(cellW, cellH));
    vec2 cellUV = fract(frag / vec2(cellW, cellH));

    float t = iTime;

    // Per-column traits.
    float colHash = hash11(cellId.x * 1.31 + 0.7);
    float speed   = 7.0 + colHash * 16.0;
    float phase   = hash11(cellId.x * 7.13 + 4.7) * 200.0;
    float tailLen = 18.0 + hash11(cellId.x * 2.91 + 1.7) * 18.0;

    float rowsTotal = iResolution.y / cellH + tailLen;
    float headRow   = mod(t * speed + phase, rowsTotal) - tailLen;
    float rowsBehind = cellId.y - headRow;

    float vis    = step(0.0, rowsBehind) * step(rowsBehind, tailLen);
    float tailT  = clamp(rowsBehind / tailLen, 0.0, 1.0);
    float bright = pow(1.0 - tailT, 1.4) * vis;

    // 3x5 sub-grid of pixels inside the cell. Reroll the bitmap every
    // 250 ms so the glyphs scramble — that motion is what sells "data".
    float glyphTick = floor(t * 4.0);
    float subX = floor(cellUV.x * 3.0);
    float subY = floor(cellUV.y * 5.0);
    float pixOn = step(0.50,
        hash12(vec2(cellId.x * 11.1 + subX * 3.7,
                    cellId.y * 7.3  + subY * 2.9 + glyphTick * 13.1)));

    float margin = step(0.05, cellUV.x) * step(cellUV.x, 0.95)
                 * step(0.05, cellUV.y) * step(cellUV.y, 0.95);

    float pixel = pixOn * margin * bright;

    float isHead = step(rowsBehind, 0.5) * vis;
    vec3  inkHot = mix(colAccent.rgb, colInk.rgb, 0.85);
    vec3  glyph  = mix(colAccent.rgb, inkHot, isHead);

    vec3 col = colPaper.rgb * 0.08;
    col += glyph * pixel;

    // Mild scanlines so the rain reads as CRT output.
    float scan = 0.92 + 0.08 * sin(frag.y * 3.14159);
    col *= scan;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
