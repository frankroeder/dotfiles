#version 440

// Fake terminal session. Lines scroll up; each line is a deterministic
// hash-driven sequence of "characters" picked from A..Z + 0..9 + a few
// symbols. The bottom line types out character-by-character with a
// blinking caret. Prompt prefix is rendered in a different colour so
// the eye reads "shell session" without the chars being real text.
//
// Glyph table is 3x5 packed bitmaps as in hexdump/buffer.

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

// 0..9 digits, 10..35 letters A..Z, 36 colon, 37 dot, 38 slash, 39 dash,
// 40 underscore, 41 at, 42 gt, 43 hash, 44 dollar.
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
    if (c == 10) return 0x5BEA; // A
    if (c == 11) return 0x3AEB; // B
    if (c == 12) return 0x624E; // C
    if (c == 13) return 0x3B6B; // D
    if (c == 14) return 0x72CF; // E
    if (c == 15) return 0x12CF; // F
    if (c == 16) return 0x6B4E; // G
    if (c == 17) return 0x5BED; // H
    if (c == 18) return 0x7497; // I
    if (c == 19) return 0x2B24; // J
    if (c == 20) return 0x5AED; // K
    if (c == 21) return 0x7249; // L
    if (c == 22) return 0x5BFD; // M
    if (c == 23) return 0x5B7D; // N
    if (c == 24) return 0x2B6A; // O
    if (c == 25) return 0x12EB; // P
    if (c == 26) return 0x676A; // Q
    if (c == 27) return 0x5AEB; // R
    if (c == 28) return 0x388E; // S
    if (c == 29) return 0x2497; // T
    if (c == 30) return 0x7B6D; // U
    if (c == 31) return 0x2B6D; // V
    if (c == 32) return 0x5F6D; // W
    if (c == 33) return 0x5AAD; // X
    if (c == 34) return 0x24AD; // Y
    if (c == 35) return 0x72A7; // Z (same as 2 shape - 3x5 limits)
    if (c == 36) return 0x0410; // colon
    if (c == 37) return 0x2000; // dot
    if (c == 38) return 0x1124; // slash: ..1 / ..1 / .1. / 1.. / 1..
    if (c == 39) return 0x01C0; // dash:  ... / ... / 111 / ... / ...
    if (c == 40) return 0x7000; // underscore: bottom row full
    if (c == 41) return 0x6F6F; // at: .11 / 111 / 111 / 1.. / .11
    if (c == 42) return 0x1112; // gt:   .1. / ..1 / .1. / 1.. / ...
    if (c == 43) return 0x57DD; // hash
    if (c == 44) return 0x24A7; // dollar approx
    return 0;
}

float hash11(float n) { return fract(sin(n) * 43758.5453); }

float renderGlyph(int c, vec2 cellUV) {
    int sx = int(floor(cellUV.x * 3.0));
    int sy = int(floor(cellUV.y * 5.0));
    return float((glyphBits(c) >> (sy * 3 + sx)) & 1);
}

// Pseudo-random "char code" for a position. Mix of uppercase letters
// and digits with occasional symbols.
int randChar(float seed) {
    float h = hash11(seed);
    // 70% letters, 25% digits, 5% punctuation/symbol
    if (h < 0.70) return 10 + int(h / 0.70 * 26.0);
    if (h < 0.95) return int((h - 0.70) / 0.25 * 10.0);
    return 36 + int((h - 0.95) / 0.05 * 9.0);
}

void main() {
    vec2 frag = qt_TexCoord0 * iResolution;

    float cellW = clamp(iResolution.x / 90.0, 8.0, 22.0);
    float cellH = cellW * 1.55;

    // Lines scroll up over time. Bottom line is index 0; older lines
    // have higher indices and live higher on the screen.
    float t = iTime;
    float linesPerSec = 0.65;
    float scrollFrac = fract(t * linesPerSec);
    int   currentLine = int(floor(t * linesPerSec));

    // Line y where line 0 (the active one) sits.
    float baseY = iResolution.y - cellH * 1.5;

    // Which line index is this fragment on?
    float lineFloat = (baseY + scrollFrac * cellH - frag.y) / cellH;
    int line = int(floor(lineFloat));
    vec2 cellUV;
    cellUV.y = fract(lineFloat);

    // Each line's absolute index (older lines = higher absoluteLine).
    int absLine = currentLine - line;
    if (absLine < 0) {
        fragColor = vec4(colPaper.rgb * 0.05, 1.0) * qt_Opacity;
        return;
    }

    // Column.
    int colsLeft = 2;  // left margin in cells
    float colF = (frag.x / cellW) - float(colsLeft);
    int col = int(floor(colF));
    cellUV.x = fract(colF);

    vec3 col_rgb = colPaper.rgb * 0.06;

    // Prompt: 5 chars wide, e.g., "user@". Drawn in seal.
    // Then a $ prompt char, space, then the command.
    // Total prompt = 7 cells (incl. $ and space).
    int promptW = 7;

    // Per-line length of "command" body (hashed off line index).
    int bodyLen = 18 + int(hash11(float(absLine) * 11.1 + 3.1) * 32.0);

    // For the bottom (current) line, animate the typing — chars appear
    // one-by-one until full, then hold until scroll.
    float typeSpeed = 22.0;  // chars/sec
    float typedCount = (absLine == 0)
        ? min(float(bodyLen), scrollFrac / linesPerSec * typeSpeed)
        : float(bodyLen);

    if (col < 0) {
        // left margin - leave dark
    } else if (col < promptW - 2) {
        // User@host prefix (4 letters or so) — use a per-line stable
        // glyph sequence keyed only off the line index so the prompt
        // looks stable across the whole session.
        int charCode;
        if (col == promptW - 3) charCode = 41; // '@'
        else                    charCode = 10 + int(hash11(float(col) * 1.3 + 0.7) * 26.0);
        float marg = step(0.06, cellUV.x) * step(cellUV.x, 0.94)
                   * step(0.06, cellUV.y) * step(cellUV.y, 0.94);
        float on = renderGlyph(charCode, cellUV);
        col_rgb = mix(col_rgb, colSeal.rgb, on * marg);
    } else if (col == promptW - 2) {
        // '$' prompt char
        float marg = step(0.06, cellUV.x) * step(cellUV.x, 0.94)
                   * step(0.06, cellUV.y) * step(cellUV.y, 0.94);
        float on = renderGlyph(44, cellUV);
        col_rgb = mix(col_rgb, colInk.rgb, on * marg);
    } else if (col == promptW - 1) {
        // space after prompt
    } else if (col >= promptW && col < promptW + bodyLen) {
        // Body text. Use a different seed for "command" lines vs.
        // "output" lines so the visual rhythm varies.
        int relCol = col - promptW;
        if (float(relCol) < typedCount) {
            int charCode = randChar(float(absLine) * 19.3 + float(relCol) * 1.7 + 0.3);
            float marg = step(0.06, cellUV.x) * step(cellUV.x, 0.94)
                       * step(0.06, cellUV.y) * step(cellUV.y, 0.94);
            float on = renderGlyph(charCode, cellUV);
            vec3 textCol = (absLine == 0) ? colInk.rgb : colAccent.rgb;
            col_rgb = mix(col_rgb, textCol, on * marg);
        }
    }

    // Caret on the active line at the end of typed text. 2 Hz blink.
    if (absLine == 0) {
        int caretCol = promptW + int(typedCount);
        float blink = step(0.5, fract(t * 2.0));
        if (col == caretCol && blink > 0.5) {
            float marg = step(0.10, cellUV.x) * step(cellUV.x, 0.90)
                       * step(0.10, cellUV.y) * step(cellUV.y, 0.90);
            col_rgb = mix(col_rgb, colInk.rgb, marg);
        }
    }

    // Scan + vignette.
    float scan = 0.92 + 0.08 * sin(frag.y * 3.14159);
    col_rgb *= scan;
    float vig = smoothstep(1.20, 0.50, length((qt_TexCoord0 - 0.5) * 1.6));
    col_rgb *= 0.55 + 0.45 * vig;

    fragColor = vec4(col_rgb, 1.0) * qt_Opacity;
}
