// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// The whole renderer. Imports only QtQuick so it also runs outside Plasma.
Item {
    id: scene

    property var iconRects: []          // [{ x, y, w, h }] in this item's coordinates
    property bool running: true         // water animation on/off
    property int fps: 30
    property real shoreDistance: 70     // px
    property real coastWarp: 30         // px
    property int appearDelay: 2000      // ms
    property int disappearDelay: 3000   // ms
    property int morphDuration: 1800    // ms
    property bool animateChanges: true  // false: icon changes apply instantly
    property real renderScale: 1.0      // 0.5..1.0
    property real time: 0
    readonly property int frameCount: ticker.frames

    Timer {
        id: ticker
        property int frames: 0
        property real last: 0
        interval: Math.max(16, Math.round(1000 / Math.max(1, scene.fps)))
        repeat: true
        running: scene.running && scene.visible
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            // 3769.911184 = 2*pi*600: every sin() term in ocean.frag is continuous across the wrap.
            scene.time = (scene.time + Math.min(0.25, (now - last) / 1000)) % 3769.911184;
            last = now;
            frames += 1;
        }
    }

    LandMask {
        id: land
        anchors.fill: parent
        rects: scene.iconRects
        sigma: scene.shoreDistance
        appearDelay: scene.appearDelay
        disappearDelay: scene.disappearDelay
        morphDuration: scene.morphDuration
        animateChanges: scene.animateChanges
    }

    ShaderEffectSource {
        id: maskTexture
        sourceItem: land
        hideSource: true
        visible: false
        live: true
        smooth: true
        textureSize: Qt.size(Math.max(1, Math.ceil(scene.width * 0.25)), Math.max(1, Math.ceil(scene.height * 0.25)))
    }

    ShaderEffect {
        id: ocean
        anchors.fill: parent
        blending: false
        property var mask: maskTexture
        property real time: scene.time
        property real sigma: scene.shoreDistance
        property real warp: scene.coastWarp
        property vector2d resolution: Qt.vector2d(width, height)
        fragmentShader: Qt.resolvedUrl("../shaders/ocean.frag.qsb")
        layer.enabled: scene.renderScale < 0.999
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * scene.renderScale)), Math.max(1, Math.ceil(height * scene.renderScale)))
    }
}
