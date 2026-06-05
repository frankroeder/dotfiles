#version 440

// Space Invaders attract loop. A 5x11 formation of 11x8 pixel-art
// invaders steps side-to-side; the formation drops a row whenever it
// hits an edge. Two animation frames swap each step so the legs/arms
// alternate. Occasional player shot rises, occasional bomb falls. A UFO
// crosses the top of the screen on a slow cycle.

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

float hash11(float n) { return fract(sin(n) * 43758.5453); }

// 11x8 invader bitmaps. Pixel at (x,y) on iff bit (y*11 + x) set.
// Three invader rows × two frames each.

int spriteA0() { return int(0x00010410) + (int(0x80) << 20); /* placeholder */ }

// More straightforward: build pixel from explicit pattern function.
// kind: 0..2 (row band), frame: 0..1 (animation phase).
float invaderPixel(int kind, int frame, ivec2 p) {
    // p in 0..10, 0..7
    if (p.x < 0 || p.x > 10 || p.y < 0 || p.y > 7) return 0.0;

    // Mirror so we only need to define 6 columns (0..5).
    int x = p.x <= 5 ? p.x : 10 - p.x;
    int y = p.y;

    if (kind == 0) {
        // Top row: classic "squid" — small, two long tentacles.
        // 6x8 half (cols 0..5):
        //  y=0: . . . 1 1 1
        //  y=1: . . 1 1 1 1
        //  y=2: . 1 1 1 1 1
        //  y=3: 1 1 . . 1 1
        //  y=4: 1 1 1 1 1 1
        //  y=5: . . 1 . . 1
        //  y=6: . 1 1 . 1 . (frame 0) | . 1 . . 1 1 (frame 1)
        //  y=7: 1 . 1 . 1 . (frame 0) | 1 . . . . . (frame 1)
        if (y == 0) return (x >= 3) ? 1.0 : 0.0;
        if (y == 1) return (x >= 2) ? 1.0 : 0.0;
        if (y == 2) return (x >= 1) ? 1.0 : 0.0;
        if (y == 3) return (x == 0 || x == 1 || x == 4 || x == 5) ? 1.0 : 0.0;
        if (y == 4) return 1.0;
        if (y == 5) return (x == 2 || x == 5) ? 1.0 : 0.0;
        if (frame == 0) {
            if (y == 6) return (x == 1 || x == 2 || x == 4) ? 1.0 : 0.0;
            if (y == 7) return (x == 0 || x == 2 || x == 4) ? 1.0 : 0.0;
        } else {
            if (y == 6) return (x == 1 || x == 4 || x == 5) ? 1.0 : 0.0;
            if (y == 7) return (x == 0) ? 1.0 : 0.0;
        }
        return 0.0;
    } else if (kind == 1) {
        // Middle row: "crab".
        if (y == 0) return (x == 1 || x == 5) ? 1.0 : 0.0;
        if (y == 1) {
            bool b = frame == 0 ? (x == 1 || x == 2) : (x == 2);
            return b ? 1.0 : 0.0;
        }
        if (y == 2) return (x == 1 || x == 2 || x == 3 || x == 4 || x == 5) ? 1.0 : 0.0;
        if (y == 3) return (x == 0 || x == 2 || x == 3 || x == 4 || x == 5) ? 1.0 : 0.0;
        if (y == 4) return 1.0;
        if (y == 5) return (x == 1 || x == 2 || x == 3 || x == 4 || x == 5) ? 1.0 : 0.0;
        if (y == 6) return (x == 1 || x == 3 || x == 5) ? 1.0 : 0.0;
        if (y == 7) {
            bool b = frame == 0 ? (x == 0 || x == 1) : (x == 2 || x == 3);
            return b ? 1.0 : 0.0;
        }
        return 0.0;
    } else {
        // Bottom row: "octopus" — bigger, wider.
        if (y == 0) return (x >= 2 && x <= 5) ? 1.0 : 0.0;
        if (y == 1) return (x >= 1 && x <= 5) ? 1.0 : 0.0;
        if (y == 2) return 1.0;
        if (y == 3) return (x == 0 || x == 1 || x == 3 || x == 5) ? 1.0 : 0.0;
        if (y == 4) return (x >= 0 && x <= 5) ? 1.0 : 0.0;
        if (y == 5) return (x == 2 || x == 3 || x == 5) ? 1.0 : 0.0;
        if (y == 6) {
            if (frame == 0) return (x == 1 || x == 4 || x == 5) ? 1.0 : 0.0;
            else            return (x == 0 || x == 4)           ? 1.0 : 0.0;
        }
        if (y == 7) {
            if (frame == 0) return (x == 2 || x == 5) ? 1.0 : 0.0;
            else            return (x == 1 || x == 2 || x == 5) ? 1.0 : 0.0;
        }
        return 0.0;
    }
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 frag = uv * iResolution;

    // Cell size for one invader (11+2 = 13 wide, 8+4 = 12 tall).
    float cell = clamp(iResolution.y / 36.0, 6.0, 16.0);
    float invW = cell * 13.0;
    float invH = cell * 12.0;

    // Formation: 11 cols × 5 rows.
    float formationW = invW * 11.0;
    float t = iTime;
    float stepInterval = 0.55;
    int step_ = int(floor(t / stepInterval));
    int frame = step_ & 1;

    // Horizontal sweep: bounces between left/right margins.
    float marginX = (iResolution.x - formationW) * 0.5;
    float maxOffset = max(marginX - cell * 0.5, 0.0);
    float steps10   = 12.0;  // steps before reversing direction
    float phase     = mod(float(step_), steps10 * 2.0) / steps10;
    float dirX      = phase < 1.0 ? phase : 2.0 - phase;
    float offsetX   = -maxOffset + dirX * 2.0 * maxOffset;

    // Vertical drop happens once per full sweep.
    int drops = int(floor(float(step_) / (steps10 * 2.0))) - 1;
    drops = max(drops, 0);
    float offsetY = float(drops) * invH * 0.45;
    offsetY = mod(offsetY, iResolution.y * 0.55);  // wrap so we don't fall off

    // Formation origin.
    float originX = marginX + offsetX;
    float originY = cell * 4.0 + offsetY;

    vec3 col_rgb = colPaper.rgb * 0.07;

    // Background star field — very sparse.
    {
        vec2 sp = floor(frag / 5.0);
        float h = hash11(sp.x * 1.31 + sp.y * 7.7 + 0.3);
        float twinkle = 0.5 + 0.5 * sin(h * 100.0 + t * 1.5);
        float star = step(0.997, h) * twinkle;
        col_rgb += colInk.rgb * star * 0.5;
    }

    // Identify which invader cell (if any) this pixel is inside.
    float gridX = (frag.x - originX) / invW;
    float gridY = (frag.y - originY) / invH;
    int gx = int(floor(gridX));
    int gy = int(floor(gridY));
    if (gx >= 0 && gx < 11 && gy >= 0 && gy < 5) {
        vec2 inside = vec2(fract(gridX), fract(gridY));
        // Map inside cell (0..1) -> sprite pixel index (0..10, 0..7) with
        // a 1-pixel padding around the sprite.
        float padX = 1.0 / 13.0;
        float padY = 2.0 / 12.0;
        if (inside.x > padX && inside.x < 1.0 - padX
            && inside.y > padY && inside.y < 1.0 - padY) {
            int px = int(floor((inside.x - padX) / (1.0 - 2.0 * padX) * 11.0));
            int py = int(floor((inside.y - padY) / (1.0 - 2.0 * padY) * 8.0));
            int kind = gy < 1 ? 0 : (gy < 3 ? 1 : 2);
            float on = invaderPixel(kind, frame, ivec2(px, py));
            vec3 ic = (kind == 0) ? colInk.rgb
                    : (kind == 1) ? colAccent.rgb
                    :               colSeal.rgb;
            col_rgb = mix(col_rgb, ic, on);
        }
    }

    // Player paddle near the bottom.
    float paddleY = iResolution.y - cell * 3.0;
    float paddleX = iResolution.x * 0.5
                  + sin(t * 1.4) * iResolution.x * 0.35;
    {
        vec2 d = (frag - vec2(paddleX, paddleY)) / cell;
        if (d.y > 0.0 && d.y < 1.0
            && abs(d.x) < 2.5
            && !(d.y < 0.5 && abs(d.x) > 1.8)
            && !(d.y < 0.2 && abs(d.x) > 0.3)) {
            col_rgb = mix(col_rgb, colAccent.rgb, 1.0);
        }
    }

    // Player shot: vertical line rising every 1.7 s.
    {
        float shotCycle = 1.7;
        float shotT = mod(t, shotCycle);
        if (shotT < 0.9) {
            float shotX = paddleX;
            float shotY = paddleY - shotT / 0.9 * iResolution.y;
            if (abs(frag.x - shotX) < cell * 0.18
                && abs(frag.y - shotY) < cell * 0.7) {
                col_rgb = mix(col_rgb, colInk.rgb * 1.3, 1.0);
            }
        }
    }

    // Bomb: zig-zag line falling every 1.3 s from a random invader column.
    {
        float bombCycle = 1.3;
        float bombT = mod(t, bombCycle);
        if (bombT < 1.0) {
            float lane = floor(hash11(floor(t / bombCycle) * 7.1) * 11.0);
            float bx = originX + (lane + 0.5) * invW
                     + sin(bombT * 16.0) * cell * 0.4;
            float by = originY + invH * 5.0 + bombT * iResolution.y * 1.1;
            if (abs(frag.x - bx) < cell * 0.18
                && abs(frag.y - by) < cell * 0.8) {
                col_rgb = mix(col_rgb, colSeal.rgb, 1.0);
            }
        }
    }

    // UFO crossing the top every 22s.
    {
        float ufoCycle = 22.0;
        float ufoT = mod(t, ufoCycle) / ufoCycle;
        if (ufoT > 0.04 && ufoT < 0.96) {
            float ufoX = ufoT * iResolution.x;
            float ufoY = cell * 1.5;
            vec2 d = (frag - vec2(ufoX, ufoY)) / cell;
            float onBody = (d.y > 0.0 && d.y < 0.8 && abs(d.x) < 2.4
                            && (d.y > 0.3 || abs(d.x) < 1.7)) ? 1.0 : 0.0;
            col_rgb = mix(col_rgb, colSeal.rgb * 1.2, onBody);
        }
    }

    // Ground line.
    if (frag.y > iResolution.y - cell * 1.4
        && frag.y < iResolution.y - cell * 1.4 + 2.0) {
        col_rgb = mix(col_rgb, colInk.rgb, 0.65);
    }

    // CRT scan + vignette.
    float scan = 0.93 + 0.07 * sin(frag.y * 3.14159);
    col_rgb *= scan;
    float vig = smoothstep(1.20, 0.50, length((uv - 0.5) * 1.6));
    col_rgb *= 0.55 + 0.45 * vig;

    fragColor = vec4(col_rgb, 1.0) * qt_Opacity;
}
