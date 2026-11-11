#version 440
// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;       // seconds, wraps at 3769.911184; 0 while the trees do not sway
    float cell;       // px, spacing of the tree grid
    float keep;       // 0..1, share of grid cells that hold a tree
    float size;       // px, scale of a tree: up to 2 sizes tall and 0.8 sizes to each side; >= cell
    float sway;       // px, how far a tree top moves in the wind
    vec2 resolution;  // px, item size
    vec4 tint;        // light colour, multiplies the result
    vec4 cGrassLight;
    vec4 cGrassMid;
    vec4 cGrassDeep;
    vec4 cInk;
    vec4 cShadow;     // multiplies the grass under a tree
    vec4 cTrunk;
    vec4 cLeaf0;
    vec4 cLeaf1;
    vec4 cLeaf2;
    vec4 cLeaf3;
    vec4 cLeaf4;
    vec4 cLeaf5;
};
layout(binding = 1) uniform sampler2D mask;     // r = narrow sum: > 0 near an icon
layout(binding = 2) uniform sampler2D noiseTex; // r, g: 2-octave noise, b: 1 octave; tile = 2048 px, repeats

const float E0 = 0.0183156;   // exp(-4): the field blobs' floor, see shaders/field.frag

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

vec3 leaf(float k) {
    if (k < 1.0) return cLeaf0.rgb;
    if (k < 2.0) return cLeaf1.rgb;
    if (k < 3.0) return cLeaf2.rgb;
    if (k < 4.0) return cLeaf3.rgb;
    if (k < 5.0) return cLeaf4.rgb;
    return cLeaf5.rgb;
}

// Half width of a crown at height v (0 = root, 1 = top) as a share of the tree's half width; 0 outside.
// kind: 0 fir (tiers), 1 round, 2 cypress, 3 two stacked balls, 4 broad crown on a long trunk.
// tier: 0..1 position inside a fir tier (0 elsewhere).
float crown(float kind, float v, float seed, out float tier) {
    tier = 0.0;
    if (kind < 0.5) {
        float t = (v - 0.14) / 0.86;
        if (t < 0.0 || t > 1.0) return 0.0;
        float n = 3.0 + floor(seed * 2.0);
        tier = fract(t * n);
        return (1.0 - 0.80 * t) * (1.0 - 0.45 * tier) * smoothstep(0.0, 0.10, tier) * (1.0 - smoothstep(0.94, 1.0, t));
    }
    if (kind < 1.5) {
        float y = (v - 0.62) / 0.38;
        return sqrt(max(0.0, 1.0 - y * y));
    }
    if (kind < 2.5) {
        float y = (v - 0.56) / 0.44;
        return 0.52 * pow(max(0.0, 1.0 - y * y), 0.75);
    }
    if (kind < 3.5) {
        float a = (v - 0.42) / 0.27;
        float b = (v - 0.77) / 0.23;
        return max(sqrt(max(0.0, 1.0 - a * a)), 0.70 * sqrt(max(0.0, 1.0 - b * b)));
    }
    float y = (v - 0.72) / 0.28;
    return sqrt(max(0.0, 1.0 - y * y)) * (0.93 + 0.07 * sin(v * 38.0 + seed * 6.2832));
}

// Height where the crown starts: the trunk shows below it.
float crownBase(float kind) {
    if (kind < 0.5) return 0.14;
    if (kind < 1.5) return 0.24;
    if (kind < 2.5) return 0.12;
    if (kind < 3.5) return 0.15;
    return 0.44;
}

// Short pen strokes in the grass, one per 12 x 6 px cell. dens: share of cells with a stroke.
float strokes(vec2 p, float dens) {
    const vec2 g = vec2(12.0, 6.0);
    vec2 id = floor(p / g);
    float a = 0.0;
    for (int j = -1; j <= 1; ++j) {
        vec2 c = id + vec2(0.0, float(j));
        vec2 h = hash2(c);
        if (hash(c + 4.2) > dens) continue;
        vec2 d = p - (c + vec2(0.5, 0.2 + 0.6 * h.y)) * g;
        float ang = (h.x - 0.5) * 0.7;
        vec2 r = vec2(d.x * cos(ang) + d.y * sin(ang), d.y * cos(ang) - d.x * sin(ang));
        float dist = length(vec2(max(abs(r.x) - (2.5 + 3.0 * h.y), 0.0), r.y));
        a = max(a, (1.0 - smoothstep(0.4, 1.1, dist)) * (0.35 + 0.45 * h.x));
    }
    return a;
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;

    // Grass: pale washes, darker patches, pen strokes where the washes are light.
    float w1 = texture(noiseTex, px / 1900.0).r;
    float w2 = texture(noiseTex, px / 650.0 + 0.37).g;
    float w3 = texture(noiseTex, px / 1300.0 + 0.11).b;
    vec4 grainTex = texture(noiseTex, px / 260.0);
    vec3 grass = mix(cGrassMid.rgb, cGrassLight.rgb, smoothstep(0.30, 0.75, w1 * 0.7 + w2 * 0.3));
    grass = mix(grass, cGrassDeep.rgb, 0.4 * smoothstep(0.50, 0.80, w3));
    float dens = 0.75 * smoothstep(0.42, 0.72, w2) * smoothstep(0.35, 0.60, w3) + 0.02;
    grass = mix(grass, cInk.rgb, 0.6 * strokes(px, dens));
    // The clearing is a little brighter than the forest floor.
    grass *= 1.0 + 0.05 * smoothstep(0.0, 0.5, texture(mask, qt_TexCoord0).r);

    // Trees: one per grid cell, drawn front (lower on screen) to back. A tree is at most 2 sizes
    // tall and 0.8 sizes (plus the sway) to each side. Its root lies 0.15..0.85 into its cell, so
    // rows up to 0.85 + 2 sizes / cell below and columns up to 0.85 + 0.8 sizes / cell aside can
    // cover a pixel: 3 rows and 3 columns at the default spacing (cell == size). The row above
    // only adds its shadow.
    vec2 id = floor(px / cell);
    vec4 acc = vec4(0.0);      // premultiplied colour of the trees over this pixel
    float shade = 0.0;         // 0..1 ground shadow
    int rows = int(floor(0.85 + 2.0 * size / cell));
    int side = int(floor(0.85 + (0.8 * size + sway) / cell));
    for (int dj = rows; dj >= -1; --dj) {
        for (int di = -side; di <= side; ++di) {
            if (acc.a > 0.995) continue;
            vec2 c = id + vec2(float(di), float(dj));
            vec2 h = hash2(c);
            vec2 k = hash2(c + 17.3);
            if (k.x > keep) continue;
            vec2 root = (c + 0.15 + 0.7 * h) * cell;
            float kindSel = fract(k.x * 61.0);
            float kind = kindSel < 0.36 ? 0.0 : (kindSel < 0.58 ? 1.0 : (kindSel < 0.72 ? 2.0 : (kindSel < 0.86 ? 3.0 : 4.0)));
            float height = size * (1.25 + 0.75 * k.y);
            float halfW = min(0.8, (0.46 + 0.26 * fract(k.y * 37.0)) * (kind < 0.5 ? 1.0 : (kind < 1.5 ? 1.15 : (kind < 2.5 ? 1.0 : (kind < 3.5 ? 0.95 : 1.3))))) * size;

            // The tree shrinks into the ground where its middle is near an icon. lev is the distance to
            // the nearest icon's core in units of sigma (2: far away). A wide band of lev keeps each tree
            // shrinking for several hundred ms while the clearing grows; each tree has its own band.
            float open = clamp(texture(mask, (root - vec2(0.0, 0.5 * height)) / resolution).r, 0.0, 1.0);
            float lev = sqrt(-log(open * (1.0 - E0) + E0));
            float jit = 0.3 * (fract(k.x * 17.0) - 0.5);
            float s = smoothstep(1.0 + jit, 1.8 + jit, lev);
            if (s < 0.02) continue;
            float fade = smoothstep(0.02, 0.4, s);                   // the last bit of a tree fades out

            vec2 q = vec2(px.x - root.x, root.y - px.y) / s;     // px in the tree's own frame, y up

            if (dj <= 1) {
                vec2 e = (q - vec2(0.30 * halfW, -0.03 * height)) / vec2(0.9 * halfW, 0.10 * height + 2.0);
                shade = max(shade, (1.0 - smoothstep(0.55, 1.0, length(e))) * s * fade);
            }
            if (dj < 0 || q.y < 0.0 || q.y > height) continue;

            float v = q.y / height;
            // Wind: gusts sweep across the forest downwind (60 px/s) and lean the trees they pass;
            // each tree also flutters on its own.
            float gust = smoothstep(0.15, 0.95, 0.5 + 0.5 * sin(dot(root, vec2(0.94, 0.34)) * 0.005 - time * 0.3));
            float rate = floor(300.0 + 240.0 * h.x) / 600.0;     // 0.5..0.9 rad/s, a multiple of 1/600
            float flutter = floor(1200.0 + 600.0 * h.y) / 600.0; // 2..3 rad/s
            q.x -= sway * v * v * (gust * (0.75 + 0.25 * sin(time * flutter + 6.2832 * h.x)) + 0.2 * sin(time * rate + 6.2832 * h.y));
            float tier;
            float cw = crown(kind, v, h.x, tier) * halfW;
            float trunk = v < crownBase(kind) + 0.06 ? max(1.5, 0.07 * halfW + 0.012 * height) : 0.0;
            float aCrown = clamp((cw - abs(q.x)) * s + 0.5, 0.0, 1.0) * step(0.001, cw);
            float aTrunk = clamp((trunk - abs(q.x)) * s + 0.5, 0.0, 1.0) * step(0.001, trunk);
            float a = max(aCrown, aTrunk) * fade;
            if (a <= 0.0) continue;

            vec3 col = leaf(floor(fract(k.y * 91.0) * 6.0));
            float u = q.x / halfW;
            col *= 0.94 + 0.12 * h.y;                                    // each tree a little lighter or darker
            col *= 1.0 - 0.10 * u + 0.08 * (v - 0.5);                    // lit from the top left
            col *= kind < 0.5 ? 0.86 + 0.20 * tier : 1.0;                // fir tiers: dark under each tier
            if (kind > 0.5 && fract(k.x * 29.0) < 0.3) {
                // Scale pattern: rows of arcs.
                vec2 t = vec2(q.x / 10.0, q.y / 8.0);
                t.x += 0.5 * mod(floor(t.y), 2.0);
                float arc = length(fract(t) - vec2(0.5, 0.0));
                col *= 1.0 - 0.16 * (1.0 - smoothstep(0.0, 0.07, abs(arc - 0.46)));
            }
            col = aCrown >= aTrunk ? col : cTrunk.rgb * (0.9 + 0.2 * h.y);
            col *= 0.96 + 0.08 * grainTex.r;                              // paper grain
            acc += (1.0 - acc.a) * a * vec4(col, 1.0);
        }
    }

    grass = mix(grass, grass * cShadow.rgb, 0.8 * shade);
    vec3 outc = grass * (1.0 - acc.a) + acc.rgb;
    outc += (hash(floor(px)) - 0.5) * 0.012;
    outc *= tint.rgb;
    fragColor = vec4(outc, 1.0) * qt_Opacity;
}
