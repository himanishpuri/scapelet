// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../../engine"
import "city.js" as City
import "../../code/paths.js" as Paths

// City: a crowded old town of the industrial age; the houses fold away to open a square around the icons.
// The houses are drawn from the influence field: a square opens where the field rises and closes
// where it falls, so the theme needs no handler for the core events.
ThemeBase {
    id: theme

    readonly property var pal: City.palettes[theme.settings.palette ?? 0]
    readonly property bool smoking: theme.settings.smoke ?? true
    readonly property bool showPigeons: theme.settings.pigeons ?? true
    accentColor: pal.accent

    ShaderEffect {
        anchors.fill: parent
        blending: false
        property var mask: theme.env.field
        property var noiseTex: theme.env.noise
        property real time: theme.env.time
        property real cell: 48
        property real keep: 0.46 + 0.06 * (theme.settings.density ?? 8)
        property real lit: theme.pal.lit
        property real smoke: theme.smoking ? 1 : 0
        property real windmills: (theme.settings.windmills ?? true) ? 1 : 0
        property vector2d resolution: Qt.vector2d(width, height)
        property color tint: (theme.settings.timeOfDay ?? false) ? theme.env.dayTint : "white"
        property color cPaveLight: theme.pal.paveLight
        property color cPaveMid: theme.pal.paveMid
        property color cPaveDeep: theme.pal.paveDeep
        property color cGrassLight: theme.pal.grassLight
        property color cGrassMid: theme.pal.grassMid
        property color cInk: theme.pal.ink
        property color cShadow: theme.pal.shadow
        property color cWall0: theme.pal.wall0
        property color cWall1: theme.pal.wall1
        property color cWall2: theme.pal.wall2
        property color cWall3: theme.pal.wall3
        property color cWall4: theme.pal.wall4
        property color cRoof0: theme.pal.roof0
        property color cRoof1: theme.pal.roof1
        property color cRoof2: theme.pal.roof2
        property color cGlass: theme.pal.glass
        property color cLamp: theme.pal.lamp
        property color cDoor: theme.pal.door
        property color cLeaf: theme.pal.leaf
        property color cTrunk: theme.pal.trunk
        property color cSmoke: theme.pal.smoke
        fragmentShader: Qt.resolvedUrl("city.frag.qsb")
        // Cached while the pigeons fly: frames between engine ticks then cost a texture copy, not the shader.
        layer.enabled: clock.running
    }

    // Runs only while the pigeons are in view (the first 35 % of each cycle, plus a margin).
    FrameClock {
        id: clock
        env: theme.env
        readonly property real coarse: ((theme.env.time * 75 / 3769.911184) % 1) / 0.35
        active: theme.showPigeons && (clock.coarse <= 1.05 || clock.coarse >= 2.8)
    }

    // Seven pigeons follow one curved route every 50 s (75 per time wrap), in view for the first 35 % of each cycle.
    Item {
        id: flight
        readonly property real cycle: clock.time * 75 / 3769.911184
        readonly property real p: (cycle % 1) / 0.35
        readonly property var route: Paths.route(71, Math.floor(cycle), theme.width, theme.height, 80)
        z: 4
        visible: theme.showPigeons && p <= 1

        // 1 right after a click near the flock, back to 0 within three seconds: the birds scatter.
        property real scatter: 0
        SequentialAnimation {
            id: startle
            NumberAnimation { target: flight; property: "scatter"; to: 1; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { target: flight; property: "scatter"; to: 0; duration: 2600; easing.type: Easing.InOutQuad }
        }

        Repeater {
            model: [{ lag: 0, side: 0 }, { lag: 0.010, side: 20 }, { lag: 0.014, side: -18 }, { lag: 0.026, side: 8 },
                    { lag: 0.030, side: -34 }, { lag: 0.040, side: 30 }, { lag: 0.046, side: -10 }]
            delegate: ShadowSprite {
                id: pigeon
                required property var modelData
                required property int index
                readonly property var pos: Paths.at(flight.route, flight.p - modelData.lag)
                // Pigeons flap steadily and rock a little from side to side.
                readonly property real rock: 4 * Math.sin(clock.time * 2 + index * 1.7)
                // Scattered, a pigeon swings wide of its place (the leader too).
                readonly property real wide: (modelData.side + rock + (index === 0 ? 24 : 0) * flight.scatter) * (1 + 1.8 * flight.scatter)
                x: pos.x - wide * Math.sin(pos.angle * Math.PI / 180)
                y: pos.y + wide * Math.cos(pos.angle * Math.PI / 180)
                heading: pos.angle + 30 * flight.scatter * Math.sin(index * 2.4 + 1)
                source: Qt.resolvedUrl("pigeon.svg")
                shadowSource: Qt.resolvedUrl("pigeon-shadow.svg")
                spriteWidth: 22
                spriteHeight: 18
                sourceSize: Qt.size(44, 36)
                altitude: 46
                shadowOpacity: 0.20
                beatY: 1 - 0.45 * (0.5 + 0.5 * Math.sin(clock.time * 18 + index * 2))
            }
        }
    }

    Component {
        id: startled
        Burst { source: Qt.resolvedUrl("pigeon.svg"); count: 4; spriteWidth: 22; spriteHeight: 18; z: 4 }
    }

    // A click: pigeons near it scatter; anywhere else, pigeons take off from the street.
    onTapped: (x, y) => {
        const lead = Paths.at(flight.route, flight.p);
        if (flight.visible && Math.hypot(x - lead.x, y - lead.y) < 110) {
            startle.restart();
            return;
        }
        startled.createObject(theme, { cx: x, cy: y });
    }
}
