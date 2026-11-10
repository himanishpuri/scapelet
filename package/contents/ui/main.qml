// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    IconProbe {
        id: probe
        host: root
        debug: root.configuration.DebugLog
    }

    // Icons present when the desktop loads get their islands instantly;
    // changes after this timer animate with the configured delays.
    Timer {
        id: settle
        interval: 2000
        onTriggered: scene.animateChanges = true
    }

    Connections {
        target: probe
        function onAvailableChanged() {
            if (probe.available && !scene.animateChanges) {
                settle.start();
            }
        }
    }

    // Loaded through a Loader so a missing org.kde.taskmanager module only disables pausing.
    Loader {
        id: pauseLoader
        active: root.configuration.PauseWhenCovered
        source: "PauseMonitor.qml"
        onLoaded: item.screenGeometry = Qt.binding(() => Qt.rect(root.Screen.virtualX, root.Screen.virtualY, root.Screen.width, root.Screen.height))
    }

    readonly property bool covered: pauseLoader.status === Loader.Ready && pauseLoader.item.covered
    onCoveredChanged: {
        if (root.configuration.DebugLog) {
            console.info("archipelago: covered=" + covered);
        }
    }

    Scene {
        id: scene
        anchors.fill: parent
        iconRects: probe.rects
        animateChanges: false
        running: root.configuration.AnimateWater && !root.covered
        fps: root.configuration.Fps
        shoreDistance: root.configuration.ShoreDistance
        coastWarp: root.configuration.CoastWarp
        appearDelay: root.configuration.AppearDelay
        disappearDelay: root.configuration.DisappearDelay
        morphDuration: root.configuration.MorphDuration
        renderScale: root.configuration.RenderScale / 100
    }
}
