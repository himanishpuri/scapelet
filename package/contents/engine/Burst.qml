// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick

// A few small pictures that fly up and away from (cx, cy) and fade, then the item destroys itself:
// birds startled out of a tree, pigeons taking off. The picture faces +x.
// Create it with Component.createObject(parent, { cx, cy, source, count, spriteWidth, spriteHeight }).
Item {
    id: burst

    property real cx: 0
    property real cy: 0
    property url source
    property int count: 3
    property real spriteWidth: 20
    property real spriteHeight: 16
    property real reach: 190             // px each picture travels
    property int duration: 1500
    property real progress: 0            // 0..1

    x: cx
    y: cy

    Repeater {
        model: burst.count
        delegate: Image {
            id: bird
            required property int index
            // Directions fan out over the upper half: -150 .. -30 degrees.
            readonly property real angle: -150 + 120 * (index + 0.5) / burst.count + 14 * Math.sin(index * 7.3)
            readonly property real far: burst.reach * (0.7 + 0.3 * Math.abs(Math.sin(index * 3.1))) * burst.progress
            x: far * Math.cos(angle * Math.PI / 180) - width / 2
            y: far * Math.sin(angle * Math.PI / 180) - height / 2 - 30 * Math.sin(Math.PI * burst.progress)
            width: burst.spriteWidth
            height: burst.spriteHeight
            source: burst.source
            sourceSize: Qt.size(2 * burst.spriteWidth, 2 * burst.spriteHeight)
            rotation: angle
            opacity: Math.min(1, 4 * (1 - burst.progress))
            // Wing beat.
            transform: Scale { origin.y: bird.height / 2; yScale: 0.55 + 0.45 * Math.sin(burst.progress * 40 + bird.index * 2) }
        }
    }

    SequentialAnimation {
        running: true
        NumberAnimation { target: burst; property: "progress"; to: 1; duration: burst.duration; easing.type: Easing.OutQuad }
        ScriptAction { script: burst.destroy() }
    }
}
