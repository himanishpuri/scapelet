// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../package/contents/themes/beach/beach.js" as Beach

TestCase {
    name: "Beach"

    function test_palettes_complete() {
        compare(Beach.palettes.length, 3);
        const keys = ["deep", "mid", "shallow", "shoal", "foam", "sandWet", "sandDry", "sandHigh", "accent"];
        for (const p of Beach.palettes) {
            for (const k of keys) {
                verify(/^#[0-9a-f]{6}$/.test(p[k]), k + " = " + p[k]);
            }
        }
    }

    function test_palmSpots_small_cluster() {
        compare(Beach.palmSpots([{ x: 1, y: 1, cluster: "a", seed: 0.9 }], [{ id: "a", size: 2 }]), []);
    }

    function test_palmSpots_quota() {
        const spots = [0.1, 0.9, 0.5, 0.7].map((s, i) => ({ x: i, y: 0, cluster: "a", seed: s }));
        const out = Beach.palmSpots(spots, [{ id: "a", size: 4 }]);
        compare(out.length, 2);
        compare(out[0].seed, 0.9);
        compare(out[1].seed, 0.7);
    }
}
