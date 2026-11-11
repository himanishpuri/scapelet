#version 440
// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;       // seconds, wraps at 3769.911184
    float cell;       // px, width of a house lot; a lot is 0.8 cells deep
    float keep;       // 0..1, share of the lots in a block that hold a house
    float lit;        // 0..1, share of windows with a light on
    float smoke;      // 1: chimneys smoke, 0: they do not
    float windmills;  // 1: a few windmills stand among the houses, 0: trees stand in their place
    vec2 resolution;  // px, item size
    vec4 tint;        // light colour, multiplies the result
    vec4 cPaveLight;  // the sand of the square
    vec4 cPaveMid;    // the sand of the streets
    vec4 cPaveDeep;
    vec4 cGrassLight;
    vec4 cGrassMid;
    vec4 cInk;        // pen lines
    vec4 cShadow;     // multiplies the paving beside a house
    vec4 cWall0;      // also the plaster of half-timbered houses
    vec4 cWall1;
    vec4 cWall2;
    vec4 cWall3;
    vec4 cWall4;
    vec4 cRoof0;
    vec4 cRoof1;
    vec4 cRoof2;
    vec4 cGlass;      // a dark window
    vec4 cLamp;       // a lit window
    vec4 cDoor;       // doors and timber
    vec4 cLeaf;
    vec4 cTrunk;
    vec4 cSmoke;
};
layout(binding = 1) uniform sampler2D mask;     // r = narrow sum: > 0 near an icon
layout(binding = 2) uniform sampler2D noiseTex; // r, g: 2-octave noise, b: 1 octave; tile = 2048 px, repeats

const float E0 = 0.0183156;   // exp(-4): the field blobs' floor, see shaders/field.frag
const float DEPTH = 0.8;      // depth of a lot in cells
const float STREET = 0.042;   // streetAt() below this: no house stands here

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

vec3 wall(float k) {
    if (k < 1.0) return cWall0.rgb;
    if (k < 2.0) return cWall1.rgb;
    if (k < 3.0) return cWall2.rgb;
    if (k < 4.0) return cWall3.rgb;
    return cWall4.rgb;
}

vec3 roof(float k) {
    if (k < 1.0) return cRoof0.rgb;
    if (k < 2.0) return cRoof1.rgb;
    return cRoof2.rgb;
}

float box(vec2 p, vec2 c, vec2 b) {
    vec2 d = abs(p - c) - b;
    return max(d.x, d.y);
}

// How far p is from the middle of a street: 0 on it, about 0.01 per 2 px off it. The streets
// follow the contours of two slow noises, so they wind, fork and cross, and no two blocks are alike.
float streetAt(vec2 p) {
    vec2 n = abs(texture(noiseTex, p / 1500.0 + 0.23).rg - 0.5);
    return min(n.x, n.y);
}

// What stands at root on lot c when no icon is near. Kinds: 0 gable to the street, 1 eaves to the
// street, 2 stepped gable, 3 clock tower, 4 tree, 5 windmill, 6 market stall, 7 well, 8 factory,
// 9 street lamp, 10 bench, 11 barrels and a crate, 12 handcart, -1 nothing.
// low: 1 when a street runs behind the house; it is then built low, so the street shows above its roof.
float kindAt(vec2 k, vec2 root, out float low) {
    float sel = fract(k.x * 61.0);
    low = 0.0;
    if (streetAt(root - vec2(0.0, 0.1 * cell)) < STREET) {
        // On the street: mostly nothing.
        return sel < 0.07 ? 9.0 : (sel < 0.10 ? 12.0 : (sel < 0.14 ? 11.0 : (sel < 0.16 ? 6.0 : (sel < 0.19 ? 4.0 : (sel < 0.21 ? 10.0 : (sel < 0.22 ? 7.0 : -1.0))))));
    }
    if (k.x > keep) return sel < 0.5 ? 4.0 : -1.0;               // a yard
    low = step(streetAt(root - vec2(0.0, 1.1 * cell)), STREET);
    float kind = sel < 0.36 ? 0.0 : (sel < 0.72 ? 1.0 : (sel < 0.85 ? 2.0 : (sel < 0.88 ? 3.0 : (sel < 0.895 ? 5.0 : (sel < 0.96 ? 8.0 : 4.0)))));
    if (kind > 4.5 && kind < 5.5 && windmills < 0.5) kind = 4.0;
    if (low > 0.5 && (kind > 2.5 && kind < 3.5 || kind > 4.5)) kind = 1.0;
    return kind;
}

// The size of what stands on a lot: x = half width px, y = height of the walls px, z = height of
// the roof px (for a factory: of the roof and the smokestack).
vec3 dims(float kind, vec2 k, float low) {
    float hw = cell * (0.46 + 0.14 * fract(k.y * 37.0));
    float hb = cell * (0.62 + 0.75 * k.y) * (1.0 - 0.45 * low);
    float hr = 0.80 * hw;
    if (kind > 0.5 && kind < 1.5) hr = cell * (0.28 + 0.16 * fract(k.y * 53.0));
    if (kind > 1.5 && kind < 2.5) hr = 5.0 * ceil((hw - 3.0) / 5.0);
    if (kind > 2.5 && kind < 3.5) {
        hw = cell * (0.22 + 0.04 * fract(k.y * 37.0));
        hb = cell * (1.40 + 0.30 * k.y);
        hr = 2.1 * hw;
    }
    if (kind > 3.5 && kind < 4.5) {
        hw = cell * (0.26 + 0.05 * fract(k.y * 37.0));
        hb = 0.28 * cell;
        hr = 2.0 * hw;
    }
    if (kind > 4.5 && kind < 5.5) {
        hw = 0.34 * cell;
        hb = 1.15 * cell;
        hr = 0.22 * cell;
    }
    if (kind > 5.5 && kind < 6.5) {
        hw = 0.30 * cell;
        hb = 0.22 * cell;
        hr = 0.14 * cell;
    }
    if (kind > 6.5 && kind < 7.5) {
        hw = 0.20 * cell;
        hb = 0.12 * cell;
        hr = 0.26 * cell;
    }
    if (kind > 7.5 && kind < 8.5) {
        hw = 0.62 * cell;
        hb = cell * (0.55 + 0.25 * k.y);
        hr = cell * (1.9 + 0.4 * fract(k.y * 53.0)) - hb;
    }
    if (kind > 8.5 && kind < 9.5) {
        hw = 0.07 * cell;
        hb = 0.42 * cell;
        hr = 0.10 * cell;
    }
    if (kind > 9.5) {
        hw = (kind < 10.5 ? 0.17 : (kind < 11.5 ? 0.16 : 0.24)) * cell;
        hb = (kind < 10.5 ? 0.10 : (kind < 11.5 ? 0.20 : 0.16)) * cell;
        hr = 0.08 * cell;
    }
    return vec3(hw, hb, hr);
}

// The foot of what stands on lot c, px.
vec2 foot(vec2 c, vec2 h, vec2 lotSize) {
    return (c + vec2(0.5 + 0.30 * (h.x - 0.5), 0.50 + 0.30 * h.y)) * lotSize;
}

// False when what stands at root would be cut off by an edge of the screen; such a lot stays empty.
// A windmill's sails reach 0.64 cells to each side, and things on a roof stand up to 13 px above it.
bool fits(vec2 root, float kind, float hw, float height) {
    float reach = kind > 4.5 && kind < 5.5 ? 0.64 * cell : hw + 3.0;
    return root.x - reach > 0.0 && root.x + reach < resolution.x && root.y - height - 14.0 > 0.0 && root.y + 3.0 < resolution.y;
}

// The distance from p to the core of the nearest icon in units of sigma (0 at the core, 2 far away).
float level(vec2 p) {
    float m = clamp(texture(mask, p / resolution).r, 0.0, 1.0);
    return sqrt(-log(m * (1.0 - E0) + E0));
}

// Short pen strokes on the ground, one per 12 x 6 px cell. dens: share of cells with a stroke.
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
        float dist = length(vec2(max(abs(r.x) - (2.0 + 2.5 * h.y), 0.0), r.y));
        a = max(a, (1.0 - smoothstep(0.4, 1.1, dist)) * (0.35 + 0.45 * h.x));
    }
    return a;
}

// Rows of roof tiles at p (px, y up from the eaves). style: 0 scallops, 1 courses with joints, 2 slates. 0..1.
float tiles(vec2 p, float style) {
    if (style < 0.5) {
        vec2 t = vec2(p.x / 5.0, p.y / 4.0);
        t.x += 0.5 * mod(floor(t.y), 2.0);
        vec2 f = (fract(t) - vec2(0.5, 1.0)) * vec2(5.0, 4.0);
        return 1.0 - smoothstep(0.3, 0.9, abs(length(f) - 2.9));
    }
    if (style < 1.5) {
        float row = floor(p.y / 4.0);
        return max(step(fract(p.y / 4.0), 0.2), 0.6 * step(fract(p.x / 4.0 + 0.5 * mod(row, 2.0)), 0.2));
    }
    vec2 u = vec2(p.x + 1.4 * p.y, p.x - 1.4 * p.y) / 6.0;
    return step(min(fract(u.x), fract(u.y)), 0.15);
}

void main() {
    vec2 px = qt_TexCoord0 * resolution;
    vec2 lotSize = vec2(cell, DEPTH * cell);
    float open = texture(mask, qt_TexCoord0).r;

    // Ground, in watercolour: sandy streets and squares, grass in washes everywhere else.
    float w1 = texture(noiseTex, px / 1700.0).r;
    float w2 = texture(noiseTex, px / 600.0 + 0.37).g;
    float w3 = texture(noiseTex, px / 1300.0 + 0.11).b;
    float w4 = texture(noiseTex, px / 330.0 + 0.61).r;
    vec4 grainTex = texture(noiseTex, px / 260.0);
    float street = 1.0 - smoothstep(0.022, 0.040, streetAt(px) + 0.012 * (w4 - 0.5));
    // The square: sand where the houses have folded away, inside a dashed pen line.
    float lv = level(px);
    float square = 1.0 - smoothstep(1.02, 1.12, lv + 0.10 * (w4 - 0.5));
    float turf = smoothstep(0.38, 0.52, 0.55 * w2 + 0.45 * w3 + 0.25 * (w4 - 0.5));     // where grass would grow
    float grassy = turf * (1.0 - 0.92 * street) * (1.0 - 0.80 * square);
    grassy = max(grassy, 0.75 * square * smoothstep(0.62, 0.70, 0.5 * w4 + 0.5 * w3));   // a few blots of grass on the square
    vec3 sand = mix(cPaveMid.rgb, cPaveDeep.rgb, smoothstep(0.35, 0.75, w1 * 0.6 + w2 * 0.4));
    sand = mix(sand, cPaveLight.rgb, 0.7 * square);
    vec3 grass = mix(cGrassLight.rgb, cGrassMid.rgb, smoothstep(0.30, 0.70, w1 * 0.5 + w4 * 0.5));
    float wet = smoothstep(0.35, 0.65, grassy);
    vec3 ground = mix(sand, grass, wet);
    ground *= 1.0 - 0.10 * (1.0 - smoothstep(0.0, 0.5, abs(wet - 0.5)));                // the wash pools along its edge
    ground = mix(ground, cInk.rgb, 0.50 * strokes(px, 0.30 * wet));
    // Cobbles on the streets and the square: setts laid in fans.
    vec2 ft = vec2(px.x / 16.0, px.y / 8.0);
    ft.x += 0.5 * mod(floor(ft.y), 2.0);
    vec2 ff = (fract(ft) - vec2(0.5, 1.0)) * vec2(16.0, 8.0);
    float fan = 1.0 - smoothstep(0.25, 0.85, abs(length(ff) - 8.5));                    // one arch per sett fan
    float paved = max(street, square) * (1.0 - wet);
    ground *= 1.0 - 0.05 * paved * (hash(floor(ft)) - 0.3);
    ground = mix(ground, cInk.rgb, 0.17 * fan * paved);
    float dash = mod(floor(px.x / 5.0) + floor(px.y / 5.0), 2.0);
    float line = abs(lv + 0.10 * (w4 - 0.5) - 1.07) / max(fwidth(lv), 1e-4);
    ground = mix(ground, cInk.rgb, 0.55 * dash * (1.0 - smoothstep(0.6, 1.5, line)));

    // Houses: one per lot, drawn front (lower on screen) to back. A house is at most 0.76 cells wide
    // to each side and, with a factory's smokestack, 2.6 cells tall; its foot lies 0.2..1 into its
    // lot. So the lots beside it and up to three rows below can cover a pixel; the row above only
    // adds its shadow.
    vec2 id = floor(px / lotSize);
    vec4 acc = vec4(0.0);      // premultiplied colour of the houses over this pixel
    float shade = 0.0;         // 0..1 ground shadow
    for (int dj = 3; dj >= -1; --dj) {
        for (int di = -1; di <= 1; ++di) {
            if (acc.a > 0.995) continue;
            vec2 c = id + vec2(float(di), float(dj));
            vec2 h = hash2(c);
            vec2 k = hash2(c + 17.3);
            vec2 root = foot(c, h, lotSize);
            // Nothing on this lot reaches the pixel when it is too far aside, above or below.
            if (abs(px.x - root.x) > 0.80 * cell || px.y > root.y + 9.0 || px.y < root.y - 2.9 * cell) continue;
            // A house folds down into the square where it is near an icon, and a ring of trees,
            // lamps, benches and stalls comes up just inside the line where the houses end.
            // Each lot has its own line (jit), so the houses fold one after another.
            float lev = level(root - vec2(0.0, 0.4 * cell));
            float jit = 0.3 * (fract(k.x * 17.0) - 0.5);
            float low;
            float kind = kindAt(k, root, low);
            float s = smoothstep(1.2 + jit, 1.6 + jit, lev);
            if (s < 0.02) {
                float pick = fract(k.y * 113.0);
                kind = pick < 0.34 ? 4.0 : (pick < 0.60 ? 9.0 : (pick < 0.76 ? 10.0 : (pick < 0.88 ? 6.0 : -1.0)));
                s = smoothstep(0.70, 0.85, lev) * (1.0 - smoothstep(1.0 + jit, 1.14 + jit, lev));
            }
            if (kind < -0.5 || s < 0.02) continue;
            vec3 D = dims(kind, k, low);
            float hw = D.x, hb = D.y, hr = D.z;
            float height = hb + hr;
            if (!fits(root, kind, hw, height)) continue;
            float fade = smoothstep(0.02, 0.3, s);
            // A house folds flat (it narrows less than it sinks); a tree, a lamp or a stall grows as a whole.
            bool thing = (kind > 3.5 && kind < 4.5) || (kind > 5.5 && kind < 7.5) || kind > 8.5;
            float sx = thing ? s : mix(1.0, s, 0.35);

            vec2 q = vec2((px.x - root.x) / sx, (root.y - px.y) / s);   // px in the house's own frame, y up

            vec2 e = (q - vec2(0.35 * hw, -1.0)) / vec2(hw + 5.0, 7.0);
            shade = max(shade, (1.0 - smoothstep(0.6, 1.0, max(abs(e.x), abs(e.y)))) * s * fade);
            if (dj < 0 || q.y < 0.0 || q.y > height + 13.0) continue;

            vec2 r3 = hash2(c + 31.7);
            float y = q.y - hb;           // px above the eaves
            float d = 1e3;                // signed distance to the outline, px
            vec3 col;

            if (kind > 11.5) {
                // A handcart: a loaded bed on a wheel, with a shaft.
                float dBed = box(q, vec2(-1.0, 6.5), vec2(hw - 3.0, 2.0));
                float dLoad = min(length((q - vec2(-4.0, 9.5)) / vec2(3.6, 2.6)) - 1.0, length((q - vec2(2.0, 9.8)) / vec2(3.2, 2.4)) - 1.0);
                float dWheel = abs(length(q - vec2(-2.0, 4.0)) - 3.2) - 0.8;
                vec2 sq = q - vec2(hw - 4.0, 6.5);
                float dShaft = max(abs(sq.y + 0.7 * sq.x) - 0.6, max(-sq.x, sq.x - 4.5));
                d = min(min(dBed, dLoad), min(dWheel, dShaft));
                col = dWheel < 0.0 ? cInk.rgb * 0.45 : (dBed < 0.0 ? cDoor.rgb * 1.25 : (dLoad < 0.0 ? cWall0.rgb * 0.92 : cDoor.rgb));
            } else if (kind > 10.5) {
                // Two barrels and a crate.
                float dA = box(q, vec2(-0.45 * hw, 0.5 * hb), vec2(0.42 * hw, 0.5 * hb));
                float dB = box(q, vec2(-0.30 * hw, hb + 0.25 * hb), vec2(0.36 * hw, 0.25 * hb));
                float dC = box(q, vec2(0.50 * hw, 0.36 * hb), vec2(0.42 * hw, 0.36 * hb));
                d = min(min(dA, dB), dC);
                if (dC < 0.0) {
                    vec2 xq = q - vec2(0.50 * hw, 0.36 * hb);
                    col = cWall1.rgb * (abs(abs(xq.x) - abs(xq.y)) < 0.7 || dC > -1.0 ? 0.62 : 0.90);
                } else {
                    col = cDoor.rgb * (fract(q.y / (0.5 * hb) + 0.25) < 0.22 ? 0.7 : 1.35);
                }
            } else if (kind > 9.5) {
                // A bench.
                float dSeat = box(q, vec2(0.0, 0.5 * hb), vec2(hw, 0.8));
                float dBack = box(q, vec2(0.0, hb + 2.0), vec2(hw, 1.2));
                float dLegs = max(abs(abs(q.x) - hw + 1.5) - 0.7, q.y - hb - 2.0);
                d = min(min(dSeat, dBack), dLegs);
                col = dLegs < 0.0 && dBack > 0.0 && dSeat > 0.0 ? cInk.rgb * 0.45 : cLeaf.rgb * 0.62;
            } else if (kind > 8.5) {
                // A street lamp: a post with a lantern.
                float dPost = box(q, vec2(0.0, 0.5 * hb), vec2(0.7, 0.5 * hb));
                float dLamp = box(q, vec2(0.0, hb + 0.5 * hr), vec2(2.0, 0.5 * hr));
                d = min(dPost, dLamp);
                col = dLamp < 0.0 ? (lit > 0.2 ? cLamp.rgb * 1.1 : mix(cGlass.rgb, vec3(1.0), 0.45)) : cInk.rgb * 0.45;
            } else if (kind > 7.5) {
                // A factory: a brick shed under a sawtooth roof, with a tall smokestack.
                float shed = 0.20 * cell;
                float tooth = 2.0 * hw / 3.0;
                float tx = mod(q.x + hw, tooth);
                float dBody = max(abs(q.x) - hw, q.y - hb);
                float dSaw = max(max(abs(q.x) - hw, -y), y - shed * (1.0 - tx / tooth));
                float sx0 = (h.x < 0.5 ? -0.55 : 0.55) * hw;
                float dStack = max(abs(q.x - sx0) - (3.6 - 1.2 * clamp(q.y / height, 0.0, 1.0)), q.y - height);
                d = min(min(dBody, dSaw), dStack);
                vec3 brick = mix(cRoof0.rgb, cWall2.rgb, 0.3 + 0.3 * h.y);
                float bond = max(step(fract(q.y / 3.0), 0.25), step(fract(q.x / 7.0 + 0.5 * mod(floor(q.y / 3.0), 2.0)), 0.13));
                if (dBody < 0.0) {
                    col = brick * (1.0 - 0.12 * bond) * (1.0 - 0.05 * q.x / hw);
                    col *= 1.0 - 0.16 * smoothstep(4.0, 0.0, hb - q.y);
                    // Tall windows of many panes, and a wide gate.
                    float bay = floor((q.x + hw) / 9.0);
                    vec2 wq = vec2(mod(q.x + hw, 9.0) - 4.5, q.y - 0.55 * hb);
                    if (abs(q.x) < hw - 2.0 && box(wq, vec2(0.0), vec2(3.0, 0.25 * hb)) < 0.0) {
                        col = (hash(c * 3.7 + bay) < lit ? cLamp.rgb : cGlass.rgb) * (1.0 - 0.2 * max(step(fract(wq.x / 3.0 + 0.5), 0.2), step(fract(wq.y / 3.5), 0.2)));
                    }
                    if (box(q, vec2(-sx0 * 0.6, 5.5), vec2(5.0, 5.5)) < 0.0) col = cDoor.rgb * (1.0 - 0.2 * step(fract(q.x / 2.5), 0.25));
                } else if (dSaw < 0.0) {
                    col = tx < 1.6 ? mix(cGlass.rgb, vec3(1.0), 0.35) : roof(2.0) * (1.0 - 0.10 * step(fract(tx / 3.0), 0.25));
                } else {
                    col = brick * (1.0 - 0.12 * bond) * (1.0 - 0.10 * step(0.0, q.x - sx0));
                    if (q.y > height - 3.0 || abs(q.y - height + 9.0) < 1.0) col *= 0.7;       // the rim and a band
                }
            } else if (kind > 6.5) {
                // A well: a round stone basin with water, under a little roof on two posts.
                float dBasin = length((q - vec2(0.0, 0.5 * hb)) / vec2(hw, 0.5 * hb + 1.0)) - 1.0;
                float dPost = max(abs(abs(q.x) - hw + 1.5) - 0.8, q.y - hb - 0.6 * hr);
                float dCap = max(dot(vec2(abs(q.x) - hw - 1.5, q.y - hb - 0.6 * hr), normalize(vec2(0.4 * hr, hw + 1.5))), hb + 0.6 * hr - q.y);
                d = min(min(dBasin * hw, dPost), dCap);
                col = dCap < 0.0 ? cRoof1.rgb : (dBasin < 0.0 ? (dBasin < -0.45 && q.y > 0.45 * hb ? cWall3.rgb * 0.9 : cPaveDeep.rgb * 0.82) : cDoor.rgb);
            } else if (kind > 5.5) {
                // A market stall: a striped awning on two posts over a counter.
                float dCounter = box(q, vec2(0.0, 0.3 * hb), vec2(hw - 1.5, 0.3 * hb));
                float dPost = max(abs(abs(q.x) - hw + 1.0) - 0.8, q.y - hb);
                float dAwn = max(abs(q.x) - hw - 1.5 + 0.35 * y, max(-y, y - hr));
                d = min(min(dCounter, dPost), dAwn);
                vec3 stripe = mod(floor((q.x + hw) / 3.2), 2.0) < 0.5 ? roof(floor(r3.x * 3.0)) : cWall0.rgb;
                col = dAwn < 0.0 ? stripe * (y < 1.5 ? 0.85 : 1.0) : (dCounter < 0.0 ? (q.y > 0.45 * hb ? mix(cRoof0.rgb, cWall1.rgb, step(0.5, fract(q.x / 4.0))) : cDoor.rgb * 1.3) : cDoor.rgb);
            } else if (kind > 4.5) {
                // A windmill: a tapering tower under a cap, and four sails that turn (0.25 rad/s).
                float taper = hw * (1.0 - 0.38 * clamp(q.y / hb, 0.0, 1.0));
                float dBody = max(abs(q.x) - taper, q.y - hb);
                float dCap = max(length((q - vec2(0.0, hb)) / vec2(0.66 * hw, hr)) - 1.0, -y) * hr;
                vec2 hub = q - vec2(0.0, hb + 0.2 * hr);
                float ang = time * 0.25 + 6.2832 * h.x;
                vec2 sp = vec2(hub.x * cos(ang) + hub.y * sin(ang), hub.y * cos(ang) - hub.x * sin(ang));
                // Fold the four sails onto one: each is a spar along +x with a lattice on one side.
                if (abs(sp.y) > abs(sp.x)) sp = vec2(sp.y, -sp.x);
                if (sp.x < 0.0) sp = -sp;
                float reach = 0.62 * cell;
                float dSpar = box(sp, vec2(0.5 * reach, 0.0), vec2(0.5 * reach, 0.7));
                float dSail = box(sp, vec2(0.6 * reach, 2.6), vec2(0.36 * reach, 2.2));
                float dSails = min(dSpar, dSail);
                d = min(min(dBody, dCap), dSails);
                if (dSails < 0.0) {
                    col = dSpar < 0.0 ? cDoor.rgb : mix(cWall0.rgb, cDoor.rgb, 0.55 * step(fract(sp.x / 3.0), 0.3));
                } else if (dCap < 0.0 && dCap < dBody) {
                    col = roof(floor(r3.y * 3.0));
                } else {
                    col = cWall0.rgb * (1.0 - 0.07 * q.x / hw);
                    col *= 1.0 - 0.10 * step(fract(q.y / 3.5), 0.2);               // boards
                    if (box(q, vec2(0.0, 5.0), vec2(2.8, 5.0)) < 0.0) col = cDoor.rgb;
                    if (box(q, vec2(0.0, 0.55 * hb), vec2(2.0, 2.6)) < 0.0) col = hash(c * 3.7) < lit ? cLamp.rgb : cGlass.rgb;
                }
            } else if (kind > 3.5) {
                // A round tree of two lobes.
                float dc = min(length(q - vec2(-0.15 * hw, hb + 0.85 * hw)) - hw, length(q - vec2(0.45 * hw, hb + 0.55 * hw)) - 0.7 * hw);
                float dt = max(abs(q.x) - 1.6, q.y - hb - 2.0);
                d = min(dc, dt);
                col = dc < dt ? cLeaf.rgb * (0.90 + 0.20 * h.y) * (1.0 - 0.08 * q.x / hw + 0.05 * (q.y - hb) / hw) : cTrunk.rgb;
            } else {
                float wallStyle = kind > 2.5 ? 4.0 : min(4.0, floor(r3.x * 6.0));  // 0 plaster, 1 half-timber, 2 brick, 3 boards, 4 and 5 (as 4): stone
                float roofStyle = floor(r3.y * 3.0);
                float winStyle = floor(fract(r3.x * 7.0) * 3.0);                // 0 plain, 1 shutters, 2 flower box
                bool shop = kind > 0.5 && kind < 1.5 && fract(r3.y * 13.0) < 0.35 && hb > 31.0;
                vec3 wallC = wall(floor(fract(k.y * 91.0) * 5.0)) * (0.95 + 0.10 * h.y);
                if (wallStyle > 0.5 && wallStyle < 1.5) wallC = cWall0.rgb * (0.97 + 0.06 * h.y);
                if (wallStyle > 1.5 && wallStyle < 2.5) wallC = mix(cRoof0.rgb, cWall2.rgb, 0.25 + 0.4 * h.y) * (0.85 + 0.2 * k.y);
                if (wallStyle > 3.5) wallC = mix(wallC, cPaveDeep.rgb, 0.6);
                vec3 roofC = roof(floor(fract(k.x * 23.0) * 3.0)) * (0.94 + 0.12 * h.x);
                vec3 trim = fract(r3.y * 5.0) < 0.5 ? roof(floor(fract(r3.x * 3.0) * 3.0)) : cLeaf.rgb * 0.8;
                col = wallC;

                float dBody = max(abs(q.x) - hw, q.y - hb);
                float dRoof;
                float dSlope = dot(vec2(abs(q.x) - hw - 2.0, y), normalize(vec2(hr, hw + 2.0)));     // the sloping edges of a gable
                // Three houses in four have a chimney: a brick stack with a cap, a stack with two pots, or a pipe with a cowl.
                bool chimney = kind < 1.5 && fract(k.x * 41.0) < 0.75;
                float stack = fract(k.y * 71.0);
                float side = h.x < 0.5 ? -1.0 : 1.0;
                float cx = side * 0.5 * hw;
                float cTop = (kind > 0.5 ? hr : 0.5 * hr) + 7.0;
                float dChim = 1e3;
                float dPots = 1e3;
                if (chimney) {
                    dChim = max(abs(q.x - cx) - (stack < 0.7 ? 2.6 : 1.2), max(-y, y - cTop));
                    if (stack > 0.7) {
                        dPots = max(dot(vec2(abs(q.x - cx) - 3.0, y - cTop), normalize(vec2(3.0, 3.0))), cTop - y);
                    } else if (stack > 0.4) {
                        dPots = box(vec2(abs(q.x - cx), y), vec2(1.4, cTop + 1.5), vec2(0.8, 1.5));
                    }
                }
                // Something on the roof of most houses: an aerial, pigeons, a weather vane, a flag or a cat.
                // It stands on the ridge of an eaves roof, on the tip of a gable, and always on a tower (a vane).
                float topper = kind > 2.5 ? 0.33 : fract(r3.x * 29.0);
                float ridge = kind > 0.5 && kind < 1.5 ? hw - 6.0 : 0.0;
                vec2 tq = q - vec2((kind > 0.5 && kind < 1.5 ? -side : 0.0) * ridge * (0.3 + 0.7 * fract(r3.y * 19.0)), height);
                float dTop = 1e3;
                vec3 topC = cInk.rgb * 0.7;
                if (topper < 0.18) {
                    // An aerial: a mast with three bars.
                    dTop = min(box(tq, vec2(0.0, 5.5), vec2(0.5, 5.5)), box(vec2(tq.x, mod(tq.y, 2.5)), vec2(0.0, 1.25), vec2(tq.y > 4.0 && tq.y < 11.0 ? 1.0 + 0.4 * tq.y : 0.0, 0.45)));
                } else if (topper < 0.32) {
                    // One to three pigeons.
                    float n = 1.0 + floor(fract(r3.y * 43.0) * 3.0);
                    float bx = tq.x - 5.0 * clamp(floor(tq.x / 5.0 + 0.5), 0.0, n - 1.0);
                    dTop = min(length(vec2(bx, tq.y - 1.7) / vec2(2.5, 1.8)) - 1.0, length(vec2(bx - 1.9, tq.y - 3.4)) / 1.1 - 1.0);
                    topC = mix(cRoof2.rgb, cInk.rgb, 0.3) * (0.7 + 0.5 * hash(c + floor(tq.x / 5.0 + 0.5)));
                } else if (topper < 0.40) {
                    // A weather vane: an arrow on a mast.
                    dTop = min(min(box(tq, vec2(0.0, 4.5), vec2(0.5, 4.5)), box(tq, vec2(0.5, 8.0), vec2(4.0, 0.5))),
                               min(box(tq, vec2(-3.0, 8.0), vec2(1.1, 1.6)), length(tq - vec2(0.0, 10.0)) - 1.1));
                } else if (topper < 0.47) {
                    // A flag that waves (3 rad/s).
                    float wave = 0.8 * sin(time * 3.0 + 0.9 * tq.x + 6.2832 * h.y) * step(0.5, tq.x);
                    float dFlag = box(vec2(tq.x, tq.y + wave), vec2(3.6, 10.0), vec2(3.2, 2.2));
                    dTop = min(box(tq, vec2(0.0, 6.2), vec2(0.5, 6.2)), dFlag);
                    if (dFlag < 0.0) topC = trim;
                } else if (topper < 0.52) {
                    // A cat.
                    dTop = min(min(length((tq - vec2(0.0, 2.0)) / vec2(3.4, 2.2)) - 1.0, (length(tq - vec2(3.2, 4.3)) - 1.8) / 1.8),
                               min(box(vec2(abs(tq.x - 3.2), tq.y), vec2(1.0, 6.3), vec2(0.5, 0.8)), box(tq, vec2(-3.7, 4.0), vec2(0.5, 2.6))));
                    topC = cInk.rgb * 0.45;
                }
                if (kind < 0.5 || kind > 2.5) {
                    dRoof = max(dSlope, -y);
                } else if (kind < 1.5) {
                    dRoof = max(dot(vec2(abs(q.x) - hw - 2.5, y), normalize(vec2(hr, 6.0))), max(-y - 1.0, y - hr));
                } else {
                    dRoof = max(abs(q.x) - (hw + 1.0 - 5.0 * floor(y / 5.0)), max(-y, y - hr));
                }
                d = min(min(min(dBody, dRoof), min(dChim, dPots)), dTop);

                // The timber frame and the bond of the wall at q; used on the walls and on the gables.
                float storey = floor((q.y - 3.0) / 14.0);
                float cols = hw > 0.47 * cell ? 3.0 : 2.0;
                float span = 2.0 * hw / cols;
                float ci = floor((q.x + hw) / span);
                float wx = q.x + hw - (ci + 0.5) * span;
                float wy = q.y - 3.0 - 14.0 * storey;
                float bond = 0.0;
                float beam = 0.0;
                if (wallStyle < 0.5) {
                    bond = 0.8 * step(q.y, 3.0);                                                         // plinth
                } else if (wallStyle < 1.5) {
                    if (storey > 0.5) {
                        beam = max(step(wy, 1.6), step(0.5 * span - 0.8, abs(wx)));
                        beam = max(beam, 1.0 - smoothstep(0.6, 1.3, abs(abs(wx) * 28.0 / span - wy + 0.8)));
                        beam = max(beam, step(hw - 1.6, abs(q.x)));
                    }
                } else if (wallStyle < 2.5) {
                    bond = max(step(fract(q.y / 3.0), 0.25), step(fract(q.x / 7.0 + 0.5 * mod(floor(q.y / 3.0), 2.0)), 0.13));
                } else if (wallStyle < 3.5) {
                    bond = 0.8 * step(fract(q.y / 3.5), 0.2);
                } else {
                    bond = step(hw - 3.5 + 2.0 * mod(floor(q.y / 4.0), 2.0), abs(q.x)) + 0.5 * step(fract(q.y / 8.0), 0.1);
                }

                if (dTop < 0.0 && tq.y > 0.0) {
                    col = topC;
                } else if (dRoof < 0.0 && dRoof <= dBody) {
                    if (kind < 0.5) {
                        // The gable is wall with a band of roof along both slopes and an attic window.
                        if (dSlope > -4.0) {
                            col = roofC * (dSlope > -1.2 ? 0.86 : 1.0);
                        } else {
                            col = wallC * (1.0 - 0.12 * bond);
                            if (wallStyle > 0.5 && wallStyle < 1.5) {
                                float post = max(step(abs(q.x), 0.8), step(y, 1.6));
                                post = max(post, 1.0 - smoothstep(0.6, 1.3, abs(dSlope + 8.5)));
                                col = mix(col, cDoor.rgb, post);
                            }
                            vec2 aw = q - vec2(0.0, hb + 0.30 * hr);
                            if (r3.x < 0.5 ? length(aw) < 3.1 : box(aw, vec2(0.0), vec2(2.6, 3.2)) < 0.0) col = mix(wallC, vec3(1.0), 0.5);
                            if (r3.x < 0.5 ? length(aw) < 2.1 : box(aw, vec2(0.0), vec2(1.7, 2.3)) < 0.0) col = hash(c * 5.1) < lit ? cLamp.rgb : cGlass.rgb;
                        }
                    } else if (kind < 1.5) {
                        col = roofC * (1.0 - 0.15 * tiles(vec2(q.x, y), roofStyle));
                        col *= y > hr - 1.8 ? 1.12 : (y < 0.6 ? 0.82 : 1.0);                    // ridge cap, eaves
                        if (fract(r3.y * 31.0) < 0.3) {
                            col = mix(col, cLeaf.rgb, 0.45 * smoothstep(0.62, 0.72, texture(noiseTex, px / 45.0 + h).g));   // moss
                        }
                        if (hr > 15.0 && fract(r3.x * 17.0) < 0.6) {
                            // A dormer on the side away from the chimney.
                            vec2 dq = vec2(q.x + side * 0.38 * hw, y - 2.5);
                            float dGable = max(dot(vec2(abs(dq.x) - 4.6, dq.y - 6.0), normalize(vec2(4.0, 4.6))), 6.0 - dq.y);
                            if (box(dq, vec2(0.0, 3.0), vec2(3.6, 3.0)) < 0.0) col = wallC;
                            if (box(dq, vec2(0.0, 3.2), vec2(2.0, 2.0)) < 0.0) col = hash(c * 5.1) < lit ? cLamp.rgb : cGlass.rgb;
                            if (dGable < 0.0) col = roofC * 0.78;
                        }
                    } else if (kind < 2.5) {
                        col = wallC * (1.0 - 0.12 * bond) * (fract(y / 5.0) > 0.72 ? 0.78 : 1.0);     // capstones on the steps
                        if (box(vec2(q.x, y), vec2(0.0, 5.0), vec2(1.8, 2.6)) < 0.0) col = hash(c * 5.1) < lit ? cLamp.rgb : cGlass.rgb;
                    } else {
                        col = roofC * (1.0 - 0.15 * tiles(vec2(q.x, y), 2.0)) * (1.0 - 0.10 * step(0.0, q.x));
                    }
                } else if (dPots < 0.0 && dBody > 0.0) {
                    col = stack > 0.7 ? cInk.rgb * 0.5 : cRoof0.rgb;
                } else if (dChim < 0.0 && dBody > 0.0) {
                    col = stack > 0.7 ? cInk.rgb * 0.6 : mix(cRoof0.rgb, cWall2.rgb, 0.4) * (y > cTop - 2.0 ? 0.62 : 0.85);
                } else {
                    // Walls: the bond, a shadow under the eaves, then windows and a door or a shop front.
                    col *= 1.0 - 0.12 * bond;
                    col = mix(col, cDoor.rgb, beam);
                    col *= 1.0 - 0.05 * q.x / hw;
                    col *= 1.0 - 0.16 * smoothstep(4.0, 0.0, hb - q.y);
                    if (kind > 2.5) {
                        // Tower: a bell arch, a clock under it, and slits below.
                        vec2 bq = q - vec2(0.0, hb - 7.0);
                        if (box(bq, vec2(0.0, -1.5), vec2(2.4, 2.5)) < 0.0 || length(bq - vec2(0.0, 1.0)) < 2.4) col = cGlass.rgb;
                        vec2 cc = q - vec2(0.0, hb - 13.0 - hw);
                        float r = 0.66 * hw;
                        if (length(cc) < r + 1.3) col = roofC * 0.8;
                        if (length(cc) < r) {
                            col = mix(cWall0.rgb, vec3(1.0), 0.4);
                            float hand = min(length(vec2(cc.x, cc.y - clamp(cc.y, 0.0, 0.72 * r))),
                                             length(vec2(cc.x - clamp(cc.x, 0.0, 0.5 * r), cc.y)));
                            col = mix(cInk.rgb * 0.4, col, smoothstep(0.5, 1.2, hand));
                        }
                        float fy = q.y - 5.0;
                        if (fy > 0.0 && q.y < hb - 2.0 * hw - 18.0 && box(vec2(q.x, mod(fy, 16.0)), vec2(0.0, 6.0), vec2(1.6, 3.6)) < 0.0) {
                            col = hash(c * 3.7 + floor(fy / 16.0)) < lit ? cLamp.rgb : cGlass.rgb;
                        }
                        if (length(vec2(q.x, q.y - 6.0)) < 3.2 || box(q, vec2(0.0, 3.0), vec2(3.2, 3.0)) < 0.0) col = cDoor.rgb;
                    } else {
                        bool top = 3.0 + 14.0 * (storey + 1.0) > hb - 1.0;      // no room for another storey
                        float doorCol = floor(h.y * cols);
                        vec3 pane = hash(c * 3.7 + vec2(ci, storey)) < lit ? cLamp.rgb : cGlass.rgb;
                        if (shop && q.y < 17.0) {
                            // A shop: a wide window and a door under a striped awning.
                            float aw = q.y - 11.0;
                            if (aw > 0.0 && aw < 5.5 - 1.2 * step(0.5, fract((q.x + hw) / 6.4))) {
                                col = (mod(floor((q.x + hw) / 3.2), 2.0) < 0.5 ? trim : cWall0.rgb) * (aw < 1.2 ? 0.85 : 1.0);
                            } else if (q.y < 11.0 && abs(q.x) < hw - 2.5) {
                                if (ci == doorCol && abs(wx) < 3.4) {
                                    col = cDoor.rgb;
                                } else if (q.y > 3.0) {
                                    col = (lit > 0.2 ? cLamp.rgb : cGlass.rgb) * (1.0 - 0.15 * step(fract((q.x + hw) / 6.4), 0.14));
                                }
                            }
                        } else if (storey < 0.5 && ci == doorCol) {
                            if (box(vec2(wx, q.y), vec2(0.0, 4.5), vec2(3.3, 4.5)) < 0.0 || length(vec2(wx, q.y - 9.0)) < 3.3) {
                                col = fract(r3.y * 3.0) < 0.5 ? cDoor.rgb : trim * 0.8;
                                if (length(vec2(wx - 1.7, q.y - 5.5)) < 0.75) col = cLamp.rgb;         // door knob
                            }
                        } else if (!top && storey > -0.5) {
                            vec2 wq = vec2(wx, wy - 7.5);
                            if (winStyle > 0.5 && winStyle < 1.5 && box(vec2(abs(wx), wq.y), vec2(5.0, 0.0), vec2(1.3, 4.3)) < 0.0) {
                                col = trim * (1.0 - 0.15 * step(fract(wq.y / 2.0), 0.3));               // shutters
                            }
                            bool arched = fract(r3.y * 47.0) < 0.4;
                            if (box(wq, vec2(0.0), vec2(3.5, 4.7)) < 0.0 && (!arched || wq.y < 1.2 || length(wq - vec2(0.0, 1.2)) < 3.5)) col = mix(wallC, vec3(1.0), 0.55);   // frame
                            if (box(wq, vec2(0.0), vec2(2.6, 3.8)) < 0.0 && (!arched || wq.y < 1.2 || length(wq - vec2(0.0, 1.2)) < 2.6)) {
                                col = pane * (1.0 - 0.14 * max(step(abs(wx), 0.45), step(abs(wq.y - 0.6), 0.45)));
                            }
                            if (winStyle > 1.5 && box(wq, vec2(0.0, -5.4), vec2(4.0, 1.3)) < 0.0) {
                                col = fract(wx / 2.6 + 0.3 * ci) < 0.5 ? cRoof0.rgb * 1.15 : cLeaf.rgb;   // flower box
                            }
                        }
                    }
                }
            }

            float a = clamp(0.5 - d * s, 0.0, 1.0) * fade;
            if (a <= 0.0) continue;
            // Watercolour: the paint is mottled and pools a little darker along the edge.
            col *= 0.94 + 0.12 * texture(noiseTex, px / 70.0 + h).r;
            col *= 1.0 - 0.10 * (1.0 - smoothstep(0.0, 2.5, -d * s));
            col = mix(cInk.rgb * 0.8, col, smoothstep(0.5, 1.4, -d * s) * 0.85 + 0.15);   // a pen line around it
            col *= 0.96 + 0.08 * grainTex.r;
            acc += (1.0 - acc.a) * a * vec4(col, 1.0);
        }
    }

    ground = mix(ground, ground * cShadow.rgb, 0.8 * shade);
    vec3 outc = ground * (1.0 - acc.a) + acc.rgb;

    // Smoke: three puffs per smoking chimney rise 48 px in 12.6 s, drift downwind and thin out;
    // a smokestack's puffs are bigger, darker and rise 80 px. A puff reaches at most 4.4 cells
    // (5.5 lots) above the foot of its house and 45 px to the right.
    if (smoke > 0.5) {
        float puffs = 0.0;
        float soot = 0.0;
        for (int dj = 5; dj >= 0; --dj) {
            for (int di = -1; di <= 1; ++di) {
                vec2 c = id + vec2(float(di), float(dj));
                vec2 h = hash2(c);
                vec2 k = hash2(c + 17.3);
                if (fract(k.x * 41.0) > 0.45 && fract(k.x * 61.0) < 0.895) continue;     // neither a smoking chimney nor a factory
                vec2 root = foot(c, h, lotSize);
                // No puff from this lot reaches the pixel when it is too far aside, above or below.
                if (px.x < root.x - 0.9 * cell || px.x > root.x + 1.9 * cell || px.y > root.y || px.y < root.y - 4.5 * cell) continue;
                float low;
                float kind = kindAt(k, root, low);
                bool stackSmoke = kind > 7.5 && kind < 8.5;
                if (!stackSmoke && (kind < -0.5 || kind > 1.5 || fract(k.x * 41.0) > 0.45 || fract(k.y * 71.0) > 0.7)) continue;
                if (level(root - vec2(0.0, 0.4 * cell)) < 1.6 + 0.3 * (fract(k.x * 17.0) - 0.5)) continue;
                vec3 D = dims(kind, k, low);
                if (!fits(root, kind, D.x, D.y + D.z)) continue;
                float cTop = stackSmoke ? D.y + D.z : D.y + (kind > 0.5 ? D.z : 0.5 * D.z) + 7.0;
                vec2 mouth = root + vec2((h.x < 0.5 ? -0.5 : 0.5) * (stackSmoke ? 1.1 : 1.0) * D.x, -cTop);
                float big = stackSmoke ? 1.7 : 1.0;
                for (int i = 0; i < 3; ++i) {
                    float p = fract(time * 300.0 / 3769.911184 + float(i) / 3.0 + h.y);
                    vec2 at = mouth + big * vec2(24.0 * p * p + 2.5 * sin(p * 9.0 + 6.2832 * h.x), -4.0 - 44.0 * p);
                    float r = big * (3.5 + 8.0 * p);
                    float a = (1.0 - smoothstep(r - 3.0, r, length(px - at))) * 0.8 * (1.0 - p * p) * smoothstep(0.0, 0.1, p);
                    if (a > puffs) {
                        puffs = a;
                        soot = stackSmoke ? 0.45 : 0.0;
                    }
                }
            }
        }
        outc = mix(outc, mix(cSmoke.rgb, cInk.rgb * 0.6, soot), puffs);
    }

    outc += (hash(floor(px)) - 0.5) * 0.012;
    outc *= tint.rgb;
    fragColor = vec4(outc, 1.0) * qt_Opacity;
}
