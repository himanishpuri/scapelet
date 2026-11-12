// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// Keeps the still part of a theme's picture, so that it is drawn once and not on every frame.
// sourceItem: a ShaderEffect (blending: false) that draws the whole picture for one
// fixed time and writes alpha 0 where something moves, alpha 1 elsewhere. The shader that draws the
// frames reads this texture at qt_TexCoord0: a pixel with alpha 1 it copies, any other it draws anew.
// The texture is redrawn only when the source changes: the field, a setting, the size.
// It has the pixels the theme is drawn with, so every pixel of a frame reads exactly its own texel.
ShaderEffectSource {
    id: cache

    required property var env            // the engine, as given to the theme

    visible: false
    hideSource: true                     // the source is drawn into this texture only, not on the screen
    smooth: false
    textureSize: cache.sourceItem
                 ? Qt.size(Math.max(1, Math.ceil(cache.sourceItem.width * cache.env.renderScale)),
                           Math.max(1, Math.ceil(cache.sourceItem.height * cache.env.renderScale)))
                 : Qt.size(1, 1)
}
