// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../code/world.js" as Islands

// Keeps one IslandBlob per icon rectangle.
Item {
    id: mask

    property var rects: []
    property real sigma: 70
    property int appearDelay: 2000
    property int disappearDelay: 3000
    property int morphDuration: 1800
    property bool animateChanges: true

    onRectsChanged: sync()

    ListModel { id: blobs }

    function indexOfKey(key) {
        for (let i = 0; i < blobs.count; ++i) {
            if (blobs.get(i).key === key) {
                return i;
            }
        }
        return -1;
    }

    function setPresent(key, value) {
        const i = indexOfKey(key);
        if (i >= 0) {
            blobs.setProperty(i, "present", value);
        }
    }

    function expire(key) {
        const i = indexOfKey(key);
        if (i >= 0 && !blobs.get(i).present) {
            blobs.remove(i);
        }
    }

    function sync() {
        const existing = [];
        for (let i = 0; i < blobs.count; ++i) {
            const b = blobs.get(i);
            existing.push({ key: b.key, present: b.present });
        }
        const d = Islands.diff(existing, mask.rects || []);
        for (const key of d.retire) {
            setPresent(key, false);
        }
        for (const key of d.revive) {
            setPresent(key, true);
        }
        for (const r of d.add) {
            blobs.append({ key: Islands.keyOf(r), bx: r.x, by: r.y, bw: r.w, bh: r.h, present: true });
        }
    }

    Repeater {
        model: blobs
        delegate: IslandBlob {
            sigma: mask.sigma
            animate: mask.animateChanges
            appearDelay: mask.appearDelay
            disappearDelay: mask.disappearDelay
            morphDuration: mask.morphDuration
            onExpired: key => Qt.callLater(mask.expire, key)
        }
    }
}
