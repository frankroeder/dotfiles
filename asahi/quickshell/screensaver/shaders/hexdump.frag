#version 440

// xxd-style memory dump scrolling upward. Each row has an 8-hex
// address, a colon, sixteen hex bytes, then an ASCII gutter — printable
// bytes faked with a random 3x5 pixel pattern, non-printable shown as
// dots. All byte values are hashed off (row, column), so the dump is
// deterministic but never repeats.
//
// Glyph rendering: each character is encoded as a 15-bit bitmap packed
// in one int. Pixel at (row, col) inside the cell is on iff bit
// (row*3 + col) of the int is set.

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

int glyphBits(int c) {
    if (c == 0)  return 0x7B6F;
    if (c == 1)  return 0x749A;
    if (c == 2)  return 0x72A7;
    if (c == 3)  return 0x79A7;
    if (c == 4)  return 0x49ED;
    if (c == 5)  return 0x38CF;
    if (c == 6)  return 0x2ACE;
    if (c == 7)  return 0x12A7;
    if (c == 8)  return 0x2AAA;
    if (c == 9)  return 0x39AA;
    if (c == 10) return 0x5BEA;
    if (c == 11) return 0x3AEB;
    if (c == 12) return 0x624E;
    if (c == 13) return 0x3B6B;
    if (c == 14) return 0x72CF;
    if (c == 15) return 0x12CF;
    if (c == 16) return 0x0410;  // colon
    if (c == 17) return 0x2000;  // dot
    return 0;
}

float hash11(float n) { return fract(sin(n) * 43758.5453); }

float renderGlyph(int c, vec2 cellUV) {
    int sx = int(floor(cellUV.x * 3.0));
    int sy = int(floor(cellUV.y * 5.0));
    return float((glyphBits(c) >> (sy * 3 + sx)) & 1);
}

void main() {
    vec2 frag = qt_TexCoord0 * iResolution;

    int colsTotal = 76;
    // Auto-fit cell width so the dump fills ~88% of screen width.
    float cellW = clamp(iResolution.x / (float(colsTotal) + 8.0), 8.0, 24.0);
    float cellH = cellW * 1.55;

    float scrollY  = iTime * cellH * 1.2;
    float firstCol = max(0.0, floor((iResolution.x / cellW - float(colsTotal)) * 0.5));

    float cellX     = floor(frag.x / cellW);
    float cellYf    = (frag.y + scrollY) / cellH;
    float cellY     = floor(cellYf);
    vec2  cellUV    = vec2(fract(frag.x / cellW), fract(cellYf));
    int   col       = int(cellX - firstCol);
    int   row       = int(cellY);

    vec3 col_rgb = colPaper.rgb * 0.06;

    if (col >= 0 && col < colsTotal) {
        int   charCode = -1;
        vec3  charCol  = colAccent.rgb;
        float dim      = 1.0;

        if (col < 8) {
            int shift = (7 - col) * 4;
            int addr  = row * 16 + 0x4F000;
            charCode  = (addr >> shift) & 0xF;
            charCol   = colSeal.rgb;
            dim       = 0.85;
        } else if (col == 8) {
            charCode = 16;
            charCol  = colInk.rgb;
            dim      = 0.55;
        } else if (col >= 10 && col < 58) {
            int byteCol = col - 10;
            int byteIdx = byteCol / 3;
            int subCol  = byteCol - byteIdx * 3;
            if (subCol < 2) {
                int byteVal = int(hash11(float(row) * 13.7 + float(byteIdx) * 9.1 + 3.1) * 256.0);
                charCode = (subCol == 0)
                    ? (byteVal >> 4) & 0xF
                    : byteVal & 0xF;
                charCol = colAccent.rgb;
            }
        } else if (col >= 60 && col < 76) {
            int gutCol = col - 60;
            float h    = hash11(float(row) * 13.7 + float(gutCol) * 9.1 + 3.1);
            if (h > 0.42) {
                // Random "letter-like" 3x5 pattern.
                float sx = floor(cellUV.x * 3.0);
                float sy = floor(cellUV.y * 5.0);
                float h2 = hash11(float(row) * 21.31 + float(col) * 17.13
                                + sx * 3.7 + sy * 5.3);
                float on = step(0.55, h2);
                float marg = step(0.06, cellUV.x) * step(cellUV.x, 0.94)
                           * step(0.06, cellUV.y) * step(cellUV.y, 0.94);
                col_rgb = mix(col_rgb, colInk.rgb * 0.55, on * marg);
                charCode = -1;  // already drawn
            } else {
                charCode = 17;
                charCol  = colInk.rgb;
                dim      = 0.6;
            }
        }

        if (charCode >= 0) {
            float marg = step(0.06, cellUV.x) * step(cellUV.x, 0.94)
                       * step(0.06, cellUV.y) * step(cellUV.y, 0.94);
            float on = renderGlyph(charCode, cellUV);
            col_rgb = mix(col_rgb, charCol * dim, on * marg);
        }
    }

    // Faint guide line where the ASCII gutter starts.
    if (col == 59) {
        col_rgb += colInk.rgb * 0.03;
    }

    // CRT scan + vignette.
    float scan = 0.93 + 0.07 * sin(frag.y * 3.14159);
    col_rgb *= scan;
    float vig = smoothstep(1.20, 0.50, length((qt_TexCoord0 - 0.5) * 1.6));
    col_rgb *= 0.55 + 0.45 * vig;

    fragColor = vec4(col_rgb, 1.0) * qt_Opacity;
}
