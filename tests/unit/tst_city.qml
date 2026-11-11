// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../package/contents/themes/city/city.js" as City

TestCase {
    name: "City"

    function test_palettes_complete() {
        compare(City.palettes.length, 3);
        const keys = ["paveLight", "paveMid", "paveDeep", "grassLight", "grassMid", "ink", "shadow", "wall0", "wall1", "wall2", "wall3", "wall4",
                      "roof0", "roof1", "roof2", "glass", "lamp", "door", "leaf", "trunk", "smoke", "accent"];
        for (const p of City.palettes) {
            for (const k of keys) {
                verify(/^#[0-9a-f]{6}$/.test(p[k]), k + " = " + p[k]);
            }
            verify(p.lit >= 0 && p.lit <= 1);
        }
    }
}
