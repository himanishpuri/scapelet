// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// A rect is { x, y, w, h } in integer scene pixels.
function keyOf(r) {
    return r.x + "," + r.y + "," + r.w + "," + r.h;
}

// existing: [{ key: string, present: bool }] — blobs currently in the model.
// rects: [{ x, y, w, h }] — icons that exist now.
// Returns { add: [rect], revive: [key], retire: [key] }.
function diff(existing, rects) {
    var want = {};
    for (var i = 0; i < rects.length; ++i) {
        want[keyOf(rects[i])] = rects[i];
    }
    var have = {};
    var add = [], revive = [], retire = [];
    for (var j = 0; j < existing.length; ++j) {
        var e = existing[j];
        have[e.key] = true;
        var wanted = want.hasOwnProperty(e.key);
        if (e.present && !wanted) {
            retire.push(e.key);
        } else if (!e.present && wanted) {
            revive.push(e.key);
        }
    }
    for (var k in want) {
        if (!have[k]) {
            add.push(want[k]);
        }
    }
    return { add: add, revive: revive, retire: retire };
}
