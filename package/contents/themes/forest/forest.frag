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
    float size;       // px, scale of a tree: up to 2.1 sizes tall and 0.97 sizes to each side; >= cell
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

float circle(vec2 p, vec2 c, float r) {
    return length(p - c) - r;
}

float smin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

// Signed distance (px, negative inside) to the crown of a tree, in the tree's own frame:
// p.x px from the trunk, p.y px above the root. H: height, w: half width, seed: 0..1.
// kind: 0 fir, 1 lumpy broadleaf, 2 cypress, 3 stacked balls, 4 wide crown on a long trunk, 5 slim spruce.
// mark: 0..1 strength of the pen marks drawn on the crown (branch chevrons, scallops).
float crown(float kind, vec2 p, float H, float w, float seed, out float mark) {
    mark = 0.0;
    if (kind < 0.5 || kind > 4.5) {
        // Fir and spruce: a pointed cone made of drooping tiers, each tier wider at its lower edge.
        float base = 0.10 * H;
        float t = (p.y - base) / (H - base);
        float n = kind < 0.5 ? 3.0 + floor(seed * 3.0) : 5.0 + floor(seed * 3.0);
        float tier = fract(t * n);
        float side = 0.62 + 0.05 * sin(floor(t * n) * 2.3 + seed * 9.0);   // tiers differ a little
        float cw = w * (1.0 - t) * (side + (1.0 - side) * (1.0 - tier) * (1.0 - tier));
        float d = abs(p.x) - cw;
        d = max(d, max(base - p.y, p.y - H));
        // Branch marks: a short dash on each side of every tier, sloping down and out.
        float tierH = (H - base) / n;
        float u = abs(p.x) / max(cw, 1.0);
        float target = (0.62 - 0.45 * u) * tierH;
        mark = (1.0 - smoothstep(0.5, 1.3, abs(tier * tierH - target))) * step(0.22, u) * step(u, 0.62) * step(t, 0.9);
        return d;
    }
    if (kind < 1.5) {
        // Broadleaf: a big lobe with two smaller ones low on either side.
        // The crown sits low: its lowest lobe ends a fifth of the way up, so the trunk stays short.
        float r = 0.42 * H * (0.85 + 0.15 * seed);
        float top = min(H, 0.20 * H + 1.62 * r);
        float d = circle(p, vec2(0.0, top - 0.72 * r), 0.72 * r);
        d = smin(d, circle(p, vec2(-0.50 * r, top - 1.05 * r - 0.10 * r * seed), (0.46 + 0.08 * seed) * r), 5.0);
        d = smin(d, circle(p, vec2(0.48 * r, top - 1.00 * r), (0.54 - 0.08 * seed) * r), 5.0);
        return d;
    }
    if (kind < 2.5) {
        // Cypress: a tall flame, widest a third of the way up, pointed at the top.
        float base = 0.07 * H;
        float t = (p.y - base) / (H - base);
        float cw = w * 0.62 * (t < 0.32 ? sqrt(max(0.0, 1.0 - pow((t - 0.32) / 0.32, 2.0)))
                                         : pow(max(0.0, 1.0 - (t - 0.32) / 0.68), 0.85));
        return max(abs(p.x) - cw, max(base - p.y, p.y - H));
    }
    if (kind < 3.5) {
        // Two or three balls stacked, smaller toward the top.
        float A = 0.88 * H;
        float y0 = 0.12 * H;
        if (seed < 0.5) {
            float r1 = min(w, 0.30 * A), r2 = min(0.8 * w, 0.24 * A);
            return smin(circle(p, vec2(0.0, y0 + r1), r1), circle(p, vec2(0.0, y0 + 0.72 * A), r2), 4.0);
        }
        float r1 = min(w, 0.22 * A), r2 = min(0.85 * w, 0.18 * A), r3 = min(0.7 * w, 0.14 * A);
        float d = circle(p, vec2(0.0, y0 + 0.22 * A), r1);
        d = smin(d, circle(p, vec2(0.0, y0 + 0.55 * A), r2), 4.0);
        return smin(d, circle(p, vec2(0.0, y0 + 0.82 * A), r3), 4.0);
    }
    // Wide crown of four lobes high on a long trunk.
    float r = min(w, 0.5 * H);
    float d = circle(p, vec2(0.0, H - 0.55 * r), 0.55 * r);
    d = smin(d, circle(p, vec2(-0.55 * r, H - 0.80 * r), 0.45 * r), 5.0);
    d = smin(d, circle(p, vec2(0.58 * r, H - 0.76 * r), (0.40 + 0.06 * seed) * r), 5.0);
    return smin(d, circle(p, vec2(-0.05 * r, H - 1.00 * r), 0.50 * r), 5.0);
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

    // Trees: one per grid cell, drawn front (lower on screen) to back. A tree is at most 2.1 sizes
    // tall and 0.97 sizes (plus the sway) to each side. Its root lies 0.15..0.85 into its cell, so
    // rows up to 0.85 + 2.1 sizes / cell below and columns up to 0.85 + 0.97 sizes / cell aside can
    // cover a pixel: 3 rows and 3 columns at the default spacing (cell == size). The row above
    // only adds its shadow.
    vec2 id = floor(px / cell);
    vec4 acc = vec4(0.0);      // premultiplied colour of the trees over this pixel
    float shade = 0.0;         // 0..1 ground shadow
    int rows = int(floor(0.85 + 2.1 * size / cell));
    int side = int(floor(0.85 + (0.97 * size + sway) / cell));
    for (int dj = rows; dj >= -1; --dj) {
        for (int di = -side; di <= side; ++di) {
            if (acc.a > 0.995) continue;
            vec2 c = id + vec2(float(di), float(dj));
            vec2 h = hash2(c);
            vec2 k = hash2(c + 17.3);
            if (k.x > keep) continue;
            vec2 root = (c + 0.15 + 0.7 * h) * cell;
            float kindSel = fract(k.x * 61.0);
            float kind = kindSel < 0.30 ? 0.0 : (kindSel < 0.40 ? 5.0 : (kindSel < 0.60 ? 1.0 : (kindSel < 0.74 ? 2.0 : (kindSel < 0.86 ? 3.0 : 4.0))));
            float height = size * (1.35 + 0.75 * k.y);
            float widthK = kind < 0.5 ? 1.3 : (kind < 1.5 ? 1.25 : (kind < 2.5 ? 1.0 : (kind < 3.5 ? 1.0 : (kind < 4.5 ? 1.4 : 0.62))));
            float halfW = (0.44 + 0.22 * fract(k.y * 37.0)) * widthK * size;     // at most 0.93 size; lobes reach 1.05 halfW

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
            float mark;
            float cd = crown(kind, q, height, halfW, h.x, mark);
            float trunkTop = kind > 3.5 && kind < 4.5 ? 0.6 * height : 0.35 * height;
            float tw = max(2.0, 0.07 * halfW + 0.02 * height);
            float td = max(abs(q.x) - tw, q.y - trunkTop);
            float aCrown = clamp(0.5 - cd * s, 0.0, 1.0);
            float aTrunk = clamp(0.5 - td * s, 0.0, 1.0);
            float a = max(aCrown, aTrunk) * fade;
            if (a <= 0.0) continue;

            vec3 col;
            if (aCrown >= aTrunk) {
                col = leaf(floor(fract(k.y * 91.0) * 6.0));
                col *= 0.94 + 0.12 * h.y;                                    // each tree a little lighter or darker
                col *= 1.0 - 0.07 * q.x / halfW + 0.06 * (v - 0.5);          // lit from the top left
                // Watercolour: the paint is mottled and pools a little darker along the edge.
                col *= 0.93 + 0.14 * texture(noiseTex, px / 70.0 + h).r;
                col *= 1.0 - 0.10 * (1.0 - smoothstep(0.0, 4.0, -cd * s));
                if (kind > 0.5 && kind < 4.5 && kind != 2.0 && fract(k.x * 29.0) < 0.35) {
                    // Scales: rows of arcs, slightly uneven.
                    vec2 t = vec2(q.x / 13.0, q.y / 9.0 + 0.3 * h.x);
                    t.x += 0.5 * mod(floor(t.y), 2.0) + 0.08 * sin(floor(t.y) * 3.1);
                    float arc = length(fract(t) - vec2(0.5, 0.0));
                    mark = (1.0 - smoothstep(0.0, 0.08, abs(arc - 0.45))) * step(fract(t.y), 0.5) * smoothstep(2.0, 5.0, -cd);
                }
                col *= 1.0 - 0.32 * mark;
            } else {
                col = cTrunk.rgb * (0.9 + 0.2 * h.y);
            }
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
