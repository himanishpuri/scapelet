// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// A ring that spreads from (cx, cy) to `size` px across and fades, then destroys itself.
// Create it with Component.createObject(parent, { cx, cy, size, tone }).
Rectangle {
    id: ring

    property real cx: 0
    property real cy: 0
    property real size: 120
    property int duration: 1400
    property int delay: 0
    property real peak: 0.7              // opacity at its strongest
    property color tone: "white"

    x: cx - size / 2
    y: cy - size / 2
    width: size
    height: size
    radius: size / 2
    color: "transparent"
    border.color: tone
    border.width: 2
    opacity: 0
    scale: 0.15

    SequentialAnimation {
        running: true
        PauseAnimation { duration: ring.delay }
        ParallelAnimation {
            NumberAnimation { target: ring; property: "scale"; to: 1; duration: ring.duration; easing.type: Easing.OutCubic }
            SequentialAnimation {
                NumberAnimation { target: ring; property: "opacity"; to: ring.peak; duration: 0.15 * ring.duration }
                NumberAnimation { target: ring; property: "opacity"; to: 0; duration: 0.85 * ring.duration }
            }
        }
        ScriptAction { script: ring.destroy() }
    }
}
