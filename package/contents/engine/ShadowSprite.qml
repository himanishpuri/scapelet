// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// A flat picture seen from above, with its shadow on the ground. The item itself has no size:
// x, y is the middle of the picture. Light comes from the top left, so the shadow lies
// `altitude` px away along (0.6, 0.8).
Item {
    id: sprite

    property url source                   // the picture; it faces +x
    property url shadowSource             // the same outline in black
    property real spriteWidth: 0          // px
    property real spriteHeight: 0         // px
    property size sourceSize
    property real heading: 0              // degrees clockwise from +x
    property real altitude: 0             // px above the ground
    property real shadowOpacity: 0.25
    property bool castShadow: true
    property real beatX: 1                // wing beat: scale along the picture's x axis
    property real beatY: 1                // wing beat: scale along the picture's y axis

    Image {
        visible: sprite.castShadow
        x: 0.6 * sprite.altitude - width / 2
        y: 0.8 * sprite.altitude - height / 2
        width: sprite.spriteWidth
        height: sprite.spriteHeight
        source: sprite.shadowSource
        sourceSize: sprite.sourceSize
        opacity: sprite.shadowOpacity
        transform: [
            Scale { origin.x: sprite.spriteWidth / 2; origin.y: sprite.spriteHeight / 2; xScale: sprite.beatX; yScale: sprite.beatY },
            Rotation { origin.x: sprite.spriteWidth / 2; origin.y: sprite.spriteHeight / 2; angle: sprite.heading }
        ]
    }

    Image {
        x: -width / 2
        y: -height / 2
        width: sprite.spriteWidth
        height: sprite.spriteHeight
        source: sprite.source
        sourceSize: sprite.sourceSize
        transform: [
            Scale { origin.x: sprite.spriteWidth / 2; origin.y: sprite.spriteHeight / 2; xScale: sprite.beatX; yScale: sprite.beatY },
            Rotation { origin.x: sprite.spriteWidth / 2; origin.y: sprite.spriteHeight / 2; angle: sprite.heading }
        ]
    }
}
