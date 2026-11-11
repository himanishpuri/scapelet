#version 440
// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;       // seconds, wraps at 3769.911184
    float density;    // 1..10, 5 is the default amount of stars
    float band;       // 1: draw the Milky Way, 0: none
    float drift;      // 1: the sky drifts slowly, 0: it stands still
    vec2 resolution;  // px, item size
    vec4 cSpace;
    vec4 cNebulaA;
    vec4 cNebulaB;
    vec4 cCore;       // the hot middle of a nebula
    vec4 cStar;
};
layout(binding = 1) uniform sampler2D mask;     // r = narrow sum (heart), g = wide sum (gas)
layout(binding = 2) uniform sampler2D noiseTex; // r, g: 2-octave noise, b: 1 octave; tile = 2048 px, repeats

const float W = 3769.911184;

// Hashes that repeat every `period` cells, so a layer can drift a whole period per time wrap.
float hashp(vec2 i, float period) {
    return fract(sin(dot(mod(i, period), vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2p(vec2 i, float period) {
    i = mod(i, period);
    return fract(sin(vec2(dot(i, vec2(127.1, 311.7)), dot(i, vec2(269.5, 183.3)))) * 43758.5453);
}

// One star per cell. keep: share of cells that hold a star; size: core radius in px of the faintest star;
// flare: 0..1 strength of the glow and the four spikes around bright stars.
vec3 stars(vec2 p, float cell, float period, float keep, float size, float flare, float t) {
    vec2 i = floor(p / cell);
    vec2 r = hash2p(i, period);
    if (hashp(i + 31.7, period) > keep) {
        return vec3(0.0);
    }
    vec2 q = p - (i + 0.2 + 0.6 * r) * cell;
    float d = length(q);
    float mag = pow(hashp(i + 5.1, period), 5.0);                // few bright stars, many faint ones
    float rad = size * (0.8 + 1.4 * mag);
    float rate = floor(360.0 + 1080.0 * r.x) / 600.0;            // 0.6..2.4 rad/s, a multiple of 1/600
    float twinkle = 1.0 - 0.3 * (0.5 + 0.5 * sin(t * rate + 6.2832 * r.y));
    float light = exp(-d * d / (rad * rad));
    // Glow and spikes stay inside the cell: they fade out 0.2 cells from the star.
    float reach = 1.0 - smoothstep(0.08 * cell, 0.2 * cell, d);
    light += flare * mag * reach * (0.35 / (1.0 + d * d / (rad * rad * 3.0))
                                    + 0.6 * exp(-abs(q.x) * abs(q.y) * 0.6) * exp(-d / (5.0 + 16.0 * mag)));
    float k = hashp(i + 11.3, period);                           // colour temperature
    vec3 hue = k < 0.22 ? vec3(0.72, 0.82, 1.00) : (k < 0.62 ? vec3(1.0) : (k < 0.86 ? vec3(1.00, 0.93, 0.78) : vec3(1.00, 0.78, 0.58)));
    return hue * light * twinkle * (0.30 + 0.70 * mag);
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;
    float t = time;
    float w = drift * t / W;                                     // 0..1 over one time wrap
    vec4 m = texture(mask, qt_TexCoord0);
    float heart = clamp(m.r, 0.0, 1.0);
    float halo = clamp(m.g, 0.0, 1.0);

    // The far sky moves 2816 px per wrap (0.75 px/s); nearer star layers move faster.
    vec2 far = px + vec2(2816.0 * w, 0.0);

    // Space: near black, faintly mottled.
    vec4 n0 = texture(noiseTex, far / 1408.0);
    vec3 col = cSpace.rgb * (0.75 + 0.5 * n0.r) + cNebulaA.rgb * 0.04 * n0.g;

    // Milky Way: a band of faint light across the screen, split by dark dust rifts.
    float milky = 0.0;
    if (band > 0.5) {
        float across = dot(px - 0.5 * resolution, vec2(0.5, 0.866));            // px from the band's middle line
        float width = 0.26 * min(resolution.x, resolution.y);
        vec4 nb = texture(noiseTex, far / 704.0 + 0.21);
        float profile = exp(-pow((across + 0.5 * width * (n0.g - 0.5)) / width, 2.0));
        float rift = smoothstep(0.50, 0.95, 1.0 - abs(2.0 * nb.r - 1.0)) * exp(-pow(across / (0.45 * width), 2.0));
        milky = profile * (0.35 + 0.65 * n0.b) * (1.0 - 0.75 * rift);
        col += (0.55 * cStar.rgb + 0.45 * cNebulaA.rgb) * milky * 0.16 * (0.6 + 0.8 * nb.g);
    }

    // Nebula around the icons: warped noise gives wisps and filaments instead of flat patches.
    vec2 warp = texture(noiseTex, px / 1100.0 + vec2(15.0, -9.0) * (t / W)).rg - 0.5;
    vec2 q = px + 130.0 * warp;
    vec4 f1 = texture(noiseTex, q / 760.0 + vec2(-6.0, 4.0) * (t / W));
    vec4 f2 = texture(noiseTex, q / 290.0 + 0.43);
    vec4 f3 = texture(noiseTex, q / 120.0 + 0.71);
    float cloud = 0.50 * f1.r + 0.32 * f2.g + 0.18 * f3.r;
    float filament = pow(1.0 - abs(2.0 * f2.r - 1.0), 3.0);
    float gas = halo * smoothstep(0.30, 0.80, cloud + 0.30 * heart);
    vec3 neb = mix(cNebulaA.rgb, cNebulaB.rgb, smoothstep(0.35, 0.75, f2.g + 0.35 * heart));
    col += neb * gas * (0.50 + 0.35 * filament);
    col += cNebulaB.rgb * filament * halo * halo * 0.22;
    col += cCore.rgb * heart * heart * (0.20 + 0.30 * f3.g);
    col *= 1.0 - 0.55 * halo * smoothstep(0.45, 0.85, 1.0 - abs(2.0 * f1.g - 1.0)) * (1.0 - 0.7 * heart);   // dust lanes

    // Stars: three depths. The faint layer is denser inside the gas and the Milky Way.
    float dens = density / 5.0;
    vec3 s = stars(far, 22.0, 128.0, 0.30 * dens * (0.6 + 0.7 * halo + 2.2 * milky), 0.75, 0.0, t) * 0.75;
    s += stars(px + vec2(3840.0 * w + 113.0, 57.0), 60.0, 64.0, 0.50 * dens, 1.0, 0.5, t);
    s += stars(px + vec2(6080.0 * w + 571.0, 311.0), 190.0, 32.0, 0.55 * dens, 1.3, 1.0, t) * 1.2;
    col += cStar.rgb * s;

    // Soft roll-off instead of clipping, then a slight darkening toward the corners.
    col = 1.0 - exp(-1.25 * col);
    vec2 v = (qt_TexCoord0 - 0.5) * 2.0;
    col *= 1.0 - 0.22 * smoothstep(0.7, 1.5, length(v));

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
