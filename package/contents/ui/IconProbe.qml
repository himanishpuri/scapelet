// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// Reads desktop icon rectangles from the Folder View containment that hosts
// this wallpaper. Relies on Plasma-internal names (verified on Plasma 6.8.2):
//   WallpaperItem.parent                 -> ContainmentItem (desktop containment root)
//   .folderViewLayer                     -> Loader (FolderViewLayerLoader)
//   .view                                -> FolderView
//   .view                                -> GridView
//   .contentItem.children[i].blank       -> false for real icons
// Every link is optional; when one is missing, `available` is false and `rects` is empty.
Item {
    id: probe
    visible: false

    property Item host: null
    property bool debug: false
    property var rects: []
    property bool available: false
    property string signature: "?"

    readonly property var folderLayer: (host && host.parent) ? (host.parent.folderViewLayer ?? null) : null
    readonly property var folderView: folderLayer ? (folderLayer.view ?? null) : null
    readonly property var grid: folderView ? (folderView.view ?? null) : null
    readonly property var gridModel: grid ? (grid.model ?? null) : null
    readonly property var gridContent: grid ? (grid.contentItem ?? null) : null

    onGridChanged: kick()
    onGridModelChanged: kick()
    Component.onCompleted: kick()

    function kick() {
        debounce.restart();
    }

    function publish(list, ok) {
        const sig = ok + ":" + JSON.stringify(list);
        if (sig === signature) {
            return;
        }
        signature = sig;
        available = ok;
        rects = list;
        if (debug) {
            console.info("archipelago: icons=" + list.length + " available=" + ok);
        }
    }

    function scan() {
        const content = probe.gridContent;
        if (!content || !probe.host) {
            publish([], false);
            return;
        }
        const kids = content.children;
        const out = [];
        for (let i = 0; i < kids.length; ++i) {
            const c = kids[i];
            if (!c || c.blank !== false || !c.visible || c.width <= 0 || c.height <= 0) {
                continue;
            }
            const r = c.mapToItem(probe.host, 0, 0, c.width, c.height);
            out.push({ x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) });
        }
        out.sort((a, b) => a.x - b.x || a.y - b.y);
        publish(out, true);
    }

    Timer { id: debounce; interval: 60; onTriggered: probe.scan() }

    // Safety net for changes that emit none of the signals below.
    Timer { interval: 1000; repeat: true; running: true; onTriggered: probe.scan() }

    Connections {
        target: probe.gridModel
        ignoreUnknownSignals: true
        function onDataChanged() { probe.kick() }
        function onRowsInserted() { probe.kick() }
        function onRowsRemoved() { probe.kick() }
        function onRowsMoved() { probe.kick() }
        function onModelReset() { probe.kick() }
        function onLayoutChanged() { probe.kick() }
    }

    Connections {
        target: probe.grid
        ignoreUnknownSignals: true
        function onCellWidthChanged() { probe.kick() }
        function onCellHeightChanged() { probe.kick() }
        function onContentXChanged() { probe.kick() }
        function onContentYChanged() { probe.kick() }
        function onWidthChanged() { probe.kick() }
        function onHeightChanged() { probe.kick() }
        function onCountChanged() { probe.kick() }
    }

    Connections {
        target: probe.gridContent
        ignoreUnknownSignals: true
        function onChildrenChanged() { probe.kick() }
    }

    Connections {
        target: probe.host
        ignoreUnknownSignals: true
        function onWidthChanged() { probe.kick() }
        function onHeightChanged() { probe.kick() }
    }
}
