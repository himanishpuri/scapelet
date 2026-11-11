// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../../engine"
import "forest.js" as Forest
import "../../code/paths.js" as Paths
import "../../code/world.js" as World

// Forest: trees cover the desktop and step back around the icons.
// The trees are drawn from the influence field: a clearing opens where the field rises and
// closes where it falls, so the theme needs no handler for the core events.
ThemeBase {
    id: theme

    readonly property var pal: Forest.palettes[theme.settings.palette ?? 0]
    readonly property bool swaying: theme.settings.sway ?? true
    readonly property bool showSparrows: theme.settings.sparrows ?? true
    readonly property int hikers: theme.settings.hikers ?? 3
    readonly property bool cutterOn: theme.settings.woodcutter ?? true
    readonly property int trailCount: theme.settings.paths ?? 2
    readonly property bool bendPaths: (theme.settings.pathIcons ?? 0) === 1
    // Icons and widgets at rest. Hikers step around them, and a footpath that bends keeps clear of them.
    readonly property var blocks: theme.env ? theme.env.sources.filter(s => !s.lifted) : []
    // The footpaths: curved routes from one screen edge to another (see Trail below).
    readonly property var trails: [trailA.route, trailB.route]
    property int waving: -1              // the hiker who waves back at a click, or -1

    // Hiker i as the shader wants it (see who0 in forest.frag). A hiker crosses the screen every
    // 126 s (30 per time wrap), in view for the first 85 % of each cycle: along a footpath when
    // there is one, every other time the other way; else on a curved route of its own.
    function hiker(i, time) {
        const cycle = time * 30 / 3769.911184 + 0.37 * i;
        const n = Math.floor(cycle) % 30, p = (cycle % 1) / 0.85;
        if (i >= theme.hikers || p > 1) {
            return Qt.vector4d(-1000, -1000, 0, 1);
        }
        const onTrail = theme.trailCount > 0;
        if (onTrail && (i % theme.trailCount === 0 ? trailA : trailB).moving) {
            return Qt.vector4d(-1000, -1000, 0, 1);     // his path is being redrawn
        }
        const route = onTrail ? theme.trails[i % theme.trailCount] : Paths.route(83 + i, n, theme.width, theme.height, 30);
        const back = onTrail && (i + n) % 2 === 1;
        const pos = theme.around(Paths.at(route, back ? 1 - p : p));
        const facing = (Math.cos(pos.angle * Math.PI / 180) >= 0 ? 1 : -1) * (back ? -1 : 1);
        return Qt.vector4d(pos.x, pos.y, (p * route.len / 9) % 1, facing * (1 + i % 4 + (theme.waving === i ? 8 : 0)));
    }

    // pos (from Paths.at) moved sideways off its line of travel, so that it passes around every
    // block in a smooth arc instead of under it.
    function around(pos) {
        const a = pos.angle * Math.PI / 180, tx = Math.cos(a), ty = Math.sin(a);
        let shift = 0;
        for (const s of theme.blocks) {
            const r = 0.5 * Math.max(s.w, s.h) + 8;
            const rx = s.x + s.w / 2 - pos.x, ry = s.y + s.h / 2 - pos.y;
            const along = rx * tx + ry * ty, beside = ry * tx - rx * ty;
            const k = 1 - along * along / (4 * r * r);
            if (k <= 0 || Math.abs(beside) >= r * k * k) {
                continue;
            }
            const d = beside >= 0 ? beside - r * k * k : beside + r * k * k;
            if (Math.abs(d) > Math.abs(shift)) {
                shift = d;
            }
        }
        return { x: pos.x - ty * shift, y: pos.y + tx * shift, angle: pos.angle };
    }

    // The woodcutter fells one tree every 314 s (12 per time wrap). The tree is picked when the job
    // begins: the first of eight candidates well away from every icon and from the screen edges.
    // With footpaths the candidates stand 50 px beside a path, on its upper side, so the path keeps
    // the view on him open; without, they are anywhere.
    readonly property real jobCycle: theme.env.time * 12 / 3769.911184
    readonly property int jobN: Math.floor(jobCycle)
    property var job: null               // { cx, cy, side } or null
    function pickJob() {
        if (!theme.env) {
            return;
        }
        const cell = trees.cell, cols = Math.floor(theme.width / cell), rows = Math.floor(theme.height / cell);
        theme.job = null;
        if (cols < 8 || rows < 7) {
            return;
        }
        for (let k = 0; k < 8; ++k) {
            const u = World.hash01(theme.jobN + 0.31, 61 + k), v = World.hash01(theme.jobN + 0.31, 71 + k);
            let cx = 3 + Math.floor(u * (cols - 6)), cy = 3 + Math.floor(v * (rows - 5));
            if (theme.trailCount > 0) {
                const pos = Paths.at(theme.trails[(theme.jobN + k) % theme.trailCount], 0.12 + 0.76 * u);
                const a = pos.angle * Math.PI / 180, up = Math.cos(a) >= 0 ? 1 : -1;
                cx = Math.floor((pos.x + 50 * up * Math.sin(a)) / cell);
                cy = Math.floor((pos.y - 50 * up * Math.cos(a)) / cell);
                if (cx < 3 || cx > cols - 4 || cy < 3 || cy > rows - 3) {
                    continue;
                }
            }
            const x = (cx + 0.5) * cell, y = (cy + 0.5) * cell;
            if (theme.env.sources.every(s => Paths.rectDist(x, y, s) > 2.4 * theme.env.influenceRadius)) {
                theme.job = { cx: cx, cy: cy, side: x < theme.width / 2 ? -1 : 1 };
                return;
            }
        }
    }
    onJobNChanged: pickJob()
    onWidthChanged: pickJob()
    onHeightChanged: pickJob()
    Component.onCompleted: pickJob()

    // One footpath. Its line is route 0 of its seed; when footpaths bend around icons it is the
    // first of 24 candidate lines that stays 34 px clear of every block (route 0 when none does).
    // A path that has to move fades out and comes back on its new line.
    component Trail: Item {
        id: trail
        property int index: 0
        property var route: Paths.route(101 + index, 0, theme.width, theme.height, 40)
        property var pending: null
        readonly property bool moving: swap.running

        function refresh(fade) {
            if (!theme.env) {
                return;
            }
            const straight = Paths.route(101 + index, 0, theme.width, theme.height, 40);
            const next = theme.bendPaths ? (Paths.pick(101 + index, 0, theme.width, theme.height, 40, theme.blocks, 34, 24) ?? straight) : straight;
            if (!fade || !visible || !theme.env.animateChanges) {
                swap.stop();
                opacity = 1;
                route = next;
            } else if (next.k !== (swap.running ? pending.k : route.k)) {
                pending = next;
                swap.restart();
            }
        }
        Component.onCompleted: refresh(false)

        Connections {
            target: theme
            function onBlocksChanged() { trail.refresh(true) }
            function onBendPathsChanged() { trail.refresh(true) }
            function onWidthChanged() { trail.refresh(false) }
            function onHeightChanged() { trail.refresh(false) }
        }

        SequentialAnimation {
            id: swap
            NumberAnimation { target: trail; property: "opacity"; to: 0; duration: 700 }
            ScriptAction { script: trail.route = trail.pending }
            NumberAnimation { target: trail; property: "opacity"; to: 1; duration: 700 }
        }

        Repeater {
            model: [{ width: 70, alpha: 0.25 }, { width: 44, alpha: 0.5 }, { width: 22, alpha: 1 }]
            delegate: Shape {
                id: band
                required property var modelData
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: band.modelData.width
                    strokeColor: Qt.rgba(1, 1, 1, band.modelData.alpha)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: trail.route.x[0]
                    startY: trail.route.y[0]
                    PathCubic {
                        control1X: trail.route.x[1]
                        control1Y: trail.route.y[1]
                        control2X: trail.route.x[2]
                        control2Y: trail.route.y[2]
                        x: trail.route.x[3]
                        y: trail.route.y[3]
                    }
                }
            }
        }
    }

    // The footpaths as a texture for the shader: 1 on the middle of a path, falling to 0 at 35 px from it.
    Item {
        id: trailArt
        anchors.fill: parent
        Trail { id: trailA; index: 0; visible: theme.trailCount > 0 }
        Trail { id: trailB; index: 1; visible: theme.trailCount > 1 }
    }

    ShaderEffectSource {
        id: trailTexture
        sourceItem: trailArt
        hideSource: true
        visible: false
        smooth: true
        textureSize: Qt.size(Math.max(1, Math.ceil(theme.width * 0.5)), Math.max(1, Math.ceil(theme.height * 0.5)))
    }
    accentColor: pal.accent

    ShaderEffect {
        id: trees
        anchors.fill: parent
        blending: false
        property var mask: theme.env.field
        property var noiseTex: theme.env.noise
        property var trail: trailTexture
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
        property color cDirt: theme.pal.dirt
        property real trails: theme.trailCount
        property vector4d who0: theme.hiker(0, theme.env.time)
        property vector4d who1: theme.hiker(1, theme.env.time)
        property vector4d who2: theme.hiker(2, theme.env.time)
        property vector4d who3: theme.hiker(3, theme.env.time)
        property vector4d chop: theme.cutterOn && theme.job
            ? Qt.vector4d(theme.job.cx, theme.job.cy, (theme.jobCycle % 1) * 314.159265, theme.job.side) : Qt.vector4d(0, 0, -1, 1)
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

        // 1 right after a click near the flock, back to 0 within three seconds: the birds scatter.
        property real scatter: 0
        SequentialAnimation {
            id: startle
            NumberAnimation { target: flight; property: "scatter"; to: 1; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { target: flight; property: "scatter"; to: 0; duration: 2600; easing.type: Easing.InOutQuad }
        }

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
                // Scattered, a sparrow swings wide of its place (the leader too).
                readonly property real wide: (modelData.side + bound + (index === 0 ? 24 : 0) * flight.scatter) * (1 + 1.8 * flight.scatter)
                x: pos.x - wide * Math.sin(pos.angle * Math.PI / 180)
                y: pos.y + wide * Math.cos(pos.angle * Math.PI / 180)
                heading: pos.angle + 30 * flight.scatter * Math.sin(index * 2.4 + 1)
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

    Component {
        id: startled
        Burst { source: Qt.resolvedUrl("sparrow.svg"); count: 3; spriteWidth: 20; spriteHeight: 16; z: 4 }
    }

    Timer { id: waveEnd; interval: 2500; onTriggered: theme.waving = -1 }

    // A click: sparrows near it scatter, a hiker near it waves back; anywhere else, birds fly up out of the trees.
    onTapped: (x, y) => {
        const lead = Paths.at(flight.route, flight.p);
        if (flight.visible && Math.hypot(x - lead.x, y - lead.y) < 110) {
            startle.restart();
            return;
        }
        for (let i = 0; i < theme.hikers; ++i) {
            const w = theme.hiker(i, theme.env.time);
            if (Math.hypot(x - w.x, y - (w.y - 10)) < 45) {
                theme.waving = i;
                waveEnd.restart();
                return;
            }
        }
        for (const o of theme.env.sources) {
            if (Paths.rectDist(x, y, o) < theme.env.influenceRadius) {
                return;   // in a clearing: no tree to fly out of
            }
        }
        startled.createObject(theme, { cx: x, cy: y });
    }
}
