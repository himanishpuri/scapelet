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

    function test_ship_by_setting() {
        compare(Beach.ship(0, 3), null);
        compare(Beach.ship(7, 3), null);
        const seen = {};
        for (let n = 0; n < 20; ++n) {
            const old = Beach.ship(1, n).name, modern = Beach.ship(2, n).name, mixed = Beach.ship(3, n).name;
            verify(["sloop", "galleon", "corsair"].indexOf(old) >= 0, old);
            verify(["yacht", "trawler"].indexOf(modern) >= 0, modern);
            seen[old] = seen[modern] = seen[mixed] = true;
            compare(Beach.ship(3, n), Beach.ship(3, n));
        }
        compare(Object.keys(seen).sort().join(","), "corsair,galleon,sloop,trawler,yacht");
    }
}
