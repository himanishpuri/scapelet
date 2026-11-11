// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../package/contents/themes/forest/forest.js" as Forest

TestCase {
    name: "Forest"

    function test_palettes_complete() {
        compare(Forest.palettes.length, 3);
        const keys = ["grassLight", "grassMid", "grassDeep", "ink", "shadow", "trunk", "dirt",
                      "leaf0", "leaf1", "leaf2", "leaf3", "leaf4", "leaf5", "accent"];
        for (const p of Forest.palettes) {
            for (const k of keys) {
                verify(/^#[0-9a-f]{6}$/.test(p[k]), k + " = " + p[k]);
            }
        }
    }
}
