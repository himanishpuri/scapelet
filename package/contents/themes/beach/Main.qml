// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../../engine"
import "beach.js" as Beach

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
}
