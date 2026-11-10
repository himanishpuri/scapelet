// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import "../code/world.js" as World

// Reads desktop widget rectangles from the containment that hosts this wallpaper:
//   WallpaperItem.parent.appletsLayout.children -> AppletContainer (has `applet`)
// Every link is optional; when one is missing `sources` stays empty.
Item {
    id: probe
    visible: false

    property Item host: null
    property bool active: true
    property bool debug: false
    property var sources: []
    property string pending: ""
    property string signature: "[]"

    readonly property var layout: (host && host.parent) ? (host.parent.appletsLayout ?? null) : null

    function scan() {
        const out = [];
        const kids = (probe.active && probe.layout && probe.host) ? probe.layout.children : [];
        for (let i = 0; i < kids.length; ++i) {
            const c = kids[i];
            if (!c || !c.applet || !c.visible || c.width <= 0 || c.height <= 0) {
                continue;
            }
            const r = c.mapToItem(probe.host, 0, 0, c.width, c.height);
            const rect = { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
            const applet = c.applet.plasmoid ?? null;
            out.push({ id: "widget:" + (applet && applet.id !== undefined ? applet.id : World.keyOf(rect)), kind: "widget",
                       x: rect.x, y: rect.y, w: rect.w, h: rect.h });
        }
        out.sort((a, b) => a.x - b.x || a.y - b.y);
        const sig = JSON.stringify(out);
        // Publish only when two scans in a row agree, so a widget being dragged or resized leaves no trail.
        if (sig === pending && sig !== signature) {
            signature = sig;
            sources = out;
            if (debug) {
                console.info("scapelet: widgets=" + out.length);
            }
        }
        pending = sig;
    }

    Timer { interval: 500; repeat: true; running: true; onTriggered: probe.scan() }
}
