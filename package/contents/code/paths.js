// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library
.import "world.js" as World

// Curved routes for sprites. A route is a cubic Bezier curve from one screen edge to another:
// { x: [4], y: [4], k, len, lut }. k: which candidate it is (see pick), len: length in px,
// lut: length of the curve from its start to t = i / 32, for i = 0..32.

var STEPS = 32;

// Distance from a point to the rect { x, y, w, h }; 0 inside.
function rectDist(px, py, r) {
    var dx = Math.max(r.x - px, 0, px - r.x - r.w);
    var dy = Math.max(r.y - py, 0, py - r.y - r.h);
    return Math.sqrt(dx * dx + dy * dy);
}

// The point `out` px outside side s (0 left, 1 top, 2 right, 3 bottom) of a w x h screen, at share f of that side.
function edgePoint(s, f, w, h, out) {
    if (s === 0) {
        return { x: -out, y: f * h };
    }
    if (s === 1) {
        return { x: f * w, y: -out };
    }
    if (s === 2) {
        return { x: w + out, y: f * h };
    }
    return { x: f * w, y: h + out };
}

// Point of route r at curve parameter t (0..1).
function point(r, t) {
    var u = 1 - t, a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t;
    return { x: a * r.x[0] + b * r.x[1] + c * r.x[2] + d * r.x[3], y: a * r.y[0] + b * r.y[1] + c * r.y[2] + d * r.y[3] };
}

// Route number n of the sprite with this seed (both integers): the same pair always gives the same route.
// It starts and ends `out` px off screen, on two different sides, and bends through two points inside.
function route(seed, n, w, h, out) {
    function rnd(i) {
        return World.hash01(n + 0.37, seed + i);
    }
    var from = Math.min(3, Math.floor(rnd(0) * 4));
    var to = (from + 1 + Math.min(2, Math.floor(rnd(1) * 3))) % 4;
    var p0 = edgePoint(from, 0.15 + 0.7 * rnd(2), w, h, out), p3 = edgePoint(to, 0.15 + 0.7 * rnd(3), w, h, out);
    var r = { x: [p0.x, w * (0.15 + 0.7 * rnd(4)), w * (0.15 + 0.7 * rnd(5)), p3.x],
              y: [p0.y, h * (0.15 + 0.7 * rnd(6)), h * (0.15 + 0.7 * rnd(7)), p3.y], k: 0, len: 0, lut: [0] };
    var prev = p0;
    for (var i = 1; i <= STEPS; ++i) {
        var p = point(r, i / STEPS);
        r.len += Math.sqrt((p.x - prev.x) * (p.x - prev.x) + (p.y - prev.y) * (p.y - prev.y));
        r.lut.push(r.len);
        prev = p;
    }
    return r;
}

// Where a sprite is after share p (0..1) of the route's length, at constant speed.
// Returns { x, y, angle }; angle is the direction of travel in degrees, clockwise from +x.
function at(r, p) {
    var s = Math.max(0, Math.min(1, p)) * r.len, i = 0;
    while (i < STEPS - 1 && r.lut[i + 1] < s) {
        ++i;
    }
    var span = r.lut[i + 1] - r.lut[i];
    var t = (i + (span > 0 ? (s - r.lut[i]) / span : 0)) / STEPS;
    var u = 1 - t;
    var dx = 3 * u * u * (r.x[1] - r.x[0]) + 6 * u * t * (r.x[2] - r.x[1]) + 3 * t * t * (r.x[3] - r.x[2]);
    var dy = 3 * u * u * (r.y[1] - r.y[0]) + 6 * u * t * (r.y[2] - r.y[1]) + 3 * t * t * (r.y[3] - r.y[2]);
    var q = point(r, t);
    return { x: q.x, y: q.y, angle: Math.atan2(dy, dx) * 180 / Math.PI };
}

// True when every sampled point of the route is at least `clearance` px from every rect in obstacles.
function clear(r, obstacles, clearance) {
    for (var i = 0; i <= STEPS; ++i) {
        var p = point(r, i / STEPS);
        for (var j = 0; j < obstacles.length; ++j) {
            if (rectDist(p.x, p.y, obstacles[j]) < clearance) {
                return false;
            }
        }
    }
    return true;
}

// The first of `tries` candidate routes for (seed, n) that is clear of the obstacles, or null.
// The candidates and their order depend only on seed and n, so a route survives changes that do not block it.
function pick(seed, n, w, h, out, obstacles, clearance, tries) {
    for (var k = 0; k < tries; ++k) {
        var r = route(seed + 100 * k, n, w, h, out);
        if (clear(r, obstacles, clearance)) {
            r.k = k;
            return r;
        }
    }
    return null;
}
