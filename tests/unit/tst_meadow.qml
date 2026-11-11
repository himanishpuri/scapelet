// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../package/contents/themes/meadow/meadow.js" as Meadow

TestCase {
    name: "Meadow"

    function test_palettes_complete() {
        compare(Meadow.palettes.length, 3);
        const keys = ["grassDark", "grassMid", "grassLight", "haze", "shadow", "cloudLight", "cloudCore", "cloudShade", "accent"];
        for (const p of Meadow.palettes) {
            for (const k of keys) {
                verify(/^#[0-9a-f]{6}$/.test(p[k]), k + " = " + p[k]);
            }
        }
    }
}
