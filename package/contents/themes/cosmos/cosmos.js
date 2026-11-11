// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Index = Cosmos setting "palette". accent is exported as the wallpaper accent colour.
var palettes = [
    { space: "#05060f", nebulaA: "#5b2a8c", nebulaB: "#c0489a", core: "#ffd9f0", star: "#ffffff", line: "#c9b8ff", accent: "#7a4ab8" },   // Violet
    { space: "#03090f", nebulaA: "#0f5f78", nebulaB: "#3fc9a8", core: "#e0fff4", star: "#f2fbff", line: "#a8e8ee", accent: "#1f8f9a" },   // Teal
    { space: "#0b0606", nebulaA: "#8c2f1a", nebulaB: "#e09a3a", core: "#fff0c8", star: "#fff6e8", line: "#ffd9a8", accent: "#c0562a" }    // Ember
];

// px kept clear around an anchor: half an icon picture (24) plus a margin.
var GAP = 34;

// The point a constellation line aims at: the middle of an icon's picture, or of a widget.
function anchor(s) {
    return s.kind === "widget" ? { x: s.x + s.w / 2, y: s.y + s.h / 2 } : { x: s.x + s.w / 2, y: s.y + 38 };
}

// Lines joining the members of every cluster of 2 or more: a minimum spanning tree over the anchors.
// Members that are not in sources are skipped. Returns [{ x1, y1, x2, y2 }].
function links(sources, clusters) {
    var byId = {}, out = [];
    for (var i = 0; i < sources.length; ++i) {
        byId[sources[i].id] = sources[i];
    }
    for (var c = 0; c < clusters.length; ++c) {
        var pts = [];
        for (var m = 0; m < clusters[c].members.length; ++m) {
            var s = byId[clusters[c].members[m]];
            if (s) {
                pts.push(anchor(s));
            }
        }
        if (pts.length < 2) {
            continue;
        }
        // Prim: best[k] is the squared distance from point k to the tree, from[k] the tree point it would join.
        var best = [], from = [], done = [];
        for (var k = 0; k < pts.length; ++k) {
            best.push(k === 0 ? 0 : Infinity);
            from.push(-1);
            done.push(false);
        }
        for (var n = 0; n < pts.length; ++n) {
            var u = -1;
            for (var a = 0; a < pts.length; ++a) {
                if (!done[a] && (u < 0 || best[a] < best[u])) {
                    u = a;
                }
            }
            done[u] = true;
            if (from[u] >= 0) {
                out.push({ x1: pts[from[u]].x, y1: pts[from[u]].y, x2: pts[u].x, y2: pts[u].y });
            }
            for (var b = 0; b < pts.length; ++b) {
                var dx = pts[b].x - pts[u].x, dy = pts[b].y - pts[u].y, d = dx * dx + dy * dy;
                if (!done[b] && d < best[b]) {
                    best[b] = d;
                    from[b] = u;
                }
            }
        }
    }
    return out;
}
