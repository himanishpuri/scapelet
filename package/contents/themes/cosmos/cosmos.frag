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
    vec2 resolution;  // px, item size
    vec4 cSpace;
    vec4 cNebulaA;
    vec4 cNebulaB;
    vec4 cStar;
};
layout(binding = 1) uniform sampler2D mask;     // r = narrow sum (heart), g = wide sum (gas)
layout(binding = 2) uniform sampler2D noiseTex; // r, g: 2-octave noise, b: 1 octave; tile = 2048 px, repeats

const float W = 3769.911184;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// One star per cell at a random spot. keep: share of cells that hold a star; size: radius in px.
float stars(vec2 p, float cell, float keep, float size, float t) {
    vec2 i = floor(p / cell);
    vec2 r = hash2(i);
    float present = step(hash(i + 31.7), keep);
    float d = length(p - (i + 0.15 + 0.7 * r) * cell);
    float rate = floor(360.0 + 1080.0 * r.x) / 600.0;            // 0.6..2.4 rad/s, a multiple of 1/600
    float twinkle = 0.65 + 0.35 * sin(t * rate + 6.2832 * r.y);
    return present * twinkle * (1.0 - smoothstep(0.0, size * (0.6 + 0.8 * hash(i + 5.1)), d));
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;
    float t = time;
    vec4 m = texture(mask, qt_TexCoord0);
    float heart = clamp(m.r, 0.0, 1.0);
    float halo = clamp(m.g, 0.0, 1.0);

    // Space: near black, faintly mottled.
    vec4 n0 = texture(noiseTex, px / 2048.0);
    vec3 col = cSpace.rgb * (0.75 + 0.5 * n0.r) + cNebulaA.rgb * 0.05 * n0.g;

    // Nebula: gas that thins out away from the icons; two noise layers drift in different directions.
    vec4 n1 = texture(noiseTex, px / 1100.0 + vec2(15.0, -9.0) * (t / W));
    vec4 n2 = texture(noiseTex, px / 420.0 + vec2(-27.0, 16.0) * (t / W) + n1.rg * 0.08);
    float wisp = 0.6 * n1.r + 0.4 * n2.g;
    float gas = halo * smoothstep(0.18, 0.80, wisp + 0.55 * heart);
    vec3 neb = mix(cNebulaA.rgb, cNebulaB.rgb, smoothstep(0.3, 0.7, n2.r + 0.3 * heart));
    col += neb * gas * 0.85;
    col += cNebulaB.rgb * heart * heart * 0.25;
    col *= 1.0 - 0.35 * halo * smoothstep(0.55, 0.75, n2.b);     // dark dust lanes

    // Stars: three sizes; the small ones are denser inside the gas.
    float dens = density / 5.0;
    float s1 = stars(px, 38.0, 0.45 * dens * (0.7 + 0.6 * halo), 1.2, t);
    float s2 = stars(px + 113.0, 97.0, 0.50 * dens, 2.0, t);
    float s3 = stars(px + 571.0, 260.0, 0.40 * dens, 3.0, t);
    col += cStar.rgb * (0.55 * s1 + 0.85 * s2 + s3);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
