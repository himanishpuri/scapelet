// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// Reports left clicks on empty desktop. A wallpaper gets no mouse events of its own: the Folder
// View above it takes them all. So this listens to the Folder View's own mouse listener. Relies on
// Plasma-internal names (read from Plasma 6.8.2, FolderView.qml):
//   FolderView.children[i] with a `pressX` property  -> its MouseEventListener, covers the whole view
//   that listener's clicked(mouse) signal            -> mouse.x, mouse.y, mouse.button
//   FolderView.hoveredItem                           -> the icon under the pointer; null or .blank on empty desktop
// When a link is missing nothing is reported. Nothing runs between clicks.
Item {
    id: probe
    visible: false

    property Item host: null             // the wallpaper; clicks are reported in its coordinates
    property var folderView: null        // IconProbe.folderView
    property bool active: true
    property bool debug: false

    signal tapped(real x, real y)

    readonly property var listener: {
        const kids = probe.folderView ? probe.folderView.children : null;
        if (kids) {
            for (let i = 0; i < kids.length; ++i) {
                if (kids[i] && kids[i].pressX !== undefined) {
                    return kids[i];
                }
            }
        }
        return null;
    }
    onListenerChanged: {
        if (debug) {
            console.info("scapelet: clicks " + (listener ? "available" : "unavailable"));
        }
    }

    Connections {
        target: probe.active ? probe.listener : null
        ignoreUnknownSignals: true
        function onClicked(mouse) {
            if (!probe.host || mouse.button !== Qt.LeftButton) {
                return;
            }
            const over = probe.folderView.hoveredItem;
            if (over && over.blank === false) {
                return;   // a click on an icon is the desktop's business
            }
            const p = probe.listener.mapToItem(probe.host, mouse.x, mouse.y);
            probe.tapped(p.x, p.y);
        }
    }
}
