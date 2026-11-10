// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root
    twinFormLayouts: parentLayout

    property alias formLayout: root

    property alias cfg_ShoreDistance: shoreDistance.value
    property alias cfg_CoastWarp: coastWarp.value
    property alias cfg_AppearDelay: appearDelay.value
    property alias cfg_DisappearDelay: disappearDelay.value
    property alias cfg_MorphDuration: morphDuration.value
    property alias cfg_AnimateWater: animateWater.checked
    property alias cfg_Fps: fps.value
    property alias cfg_RenderScale: renderScale.value
    property alias cfg_PauseWhenCovered: pauseWhenCovered.checked
    property alias cfg_DebugLog: debugLog.checked

    QQC2.SpinBox {
        id: shoreDistance
        Kirigami.FormData.label: i18n("Island size (px):")
        from: 40
        to: 150
        stepSize: 5
    }

    QQC2.SpinBox {
        id: coastWarp
        Kirigami.FormData.label: i18n("Coastline irregularity (px):")
        from: 0
        to: 80
        stepSize: 5
    }

    QQC2.SpinBox {
        id: appearDelay
        Kirigami.FormData.label: i18n("Island appears after (ms):")
        from: 0
        to: 10000
        stepSize: 250
    }

    QQC2.SpinBox {
        id: disappearDelay
        Kirigami.FormData.label: i18n("Island sinks after (ms):")
        from: 0
        to: 10000
        stepSize: 250
    }

    QQC2.SpinBox {
        id: morphDuration
        Kirigami.FormData.label: i18n("Grow/sink duration (ms):")
        from: 200
        to: 5000
        stepSize: 100
    }

    QQC2.CheckBox {
        id: animateWater
        text: i18n("Animate water")
    }

    QQC2.SpinBox {
        id: fps
        Kirigami.FormData.label: i18n("Frame rate limit (fps):")
        from: 5
        to: 60
        stepSize: 5
    }

    QQC2.SpinBox {
        id: renderScale
        Kirigami.FormData.label: i18n("Render scale (%):")
        from: 50
        to: 100
        stepSize: 25
    }

    QQC2.CheckBox {
        id: pauseWhenCovered
        text: i18n("Pause while a window is maximized or full screen")
    }

    QQC2.CheckBox {
        id: debugLog
        text: i18n("Log icon tracking to the journal")
    }
}
