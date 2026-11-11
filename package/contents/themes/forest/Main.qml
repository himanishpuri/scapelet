// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../../engine"
import "forest.js" as Forest
import "../../code/paths.js" as Paths

// Forest: trees cover the desktop and step back around the icons.
// The trees are drawn from the influence field: a clearing opens where the field rises and
// closes where it falls, so the theme needs no handler for the core events.
ThemeBase {
    id: theme

    readonly property var pal: Forest.palettes[theme.settings.palette ?? 0]
    readonly property bool swaying: theme.settings.sway ?? true
    readonly property bool showSparrows: theme.settings.sparrows ?? true
    accentColor: pal.accent

    ShaderEffect {
        anchors.fill: parent
        blending: false
        property var mask: theme.env.field
        property var noiseTex: theme.env.noise
        property real time: theme.swaying ? theme.env.time : 0
        // Density 1..10 fills more of the grid; 11..15 packs the grid closer (trees keep their size).
        readonly property real density: theme.settings.density ?? 12
        property real size: 52
        property real cell: density > 10 ? size * (1 - 0.06 * (density - 10)) : size
        property real keep: Math.min(1, 0.28 + 0.072 * density)
        property real sway: theme.swaying ? 7 : 0
        property vector2d resolution: Qt.vector2d(width, height)
        property color tint: (theme.settings.timeOfDay ?? false) ? theme.env.dayTint : "white"
        property color cGrassLight: theme.pal.grassLight
        property color cGrassMid: theme.pal.grassMid
        property color cGrassDeep: theme.pal.grassDeep
        property color cInk: theme.pal.ink
        property color cShadow: theme.pal.shadow
        property color cTrunk: theme.pal.trunk
        property color cLeaf0: theme.pal.leaf0
        property color cLeaf1: theme.pal.leaf1
        property color cLeaf2: theme.pal.leaf2
        property color cLeaf3: theme.pal.leaf3
        property color cLeaf4: theme.pal.leaf4
        property color cLeaf5: theme.pal.leaf5
        fragmentShader: Qt.resolvedUrl("forest.frag.qsb")
        // Cached while the trees stand still or the sparrows fly: frames between changes then cost a texture copy.
        layer.enabled: !theme.swaying || clock.running
    }

    // Runs only while the sparrows are in view (the first 30 % of each cycle, plus a margin).
    FrameClock {
        id: clock
        env: theme.env
        readonly property real coarse: ((theme.env.time * 90 / 3769.911184) % 1) / 0.3
        active: theme.showSparrows && (clock.coarse <= 1.05 || clock.coarse >= 3.28)
    }

    // Five sparrows follow one curved route every 42 s (90 per time wrap), in view for the first 30 % of each cycle.
    Item {
        id: flight
        readonly property real cycle: clock.time * 90 / 3769.911184
        readonly property real p: (cycle % 1) / 0.3
        readonly property var route: Paths.route(53, Math.floor(cycle), theme.width, theme.height, 80)
        z: 4
        visible: theme.showSparrows && p <= 1

        Repeater {
            model: [{ lag: 0, side: 0 }, { lag: 0.012, side: 18 }, { lag: 0.016, side: -16 }, { lag: 0.03, side: 6 }, { lag: 0.036, side: -30 }]
            delegate: ShadowSprite {
                id: sparrow
                required property var modelData
                required property int index
                readonly property var pos: Paths.at(flight.route, flight.p - modelData.lag)
                // Sparrows fly in bounds: a burst of wing beats, then a short glide with the wings folded.
                readonly property real beat: Math.max(0, Math.min(1, 0.5 + 2 * Math.sin(clock.time * 5 + index * 1.3)))
                readonly property real bound: 5 * Math.sin(clock.time * 5 + index * 1.3)
                x: pos.x - (modelData.side + bound) * Math.sin(pos.angle * Math.PI / 180)
                y: pos.y + (modelData.side + bound) * Math.cos(pos.angle * Math.PI / 180)
                heading: pos.angle
                source: Qt.resolvedUrl("sparrow.svg")
                shadowSource: Qt.resolvedUrl("sparrow-shadow.svg")
                spriteWidth: 20
                spriteHeight: 16
                sourceSize: Qt.size(40, 32)
                altitude: 40
                shadowOpacity: 0.22
                beatY: 1 - 0.3 * beat * (1 - Math.sin(clock.time * 24 + index * 2)) - 0.45 * (1 - beat)
            }
        }
    }
}
