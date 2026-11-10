// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    Scene {
        id: scene
        anchors.fill: parent
        iconRects: []
        animateChanges: false
        running: root.configuration.AnimateWater
        fps: root.configuration.Fps
        shoreDistance: root.configuration.ShoreDistance
        coastWarp: root.configuration.CoastWarp
        appearDelay: root.configuration.AppearDelay
        disappearDelay: root.configuration.DisappearDelay
        morphDuration: root.configuration.MorphDuration
        renderScale: root.configuration.RenderScale / 100
    }
}
