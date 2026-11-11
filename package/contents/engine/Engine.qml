// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../code/world.js" as World
import "../code/themes.js" as Themes

// The environment engine: sources in, world state + core events + influence field out,
// drawn by the loaded theme. Imports only QtQuick so it also runs outside Plasma.
Item {
    id: engine

    // Host inputs.
    property var input: []                // [{ id?, kind?, x, y, w, h }] in this item's coordinates
    property bool dragging: false         // an icon drag is in progress
    property bool running: true
    property int fps: 30
    property real renderScale: 1.0        // 0.5..1.0
    property real influenceRadius: 70     // px
    property int appearDelay: 2000        // ms
    property int disappearDelay: 3000     // ms
    property int morphDuration: 1800      // ms
    property bool animateChanges: true    // false: changes apply instantly and emit no events
    property string theme: "beach"
    property string themeSettingsJson: "{}"
    property real hourOverride: -1        // >= 0 replaces the wall clock (tests)
    property bool debug: false

    // State for themes.
    property real time: 0
    property var sources: []
    property var clusters: []
    property var spots: []
    property var worldState: ({})
    property real clockHour: 12
    readonly property real hour: hourOverride >= 0 ? hourOverride : clockHour
    readonly property color dayTint: {
        const t = World.dayTint(hour);
        return Qt.rgba(t.r, t.g, t.b, 1);
    }
    readonly property Item field: fieldTexture
    readonly property Item noise: noiseAtlas.texture
    readonly property int frameCount: ticker.frames
    readonly property string themeId: Themes.find(theme).id
    readonly property var themeSettings: Themes.resolve(themeId, themeSettingsJson)
    readonly property ThemeBase themeItem: themeLoader.item as ThemeBase
    readonly property color accentColor: themeItem ? themeItem.accentColor : "transparent"

    onInputChanged: update()
    onDraggingChanged: update()
    onInfluenceRadiusChanged: update()
    onThemeIdChanged: loadTheme(themeId)
    Component.onCompleted: {
        update();
        loadTheme(themeId);
    }

    function update() {
        const r = World.step(engine.worldState, World.normalize(engine.input || []), engine.dragging);
        const all = World.listOf(r.state);
        const present = all.filter(s => !s.lifted);
        const next = World.clusters(present, 2.3 * engine.influenceRadius);
        const formed = World.grouped(engine.clusters, next);
        engine.worldState = r.state;
        engine.sources = all;
        engine.clusters = next;
        engine.spots = World.decorSpots(present, next, 1.2 * engine.influenceRadius);
        const t = engine.themeItem;
        if (!t || !engine.animateChanges) {
            return;
        }
        for (const s of r.added) {
            t.iconAdded(s);
        }
        for (const s of r.removed) {
            t.iconRemoved(s);
        }
        if (r.moved.length > 0) {
            t.iconsMoved(r.moved);
        }
        for (const c of formed) {
            t.iconsGrouped(c);
        }
        if (engine.debug && r.added.length + r.removed.length + r.moved.length + formed.length > 0) {
            console.info("scapelet: events added=" + r.added.length + " removed=" + r.removed.length
                         + " moved=" + r.moved.length + " grouped=" + formed.length);
        }
    }

    // Saves this item as a PNG with blocks in place of the icons. done(ok) runs when the file is written.
    // Only the engine's own items are grabbed, so real icons and their names can never be in the picture.
    function exportImage(path, done) {
        blocks.visible = true;
        const started = engine.grabToImage(result => {
            blocks.visible = false;
            done(result.saveToFile(path));
        });
        if (!started) {
            blocks.visible = false;
            done(false);
        }
    }

    function loadTheme(id) {
        themeLoader.setSource(Qt.resolvedUrl("../themes/" + id + "/Main.qml"), { env: engine, settings: engine.themeSettings });
    }

    Timer {
        id: ticker
        property int frames: 0
        property real last: 0
        interval: Math.max(16, Math.round(1000 / Math.max(1, engine.fps)))
        repeat: true
        running: engine.running && engine.visible
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            // 3769.911184 = 2*pi*600: sin() terms with a rate that is a multiple of 1/600 are continuous across the wrap.
            engine.time = (engine.time + Math.min(0.25, (now - last) / 1000)) % 3769.911184;
            last = now;
            frames += 1;
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            const d = new Date();
            engine.clockHour = d.getHours() + d.getMinutes() / 60;
        }
    }

    NoiseAtlas { id: noiseAtlas }

    Roster {
        id: land
        anchors.fill: parent
        items: engine.sources
        delegate: FieldBlob {
            sigma: engine.influenceRadius
            animate: engine.animateChanges
            appearDelay: engine.appearDelay
            disappearDelay: engine.disappearDelay
            morphDuration: engine.morphDuration
            onExpired: key => Qt.callLater(land.expire, key)
        }
    }

    ShaderEffectSource {
        id: fieldTexture
        sourceItem: land
        hideSource: true
        visible: false
        live: true
        smooth: true
        textureSize: Qt.size(Math.max(1, Math.ceil(engine.width * 0.25)), Math.max(1, Math.ceil(engine.height * 0.25)))
    }

    Loader {
        id: themeLoader
        anchors.fill: parent
        layer.enabled: engine.renderScale < 0.999
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * engine.renderScale)), Math.max(1, Math.ceil(height * engine.renderScale)))
        onLoaded: item.settings = Qt.binding(() => engine.themeSettings)
        onStatusChanged: {
            if (status === Loader.Error) {
                console.warn("scapelet: theme '" + engine.themeId + "' failed to load");
                if (engine.themeId !== Themes.list[0].id) {
                    engine.loadTheme(Themes.list[0].id);
                }
            }
        }
    }

    // Stand-ins for the real icons in an exported picture: positions only, no names or artwork.
    Item {
        id: blocks
        anchors.fill: parent
        visible: false
        Repeater {
            model: engine.sources
            delegate: Rectangle {
                required property var modelData
                readonly property bool widget: modelData.kind === "widget"
                x: widget ? modelData.x : modelData.x + modelData.w / 2 - 24
                y: widget ? modelData.y : modelData.y + 14
                width: widget ? modelData.w : 48
                height: widget ? modelData.h : 48
                radius: 10
                color: widget ? "#552f7de1" : "#cc2f7de1"
                border.color: "white"
                border.width: 1
            }
        }
    }
}
