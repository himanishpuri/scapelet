// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../../engine"
import "cosmos.js" as Cosmos
import "../../code/world.js" as World

// Cosmos: icons are stars wrapped in nebulae.
// added -> star flares up, grouped -> constellation forms, removed -> star collapses, moved -> constellation shifts.
ThemeBase {
    id: theme

    readonly property var pal: Cosmos.palettes[theme.settings.palette ?? 0]
    readonly property bool showLines: theme.settings.lines ?? true
    readonly property bool showShooting: theme.settings.shooting ?? true
    readonly property real reach: 3.2 * theme.env.influenceRadius
    accentColor: pal.accent

    ShaderEffect {
        anchors.fill: parent
        blending: false
        property var mask: theme.env.field
        property var noiseTex: theme.env.noise
        property real time: theme.env.time
        property real density: theme.settings.density ?? 5
        property vector2d resolution: Qt.vector2d(width, height)
        property color cSpace: theme.pal.space
        property color cNebulaA: theme.pal.nebulaA
        property color cNebulaB: theme.pal.nebulaB
        property color cStar: theme.pal.star
        fragmentShader: Qt.resolvedUrl("cosmos.frag.qsb")
        // Cached while a shooting star flies: frames between engine ticks then cost a texture copy.
        layer.enabled: clock.running
    }

    // Constellations: the members of each group joined by the shortest set of lines.
    Repeater {
        model: theme.showLines ? Cosmos.links(theme.env.sources, theme.env.clusters) : []
        delegate: Item {
            id: link
            required property var modelData
            readonly property real len: Math.hypot(modelData.x2 - modelData.x1, modelData.y2 - modelData.y1)
            x: modelData.x1
            y: modelData.y1
            z: 1
            transformOrigin: Item.TopLeft
            rotation: Math.atan2(modelData.y2 - modelData.y1, modelData.x2 - modelData.x1) * 180 / Math.PI
            visible: len > 2 * Cosmos.GAP + 8
            Rectangle {
                x: Cosmos.GAP
                y: -0.75
                width: link.len - 2 * Cosmos.GAP
                height: 1.5
                color: theme.pal.line
                opacity: 0.5
                antialiasing: true
            }
            Rectangle { x: Cosmos.GAP - 2.5; y: -2.5; width: 5; height: 5; radius: 2.5; color: theme.pal.line; opacity: 0.9 }
            Rectangle { x: link.len - Cosmos.GAP - 2.5; y: -2.5; width: 5; height: 5; radius: 2.5; color: theme.pal.line; opacity: 0.9 }
        }
    }

    // Transitions: a four-point flare, and a ring that grows or collapses.
    Component {
        id: flare
        Item {
            id: f
            property real cx
            property real cy
            property real size
            property int delay
            x: cx
            y: cy
            opacity: 0
            scale: 0.2
            Rectangle { x: -f.size / 2; y: -1; width: f.size; height: 2; color: theme.pal.star }
            Rectangle { x: -1; y: -f.size / 2; width: 2; height: f.size; color: theme.pal.star }
            SequentialAnimation {
                running: true
                PauseAnimation { duration: f.delay }
                ParallelAnimation {
                    NumberAnimation { target: f; property: "scale"; to: 1; duration: 500; easing.type: Easing.OutCubic }
                    SequentialAnimation {
                        NumberAnimation { target: f; property: "opacity"; to: 0.9; duration: 150 }
                        NumberAnimation { target: f; property: "opacity"; to: 0; duration: 1100 }
                    }
                }
                ScriptAction { script: f.destroy() }
            }
        }
    }

    Component {
        id: ring
        Rectangle {
            id: r
            property real cx
            property real cy
            property real size
            property real fromScale
            property real toScale
            property int delay
            x: cx - size / 2
            y: cy - size / 2
            width: size
            height: size
            radius: size / 2
            color: "transparent"
            border.color: theme.pal.line
            border.width: 1.5
            opacity: 0
            scale: fromScale
            SequentialAnimation {
                running: true
                PauseAnimation { duration: r.delay }
                ParallelAnimation {
                    NumberAnimation { target: r; property: "scale"; to: r.toScale; duration: 1600; easing.type: Easing.OutCubic }
                    SequentialAnimation {
                        NumberAnimation { target: r; property: "opacity"; to: 0.7; duration: 200 }
                        NumberAnimation { target: r; property: "opacity"; to: 0; duration: 1400 }
                    }
                }
                ScriptAction { script: r.destroy() }
            }
        }
    }

    function spark(cx, cy, size, delay) {
        if (theme.env.running) {
            flare.createObject(theme, { cx: cx, cy: cy, size: size, delay: delay, z: 2 });
        }
    }

    function pulse(cx, cy, size, fromScale, toScale, delay) {
        if (theme.env.running) {
            ring.createObject(theme, { cx: cx, cy: cy, size: size, fromScale: fromScale, toScale: toScale, delay: delay, z: 2 });
        }
    }

    onIconAdded: source => spark(Cosmos.anchor(source).x, Cosmos.anchor(source).y, 0.6 * reach,
                                 theme.env.appearDelay + 0.5 * theme.env.morphDuration)
    onIconRemoved: source => pulse(Cosmos.anchor(source).x, Cosmos.anchor(source).y, 0.75 * reach, 1, 0.2,
                                   theme.env.disappearDelay + 0.8 * theme.env.morphDuration)
    onIconsMoved: moves => {
        for (const m of moves) {
            spark(m.to.x + m.to.w / 2, m.to.y + 38, 0.6 * reach, theme.env.appearDelay + 0.5 * theme.env.morphDuration);
        }
    }
    onIconsGrouped: cluster => pulse(cluster.cx, cluster.cy, Math.max(cluster.w, cluster.h) + reach, 0.3, 1,
                                     theme.env.appearDelay + theme.env.morphDuration)

    // Runs only while the shooting star is in view (the first 4 % of each cycle, plus a margin).
    FrameClock {
        id: clock
        env: theme.env
        readonly property real coarse: ((theme.env.time * 100 / 3769.911184) % 1) / 0.04
        active: theme.showShooting && (clock.coarse <= 1.2 || clock.coarse >= 24.6)
    }

    // One shooting star every 38 s (100 per time wrap), in view for 1.5 s. The head is at the item's origin.
    Item {
        id: meteor
        readonly property real cycle: clock.time * 100 / 3769.911184
        readonly property real p: (cycle % 1) / 0.04
        readonly property int n: Math.floor(cycle)
        readonly property real dir: World.hash01(n, 3) < 0.5 ? 1 : -1               // 1: flies right, -1: left
        readonly property real angle: 20 + 30 * World.hash01(n, 5)                  // degrees below horizontal
        readonly property real x0: theme.width * (0.15 + 0.7 * World.hash01(n, 7))
        readonly property real y0: theme.height * (0.05 + 0.45 * World.hash01(n, 9))
        z: 4
        visible: theme.showShooting && p <= 1
        x: x0 + dir * 460 * p * Math.cos(angle * Math.PI / 180)
        y: y0 + 460 * p * Math.sin(angle * Math.PI / 180)
        rotation: dir > 0 ? angle : 180 - angle
        opacity: Math.sin(Math.PI * Math.min(1, p))
        Rectangle {
            x: -110
            y: -1
            width: 110
            height: 2
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: theme.pal.star }
            }
        }
    }
}
