// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../../engine"

// Beach: icons are sandy islands in a tropical sea.
// added -> sand appears, grouped -> island expands, removed -> water returns, moved -> coastline changes.
ThemeBase {
    id: theme

    accentColor: "#1899a8"

    ShaderEffect {
        id: ocean
        anchors.fill: parent
        blending: false
        property var mask: theme.env.field
        property real time: theme.env.time
        property real sigma: theme.env.influenceRadius
        property real warp: theme.settings.coastWarp ?? 30
        property vector2d resolution: Qt.vector2d(width, height)
        fragmentShader: Qt.resolvedUrl("ocean.frag.qsb")
    }
}
