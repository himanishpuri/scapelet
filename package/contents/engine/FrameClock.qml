// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// A clock for sprites. It follows env.time, but while `active` it advances on every displayed
// frame, so sprites glide at the display rate even when the engine ticks slowly (battery saver).
// It resyncs to env.time when it drifts, wraps or was stopped.
FrameAnimation {
    id: clock

    required property var env          // the engine, as given to the theme
    property bool active: true         // set false while no sprite is in view
    property real time: 0

    running: env.running && active
    Component.onCompleted: time = env.time
    onTriggered: {
        const next = time + frameTime;
        time = Math.abs(next - env.time) > 0.5 ? env.time : next;
    }
}
