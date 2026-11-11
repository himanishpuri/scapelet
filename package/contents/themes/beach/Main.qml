// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../../engine"
import "beach.js" as Beach
import "../../code/paths.js" as Paths

// Beach: icons are sandy islands in a tropical sea.
// added -> sand appears, grouped -> island expands, removed -> water returns, moved -> coastline changes.
ThemeBase {
    id: theme

    readonly property var pal: Beach.palettes[theme.settings.palette ?? 0]
    accentColor: pal.accent

    ShaderEffect {
        id: ocean
        anchors.fill: parent
        blending: false
        property var mask: theme.env.field
        property var noiseTex: theme.env.noise
        property real time: theme.env.time
        property real sigma: theme.env.influenceRadius
        property real warp: theme.settings.coastWarp ?? 30
        property vector2d resolution: Qt.vector2d(width, height)
        property vector4d strip: Qt.vector4d(theme.settings.strip ?? 0, theme.settings.stripWidth ?? 160, 0, 0)
        property color tint: (theme.settings.timeOfDay ?? false) ? theme.env.dayTint : "white"
        property color cDeep: theme.pal.deep
        property color cMid: theme.pal.mid
        property color cShallow: theme.pal.shallow
        property color cShoal: theme.pal.shoal
        property color cFoam: theme.pal.foam
        property color cSandWet: theme.pal.sandWet
        property color cSandDry: theme.pal.sandDry
        property color cSandHigh: theme.pal.sandHigh
        fragmentShader: Qt.resolvedUrl("ocean.frag.qsb")
        // Cached while the gulls fly: the sea is then redrawn only when time or the field changes,
        // so frames between engine ticks cost a texture copy, not the ocean shader.
        layer.enabled: birdClock.running
    }

    readonly property bool showPalms: theme.settings.palms ?? true
    readonly property bool showKayak: theme.settings.kayak ?? true
    readonly property bool showBirds: theme.settings.birds ?? true
    readonly property int stripSide: theme.settings.strip ?? 0
    readonly property real stripWidth: stripSide > 0 ? (theme.settings.stripWidth ?? 160) : 0
    // Icons, widgets and the permanent beach: what the kayak must stay clear of.
    readonly property var obstacles: {
        const list = theme.env.sources.slice();
        if (stripSide === 1) {
            list.push({ x: 0, y: 0, w: stripWidth, h: theme.height });
        } else if (stripSide === 2) {
            list.push({ x: theme.width - stripWidth, y: 0, w: stripWidth, h: theme.height });
        } else if (stripSide === 3) {
            list.push({ x: 0, y: 0, w: theme.width, h: stripWidth });
        } else if (stripSide === 4) {
            list.push({ x: 0, y: theme.height - stripWidth, w: theme.width, h: stripWidth });
        }
        return list;
    }
    // px of open water the kayak keeps between itself and every obstacle.
    readonly property real clearance: 0.6 * theme.env.influenceRadius + (theme.settings.coastWarp ?? 30) + 16
    onObstaclesChanged: kayak.refresh()
    onClearanceChanged: kayak.refresh()
    onWidthChanged: kayak.refresh()
    onHeightChanged: kayak.refresh()

    // Transitions: rings of foam where the coast is about to change.
    Component {
        id: ring
        Rectangle {
            id: r
            property real cx
            property real cy
            property real size
            property int delay
            x: cx - size / 2
            y: cy - size / 2
            width: size
            height: size
            radius: size / 2
            color: "transparent"
            border.color: theme.pal.foam
            border.width: 2
            opacity: 0
            scale: 0.3
            SequentialAnimation {
                running: true
                PauseAnimation { duration: r.delay }
                ParallelAnimation {
                    NumberAnimation { target: r; property: "scale"; to: 1; duration: 1600; easing.type: Easing.OutCubic }
                    SequentialAnimation {
                        NumberAnimation { target: r; property: "opacity"; to: 0.7; duration: 200 }
                        NumberAnimation { target: r; property: "opacity"; to: 0; duration: 1400 }
                    }
                }
                ScriptAction { script: r.destroy() }
            }
        }
    }

    function ripple(cx, cy, size, delay) {
        if (!theme.env.running) {
            return;   // nobody is watching
        }
        ring.createObject(theme, { cx: cx, cy: cy, size: size, delay: delay, z: 1 });
        ring.createObject(theme, { cx: cx, cy: cy, size: size, delay: delay + 350, z: 1 });
    }

    readonly property real reach: 3.2 * theme.env.influenceRadius

    onIconAdded: source => ripple(source.x + source.w / 2, source.y + source.h / 2, reach,
                                  theme.env.appearDelay + 0.5 * theme.env.morphDuration)
    onIconRemoved: source => ripple(source.x + source.w / 2, source.y + source.h / 2, 0.75 * reach,
                                    theme.env.disappearDelay + 0.8 * theme.env.morphDuration)
    onIconsMoved: moves => {
        for (const m of moves) {
            ripple(m.to.x + m.to.w / 2, m.to.y + m.to.h / 2, reach, theme.env.appearDelay + 0.5 * theme.env.morphDuration);
        }
    }
    onIconsGrouped: cluster => ripple(cluster.cx, cluster.cy, Math.max(cluster.w, cluster.h) + reach,
                                      theme.env.appearDelay + theme.env.morphDuration)

    // A click: gulls near it scatter, the kayak under it rocks, and open water ripples.
    onTapped: (x, y) => {
        const lead = Paths.at(flock.route, flock.p);
        if (flock.visible && Math.hypot(x - lead.x, y - lead.y) < 110) {
            startle.restart();
            return;
        }
        if (kayak.visible && Math.hypot(x - kayak.x, y - kayak.y) < 60) {
            rocking.restart();
            ripple(kayak.x, kayak.y, 90, 0);
            return;
        }
        for (const o of theme.obstacles) {
            if (Paths.rectDist(x, y, o) < 0.8 * theme.env.influenceRadius) {
                return;   // on land
            }
        }
        ripple(x, y, 110, 0);
    }

    // Palm trees on clusters of three or more icons.
    Roster {
        id: palms
        anchors.fill: parent
        z: 2
        items: theme.showPalms ? Beach.palmSpots(theme.env.spots, theme.env.clusters) : []
        delegate: Image {
            id: palm
            required property string key
            required property real bx
            required property real by
            required property bool present
            required property real seed

            source: Qt.resolvedUrl("palm.svg")
            sourceSize: Qt.size(64, 64)
            width: 28 + 10 * seed
            height: width
            x: bx - width / 2
            y: by - height / 2
            rotation: 360 * seed
            scale: 0

            function apply() {
                show.stop();
                hide.stop();
                if (!present) {
                    hide.restart();
                } else if (theme.env.animateChanges) {
                    show.restart();
                } else {
                    scale = 1;
                }
            }

            onPresentChanged: apply()
            Component.onCompleted: apply()

            SequentialAnimation {
                id: show
                PauseAnimation { duration: theme.env.appearDelay + theme.env.morphDuration }   // after the sand is up
                NumberAnimation { target: palm; property: "scale"; to: 1; duration: 600; easing.type: Easing.OutBack }
            }
            SequentialAnimation {
                id: hide
                NumberAnimation { target: palm; property: "scale"; to: 0; duration: 400; easing.type: Easing.InCubic }
                ScriptAction { script: Qt.callLater(palms.expire, palm.key) }
            }
        }
    }

    // One kayak paddles a curved route from one screen edge to another, 16 routes per time wrap (236 s each).
    // All motion derives from env.time: it stops when the engine pauses, and nothing jumps at the wrap.
    // A route is kept until its crossing ends; when an icon blocks it, the kayak fades out and
    // comes back on a clear route.
    ShadowSprite {
        id: kayak
        readonly property real cycle: theme.env.time * 16 / 3769.911184
        readonly property int n: Math.floor(cycle)
        property var route: null
        property var pending: null
        property int routeN: -1
        readonly property var pos: route ? Paths.at(route, cycle % 1) : null

        function refresh() {
            const next = Paths.pick(17, n, theme.width, theme.height, 80, theme.obstacles, theme.clearance, 40);
            if (n !== routeN || !theme.env.animateChanges) {
                swap.stop();
                opacity = 1;
                route = next;
                routeN = n;
            } else if ((next ? next.k : -1) !== (route ? route.k : -1)) {
                pending = next;
                swap.restart();
            }
        }
        onNChanged: refresh()
        Component.onCompleted: refresh()

        SequentialAnimation {
            id: swap
            NumberAnimation { target: kayak; property: "opacity"; to: 0; duration: 400 }
            ScriptAction { script: kayak.route = kayak.pending }
            NumberAnimation { target: kayak; property: "opacity"; to: 1; duration: 400 }
        }

        z: 3
        visible: theme.showKayak && pos !== null
        x: pos ? pos.x : 0
        y: pos ? pos.y : 0
        // 1 right after a click on the kayak, back to 0 in two seconds: it rocks.
        property real rock: 0
        NumberAnimation { id: rocking; target: kayak; property: "rock"; from: 1; to: 0; duration: 2000; easing.type: Easing.OutQuad }
        heading: (pos ? pos.angle : 0) + 4 * Math.sin(theme.env.time * 0.5) + 26 * rock * Math.sin(rock * 20)
        source: Qt.resolvedUrl("kayak.svg")
        shadowSource: Qt.resolvedUrl("kayak-shadow.svg")
        spriteWidth: 64
        spriteHeight: 24
        sourceSize: Qt.size(64, 24)
        altitude: 10
        shadowOpacity: 0.2
    }

    // Gull clock: follows env.time, but advances on every displayed frame while the gulls are in
    // view, so they glide at the display rate even when the engine ticks slowly (battery saver).
    // Resyncs to env.time when it drifts, wraps or was paused.
    property real birdTime: 0
    FrameAnimation {
        id: birdClock
        readonly property real coarse: ((theme.env.time * 80 / 3769.911184) % 1) / 0.4
        running: theme.env.running && theme.showBirds && (coarse <= 1.05 || coarse >= 2.45)
        onTriggered: {
            const next = theme.birdTime + frameTime;
            theme.birdTime = Math.abs(next - theme.env.time) > 0.5 ? theme.env.time : next;
        }
    }

    // Three gulls follow one curved route every 47 s (80 per time wrap), in view for the first 40 % of each cycle.
    // The second and third fly a little behind the first and to either side of its path.
    Item {
        id: flock
        readonly property real cycle: theme.birdTime * 80 / 3769.911184
        readonly property real p: (cycle % 1) / 0.4
        readonly property var route: Paths.route(29, Math.floor(cycle), theme.width, theme.height, 120)
        z: 4
        visible: theme.showBirds && p <= 1

        // 1 right after a click near the flock, back to 0 within three seconds: the birds scatter.
        property real scatter: 0
        SequentialAnimation {
            id: startle
            NumberAnimation { target: flock; property: "scatter"; to: 1; duration: 250; easing.type: Easing.OutCubic }
            NumberAnimation { target: flock; property: "scatter"; to: 0; duration: 2600; easing.type: Easing.InOutQuad }
        }

        Repeater {
            model: [{ lag: 0, side: 0 }, { lag: 0.022, side: 26 }, { lag: 0.02, side: -26 }]
            delegate: ShadowSprite {
                id: bird
                required property var modelData
                required property int index
                readonly property var pos: Paths.at(flock.route, flock.p - modelData.lag)
                // 1 while the bird beats its wings, 0 while it glides.
                readonly property real beat: Math.max(0, Math.min(1, 0.5 + 2 * Math.sin(theme.birdTime * 0.7 + index * 2.1)))
                // Scattered, a gull swings wide of its place (the leader too) and beats its wings hard.
                readonly property real wide: (modelData.side + (index === 0 ? 30 : 0) * flock.scatter) * (1 + 1.6 * flock.scatter)
                x: pos.x - wide * Math.sin(pos.angle * Math.PI / 180)
                y: pos.y + wide * Math.cos(pos.angle * Math.PI / 180)
                heading: pos.angle + 25 * flock.scatter * Math.sin(index * 2.4 + 1)
                source: Qt.resolvedUrl("bird.svg")
                shadowSource: Qt.resolvedUrl("bird-shadow.svg")
                spriteWidth: 36
                spriteHeight: 24
                sourceSize: Qt.size(48, 32)
                altitude: 60
                shadowOpacity: 0.22
                beatY: 1 - (0.25 + 0.3 * flock.scatter) * Math.max(beat, flock.scatter) * (1 - Math.sin(theme.birdTime * 9 + index * 2))
            }
        }
    }
}
