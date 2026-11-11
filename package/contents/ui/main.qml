// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtCore
import QtQuick
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "../engine"

WallpaperItem {
    id: root
    accentColor: engine.accentColor
    contextualActions: [exportAction]

    PlasmaCore.Action {
        id: exportAction
        text: "Save Picture Without Icon Names"
        icon.name: "document-save-as"
        onTriggered: root.exportPicture()
    }

    function exportPicture() {
        const dir = StandardPaths.writableLocation(StandardPaths.PicturesLocation).toString().replace(/^file:\/\//, "");
        const path = dir + "/scapelet-" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss") + ".png";
        engine.exportImage(path, ok => {
            if (ok) {
                root.openUrlRequested("file://" + path);   // opens the picture in the default viewer
            } else {
                console.warn("scapelet: could not save " + path);
            }
        });
    }

    IconProbe {
        id: probe
        host: root
        debug: root.configuration.DebugLog
    }

    WidgetProbe {
        id: widgetProbe
        host: root
        active: root.configuration.IncludeWidgets
        debug: root.configuration.DebugLog
    }

    // Icons present when the desktop loads get their areas instantly;
    // changes after this timer animate with the configured delays.
    Timer {
        id: settle
        interval: 2000
        onTriggered: engine.animateChanges = true
    }

    Connections {
        target: probe
        function onAvailableChanged() {
            if (probe.available && !engine.animateChanges) {
                settle.start();
            }
        }
    }

    // True on a desktop containment; false in the lock screen greeter.
    readonly property bool onDesktop: root.parent !== null && root.parent.appletsLayout !== undefined // qmllint disable missing-property

    // Loaded through a Loader so a missing org.kde.taskmanager module only disables pausing.
    Loader {
        id: pauseLoader
        active: root.configuration.PauseMode > 0 && root.onDesktop
        source: "PauseMonitor.qml"
        onLoaded: {
            item.screenGeometry = Qt.binding(() => Qt.rect(root.Screen.virtualX, root.Screen.virtualY, root.Screen.width, root.Screen.height));
            item.mode = Qt.binding(() => root.configuration.PauseMode);
        }
    }

    // Loaded through a Loader so a missing org.kde.plasma.workspace.dbus module only disables these features.
    Loader {
        id: powerLoader
        source: "PowerMonitor.qml"
        onLoaded: item.debug = Qt.binding(() => root.configuration.DebugLog)
    }

    readonly property bool locked: root.onDesktop && powerLoader.status === Loader.Ready && powerLoader.item.locked // qmllint disable missing-property
    readonly property bool saver: root.configuration.BatterySaver && powerLoader.status === Loader.Ready
                                  && (powerLoader.item.onBattery || powerLoader.item.profile === "power-saver") // qmllint disable missing-property
    onSaverChanged: {
        if (root.configuration.DebugLog) {
            console.info("scapelet: saver=" + saver);
        }
    }

    readonly property bool covered: pauseLoader.status === Loader.Ready && pauseLoader.item.covered // qmllint disable missing-property
    onCoveredChanged: {
        if (root.configuration.DebugLog) {
            console.info("scapelet: covered=" + covered);
        }
    }

    Engine {
        id: engine
        anchors.fill: parent
        input: probe.sources.concat(widgetProbe.sources)
        dragging: probe.dragging
        animateChanges: false
        running: root.configuration.Animate && !root.covered && !root.locked
        fps: root.saver ? Math.min(15, root.configuration.Fps) : root.configuration.Fps
        renderScale: (root.saver ? Math.min(75, root.configuration.RenderScale) : root.configuration.RenderScale) / 100
        influenceRadius: root.configuration.InfluenceRadius
        appearDelay: root.configuration.AppearDelay
        disappearDelay: root.configuration.DisappearDelay
        morphDuration: root.configuration.MorphDuration
        theme: root.configuration.Theme ?? "beach"
        themeSettingsJson: root.configuration.ThemeSettings ?? "{}"
        debug: root.configuration.DebugLog
    }
}
