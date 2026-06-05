#version 440

// Transparent CRT artifact overlay. The fragment shader produces no
// background colour — only the lines and screen effects — and outputs
// premultiplied alpha so it composites over whatever sits behind the
// screensaver panel. When this shader is active, shell.qml hides the
// paper backdrop so the desktop shows through the scanlines.
//
// Layers, back to front:
//   bezel       — solid paper-tinted ring where barrel curvature has
//                 pushed the artifact UV off-screen
//   scanlines   — horizontal dark bands with a slow vertical creep
//   vignette    — corners darken
//   triad       — RGB subpixel mask, faint per-column tint
//   roll bar    — bright horizontal band scrolling up

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

void main() {
    vec2 uv = qt_TexCoord0;

    // Barrel curvature on the *artifact* UV. We can't bend the desktop
    // pixels behind us (no backdrop sampler), but bending the artifact
    // grid gives the same overall illusion of a curved glass tube.
    vec2 cc = uv - 0.5;
    float r2 = dot(cc, cc);
    uv = 0.5 + cc * (1.0 + 0.22 * r2);

    float onScreen = step(0.0, uv.x) * step(uv.x, 1.0)
                   * step(0.0, uv.y) * step(uv.y, 1.0);

    // ---------- per-layer (rgb, alpha) contributions ----------

    // Scanlines: rgb=0, alpha = darkness amount. Subtracts from backdrop
    // luminance without adding any colour.
    float scanWave = sin(uv.y * iResolution.y * 3.14159 - iTime * 1.8);
    float scanDarkA = (0.5 - 0.5 * scanWave) * 0.32 * onScreen;

    // Vignette: corners darken.
    float vig = smoothstep(0.40, 1.10, length(cc) * 1.5);
    float vigDarkA = vig * 0.55;

    // RGB subpixel mask. Every device-pixel column adds a faint coloured
    // glow biased toward R, G, or B — the screen "mesh" reads on any
    // backdrop, including pure white or pure black.
    float subPx = mod(uv.x * iResolution.x, 3.0);
    vec3 triadTint;
    if      (subPx < 1.0) triadTint = vec3(1.0, 0.10, 0.10);
    else if (subPx < 2.0) triadTint = vec3(0.10, 1.0, 0.10);
    else                  triadTint = vec3(0.10, 0.10, 1.0);
    float triadA = 0.07 * onScreen;
    vec3  triadRgb = triadTint * triadA;

    // Roll bar: bright tint band scrolling up.
    float rollY = fract(iTime * 0.06);
    float rollI = exp(-pow((uv.y - rollY) * 13.0, 2.0)) * onScreen;
    float rollA = rollI * 0.18;
    vec3  rollRgb = colInk.rgb * rollA;

    // Bezel: opaque paper-tinted frame where curvature ran off-screen.
    float bezelA = 1.0 - onScreen;
    vec3  bezelRgb = colPaper.rgb * 0.20 * bezelA;

    // ---------- premultiplied "over" composition ----------
    // Each step:  result = layer  over  result
    //   a' = layer.a + result.a * (1 - layer.a)        [Porter-Duff "over"]
    //   rgb' = layer.rgb + result.rgb * (1 - layer.a)
    // Walking back-to-front so the formula uses (1 - result.a) on the
    // incoming layer (the equivalent over-from-below form).

    vec3  rgb = bezelRgb;
    float a   = bezelA;

    // Scanline darken
    rgb = rgb;                           // adds no colour
    a   = a + scanDarkA * (1.0 - a);

    // Vignette darken
    a   = a + vigDarkA * (1.0 - a);

    // Triad tint
    rgb = rgb + triadRgb * (1.0 - a);
    a   = a + triadA    * (1.0 - a);

    // Roll bar bright
    rgb = rgb + rollRgb * (1.0 - a);
    a   = a + rollA    * (1.0 - a);

    fragColor = vec4(rgb, a) * qt_Opacity;
}
