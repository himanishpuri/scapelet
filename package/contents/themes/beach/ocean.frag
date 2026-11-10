#version 440
// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;       // seconds, wraps at 3769.911184
    float sigma;      // px, must match the field blobs' sigma
    float warp;       // px, coastline irregularity
    vec2 resolution;  // px, item size
    vec4 strip;       // x: 0 none, 1 left, 2 right, 3 top, 4 bottom; y: width px
    vec4 tint;        // light colour, multiplies the result
    vec4 cDeep;
    vec4 cMid;
    vec4 cShallow;
    vec4 cShoal;
    vec4 cFoam;
    vec4 cSandWet;
    vec4 cSandDry;
    vec4 cSandHigh;
};
layout(binding = 1) uniform sampler2D mask; // r = land sum, g = shallow sum
layout(binding = 2) uniform sampler2D noiseTex; // r, g: warp fields, b: phase field; tile = 2048 px

const float E0 = 0.0183156;
const float C0 = 0.8217; // sqrt(-ln(0.5 * (1 - E0) + E0)): shoreline is where land == 0.5

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

// Same falloff as shaders/field.frag.
float bump(float d, float s) {
    float g = exp(-(d * d) / (s * s));
    return max(0.0, (g - E0) / (1.0 - E0));
}

// Distance from the screen edge that carries the permanent beach.
float edgeDist(vec2 p) {
    if (strip.x < 1.5) return p.x;
    if (strip.x < 2.5) return resolution.x - p.x;
    if (strip.x < 3.5) return p.y;
    return resolution.y - p.y;
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;
    float t = time;

    // Static coastline warp.
    vec4 n = texture(noiseTex, px / 2048.0);
    vec2 w = n.rg - 0.5;
    vec2 pw = px + w * 2.0 * warp;
    vec4 m = texture(mask, pw / resolution);
    float land = m.r;
    float shallow = m.g;
    if (strip.x > 0.5) {
        // Solid land up to strip.y px from the edge: the 0.5 contour of bump() lies C0 * sigma past its core.
        float d = max(edgeDist(pw) - (strip.y - C0 * sigma), 0.0);
        land += bump(d, sigma);
        shallow += bump(d, sigma * 2.5);
    }
    float s = shoreDist(land);
    shallow = clamp(shallow, 0.0, 1.0);

    // Sea colour by depth.
    vec3 water = mix(cDeep.rgb, cMid.rgb, smoothstep(0.0, 0.35, shallow));
    water = mix(water, cShallow.rgb, smoothstep(0.30, 0.85, shallow));

    // Drifting ripple lines where two moving noise fields meet.
    float r1 = vnoise(px * 0.018 + vec2(t * 0.35, t * 0.22));
    float r2 = vnoise(px * 0.031 + vec2(-t * 0.27, t * 0.31));
    float ripple = 1.0 - smoothstep(0.0, 0.035, abs(r1 - r2));
    water += ripple * 0.07 * (0.4 + 0.6 * shallow);

    // Swash: the waterline moves in and out by 6 px, phase varies along the coast.
    float phase = 6.2832 * n.b;
    float sw = s + 6.0 * sin(t * 0.9 + phase); // > 0 is water

    // Clear water over sand near the shore.
    water = mix(water, cShoal.rgb, (1.0 - smoothstep(0.0, 26.0, sw)) * 0.75);

    // Sand: lighter toward the island centre, darker (wet) near the waterline.
    float grain = hash(floor(px)) - 0.5;
    vec3 sand = mix(cSandHigh.rgb, cSandDry.rgb, smoothstep(-0.6 * sigma, -12.0, s));
    sand = mix(sand, cSandWet.rgb, smoothstep(-16.0, -6.0, s) * 0.85);
    sand += grain * 0.035;

    vec3 col = mix(sand, water, smoothstep(-0.75, 0.75, sw));

    // Foam: a solid line at the waterline and a broken second line offshore.
    float foam1 = 1.0 - smoothstep(0.0, 2.5, abs(sw - 1.5));
    float foam2 = 1.0 - smoothstep(0.0, 2.0, abs(sw - 13.0 - 3.0 * sin(t * 0.6 + phase * 1.7)));
    float foamBreak = smoothstep(0.25, 0.6, vnoise(px * 0.05 + vec2(t * 0.1, 0.0)));
    col = mix(col, cFoam.rgb, clamp(foam1 * 0.9 + foam2 * foamBreak * 0.45, 0.0, 1.0));

    col += grain * 0.012;
    col *= tint.rgb;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
