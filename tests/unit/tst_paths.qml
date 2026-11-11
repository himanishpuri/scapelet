// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../package/contents/code/paths.js" as Paths

TestCase {
    name: "Paths"

    function test_rectDist() {
        const r = { x: 100, y: 100, w: 50, h: 20 };
        compare(Paths.rectDist(120, 110, r), 0);
        compare(Paths.rectDist(90, 110, r), 10);
        compare(Paths.rectDist(153, 124, r), 5);
    }

    function test_edgePoint() {
        compare(Paths.edgePoint(0, 0.5, 800, 600, 40), { x: -40, y: 300 });
        compare(Paths.edgePoint(1, 0.25, 800, 600, 40), { x: 200, y: -40 });
        compare(Paths.edgePoint(2, 0.5, 800, 600, 40), { x: 840, y: 300 });
        compare(Paths.edgePoint(3, 0.25, 800, 600, 40), { x: 200, y: 640 });
    }

    // The same seed and number give the same route; it starts and ends off screen on two different sides.
    function test_route_stable_edge_to_edge() {
        for (let n = 0; n < 40; ++n) {
            const a = Paths.route(7, n, 1280, 800, 60), b = Paths.route(7, n, 1280, 800, 60);
            compare(a.x, b.x);
            compare(a.y, b.y);
            const off = (x, y) => x === -60 || x === 1340 || y === -60 || y === 860;
            verify(off(a.x[0], a.y[0]), "start of route " + n);
            verify(off(a.x[3], a.y[3]), "end of route " + n);
            verify(a.x[0] !== a.x[3] || a.y[0] !== a.y[3]);
            verify(a.x[1] >= 192 && a.x[1] <= 1088 && a.y[1] >= 120 && a.y[1] <= 680);
        }
        verify(Paths.route(7, 1, 1280, 800, 60).x[1] !== Paths.route(7, 2, 1280, 800, 60).x[1]);
    }

    function test_lut() {
        const r = Paths.route(3, 5, 1280, 800, 60);
        compare(r.lut.length, 33);
        compare(r.lut[0], 0);
        compare(r.lut[32], r.len);
        for (let i = 1; i <= 32; ++i) {
            verify(r.lut[i] > r.lut[i - 1]);
        }
    }

    // at() runs from the first point to the last at constant speed.
    function test_at() {
        const r = Paths.route(3, 5, 1280, 800, 60);
        fuzzyCompare(Paths.at(r, 0).x, r.x[0], 0.001);
        fuzzyCompare(Paths.at(r, 0).y, r.y[0], 0.001);
        fuzzyCompare(Paths.at(r, 1).x, r.x[3], 0.001);
        fuzzyCompare(Paths.at(r, 1).y, r.y[3], 0.001);
        fuzzyCompare(Paths.at(r, -1).x, r.x[0], 0.001);
        fuzzyCompare(Paths.at(r, 2).x, r.x[3], 0.001);
        let prev = Paths.at(r, 0);
        for (let i = 1; i <= 20; ++i) {
            const p = Paths.at(r, i / 20);
            const step = Math.hypot(p.x - prev.x, p.y - prev.y);
            verify(step > 0.8 * r.len / 20 && step < 1.05 * r.len / 20, "step " + i + " = " + step);
            prev = p;
        }
    }

    function test_clear() {
        const r = Paths.route(3, 5, 1280, 800, 60);
        verify(Paths.clear(r, [], 100));
        const mid = Paths.point(r, 0.5);
        verify(!Paths.clear(r, [{ x: mid.x - 10, y: mid.y - 10, w: 20, h: 20 }], 50));
    }

    // pick() skips blocked candidates, keeps its choice while it stays clear, and gives up on a full screen.
    function test_pick() {
        const free = Paths.pick(9, 4, 1280, 800, 60, [], 80, 12);
        compare(free.k, 0);
        const mid = Paths.point(free, 0.5);
        const block = [{ x: mid.x - 10, y: mid.y - 10, w: 20, h: 20 }];
        const other = Paths.pick(9, 4, 1280, 800, 60, block, 80, 12);
        verify(other !== null);
        verify(other.k > 0);
        verify(Paths.clear(other, block, 80));
        const far = [{ x: -5000, y: -5000, w: 10, h: 10 }];
        compare(Paths.pick(9, 4, 1280, 800, 60, far, 80, 12).k, 0);
        compare(Paths.pick(9, 4, 1280, 800, 60, [{ x: 0, y: 0, w: 1280, h: 800 }], 80, 12), null);
    }
}
