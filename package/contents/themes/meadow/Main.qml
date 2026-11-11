// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../../engine"
import "meadow.js" as Meadow
import "../../code/world.js" as World

// Meadow: icons rest on clouds that float over wind-swept grass.
// added -> cloud gathers, grouped -> clouds merge, removed -> cloud dissolves, moved -> cloud follows.
ThemeBase {
    id: theme

    readonly property var pal: Meadow.palettes[theme.settings.palette ?? 0]
    readonly property bool showButterflies: theme.settings.butterflies ?? true
    readonly property real reach: 3.2 * theme.env.influenceRadius
    accentColor: pal.accent

    ShaderEffect {
        anchors.fill: parent
        blending: false
        property var mask: theme.env.field
        property var noiseTex: theme.env.noise
        property real time: theme.env.time
        property real sigma: theme.env.influenceRadius
        property real fluff: theme.settings.fluff ?? 20
        property real shadow: (theme.settings.shadows ?? true) ? 1 : 0
        property vector2d resolution: Qt.vector2d(width, height)
        property color tint: (theme.settings.timeOfDay ?? false) ? theme.env.dayTint : "white"
        property color cGrassDark: theme.pal.grassDark
        property color cGrassMid: theme.pal.grassMid
        property color cGrassLight: theme.pal.grassLight
        property color cHaze: theme.pal.haze
        property color cCloudLight: theme.pal.cloudLight
        property color cCloudCore: theme.pal.cloudCore
        property color cCloudShade: theme.pal.cloudShade
        fragmentShader: Qt.resolvedUrl("meadow.frag.qsb")
        // Cached while the butterflies fly: frames between engine ticks then cost a texture copy.
        layer.enabled: clock.running
    }

    // Transitions: small puffs of cloud drift outward where a cloud is about to change.
    Component {
        id: puff
        Rectangle {
            id: p
            property real cx
            property real cy
            property real dx
            property real dy
            property int delay
            width: 30
            height: 30
            radius: 15
            x: cx - 15
            y: cy - 15
            color: theme.pal.cloudLight
            opacity: 0
            scale: 0.4
            SequentialAnimation {
                running: true
                PauseAnimation { duration: p.delay }
                ParallelAnimation {
                    NumberAnimation { target: p; property: "x"; to: p.cx + p.dx - 15; duration: 1800; easing.type: Easing.OutCubic }
                    NumberAnimation { target: p; property: "y"; to: p.cy + p.dy - 15; duration: 1800; easing.type: Easing.OutCubic }
                    NumberAnimation { target: p; property: "scale"; to: 1.3; duration: 1800; easing.type: Easing.OutCubic }
                    SequentialAnimation {
                        NumberAnimation { target: p; property: "opacity"; to: 0.85; duration: 250 }
                        NumberAnimation { target: p; property: "opacity"; to: 0; duration: 1550 }
                    }
                }
                ScriptAction { script: p.destroy() }
            }
        }
    }

    // Six puffs leave a circle of the given diameter.
    function burst(cx, cy, size, delay) {
        if (!theme.env.running) {
            return;   // nobody is watching
        }
        for (let i = 0; i < 6; ++i) {
            const a = 2 * Math.PI * (i + World.hash01(cx + i, cy)) / 6;
            puff.createObject(theme, { cx: cx + 0.3 * size * Math.cos(a), cy: cy + 0.3 * size * Math.sin(a),
                                       dx: 0.2 * size * Math.cos(a), dy: 0.2 * size * Math.sin(a),
                                       delay: delay + 60 * i, z: 1 });
        }
    }

    onIconAdded: source => burst(source.x + source.w / 2, source.y + source.h / 2, reach,
                                 theme.env.appearDelay + 0.5 * theme.env.morphDuration)
    onIconRemoved: source => burst(source.x + source.w / 2, source.y + source.h / 2, 0.75 * reach,
                                   theme.env.disappearDelay + 0.8 * theme.env.morphDuration)
    onIconsMoved: moves => {
        for (const m of moves) {
            burst(m.to.x + m.to.w / 2, m.to.y + m.to.h / 2, reach, theme.env.appearDelay + 0.5 * theme.env.morphDuration);
        }
    }
    onIconsGrouped: cluster => burst(cluster.cx, cluster.cy, Math.max(cluster.w, cluster.h) + reach,
                                     theme.env.appearDelay + theme.env.morphDuration)

    // Runs only while the butterflies are in view (the first half of each cycle, plus a margin).
    FrameClock {
        id: clock
        env: theme.env
        readonly property real coarse: ((theme.env.time * 60 / 3769.911184) % 1) / 0.5
        active: theme.showButterflies && (clock.coarse <= 1.05 || clock.coarse >= 1.95)
    }

    // Three butterflies cross every 63 s (60 per time wrap), in view for the first half of each cycle.
    Item {
        id: swarm
        readonly property real cycle: clock.time * 60 / 3769.911184
        readonly property real p: (cycle % 1) / 0.5
        z: 4
        visible: theme.showButterflies && p <= 1
        x: -60 + (theme.width + 120) * p
        y: theme.height * (0.2 + 0.6 * World.hash01(Math.floor(cycle), 11)) + 30 * Math.sin(clock.time * 0.6)

        Repeater {
            model: [{ dx: 0, dy: 0 }, { dx: -44, dy: 30 }, { dx: -70, dy: -24 }]
            delegate: Image {
                id: fly
                required property var modelData
                required property int index
                x: modelData.dx + 8 * Math.sin(clock.time * 2.3 + index * 1.7)
                y: modelData.dy + 12 * Math.sin(clock.time * 3.1 + index * 2.9)
                width: 22
                height: 22
                source: Qt.resolvedUrl("butterfly.svg")
                sourceSize: Qt.size(44, 44)
                rotation: 90 + 14 * Math.sin(clock.time * 2.3 + index * 1.7)
                // Wings beat: the picture is squeezed across the body.
                transform: Scale { origin.x: 11; xScale: 0.3 + 0.7 * Math.abs(Math.sin(clock.time * 11 + fly.index * 2)) }
            }
        }
    }
}
