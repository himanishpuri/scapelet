// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../package/contents/code/world.js" as World

TestCase {
    name: "World"

    readonly property var a: ({ x: 0, y: 0, w: 100, h: 110 })
    readonly property var b: ({ x: 400, y: 330, w: 100, h: 110 })

    function test_keyOf() {
        compare(World.keyOf({ x: 10, y: 20, w: 100, h: 110 }), "10,20,100,110");
    }

    function test_addFromEmpty() {
        const d = World.diff([], [a, b]);
        compare(d.add.length, 2);
        compare(d.revive.length, 0);
        compare(d.retire.length, 0);
    }

    function test_unchanged() {
        const d = World.diff([{ key: World.keyOf(a), present: true }], [a]);
        compare(d.add.length, 0);
        compare(d.revive.length, 0);
        compare(d.retire.length, 0);
    }

    function test_retire() {
        const d = World.diff([{ key: World.keyOf(a), present: true }], []);
        compare(d.retire, [World.keyOf(a)]);
        compare(d.add.length, 0);
        compare(d.revive.length, 0);
    }

    function test_revive() {
        const d = World.diff([{ key: World.keyOf(a), present: false }], [a]);
        compare(d.revive, [World.keyOf(a)]);
        compare(d.add.length, 0);
        compare(d.retire.length, 0);
    }

    function test_retiredStaysRetired() {
        const d = World.diff([{ key: World.keyOf(a), present: false }], []);
        compare(d.add.length, 0);
        compare(d.revive.length, 0);
        compare(d.retire.length, 0);
    }

    function test_duplicateRects() {
        const d = World.diff([], [a, a]);
        compare(d.add.length, 1);
    }

    function test_move() {
        const d = World.diff([{ key: World.keyOf(a), present: true }], [b]);
        compare(d.retire, [World.keyOf(a)]);
        compare(d.add.length, 1);
        compare(d.add[0], b);
        compare(d.revive.length, 0);
    }

    function cell(col, row) {
        return { x: col * 100, y: row * 110, w: 100, h: 110 };
    }

    function src(id, col, row) {
        const r = cell(col, row);
        r.id = id;
        r.kind = "icon";
        return r;
    }

    function stateWithA() {
        return World.step({}, [src("a", 0, 0)], false).state;
    }

    function liftedState() {
        return World.step(stateWithA(), [], true).state;
    }

    function test_normalize_ids() {
        const a1 = cell(0, 0);
        a1.id = "a";
        const a2 = cell(2, 0);
        a2.id = "a";
        const out = World.normalize([cell(1, 0), a1, a2]);
        compare(out.map(s => s.id), ["a", "at:100,0,100,110", "a#2"]);
        verify(out.every(s => s.kind === "icon"));
    }

    function test_step_add() {
        const r = World.step({}, [src("a", 0, 0)], false);
        compare(r.added.length, 1);
        compare(r.removed.length, 0);
        compare(r.moved.length, 0);
        compare(r.state.a.lifted, false);
    }

    function test_step_remove() {
        const r = World.step(stateWithA(), [], false);
        compare(r.removed.length, 1);
        compare(r.state.a, undefined);
    }

    function test_step_lift() {
        const r = World.step(stateWithA(), [], true);
        compare(r.removed.length, 0);
        compare(r.state.a.lifted, true);
    }

    function test_step_drop_moved() {
        const r = World.step(liftedState(), [src("a", 3, 2)], true);
        compare(r.moved.length, 1);
        compare(r.moved[0].id, "a");
        compare(r.moved[0].from.x, 0);
        compare(r.moved[0].to.x, 300);
        compare(r.state.a.lifted, false);
    }

    function test_step_drop_same_place() {
        const r = World.step(liftedState(), [src("a", 0, 0)], false);
        compare(r.added.length, 0);
        compare(r.moved.length, 0);
        compare(r.removed.length, 0);
    }

    function test_step_drag_end_missing() {
        const r = World.step(liftedState(), [], false);
        compare(r.removed.length, 1);
    }

    function test_step_move_without_lift() {
        const r = World.step(stateWithA(), [src("a", 1, 0)], false);
        compare(r.moved.length, 1);
        compare(r.added.length, 0);
        compare(r.removed.length, 0);
    }

    function test_clusters_link() {
        const c = World.clusters([src("a", 0, 0), src("b", 1, 0), src("c", 6, 0)], 161);
        compare(c.length, 2);
        compare(c[0].id, "a");
        compare(c[0].members, ["a", "b"]);
        compare(c[0].size, 2);
        compare(c[0].x, 0);
        compare(c[0].w, 200);
        compare(c[0].cx, 100);
        compare(c[1].id, "c");
        compare(c[1].size, 1);
    }

    function test_clusters_chain() {
        const c = World.clusters([src("a", 0, 0), src("b", 2, 0), src("c", 4, 0)], 161);
        compare(c.length, 1);
        compare(c[0].size, 3);
    }

    function test_grouped_formed() {
        const prev = World.clusters([src("a", 0, 0), src("c", 6, 0)], 161);
        const next = World.clusters([src("a", 0, 0), src("b", 1, 0), src("c", 6, 0)], 161);
        const g = World.grouped(prev, next);
        compare(g.length, 1);
        compare(g[0].size, 2);
    }

    function test_grouped_shrunk_or_same() {
        const prev = World.clusters([src("a", 0, 0), src("b", 1, 0)], 161);
        compare(World.grouped(prev, World.clusters([src("a", 0, 0), src("b", 1, 0)], 161)).length, 0);
        compare(World.grouped(prev, World.clusters([src("a", 0, 0)], 161)).length, 0);
    }

    function test_spots_horizontal() {
        const list = [src("a", 0, 0), src("b", 1, 0)];
        const s = World.decorSpots(list, World.clusters(list, 161), 84);
        compare(s.length, 1);
        compare(s[0].x, 100);
        compare(s[0].y, 55);
        compare(s[0].cluster, "a");
        verify(s[0].seed >= 0 && s[0].seed < 1);
    }

    function test_spots_vertical_shifted() {
        const list = [src("a", 0, 0), src("b", 0, 1)];
        const s = World.decorSpots(list, World.clusters(list, 161), 84);
        compare(s.length, 1);
        compare(s[0].x, 100);
        compare(s[0].y, 110);
    }

    function test_spots_far() {
        const list = [src("a", 0, 0), src("b", 3, 0)];
        compare(World.decorSpots(list, World.clusters(list, 161), 84).length, 0);
    }

    function test_coverage() {
        const screen = { x: 0, y: 0, width: 1920, height: 1200 };
        compare(World.coverage({ x: 0, y: 0, width: 960, height: 1200 }, screen), 0.5);
        compare(World.coverage({ x: 2000, y: 0, width: 100, height: 100 }, screen), 0);
        compare(World.coverage(undefined, screen), 0);
    }

    function test_dayTint() {
        const noon = World.dayTint(12);
        compare(noon.r, 1);
        compare(noon.g, 1);
        compare(noon.b, 1);
        compare(World.dayTint(0).b, 0.75);
        fuzzyCompare(World.dayTint(6).r, 0.71, 0.001);
    }
}
