// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// A rect is { x, y, w, h } in integer scene pixels.
function keyOf(r) {
    return r.x + "," + r.y + "," + r.w + "," + r.h;
}

// existing: [{ key: string, present: bool }] — blobs currently in the model.
// rects: [{ x, y, w, h }] — icons that exist now.
// Returns { add: [rect], revive: [key], retire: [key] }.
function diff(existing, rects) {
    var want = {};
    for (var i = 0; i < rects.length; ++i) {
        want[keyOf(rects[i])] = rects[i];
    }
    var have = {};
    var add = [], revive = [], retire = [];
    for (var j = 0; j < existing.length; ++j) {
        var e = existing[j];
        have[e.key] = true;
        var wanted = want.hasOwnProperty(e.key);
        if (e.present && !wanted) {
            retire.push(e.key);
        } else if (!e.present && wanted) {
            revive.push(e.key);
        }
    }
    for (var k in want) {
        if (!have[k]) {
            add.push(want[k]);
        }
    }
    return { add: add, revive: revive, retire: retire };
}

// A source is { id, kind, x, y, w, h } in integer scene pixels. kind is "icon" or "widget".

// 0..1, stable for a position.
function hash01(x, y) {
    var v = Math.sin(x * 127.1 + y * 311.7) * 43758.5453;
    return v - Math.floor(v);
}

// Sorted copy (x, then y) where every source has a unique string id and a kind.
function normalize(list) {
    var sorted = list.slice().sort(function (a, b) { return a.x - b.x || a.y - b.y; });
    var seen = {}, out = [];
    for (var i = 0; i < sorted.length; ++i) {
        var s = sorted[i];
        var base = (s.id === undefined || s.id === null || s.id === "") ? "at:" + keyOf(s) : String(s.id);
        var n = (seen[base] || 0) + 1;
        seen[base] = n;
        out.push({ id: n === 1 ? base : base + "#" + n, kind: s.kind || "icon", x: s.x, y: s.y, w: s.w, h: s.h });
    }
    return out;
}

// prev: { id: { id, kind, x, y, w, h, lifted } } from the last call ({} at start).
// list: normalize()d sources that exist now. dragging: an icon drag is in progress.
// A source that vanishes during a drag is kept with lifted = true instead of being removed.
// Returns { state, added: [source], removed: [source], moved: [{ id, from, to }] }.
function step(prev, list, dragging) {
    var state = {}, added = [], removed = [], moved = [], now = {};
    for (var i = 0; i < list.length; ++i) {
        var s = list[i];
        var cur = { id: s.id, kind: s.kind, x: s.x, y: s.y, w: s.w, h: s.h, lifted: false };
        var p = prev[s.id];
        now[s.id] = true;
        state[s.id] = cur;
        if (!p) {
            added.push(cur);
        } else if (keyOf(p) !== keyOf(s)) {
            moved.push({ id: s.id, from: { x: p.x, y: p.y, w: p.w, h: p.h }, to: { x: s.x, y: s.y, w: s.w, h: s.h } });
        }
    }
    for (var id in prev) {
        if (now[id]) {
            continue;
        }
        var q = prev[id];
        if (dragging) {
            state[id] = { id: q.id, kind: q.kind, x: q.x, y: q.y, w: q.w, h: q.h, lifted: true };
        } else {
            removed.push(q);
        }
    }
    return { state: state, added: added, removed: removed, moved: moved };
}

// State as an array sorted by x, y, id.
function listOf(state) {
    var out = [];
    for (var id in state) {
        out.push(state[id]);
    }
    out.sort(function (a, b) { return a.x - b.x || a.y - b.y || (a.id < b.id ? -1 : 1); });
    return out;
}

// Distance between the centred half-size cores of two sources (the solid part of a field blob).
function coreGap(a, b) {
    var dx = Math.max(0, Math.abs((a.x + a.w / 2) - (b.x + b.w / 2)) - (a.w + b.w) / 4);
    var dy = Math.max(0, Math.abs((a.y + a.h / 2) - (b.y + b.h / 2)) - (a.h + b.h) / 4);
    return Math.sqrt(dx * dx + dy * dy);
}

// Sources whose cores are within link px share a cluster.
// Returns [{ id, members: [id], size, x, y, w, h, cx, cy }] sorted by id; id is the smallest member id.
function clusters(list, link) {
    var parent = [];
    for (var i = 0; i < list.length; ++i) {
        parent.push(i);
    }
    function root(n) {
        while (parent[n] !== n) {
            parent[n] = parent[parent[n]];
            n = parent[n];
        }
        return n;
    }
    for (var a = 0; a < list.length; ++a) {
        for (var b = a + 1; b < list.length; ++b) {
            if (coreGap(list[a], list[b]) <= link) {
                parent[root(a)] = root(b);
            }
        }
    }
    var groups = {};
    for (var k = 0; k < list.length; ++k) {
        var r = root(k);
        (groups[r] = groups[r] || []).push(list[k]);
    }
    var out = [];
    for (var g in groups) {
        var m = groups[g], ids = [], x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (var n = 0; n < m.length; ++n) {
            ids.push(m[n].id);
            x0 = Math.min(x0, m[n].x);
            y0 = Math.min(y0, m[n].y);
            x1 = Math.max(x1, m[n].x + m[n].w);
            y1 = Math.max(y1, m[n].y + m[n].h);
        }
        ids.sort();
        out.push({ id: ids[0], members: ids, size: ids.length, x: x0, y: y0, w: x1 - x0, h: y1 - y0, cx: (x0 + x1) / 2, cy: (y0 + y1) / 2 });
    }
    out.sort(function (p, q) { return p.id < q.id ? -1 : 1; });
    return out;
}

// Clusters of next with 2+ members that are not inside one cluster of prev: they formed or grew.
function grouped(prev, next) {
    var owner = {};
    for (var i = 0; i < prev.length; ++i) {
        for (var j = 0; j < prev[i].members.length; ++j) {
            owner[prev[i].members[j]] = i;
        }
    }
    var out = [];
    for (var n = 0; n < next.length; ++n) {
        var c = next[n];
        if (c.size < 2) {
            continue;
        }
        var first = owner[c.members[0]];
        var inside = first !== undefined;
        for (var k = 1; inside && k < c.members.length; ++k) {
            inside = owner[c.members[k]] === first;
        }
        if (!inside) {
            out.push(c);
        }
    }
    return out;
}

// Inland points between neighbours whose cores are within near px: room for decoration between icons.
// Vertical neighbours are shifted sideways so the point leaves the upper icon's label.
// Returns [{ x, y, w: 0, h: 0, cluster, seed }], one per distinct point.
function decorSpots(list, clusterList, near) {
    var clusterOf = {};
    for (var c = 0; c < clusterList.length; ++c) {
        for (var m = 0; m < clusterList[c].members.length; ++m) {
            clusterOf[clusterList[c].members[m]] = clusterList[c].id;
        }
    }
    var seen = {}, out = [];
    for (var i = 0; i < list.length; ++i) {
        for (var j = i + 1; j < list.length; ++j) {
            var a = list[i], b = list[j];
            if (coreGap(a, b) > near) {
                continue;
            }
            var ax = a.x + a.w / 2, bx = b.x + b.w / 2;
            var x = (ax + bx) / 2, y = (a.y + a.h / 2 + b.y + b.h / 2) / 2;
            if (Math.abs(bx - ax) < (a.w + b.w) / 4) {
                x += (a.w + b.w) / 4;
            }
            x = Math.round(x);
            y = Math.round(y);
            if (seen[x + "," + y]) {
                continue;
            }
            seen[x + "," + y] = true;
            out.push({ x: x, y: y, w: 0, h: 0, cluster: clusterOf[a.id], seed: hash01(x, y) });
        }
    }
    return out;
}

// Share (0..1) of screen covered by win; both are { x, y, width, height }.
function coverage(win, screen) {
    if (!win || !screen || screen.width <= 0 || screen.height <= 0) {
        return 0;
    }
    var w = Math.min(win.x + win.width, screen.x + screen.width) - Math.max(win.x, screen.x);
    var h = Math.min(win.y + win.height, screen.y + screen.height) - Math.max(win.y, screen.y);
    return (w > 0 && h > 0) ? (w * h) / (screen.width * screen.height) : 0;
}

var TINT_KEYS = [[0, 0.42, 0.50, 0.75], [5, 0.42, 0.50, 0.75], [7, 1.00, 0.82, 0.70], [9, 1, 1, 1],
                 [17, 1, 1, 1], [19, 1.00, 0.78, 0.62], [21, 0.42, 0.50, 0.75], [24, 0.42, 0.50, 0.75]];

// Light colour for a local hour 0..24: night blue, warm dawn and dusk, white by day.
function dayTint(hour) {
    var h = ((hour % 24) + 24) % 24;
    for (var i = 1; i < TINT_KEYS.length; ++i) {
        var a = TINT_KEYS[i - 1], b = TINT_KEYS[i];
        if (h <= b[0]) {
            var t = (h - a[0]) / (b[0] - a[0]);
            return { r: a[1] + (b[1] - a[1]) * t, g: a[2] + (b[2] - a[2]) * t, b: a[3] + (b[3] - a[3]) * t };
        }
    }
    return { r: 1, g: 1, b: 1 };
}
