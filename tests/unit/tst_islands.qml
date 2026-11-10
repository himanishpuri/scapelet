// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../package/contents/code/islands.js" as Islands

TestCase {
    name: "Islands"

    readonly property var a: ({ x: 0, y: 0, w: 100, h: 110 })
    readonly property var b: ({ x: 400, y: 330, w: 100, h: 110 })

    function test_keyOf() {
        compare(Islands.keyOf({ x: 10, y: 20, w: 100, h: 110 }), "10,20,100,110");
    }

    function test_addFromEmpty() {
        const d = Islands.diff([], [a, b]);
        compare(d.add.length, 2);
        compare(d.revive.length, 0);
        compare(d.retire.length, 0);
    }

    function test_unchanged() {
        const d = Islands.diff([{ key: Islands.keyOf(a), present: true }], [a]);
        compare(d.add.length, 0);
        compare(d.revive.length, 0);
        compare(d.retire.length, 0);
    }

    function test_retire() {
        const d = Islands.diff([{ key: Islands.keyOf(a), present: true }], []);
        compare(d.retire, [Islands.keyOf(a)]);
        compare(d.add.length, 0);
        compare(d.revive.length, 0);
    }

    function test_revive() {
        const d = Islands.diff([{ key: Islands.keyOf(a), present: false }], [a]);
        compare(d.revive, [Islands.keyOf(a)]);
        compare(d.add.length, 0);
        compare(d.retire.length, 0);
    }

    function test_retiredStaysRetired() {
        const d = Islands.diff([{ key: Islands.keyOf(a), present: false }], []);
        compare(d.add.length, 0);
        compare(d.revive.length, 0);
        compare(d.retire.length, 0);
    }

    function test_duplicateRects() {
        const d = Islands.diff([], [a, a]);
        compare(d.add.length, 1);
    }

    function test_move() {
        const d = Islands.diff([{ key: Islands.keyOf(a), present: true }], [b]);
        compare(d.retire, [Islands.keyOf(a)]);
        compare(d.add.length, 1);
        compare(d.add[0], b);
        compare(d.revive.length, 0);
    }
}
