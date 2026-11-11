// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../../engine"
import "meadow.js" as Meadow
import "../../code/paths.js" as Paths
import "../../code/world.js" as World

// Meadow: icons rest on clouds that float over wind-swept grass.
// The clouds are drawn from the influence field, so they swell, merge, follow and shrink with it;
// the theme needs no handler for the core events.
ThemeBase {
    id: theme

    readonly property var pal: Meadow.palettes[theme.settings.palette ?? 0]
    readonly property bool showButterflies: theme.settings.butterflies ?? true
    accentColor: pal.accent

    ShaderEffect {
        anchors.fill: parent
        blending: false
        property var mask: theme.env.field
        property var noiseTex: theme.env.noise
        property real time: theme.env.time
        property real sigma: theme.env.influenceRadius
        property real puff: 44 + 1.6 * (theme.settings.fluff ?? 20)
        property real shadow: (theme.settings.shadows ?? true) ? 1 : 0
        property real altitude: theme.settings.altitude ?? 140
        property real cover: theme.settings.drift ?? 2
        property vector2d resolution: Qt.vector2d(width, height)
        property color tint: (theme.settings.timeOfDay ?? false) ? theme.env.dayTint : "white"
        property color cGrassDark: theme.pal.grassDark
        property color cGrassMid: theme.pal.grassMid
        property color cGrassLight: theme.pal.grassLight
        property color cHaze: theme.pal.haze
        property color cShadow: theme.pal.shadow
        property color cCloudLight: theme.pal.cloudLight
        property color cCloudCore: theme.pal.cloudCore
        property color cCloudShade: theme.pal.cloudShade
        fragmentShader: Qt.resolvedUrl("meadow.frag.qsb")
        // Cached while the butterflies fly: frames between engine ticks then cost a texture copy.
        layer.enabled: clock.running
    }

    // Runs only while the butterflies are in view (the first half of each cycle, plus a margin).
    FrameClock {
        id: clock
        env: theme.env
        readonly property real coarse: ((theme.env.time * 60 / 3769.911184) % 1) / 0.5
        active: theme.showButterflies && (clock.coarse <= 1.05 || clock.coarse >= 1.95)
    }

    // One to three butterflies follow one curved route every 63 s (60 per time wrap), in view for the first half of each cycle.
    // How many fly together is picked anew for each cycle.
    Item {
        id: swarm
        readonly property real cycle: clock.time * 60 / 3769.911184
        readonly property real p: (cycle % 1) / 0.5
        readonly property var route: Paths.route(41, Math.floor(cycle), theme.width, theme.height, 60)
        readonly property int count: 1 + Math.min(2, Math.floor(3 * World.hash01(Math.floor(cycle) + 0.71, 43)))
        z: 4
        visible: theme.showButterflies && p <= 1

        Repeater {
            model: [{ lag: 0, side: 0 }, { lag: 0.03, side: 30 }, { lag: 0.045, side: -24 }]
            delegate: ShadowSprite {
                id: fly
                required property var modelData
                required property int index
                visible: index < swarm.count
                readonly property var pos: Paths.at(swarm.route, swarm.p - modelData.lag)
                // Butterflies flutter: they wander around their place on the route.
                x: pos.x - modelData.side * Math.sin(pos.angle * Math.PI / 180) + 8 * Math.sin(clock.time * 2.3 + index * 1.7)
                y: pos.y + modelData.side * Math.cos(pos.angle * Math.PI / 180) + 12 * Math.sin(clock.time * 3.1 + index * 2.9)
                heading: pos.angle + 90 + 14 * Math.sin(clock.time * 2.3 + index * 1.7)     // the picture faces up
                source: Qt.resolvedUrl("butterfly.svg")
                shadowSource: Qt.resolvedUrl("butterfly-shadow.svg")
                spriteWidth: 22
                spriteHeight: 22
                sourceSize: Qt.size(44, 44)
                altitude: 8
                shadowOpacity: 0.22
                // Wings beat: the picture is squeezed across the body.
                beatX: 0.3 + 0.7 * Math.abs(Math.sin(clock.time * 11 + index * 2))
            }
        }
    }
}
