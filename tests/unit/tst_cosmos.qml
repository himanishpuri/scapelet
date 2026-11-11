// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../package/contents/themes/cosmos/cosmos.js" as Cosmos

TestCase {
    name: "Cosmos"

    function test_palettes_complete() {
        compare(Cosmos.palettes.length, 3);
        const keys = ["space", "nebulaA", "nebulaB", "core", "star", "line", "accent"];
        for (const p of Cosmos.palettes) {
            for (const k of keys) {
                verify(/^#[0-9a-f]{6}$/.test(p[k]), k + " = " + p[k]);
            }
        }
    }

    function test_links_skip_singletons() {
        const s = [{ id: "a", kind: "icon", x: 0, y: 0, w: 100, h: 110 }];
        compare(Cosmos.links(s, [{ id: "a", members: ["a"], size: 1 }]).length, 0);
        compare(Cosmos.links([], []).length, 0);
    }

    // Three icons in a row: the tree joins neighbours, never the two ends.
    function test_links_tree() {
        const s = [0, 100, 200].map((x, i) => ({ id: "i" + i, kind: "icon", x: x, y: 0, w: 100, h: 110 }));
        const out = Cosmos.links(s, [{ id: "i0", members: ["i0", "i1", "i2"], size: 3 }]);
        compare(out.length, 2);
        for (const l of out) {
            compare(Math.abs(l.x2 - l.x1), 100);
            compare(l.y1, 38);
            compare(l.y2, 38);
        }
    }

    // A widget is anchored at its middle; a member that is not a source is skipped.
    function test_links_anchor_and_missing() {
        const s = [{ id: "i", kind: "icon", x: 0, y: 0, w: 100, h: 110 },
                   { id: "w", kind: "widget", x: 200, y: 100, w: 300, h: 200 }];
        const out = Cosmos.links(s, [{ id: "i", members: ["gone", "i", "w"], size: 3 }]);
        compare(out.length, 1);
        compare(out[0].x1, 50);
        compare(out[0].y1, 38);
        compare(out[0].x2, 350);
        compare(out[0].y2, 200);
    }
}
