#version 440

// Stack-smash visualiser. A vertical column of stack frames
//   ADDR : VALUE
// slowly scrolls downward as new frames push from the top. Every few
// seconds a "canary" frame's VALUE gets stomped with 0x41414141 (AAAA),
// adjacent frames flash with the seal colour, and a horizontal glitch
// band shears across the screen. After ~700ms it settles back.
//
// Same 3x5 hex glyph bitmaps as the hex-dump shader.

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

    // 19-char line: "AAAAAAAA : VVVVVVVV"
    int colsTotal = 19;
    float cellW = clamp(iResolution.x / 40.0, 14.0, 32.0);
    float cellH = cellW * 1.55;

    // Smash event timing.
    float cycle    = 5.8;
    float eventT   = mod(iTime, cycle);
    float smashing = step(eventT, 0.7);      // 1 for first 700 ms
    float smashAge = smashing * (eventT / 0.7);   // 0..1 inside event

    // Slow downward scroll; smash event nudges the scroll for shake.
    float shake = smashing * sin(eventT * 80.0) * cellH * 0.15;
    float scrollY = iTime * cellH * 0.4 + shake;
    float firstCol = max(0.0, floor((iResolution.x / cellW - float(colsTotal)) * 0.5));

    float cellX  = floor(frag.x / cellW);
    float cellYf = (frag.y - scrollY) / cellH;
    float cellY  = floor(cellYf);
    vec2  cellUV = vec2(fract(frag.x / cellW), fract(cellYf));
    int   col    = int(cellX - firstCol);
    int   row    = int(cellY);

    vec3 col_rgb = colPaper.rgb * 0.08;

    // The canary frame is at a fixed offset relative to current scroll
    // top — visible roughly centre-screen.
    int canaryRow = int(floor(scrollY / cellH)) + int((iResolution.y * 0.5) / cellH);
    bool isCanary = (row == canaryRow);
    bool isNeighbour = (abs(row - canaryRow) == 1);

    // Stack column bar on the left of the frames.
    float barX = (float(firstCol) - 0.6) * cellW;
    float barW = 2.0;
    if (frag.x > barX && frag.x < barX + barW) {
        col_rgb += colInk.rgb * 0.25;
    }

    if (col >= 0 && col < colsTotal) {
        int   charCode = -1;
        vec3  charCol  = colAccent.rgb;
        float dim      = 1.0;

        if (col < 8) {
            // Address.
            int shift = (7 - col) * 4;
            int addr  = 0x7FFFD000 - row * 16;
            charCode  = (addr >> shift) & 0xF;
            charCol   = colSeal.rgb;
            dim       = 0.80;
        } else if (col == 8 || col == 10) {
            // surrounding spaces
            charCode = -1;
        } else if (col == 9) {
            charCode = 16; // colon
            charCol  = colInk.rgb;
            dim      = 0.6;
        } else if (col >= 11 && col < 19) {
            // VALUE (8 hex digits).
            int valCol = col - 11;
            int shift = (7 - valCol) * 4;
            int valBase;

            if (isCanary && smashing > 0.5) {
                valBase = 0x41414141;  // smashed canary
            } else if (isCanary) {
                valBase = 0xCAFEBABE;
            } else {
                int v = int(hash11(float(row) * 19.3 + 7.7) * 65536.0);
                int u = int(hash11(float(row) * 31.7 + 1.1) * 65536.0);
                valBase = (v << 16) ^ u;
            }
            charCode = (valBase >> shift) & 0xF;
            if (isCanary) {
                charCol = smashing > 0.5 ? colSeal.rgb : colInk.rgb;
                dim     = 1.1;
            }
        }

        if (charCode >= 0) {
            float marg = step(0.06, cellUV.x) * step(cellUV.x, 0.94)
                       * step(0.06, cellUV.y) * step(cellUV.y, 0.94);
            float on = renderGlyph(charCode, cellUV);
            col_rgb = mix(col_rgb, charCol * dim, on * marg);
        }
    }

    // Smash glow on canary + neighbours.
    if (smashing > 0.5) {
        float distRows = abs(float(row) - float(canaryRow));
        float spread = exp(-distRows * 0.7) * (1.0 - smashAge);
        col_rgb += colSeal.rgb * spread * 0.18;
    }

    // Horizontal shear band on smash.
    if (smashing > 0.5) {
        float bandY = mod(eventT * iResolution.y * 4.0, iResolution.y);
        float band = exp(-abs(frag.y - bandY) * 0.05) * (1.0 - smashAge);
        col_rgb += colSeal.rgb * band * 0.25;
    }

    // CRT scan + vignette.
    float scan = 0.92 + 0.08 * sin(frag.y * 3.14159);
    col_rgb *= scan;
    float vig = smoothstep(1.20, 0.50, length((qt_TexCoord0 - 0.5) * 1.6));
    col_rgb *= 0.55 + 0.45 * vig;

    fragColor = vec4(col_rgb, 1.0) * qt_Opacity;
}
