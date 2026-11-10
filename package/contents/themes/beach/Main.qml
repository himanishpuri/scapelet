// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../../engine"
import "beach.js" as Beach
import "../../code/world.js" as World

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
    }

    readonly property bool showPalms: theme.settings.palms ?? true
    readonly property bool showKayak: theme.settings.kayak ?? true
    readonly property bool showBirds: theme.settings.birds ?? true
    readonly property int stripSide: theme.settings.strip ?? 0
    readonly property real stripWidth: stripSide > 0 ? (theme.settings.stripWidth ?? 160) : 0
    // Icons, widgets and a top or bottom beach: what the kayak's lane must stay clear of.
    readonly property var obstacles: {
        const list = theme.env.sources.slice();
        if (stripSide === 3) {
            list.push({ x: 0, y: 0, w: theme.width, h: stripWidth });
        } else if (stripSide === 4) {
            list.push({ x: 0, y: theme.height - stripWidth, w: theme.width, h: stripWidth });
        }
        return list;
    }

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

    // One kayak crossing open water. All motion derives from env.time: it stops when the engine pauses,
    // and every rate is a whole number of cycles per time wrap, so nothing jumps at the wrap.
    Image {
        id: kayak
        readonly property real lane: World.clearLane(theme.obstacles, theme.height, 12, 2.5 * theme.env.influenceRadius)
        readonly property real from: theme.stripSide === 1 ? theme.stripWidth + 40 : -80
        readonly property real to: theme.stripSide === 2 ? theme.width - theme.stripWidth - 40 : theme.width + 80
        z: 3
        visible: theme.showKayak && lane >= 0
        source: Qt.resolvedUrl("kayak.svg")
        sourceSize: Qt.size(64, 24)
        x: from + ((theme.env.time * 16 / 3769.911184) % 1) * (to - from)   // one crossing every 236 s
        y: lane - height / 2 + 4 * Math.sin(theme.env.time * 0.8)
        rotation: 4 * Math.sin(theme.env.time * 0.5)
    }

    // Three gulls crossing every 47 s (80 per time wrap), in view for the first 40 % of each cycle.
    Item {
        id: flock
        readonly property real cycle: theme.env.time * 80 / 3769.911184
        readonly property real p: (cycle % 1) / 0.4
        z: 4
        visible: theme.showBirds && p <= 1
        x: -120 + (theme.width + 240) * p
        y: theme.height * (0.15 + 0.7 * World.hash01(Math.floor(cycle), 7)) - 60 * p

        Repeater {
            model: [{ dx: 0, dy: 0 }, { dx: -36, dy: 22 }, { dx: -32, dy: -26 }]
            delegate: Image {
                id: bird
                required property var modelData
                required property int index
                x: modelData.dx
                y: modelData.dy
                width: 36
                height: 24
                source: Qt.resolvedUrl("bird.svg")
                sourceSize: Qt.size(48, 32)
                transform: Scale { origin.y: 12; yScale: 0.75 + 0.25 * Math.sin(theme.env.time * 9 + bird.index * 2) }
            }
        }
    }
}
