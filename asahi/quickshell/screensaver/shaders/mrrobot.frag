#version 440

// Mr. Robot hacking sequence. Scrolling rows of mixed "hacker output":
// IP/port scans, hash brute-force, progress bars, shell commands, and
// occasional centred banners ("ACCESS GRANTED" / "ROOT ACCESS"). Every
// few seconds a horizontal glitch band sweeps across with an RGB split,
// like the show's intercut "the system noticed you" moment. Same 3x5
// glyph table as the other text shaders.

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
    if (c == 35) return 0x72A7; // Z
    if (c == 36) return 0x0410; // :
    if (c == 37) return 0x2000; // .
    if (c == 38) return 0x1124; // /
    if (c == 39) return 0x01C0; // -
    if (c == 40) return 0x7000; // _
    if (c == 41) return 0x6F6F; // @
    if (c == 42) return 0x52A5; // %
    if (c == 43) return 0x5F7D; // #
    if (c == 44) return 0x24A7; // $
    if (c == 45) return 0x6496; // [
    if (c == 46) return 0x3493; // ]
    return 0;
}

float hash11(float n) { return fract(sin(n) * 43758.5453); }

float renderGlyph(int c, vec2 cellUV) {
    int sx = int(floor(cellUV.x * 3.0));
    int sy = int(floor(cellUV.y * 5.0));
    return float((glyphBits(c) >> (sy * 3 + sx)) & 1);
}

// Char `i` of a status word.
int openChar(int i) {
    if (i == 0) return 24; if (i == 1) return 25;
    if (i == 2) return 14; if (i == 3) return 23;
    return -1;
}
int filtChar(int i) {
    if (i == 0) return 15; if (i == 1) return 18;
    if (i == 2) return 21; if (i == 3) return 29;
    return -1;
}
int closChar(int i) {
    if (i == 0) return 12; if (i == 1) return 21;
    if (i == 2) return 24; if (i == 3) return 28;
    return -1;
}
int crackedChar(int i) {
    if (i == 0) return 12; if (i == 1) return 27;
    if (i == 2) return 10; if (i == 3) return 12;
    if (i == 4) return 20; if (i == 5) return 14;
    if (i == 6) return 13;
    return -1;
}
int failChar(int i) {
    if (i == 0) return 15; if (i == 1) return 10;
    if (i == 2) return 18; if (i == 3) return 21;
    return -1;
}

// "ACCESS GRANTED" banner — 14 chars. -1 marks space.
int accessChar(int i) {
    if (i == 0)  return 10; // A
    if (i == 1)  return 12; // C
    if (i == 2)  return 12; // C
    if (i == 3)  return 14; // E
    if (i == 4)  return 28; // S
    if (i == 5)  return 28; // S
    if (i == 6)  return -1; // space
    if (i == 7)  return 16; // G
    if (i == 8)  return 27; // R
    if (i == 9)  return 10; // A
    if (i == 10) return 23; // N
    if (i == 11) return 29; // T
    if (i == 12) return 14; // E
    if (i == 13) return 13; // D
    return -1;
}

void main() {
    vec2 frag = qt_TexCoord0 * iResolution;

    float cellW = clamp(iResolution.x / 100.0, 8.0, 18.0);
    float cellH = cellW * 1.55;

    float t = iTime;
    float scrollY = t * cellH * 1.6;

    float cellX  = floor(frag.x / cellW);
    float cellYf = (frag.y + scrollY) / cellH;
    float cellY  = floor(cellYf);
    vec2  cellUV = vec2(fract(frag.x / cellW), fract(cellYf));
    int   row    = int(cellY);
    int   col    = int(cellX);
    int   colsTotal = int(iResolution.x / cellW);

    vec3 col_rgb = colPaper.rgb * 0.06;

    // Row type: weighted random off row index.
    float typeHash = hash11(float(row) * 17.7 + 0.3);
    int rowType;
    if      (typeHash < 0.28) rowType = 0;   // IP scan
    else if (typeHash < 0.55) rowType = 1;   // hash crack
    else if (typeHash < 0.74) rowType = 2;   // shell command
    else if (typeHash < 0.93) rowType = 3;   // progress bar
    else                       rowType = 4;  // banner

    int   charCode = -1;
    vec3  charCol  = colAccent.rgb;
    float dim      = 0.95;
    bool  bannerRow = (rowType == 4);

    int leftPad = 2;
    int c = col - leftPad;

    if (rowType == 0 && c >= 0) {
        // AAA.BBB.CCC.DDD:PPPPP   STATE   SVC
        if (c <= 14) {
            int seg = c / 4;
            int sub = c - seg * 4;
            if (sub == 3 && seg < 3) {
                charCode = 37;  // .
                dim = 0.6;
            } else if (sub < 3) {
                int octval = int(hash11(float(row) * 13.1 + float(seg) * 7.3) * 256.0);
                int divisor = (sub == 0) ? 100 : (sub == 1 ? 10 : 1);
                charCode = (octval / divisor) % 10;
            }
        } else if (c == 15) {
            charCode = 36;  // :
            dim = 0.6;
        } else if (c >= 16 && c <= 20) {
            int port = int(hash11(float(row) * 19.7 + 0.3) * 65535.0);
            int subc = c - 16;
            int div_;
            if      (subc == 0) div_ = 10000;
            else if (subc == 1) div_ = 1000;
            else if (subc == 2) div_ = 100;
            else if (subc == 3) div_ = 10;
            else                div_ = 1;
            charCode = (port / div_) % 10;
        } else if (c >= 23 && c <= 26) {
            int state = int(hash11(float(row) * 23.3 + 1.7) * 3.0);
            int p = c - 23;
            if (state == 0) {
                charCode = openChar(p);
                charCol  = colAccent.rgb;
                dim      = 1.0;
            } else if (state == 1) {
                charCode = filtChar(p);
                charCol  = colInk.rgb;
                dim      = 0.55;
            } else {
                charCode = closChar(p);
                charCol  = colSeal.rgb;
                dim      = 0.85;
            }
        } else if (c >= 29) {
            int svcLen = 3 + int(hash11(float(row) * 5.1) * 3.0);
            int svcCol = c - 29;
            if (svcCol < svcLen) {
                charCode = 10 + int(hash11(float(row) * 11.3 + float(svcCol) * 3.7) * 26.0);
                charCol  = colInk.rgb;
                dim      = 0.65;
            }
        }
    } else if (rowType == 1 && c >= 0) {
        // Hash crack: 24 hex + spaces + status
        if (c < 24) {
            charCode = int(hash11(float(row) * 17.7 + float(c) * 1.3 + 0.7) * 16.0);
            dim = 0.85;
        } else if (c >= 26 && c <= 33) {
            int cracked = hash11(float(row) * 7.7 + 3.3) > 0.93 ? 1 : 0;
            int p = c - 26;
            if (cracked == 1) {
                charCode = crackedChar(p);
                charCol  = colSeal.rgb;
                dim      = 1.15;
            } else {
                charCode = failChar(p);
                charCol  = colInk.rgb;
                dim      = 0.50;
            }
        }
    } else if (rowType == 2 && c >= 0) {
        // $ command --flag arg
        if (c == 0) {
            charCode = 44;  // $
            charCol  = colInk.rgb;
            dim      = 0.7;
        } else if (c == 1) {
            // space
        } else {
            int cc = c - 2;
            float h = hash11(float(row) * 31.7 + float(cc) * 1.1);
            if (h < 0.12) {
                // word break (space)
            } else if (h < 0.18) {
                charCode = 39;  // -
                charCol  = colInk.rgb;
                dim      = 0.6;
            } else if (h < 0.23) {
                charCode = 38;  // /
                charCol  = colInk.rgb;
                dim      = 0.6;
            } else {
                charCode = 10 + int(hash11(float(row) * 37.3 + float(cc) * 5.7) * 26.0);
                charCol  = colAccent.rgb;
                dim      = 0.95;
            }
        }
    } else if (rowType == 3 && c >= 0) {
        // [#####..............]  NN%  FILENAME
        int progress = int(hash11(float(row) * 7.7 + 3.7) * 100.0);
        if (c == 0) {
            charCode = 45; dim = 0.7;     // [
        } else if (c >= 1 && c <= 20) {
            int filled = (c - 1) * 5;     // 5% step
            if (filled < progress) {
                charCode = 43;            // #
                charCol  = colAccent.rgb;
            } else {
                charCode = 37;            // .
                charCol  = colInk.rgb;
                dim      = 0.30;
            }
        } else if (c == 21) {
            charCode = 46; dim = 0.7;     // ]
        } else if (c == 24) {
            charCode = (progress / 10) % 10;
            charCol  = colInk.rgb;
        } else if (c == 25) {
            charCode = progress % 10;
            charCol  = colInk.rgb;
        } else if (c == 26) {
            charCode = 42; dim = 0.7;     // %
            charCol  = colInk.rgb;
        } else if (c >= 29) {
            int fnamLen = 7 + int(hash11(float(row) * 11.3) * 7.0);
            int fcol = c - 29;
            if (fcol < fnamLen) {
                charCode = 10 + int(hash11(float(row) * 41.7 + float(fcol) * 2.3) * 26.0);
                charCol  = colInk.rgb;
                dim      = 0.65;
            }
        }
    } else if (rowType == 4) {
        // Banner row, centred "ACCESS GRANTED". Background tinted seal.
        col_rgb += colSeal.rgb * 0.08;
        int bannerLen = 14;
        int bannerStart = (colsTotal - bannerLen) / 2;
        int bp = col - bannerStart;
        if (bp >= 0 && bp < bannerLen) {
            charCode = accessChar(bp);
            charCol  = colSeal.rgb;
            dim      = 1.20;
        }
    }

    if (charCode >= 0) {
        float marg = step(0.06, cellUV.x) * step(cellUV.x, 0.94)
                   * step(0.06, cellUV.y) * step(cellUV.y, 0.94);
        float on = renderGlyph(charCode, cellUV);
        col_rgb = mix(col_rgb, charCol * dim, on * marg);
    }

    // Periodic glitch: 200ms RGB-split band sweep every ~6.3 seconds.
    float glitchCycle = 6.3;
    float glitchT = mod(t, glitchCycle);
    if (glitchT < 0.22) {
        float gp = glitchT / 0.22;
        float bandY = mod(glitchT * iResolution.y * 6.5, iResolution.y);
        float band = exp(-abs(frag.y - bandY) * 0.04);
        // RGB shift toward seal/accent split
        col_rgb.r += band * colSeal.rgb.r * 0.35 * (1.0 - gp);
        col_rgb.b += band * colAccent.rgb.b * 0.35 * (1.0 - gp);
        col_rgb *= 1.0 - band * 0.15 * gp;
    }

    // Occasional whole-screen tear: 80ms flash every ~14 seconds.
    float tearCycle = 14.0;
    float tearT = mod(t, tearCycle);
    if (tearT < 0.08) {
        float r = hash11(floor(t * 60.0) + 1.3);
        float jitter = (r - 0.5) * 0.04;
        if (mod(frag.y, 6.0) < 3.0) {
            col_rgb.r *= 1.4;
        } else {
            col_rgb.gb *= 0.7;
        }
    }

    // CRT scan + vignette.
    float scan = 0.92 + 0.08 * sin(frag.y * 3.14159);
    col_rgb *= scan;
    float vig = smoothstep(1.20, 0.50, length((qt_TexCoord0 - 0.5) * 1.6));
    col_rgb *= 0.55 + 0.45 * vig;

    fragColor = vec4(col_rgb, 1.0) * qt_Opacity;
}
