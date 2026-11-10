// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// Tileable noise rendered once. r, g: two 2-octave fields (12 cells per tile); b: one field (8 cells).
// A tile spans 2048 px: sample with texture(noise, px / 2048.0).
Item {
    id: atlas

    readonly property Item texture: source

    ShaderEffect {
        id: generator
        width: 512
        height: 512
        visible: false
        fragmentShader: Qt.resolvedUrl("../shaders/noise.frag.qsb")
    }

    ShaderEffectSource {
        id: source
        sourceItem: generator
        visible: false
        live: false
        smooth: true
        wrapMode: ShaderEffectSource.Repeat
        textureSize: Qt.size(512, 512)
        Component.onCompleted: scheduleUpdate()
    }
}
