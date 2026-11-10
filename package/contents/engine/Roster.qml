// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../code/world.js" as World

// Keeps one delegate per keyed rectangle and lets it animate out before it is destroyed.
// The delegate gets required properties key, bx, by, bw, bh, present, lifted, seed. When
// `present` turns false it plays its exit and then calls expire(key) on this roster.
Item {
    id: roster

    property var items: []          // [{ x, y, w, h, lifted?, seed? }]
    property Component delegate

    onItemsChanged: sync()

    ListModel { id: entries }

    function indexOfKey(key) {
        for (let i = 0; i < entries.count; ++i) {
            if (entries.get(i).key === key) {
                return i;
            }
        }
        return -1;
    }

    function expire(key) {
        const i = indexOfKey(key);
        if (i >= 0 && !entries.get(i).present) {
            entries.remove(i);
        }
    }

    function sync() {
        const list = roster.items || [];
        const existing = [];
        for (let i = 0; i < entries.count; ++i) {
            const e = entries.get(i);
            existing.push({ key: e.key, present: e.present });
        }
        const d = World.diff(existing, list);
        for (const key of d.retire) {
            entries.setProperty(indexOfKey(key), "present", false);
        }
        for (const key of d.revive) {
            entries.setProperty(indexOfKey(key), "present", true);
        }
        for (const r of d.add) {
            entries.append({ key: World.keyOf(r), bx: r.x, by: r.y, bw: r.w, bh: r.h, present: true, lifted: r.lifted === true, seed: r.seed || 0 });
        }
        for (const r of list) {
            const i = indexOfKey(World.keyOf(r));
            if (i >= 0 && entries.get(i).lifted !== (r.lifted === true)) {
                entries.setProperty(i, "lifted", r.lifted === true);
            }
        }
    }

    Repeater {
        model: entries
        delegate: roster.delegate
    }
}
