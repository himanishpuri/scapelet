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
    float puff;       // px, spacing of the big puffs on the clouds over icons
    float shadow;     // 1: clouds cast a shadow on the grass, 0: none
    float altitude;   // px, how far from a cloud its shadow falls
    float cover;      // 0..5, amount of drifting clouds; 0: none
    vec2 resolution;  // px, item size
    vec4 tint;        // light colour, multiplies the result
    vec4 cGrassDark;
    vec4 cGrassMid;
    vec4 cGrassLight;
    vec4 cHaze;
    vec4 cShadow;     // multiplies the grass under a cloud
    vec4 cCloudLight;
    vec4 cCloudCore;
    vec4 cCloudShade;
};
layout(binding = 1) uniform sampler2D mask;     // r = narrow sum (cloud), g = wide sum (haze)
layout(binding = 2) uniform sampler2D noiseTex; // r, g: 2-octave noise, b: phase field; tile = 2048 px

const float W = 3769.911184;
const float E0 = 0.0183156;
const float C0 = 0.8217;            // the cloud outline is where the narrow sum == 0.5
const float SKY = 3072.0;           // px, one tile of the drifting-cloud noise
const float SKY_BIG = 96.0;         // px, puff spacing of the drifting clouds: SKY / 32
const vec2 LIGHT = vec2(0.6, 0.8);  // shadows fall this way

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

float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

// Approximate signed distance (px, negative inside) to the cloud mass.
// layer 0: clouds over icons, p in screen px. layer 1: drifting clouds, p in their own moving frame.
float mass(vec2 p, float layer) {
    if (layer < 0.5) {
        float g = clamp(texture(mask, p / resolution).r, 0.0, 1.0) * (1.0 - E0) + E0;
        return sigma * (sqrt(-log(g)) - C0);
    }
    return (0.74 - 0.04 * cover - texture(noiseTex, p / SKY).r) * 260.0;
}

// The clouds of one layer at p. g: spacing of the big puffs. fine: also add the small rim puffs.
// Returns the signed distance to the cloud (px, negative inside). front.xy: centre of the puff
// drawn on top at p, front.z: its radius (0: none), front.w: its shade 0..1.
float cloud(vec2 p, float layer, float g, bool fine, inout vec4 front) {
    float s = mass(p, layer);
    float d = s + 0.3 * g;                        // the mass, drawn smaller: the puffs make the outline
    if (s > 0.95 * g) {
        return d;                                 // no puff can reach this far
    }
    float period = layer < 0.5 ? 4096.0 : SKY / g;   // drifting puffs repeat with their noise tile
    vec2 id = floor(p / g);
    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            vec2 c = id + vec2(float(i), float(j));
            vec2 cm = mod(c, period);
            vec2 h = hash2(cm);
            vec2 o = (c + 0.2 + 0.6 * h) * g;
            float sc = mass(o, layer);
            float rate = floor(54.0 + 36.0 * h.y) / 600.0;                // 0.09..0.15 rad/s, a multiple of 1/600
            float r = g * (0.55 + 0.35 * hash(cm + 7.7)) * (1.0 - smoothstep(-0.6 * g, 0.15 * g, sc))
                      * (1.0 + 0.04 * sin(time * rate + 6.2832 * h.x));
            // A puff must reach 4 px into the drawn mass, so none floats free.
            if (r < sc + 0.3 * g + 4.0) continue;
            float dc = length(p - o) - r;
            d = smin(d, dc, 6.0);
            if (dc < 0.0 && o.y > front.y) {
                front = vec4(o, r, hash(cm + 3.3));
            }
        }
    }
    if (!fine) {
        return d;
    }
    float g2 = g * 0.5;
    period *= 2.0;
    id = floor(p / g2);
    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            vec2 c = id + vec2(float(i), float(j));
            vec2 cm = mod(c, period) + 91.0;
            vec2 h = hash2(cm);
            vec2 o = (c + 0.2 + 0.6 * h) * g2;
            float sc = mass(o, layer);
            // Small puffs sit only on the rim: none outside, none deeper than one big puff.
            float r = g2 * (0.50 + 0.40 * hash(cm + 7.7)) * (1.0 - smoothstep(-0.5 * g2, 0.3 * g2, sc))
                      * smoothstep(-1.1 * g, -0.5 * g, sc);
            if (r < max(5.0, sc + 0.3 * g + 4.0)) continue;
            float dc = length(p - o) - r;
            d = smin(d, dc, 6.0);
            if (dc < 0.0 && o.y > front.y) {
                front = vec4(o, r, hash(cm + 3.3));
            }
        }
    }
    return d;
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;
    float t = time;
    vec4 n = texture(noiseTex, px / 2048.0);
    vec4 m = texture(mask, qt_TexCoord0);

    // Meadow: patches of darker and lighter grass.
    const vec2 wind = vec2(0.94, 0.34);     // unit vector the gusts travel along
    const vec2 across = vec2(-0.34, 0.94);
    float tone = texture(noiseTex, px / 900.0 + 0.37).g;
    vec3 grass = mix(cGrassDark.rgb, cGrassMid.rgb, smoothstep(0.25, 0.60, n.r));
    grass = mix(grass, cGrassLight.rgb, smoothstep(0.45, 0.85, tone) * 0.6);

    // Blades: streaks stretched along the wind that sway from side to side.
    float swayx = 1.5 * sin(t * 0.7 + 6.2832 * n.b);
    float blades = vnoise(vec2(dot(px, across) * 0.55 + swayx, dot(px, wind) * 0.07));
    grass *= 0.90 + 0.20 * blades;

    // Gusts: bright bands that run downwind, in patches.
    float band = sin(dot(px, wind) * 0.035 - t * 1.2 + 9.0 * n.g);
    float gusty = smoothstep(0.35, 0.75, vnoise(px * 0.004 + vec2(-t * 0.05, t * 0.02)));
    grass = mix(grass, cGrassLight.rgb, smoothstep(0.35, 1.0, band) * gusty * 0.35);
    grass = mix(grass, cHaze.rgb, 0.10 * clamp(m.g, 0.0, 1.0));

    // Drifting clouds live in a frame that moves 6 tiles right and 1 down per time wrap (4.9 px/s).
    vec2 skyShift = vec2(6.0, 1.0) * SKY * (t / W);
    vec4 none = vec4(0.0, -1.0e6, 0.0, 0.0);

    // Shadows: the same clouds, big puffs only, seen `altitude` px up-left of here.
    if (shadow > 0.5) {
        vec2 ps = px - LIGHT * altitude;
        vec4 unused = none;
        float sd = cloud(ps, 0.0, puff, false, unused);
        if (cover > 0.5) {
            sd = min(sd, cloud(ps - skyShift, 1.0, SKY_BIG, false, unused));
        }
        grass = mix(grass, grass * cShadow.rgb, 0.85 * (1.0 - smoothstep(-3.0, 3.0, sd)));
    }

    // Clouds.
    vec4 front = none;
    float d = cloud(px, 0.0, puff, true, front);
    if (cover > 0.5) {
        vec4 skyFront = none;
        d = min(d, cloud(px - skyShift, 1.0, SKY_BIG, true, skyFront));
        skyFront.xy += skyShift;
        if (skyFront.y > front.y) {
            front = skyFront;
        }
    }

    // Each puff has one flat shade, like cut paper; the side of the outline that faces the light is white.
    vec3 cloudCol = mix(cCloudCore.rgb, cCloudShade.rgb, 0.4);
    if (front.z > 0.0) {
        vec2 v = px - front.xy;
        float lit = dot(v / max(length(v), 0.001), -LIGHT);     // 1 on the side that faces the light
        cloudCol = mix(cCloudCore.rgb, cCloudShade.rgb, 0.75 * front.w);
        cloudCol = mix(cloudCol, cCloudLight.rgb, smoothstep(-16.0, -7.0, d) * smoothstep(-0.1, 0.5, lit));
    }
    // Calm core under the icons.
    cloudCol = mix(cloudCol, cCloudCore.rgb, 0.8 * smoothstep(0.50, 0.85, m.r));

    vec3 col = mix(grass, cloudCol, 1.0 - smoothstep(-1.0, 1.0, d));
    col += (hash(floor(px)) - 0.5) * 0.012;
    col *= tint.rgb;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
