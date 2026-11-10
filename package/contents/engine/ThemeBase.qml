// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// The interface every theme implements: themes/<id>/Main.qml has this as its root.
// The engine creates the theme full-size, fills the inputs and emits the core events.
Item {
    id: theme

    // Inputs, set by the engine.
    //   env.time            seconds, wraps at 3769.911184; stops while paused
    //   env.running         animation on/off
    //   env.field           texture: r = narrow sum, g = wide sum of the influence of all sources
    //   env.noise           tileable noise texture (r, g: 2-octave noise, 12 cells; b: 8 cells), period 2048 px
    //   env.sources         [{ id, kind, x, y, w, h, lifted }]
    //   env.clusters        [{ id, members, size, x, y, w, h, cx, cy }]
    //   env.spots           [{ x, y, w: 0, h: 0, cluster, seed }] inland points between close neighbours
    //   env.influenceRadius, env.appearDelay, env.disappearDelay, env.morphDuration, env.animateChanges
    //   env.hour, env.dayTint
    required property var env
    property var settings: ({})          // this theme's settings, keys as declared in code/themes.js

    // Core events, emitted by the engine after start-up.
    signal iconAdded(var source)         // { id, kind, x, y, w, h, lifted }
    signal iconRemoved(var source)
    signal iconsMoved(var moves)         // [{ id, from: { x, y, w, h }, to: { x, y, w, h } }]
    signal iconsGrouped(var cluster)     // a cluster that formed or grew

    // Output, read by the engine.
    property color accentColor: "transparent"
}
