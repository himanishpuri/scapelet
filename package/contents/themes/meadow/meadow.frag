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
    float fluff;      // px, how far the billows push the cloud edge out and in
    float shadow;     // 1: clouds cast a shadow on the grass, 0: none
    vec2 resolution;  // px, item size
    vec4 tint;        // light colour, multiplies the result
    vec4 cGrassDark;
    vec4 cGrassMid;
    vec4 cGrassLight;
    vec4 cHaze;
    vec4 cCloudLight;
    vec4 cCloudCore;
    vec4 cCloudShade;
};
layout(binding = 1) uniform sampler2D mask;     // r = narrow sum (cloud), g = wide sum (haze)
layout(binding = 2) uniform sampler2D noiseTex; // r, g: 2-octave noise, b: phase field; tile = 2048 px

const float E0 = 0.0183156;
const float C0 = 0.8217; // the cloud outline is where the narrow sum == 0.5

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
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

// Distance to the nearest feature point in cell units, 0..1: round lobes with creases between them.
float worley(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float d = 1.0;
    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            vec2 c = vec2(float(x), float(y));
            vec2 o = 0.2 + 0.6 * hash2(i + c);
            d = min(d, length(c + o - f));
        }
    }
    return d;
}

// Approximate signed distance to the 0.5 contour of the narrow sum, in px: negative inside.
float shoreDist(float land) {
    float g = clamp(land, 0.0, 1.0) * (1.0 - E0) + E0;
    return sigma * (sqrt(-log(g)) - C0);
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;
    float t = time;
    vec4 n = texture(noiseTex, px / 2048.0);

    // Meadow: patches of darker and lighter grass.
    const vec2 wind = vec2(0.94, 0.34);     // unit vector the gusts travel along
    const vec2 across = vec2(-0.34, 0.94);
    float tone = texture(noiseTex, px / 900.0 + 0.37).g;
    vec3 grass = mix(cGrassDark.rgb, cGrassMid.rgb, smoothstep(0.25, 0.60, n.r));
    grass = mix(grass, cGrassLight.rgb, smoothstep(0.45, 0.85, tone) * 0.6);

    // Blades: streaks stretched along the wind that sway from side to side.
    float sway = 1.5 * sin(t * 0.7 + 6.2832 * n.b);
    float blades = vnoise(vec2(dot(px, across) * 0.55 + sway, dot(px, wind) * 0.07));
    grass *= 0.90 + 0.20 * blades;

    // Gusts: bright bands that run downwind, in patches.
    float band = sin(dot(px, wind) * 0.035 - t * 1.2 + 9.0 * n.g);
    float gusty = smoothstep(0.35, 0.75, vnoise(px * 0.004 + vec2(-t * 0.05, t * 0.02)));
    grass = mix(grass, cGrassLight.rgb, smoothstep(0.35, 1.0, band) * gusty * 0.35);

    // Cloud outline: the field contour, bent by static noise, with billows on top.
    vec2 pw = px + (n.rg - 0.5) * 0.6 * sigma;
    vec4 m = texture(mask, pw / resolution);
    float s = shoreDist(m.r);
    vec2 drift = vec2(t * 0.010, t * 0.004);
    float big = 1.0 - worley(px / 54.0 + drift);
    float small = 1.0 - worley(px / 23.0 + 7.3 - drift * 1.7);
    float lobes = 0.65 * big + 0.35 * small;                 // 0..1, highest in the middle of a billow
    // No billows where the field is empty, so no cloud can appear far from an icon.
    float e = s - fluff * (2.0 * lobes - 1.0) * smoothstep(0.0, 0.08, m.r);   // px, < 0 inside the cloud

    // Haze around the clouds and their shadow, shifted away from the light.
    grass = mix(grass, cHaze.rgb, 0.10 * clamp(m.g, 0.0, 1.0));
    float ss = shoreDist(texture(mask, (pw - vec2(26.0, 34.0)) / resolution).r);
    grass *= 1.0 - 0.38 * shadow * (1.0 - smoothstep(-12.0, 30.0, ss));

    // Cloud shading: a height field (rising inward, billows flattening toward the core) lit from the top left.
    float depth = clamp(-e / (0.9 * sigma), 0.0, 1.0);
    float h = 0.55 * depth + 0.45 * lobes * (1.0 - 0.6 * depth);
    // Gradient per px; dividing by the derivative of px keeps the sign and scale right on every backend.
    vec2 g = vec2(dFdx(h) / dFdx(px.x), dFdy(h) / dFdy(px.y));
    float lit = clamp(0.5 + dot(g, vec2(0.61, 0.79)) * 22.0, 0.0, 1.0);
    vec3 cloud = mix(cCloudShade.rgb, cCloudLight.rgb, lit);
    cloud = mix(cloud, cCloudCore.rgb, smoothstep(0.35, 0.9, depth) * 0.7);       // calm core under the icons
    cloud = mix(cloud, cCloudLight.rgb, (1.0 - smoothstep(0.0, 9.0, -e)) * lit * 0.6);   // bright rim on the lit side

    vec3 col = mix(grass, cloud, 1.0 - smoothstep(-1.5, 1.5, e));
    col += (hash(floor(px)) - 0.5) * 0.012;
    col *= tint.rgb;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
