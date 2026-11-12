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
    vec4 cDirt;       // a footpath
    float trails;     // number of footpaths drawn into `trail`; 0: the texture is not read
    // A walker: xy = feet px, z = 0..1 place in the stride, w = sign: facing (+ right, - left),
    // size: 1 + outfit (0..3), + 8 while waving. x < -500: nobody.
    vec4 who0;
    vec4 who1;
    vec4 who2;
    vec4 who3;
    // The woodcutter's job: xy = grid cell of the tree, z = seconds since the job began (< 0: no job),
    // w = the side of the tree he works on (-1 left, 1 right). A job lasts 314.16 s; see main().
    vec4 chop;
};
layout(binding = 1) uniform sampler2D mask;     // r = narrow sum: > 0 near an icon
layout(binding = 2) uniform sampler2D noiseTex; // r, g: 2-octave noise, b: 1 octave; tile = 2048 px, repeats
layout(binding = 3) uniform sampler2D trail;    // r: 1 on the middle of a footpath, 0.25 at 35 px from it, 0 beyond

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

// One tree, on grid cell c. force: it stands even where the grid has none. grow: 0..1, its size
// (1: full grown). tilt: radians it has tipped over, clockwise. Returns its premultiplied colour
// over px and adds its shadow to shade. root: where it stands; standing: 0..1, how much of it the
// icons and the footpaths leave (before grow).
vec4 tree(vec2 c, vec2 px, bool force, float grow, float tilt, vec4 grainTex, out vec2 root, out float standing, inout float shade) {
    vec2 h = hash2(c);
    vec2 k = hash2(c + 17.3);
    root = (c + 0.15 + 0.7 * h) * cell;
    standing = 0.0;
    if (k.x > keep && !force) return vec4(0.0);
    // Nothing of this tree reaches the pixel when it is too far aside, above or below; a tree
    // that tips over reaches as far aside as it is tall.
    float aside = tilt != 0.0 ? 2.2 * size : 1.15 * size + sway;
    if (abs(px.x - root.x) > aside || px.y > root.y + 0.3 * size + 2.0 || px.y < root.y - 2.1 * size) return vec4(0.0);

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
    if (trails > 0.5) {
        // No tree stands on a footpath, and the trees in front of one stay low, so the path shows over them.
        s *= 1.0 - smoothstep(0.15, 0.50, texture(trail, root / resolution).r);
        s *= 1.0 - 0.55 * smoothstep(0.30, 0.70, texture(trail, (root - vec2(0.0, 0.9 * size)) / resolution).r);
    }
    standing = s;
    s *= grow;
    if (s < 0.02) return vec4(0.0);
    float fade = smoothstep(0.02, 0.4, s);                   // the last bit of a tree fades out

    vec2 q = vec2(px.x - root.x, root.y - px.y) / s;         // px in the tree's own frame, y up

    vec2 e = (q - vec2(0.30 * halfW, -0.03 * height)) / vec2(0.9 * halfW, 0.10 * height + 2.0);
    shade = max(shade, (1.0 - smoothstep(0.55, 1.0, length(e))) * s * fade * (1.0 - smoothstep(0.2, 0.9, abs(tilt))));
    q = vec2(q.x * cos(tilt) - q.y * sin(tilt), q.y * cos(tilt) + q.x * sin(tilt));
    if (q.y < 0.0 || q.y > height) return vec4(0.0);

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
    if (a <= 0.0) return vec4(0.0);

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
    return a * vec4(col, 1.0);
}

float capsule(vec2 p, vec2 a, vec2 b, float r) {
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0)) - r;
}

// A person 21 px tall with the feet at `at`. facing: 1 right, -1 left. stride: 0..1 place in the
// step. outfit: 0..3 hikers (with a pack), 4 the woodcutter. wave: 1 while an arm waves.
// axe: < 0 none, else 0..1 through one swing (raised at 0.7, struck at 1). Premultiplied colour over px.
vec4 person(vec2 at, vec2 px, float facing, float stride, float outfit, float wave, float axe) {
    vec2 p = vec2((px.x - at.x) * facing, at.y - px.y);      // the person faces +x, y up
    if (abs(p.x) > 12.0 || p.y < -1.0 || p.y > 26.0) return vec4(0.0);
    float swing = 2.4 * sin(6.2832 * stride);
    float dLegs = min(capsule(p, vec2(-0.8, 7.5), vec2(-0.8 + swing, 0.6), 1.05), capsule(p, vec2(0.8, 7.5), vec2(0.8 - swing, 0.6), 1.05));
    float dBody = capsule(p, vec2(0.0, 8.5), vec2(0.0, 13.0), 2.5);
    float dPack = outfit < 3.5 ? max(abs(p.x + 3.4) - 1.7, abs(p.y - 11.3) - 2.7) : 1e3;
    float dHead = length(p - vec2(0.3, 16.8)) - 2.4;
    float dHat = min(max(abs(p.x - 0.3) - 3.1, abs(p.y - 18.7) - 0.6), max(abs(p.x - 0.1) - 1.9, abs(p.y - 19.8) - 1.0));
    vec2 hand = vec2(3.6, 10.2 - 0.8 * swing);
    if (wave > 0.5) hand = vec2(4.2 + 1.2 * sin(time * 9.0), 18.5);
    float dTool = 1e3;
    float dBlade = 1e3;
    if (axe >= 0.0) {
        // The axe goes up behind the shoulder and comes down on the trunk.
        float lift = axe < 0.7 ? axe / 0.7 : 1.0 - (axe - 0.7) / 0.3;
        float ang = mix(-0.35, 1.9, lift);
        hand = vec2(3.0 + 1.5 * cos(ang), 11.5 + 2.0 * sin(ang));
        vec2 tip = hand + 8.0 * vec2(cos(ang), sin(ang));
        dTool = capsule(p, hand, tip, 0.55);
        dBlade = length(p - tip) - 1.9;
    }
    float dArm = capsule(p, vec2(0.6, 13.2), hand, 0.95);
    float d = min(min(min(dLegs, dBody), min(dPack, dHead)), min(min(dHat, dArm), min(dTool, dBlade)));
    float a = clamp(0.5 - d, 0.0, 1.0);
    if (a <= 0.0) return vec4(0.0);
    vec3 shirt = outfit < 0.5 ? vec3(0.80, 0.27, 0.22) : (outfit < 1.5 ? vec3(0.22, 0.42, 0.66) : (outfit < 2.5 ? vec3(0.90, 0.72, 0.25) : (outfit < 3.5 ? vec3(0.93, 0.90, 0.84) : vec3(0.72, 0.20, 0.18))));
    vec3 col = vec3(0.25, 0.24, 0.30);                                   // trousers
    if (dBlade < 0.0) col = vec3(0.78, 0.80, 0.82);
    else if (dTool < 0.0) col = vec3(0.45, 0.30, 0.20);
    else if (dHat < 0.0) col = outfit > 3.5 ? vec3(0.30, 0.22, 0.18) : mix(shirt, vec3(0.35, 0.28, 0.2), 0.6);
    else if (dHead < 0.0) col = vec3(0.93, 0.76, 0.62);
    else if (dArm < 0.0) col = shirt * 0.88;
    else if (dPack < 0.0) col = vec3(0.48, 0.36, 0.24);
    else if (dBody < 0.0) col = outfit > 3.5 ? shirt * (0.8 + 0.2 * step(0.5, fract(p.y / 2.4)) * step(0.5, fract(p.x / 2.4))) : shirt;
    col = mix(col * 0.55, col, smoothstep(0.2, 1.1, -d));               // a darker edge
    return a * vec4(col, 1.0);
}

// Adds what stands at depth y (px down the screen) to the layer of people: nearer things cover farther ones.
void stack(vec4 col, float y, inout vec4 layer, inout float layerY) {
    if (col.a <= 0.0) return;
    if (y >= layerY) {
        layer = col + (1.0 - col.a) * layer;
        layerY = y;
    } else {
        layer += (1.0 - layer.a) * col;
    }
}

void walker(vec4 who, vec2 px, inout vec4 layer, inout float layerY, inout float shade) {
    if (who.x < -500.0) return;
    float code = abs(who.w) - 1.0;
    vec2 e = (px - who.xy - vec2(2.0, 0.5)) / vec2(6.0, 2.2);
    shade = max(shade, 0.8 * (1.0 - smoothstep(0.5, 1.0, length(e))));
    stack(person(who.xy, px, sign(who.w), who.z, mod(code, 8.0), step(8.0, code), -1.0), who.y, layer, layerY);
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
    // A footpath: trodden earth with a ragged edge.
    float path = trails > 0.5 ? smoothstep(0.52, 0.70, texture(trail, qt_TexCoord0).r + 0.22 * (grainTex.g - 0.5)) : 0.0;
    grass = mix(grass, cInk.rgb, 0.6 * strokes(px, dens) * (1.0 - path));
    grass = mix(grass, cDirt.rgb * (0.95 + 0.10 * w2), 0.9 * path);
    grass *= 1.0 - 0.10 * path * (1.0 - path) * 4.0;                  // the wash pools along the edge of the path
    // The clearing is a little brighter than the forest floor.
    grass *= 1.0 + 0.05 * smoothstep(0.0, 0.5, texture(mask, qt_TexCoord0).r);

    float shade = 0.0;         // 0..1 ground shadow

    // People, and the tree the woodcutter is felling, stand among the trees: `layer` holds what of
    // them covers this pixel and layerY how far down the screen it stands. Trees that stand nearer
    // (further down) are drawn over it, the others behind it.
    vec4 layer = vec4(0.0);
    float layerY = -1e6;
    walker(who0, px, layer, layerY, shade);
    walker(who1, px, layer, layerY, shade);
    walker(who2, px, layer, layerY, shade);
    walker(who3, px, layer, layerY, shade);

    // The woodcutter's job, t seconds in: 0..70 he walks in from the nearer side of the screen
    // (a tree grows there first if the grid had none), 70..95 ten blows, 95..98 the tree tips
    // over and is gone by 99.5, 104..174 he walks out, the stump stays until about 200, and
    // from 200 to 305 a new tree grows where a tree stood before.
    bool job = chop.z >= 0.0;
    if (job) {
        float t = chop.z;
        bool wasThere = hash2(chop.xy + 17.3).x <= keep;
        float blow = fract(clamp((t - 70.0) / 25.0, 0.0, 0.9999) * 10.0);       // 0..1 through one blow
        bool chopping = t >= 70.0 && t < 95.0;
        float tilt = -chop.w * 1.5 * smoothstep(95.0, 98.0, t);
        if (chopping && blow > 0.7) tilt += -chop.w * 0.05 * (1.0 - blow) / 0.3 * sin(blow * 60.0);   // it shudders at each blow
        float grow = t < 99.5 ? (wasThere ? 1.0 : smoothstep(0.0, 60.0, t)) * (1.0 - smoothstep(97.5, 99.5, t))
                              : (wasThere ? smoothstep(200.0, 305.0, t) : 0.0);
        vec2 root;
        float standing;
        vec4 felled = tree(chop.xy, px, true, grow, t < 99.5 ? tilt : 0.0, grainTex, root, standing, shade);
        stack(felled, root.y, layer, layerY);
        if (standing > 0.5) {
            // The stump: a short trunk with a pale top.
            float stump = step(95.0, t) * (1.0 - smoothstep(190.0, 205.0, t));
            vec2 sp = vec2(px.x - root.x, root.y - px.y);
            float dS = max(abs(sp.x) - 3.2, abs(sp.y - 2.5) - 2.5);
            float top = length((sp - vec2(0.0, 5.0)) / vec2(3.2, 1.3)) - 1.0;
            vec3 sc = top < 0.0 ? mix(cTrunk.rgb, vec3(1.0), 0.45) * (0.9 + 0.1 * step(0.5, fract(length(sp - vec2(0.0, 5.0)) / 1.2))) : cTrunk.rgb * 0.9;
            stack(stump * clamp(0.5 - min(dS, top * 1.3), 0.0, 1.0) * vec4(sc, 1.0), root.y - 0.5, layer, layerY);
            // The woodcutter.
            if (t < 174.0) {
                float edgeX = chop.w < 0.0 ? -20.0 : resolution.x + 20.0;
                float standX = root.x + chop.w * 12.0;
                float x = t < 70.0 ? mix(edgeX, standX, t / 70.0) : (t < 104.0 ? standX : mix(standX, edgeX, (t - 104.0) / 70.0));
                bool walking = t < 70.0 || t >= 104.0;
                vec2 at = vec2(x, root.y + 3.0);
                vec2 e = (px - at - vec2(2.0, 0.5)) / vec2(6.0, 2.2);
                shade = max(shade, 0.8 * (1.0 - smoothstep(0.5, 1.0, length(e))));
                stack(person(at, px, t < 104.0 ? -chop.w : chop.w, walking ? fract(x / 9.0) : 0.0, 4.0, 0.0, chopping ? blow : -1.0), at.y, layer, layerY);
            }
        }
    }

    // Trees: one per grid cell, drawn front (lower on screen) to back. A tree is at most 2.1 sizes
    // tall and 0.97 sizes (plus the sway) to each side. Its root lies 0.15..0.85 into its cell, so
    // rows up to 0.85 + 2.1 sizes / cell below and columns up to 0.85 + 0.97 sizes / cell aside can
    // cover a pixel: 3 rows and 3 columns at the default spacing (cell == size). The row above
    // only adds its shadow.
    vec2 id = floor(px / cell);
    vec4 acc = vec4(0.0);      // premultiplied colour of the trees in front of the people
    vec4 back = vec4(0.0);     // and of the trees behind them
    vec2 f = px / cell - id;
    float reachX = (1.15 * size + sway) / cell;
    int di0 = int(ceil(f.x - 0.85 - reachX)), di1 = int(floor(f.x - 0.15 + reachX));
    int dj0 = int(ceil(f.y - 0.85 - (0.3 * size + 2.0) / cell)), dj1 = int(floor(f.y - 0.15 + 2.1 * size / cell));
    for (int dj = dj1; dj >= dj0; --dj) {
        for (int di = di0; di <= di1; ++di) {
            if (acc.a > 0.995) continue;
            vec2 c = id + vec2(float(di), float(dj));
            if (job && c == chop.xy) continue;
            vec2 root;
            float standing;
            vec4 col = tree(c, px, false, 1.0, 0.0, grainTex, root, standing, shade);
            if (layer.a > 0.0 && root.y <= layerY) {
                back += (1.0 - back.a) * col;
            } else {
                acc += (1.0 - acc.a) * col;
            }
        }
    }
    acc += (1.0 - acc.a) * layer;
    acc += (1.0 - acc.a) * back;

    grass = mix(grass, grass * cShadow.rgb, 0.8 * shade);
    vec3 outc = grass * (1.0 - acc.a) + acc.rgb;
    outc += (hash(floor(px)) - 0.5) * 0.012;
    outc *= tint.rgb;
    fragColor = vec4(outc, 1.0) * qt_Opacity;
}
