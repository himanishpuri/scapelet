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
}
