// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../package/contents/code/themes.js" as Themes

TestCase {
    name: "Themes"

    function test_find_fallback() {
        compare(Themes.find("nope").id, "beach");
        compare(Themes.find("blueprint").id, "blueprint");
    }

    function test_resolve_defaults() {
        const v = Themes.resolve("beach", "{}");
        compare(v.palette, 0);
        compare(v.coastWarp, 30);
        compare(v.palms, true);
        compare(v.kayak, true);
        compare(v.birds, true);
        compare(v.timeOfDay, false);
        compare(v.strip, 0);
        compare(v.stripWidth, 160);
    }

    function test_resolve_garbage() {
        compare(Themes.resolve("beach", "not json").coastWarp, 30);
        compare(Themes.resolve("beach", undefined).coastWarp, 30);
        compare(Themes.resolve("beach", "[1]").coastWarp, 30);
    }

    function test_resolve_rejects_invalid() {
        const v = Themes.resolve("beach", '{"beach":{"palette":7,"coastWarp":500,"palms":"yes","stripWidth":100.5}}');
        compare(v.palette, 0);
        compare(v.coastWarp, 30);
        compare(v.palms, true);
        compare(v.stripWidth, 160);
    }

    function test_store_round_trip() {
        const json = Themes.store("{}", "beach", "palette", 2);
        compare(Themes.resolve("beach", json).palette, 2);
        const both = Themes.store(json, "blueprint", "grid", 80);
        compare(Themes.resolve("beach", both).palette, 2);
        compare(Themes.resolve("blueprint", both).grid, 80);
    }

    function test_meadow_defaults() {
        compare(Themes.find("meadow").id, "meadow");
        const v = Themes.resolve("meadow", '{"meadow":{"fluff":41}}');
        compare(v.palette, 0);
        compare(v.fluff, 20);
        compare(v.shadows, true);
        compare(v.altitude, 140);
        compare(v.drift, 2);
        compare(v.butterflies, true);
        compare(v.timeOfDay, false);
    }

    function test_cosmos_defaults() {
        compare(Themes.list.map(t => t.id).join(","), "beach,meadow,forest,cosmos,blueprint");
        const v = Themes.resolve("cosmos", '{"cosmos":{"density":11}}');
        compare(v.palette, 0);
        compare(v.density, 5);
        compare(v.lines, true);
        compare(v.shooting, true);
        compare(v.milkyWay, true);
        compare(v.drift, true);
    }

    function test_forest_defaults() {
        compare(Themes.find("forest").id, "forest");
        const v = Themes.resolve("forest", '{"forest":{"density":0,"palette":2}}');
        compare(v.palette, 2);
        compare(v.density, 8);
        compare(v.sway, true);
        compare(v.sparrows, true);
        compare(v.timeOfDay, false);
    }

    // Every theme names the shared settings in its own words.
    function test_terms() {
        for (const t of Themes.list) {
            for (const k of ["appear", "disappear", "morph", "widgets"]) {
                verify(typeof t.terms[k] === "string" && t.terms[k].length > 0, t.id + "." + k);
            }
        }
        verify(Themes.find("forest").terms.appear.indexOf("Island") < 0);
    }
}
