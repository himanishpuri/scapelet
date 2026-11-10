#version 440
// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;       // seconds, wraps at 3769.911184
    float sigma;      // px, must match the blobs' sigma
    float warp;       // px, coastline irregularity
    vec2 resolution;  // px, item size
};
layout(binding = 1) uniform sampler2D mask; // r = land sum, g = shallow sum
layout(binding = 2) uniform sampler2D noiseTex; // r, g: warp fields, b: phase field; tile = 2048 px

const float E0 = 0.0183156;
const float C0 = 0.8217; // sqrt(-ln(0.5 * (1 - E0) + E0)): shoreline is where land == 0.5

const vec3 DEEP      = vec3(0.043, 0.365, 0.478); // #0b5d7a
const vec3 MID       = vec3(0.094, 0.600, 0.659); // #1899a8
const vec3 SHALLOW   = vec3(0.310, 0.816, 0.780); // #4fd0c7
const vec3 SHOAL     = vec3(0.659, 0.925, 0.875); // #a8ecdf
const vec3 FOAM      = vec3(1.0, 1.0, 1.0);
const vec3 SAND_WET  = vec3(0.804, 0.690, 0.478); // #cdb07a
const vec3 SAND_DRY  = vec3(0.902, 0.812, 0.612); // #e6cf9c
const vec3 SAND_HIGH = vec3(0.929, 0.851, 0.671); // #edd9ab

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Approximate signed distance to the shoreline in px: negative inland, positive offshore.
float shoreDist(float land) {
    float g = clamp(land, 0.0, 1.0) * (1.0 - E0) + E0;
    return sigma * (sqrt(-log(g)) - C0);
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;
    float t = time;

    // Static coastline warp.
    vec4 n = texture(noiseTex, px / 2048.0);
    vec2 w = n.rg - 0.5;
    vec2 uv = (px + w * 2.0 * warp) / resolution;
    vec4 m = texture(mask, uv);
    float s = shoreDist(m.r);
    float shallow = clamp(m.g, 0.0, 1.0);

    // Sea colour by depth.
    vec3 water = mix(DEEP, MID, smoothstep(0.0, 0.35, shallow));
    water = mix(water, SHALLOW, smoothstep(0.30, 0.85, shallow));

    // Drifting ripple lines where two moving noise fields meet.
    float r1 = vnoise(px * 0.018 + vec2(t * 0.35, t * 0.22));
    float r2 = vnoise(px * 0.031 + vec2(-t * 0.27, t * 0.31));
    float ripple = 1.0 - smoothstep(0.0, 0.035, abs(r1 - r2));
    water += ripple * 0.07 * (0.4 + 0.6 * shallow);

    // Swash: the waterline moves in and out by 6 px, phase varies along the coast.
    float phase = 6.2832 * n.b;
    float sw = s + 6.0 * sin(t * 0.9 + phase); // > 0 is water

    // Clear water over sand near the shore.
    water = mix(water, SHOAL, (1.0 - smoothstep(0.0, 26.0, sw)) * 0.75);

    // Sand: lighter toward the island centre, darker (wet) near the waterline.
    float grain = hash(floor(px)) - 0.5;
    vec3 sand = mix(SAND_HIGH, SAND_DRY, smoothstep(-0.6 * sigma, -12.0, s));
    sand = mix(sand, SAND_WET, smoothstep(-16.0, -6.0, s) * 0.85);
    sand += grain * 0.035;

    vec3 col = mix(sand, water, smoothstep(-0.75, 0.75, sw));

    // Foam: a solid line at the waterline and a broken second line offshore.
    float foam1 = 1.0 - smoothstep(0.0, 2.5, abs(sw - 1.5));
    float foam2 = 1.0 - smoothstep(0.0, 2.0, abs(sw - 13.0 - 3.0 * sin(t * 0.6 + phase * 1.7)));
    float foamBreak = smoothstep(0.25, 0.6, vnoise(px * 0.05 + vec2(t * 0.1, 0.0)));
    col = mix(col, FOAM, clamp(foam1 * 0.9 + foam2 * foamBreak * 0.45, 0.0, 1.0));

    col += grain * 0.012;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
