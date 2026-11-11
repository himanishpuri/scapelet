// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../code/themes.js" as Themes

Kirigami.FormLayout {
    id: root
    twinFormLayouts: parentLayout // qmllint disable unqualified

    property alias formLayout: root

    property alias cfg_InfluenceRadius: influenceRadius.value
    property alias cfg_AppearDelay: appearDelay.value
    property alias cfg_DisappearDelay: disappearDelay.value
    property alias cfg_MorphDuration: morphDuration.value
    property alias cfg_Animate: animate.checked
    property alias cfg_IncludeWidgets: includeWidgets.checked
    property alias cfg_Fps: fps.value
    property alias cfg_RenderScale: renderScale.value
    property alias cfg_PauseMode: pauseMode.currentIndex
    property alias cfg_BatterySaver: batterySaver.checked
    property alias cfg_DebugLog: debugLog.checked

    property string cfg_Theme
    property string cfg_ThemeSettings

    readonly property var themeEntry: Themes.find(cfg_Theme)
    readonly property var themeValues: Themes.resolve(themeEntry.id, cfg_ThemeSettings)

    function setThemeValue(key, value) {
        cfg_ThemeSettings = Themes.store(cfg_ThemeSettings, themeEntry.id, key, value);
    }

    QQC2.ComboBox {
        id: themeBox
        Kirigami.FormData.label: "Theme:"
        model: Themes.list.map(t => t.name)
        currentIndex: Math.max(0, Themes.list.findIndex(t => t.id === root.cfg_Theme))
        onActivated: index => root.cfg_Theme = Themes.list[index].id
    }

    Repeater {
        model: root.themeEntry.settings
        delegate: RowLayout {
            id: row
            required property var modelData
            readonly property var value: root.themeValues[modelData.key]
            Kirigami.FormData.label: modelData.type === "bool" ? "" : modelData.label

            QQC2.SpinBox {
                visible: row.modelData.type === "int"
                from: row.modelData.min ?? 0
                to: row.modelData.max ?? 100
                stepSize: row.modelData.step ?? 1
                value: row.modelData.type === "int" ? row.value : 0
                onValueModified: root.setThemeValue(row.modelData.key, value)
            }
            QQC2.CheckBox {
                visible: row.modelData.type === "bool"
                text: row.modelData.label
                checked: row.modelData.type === "bool" && row.value === true
                onToggled: root.setThemeValue(row.modelData.key, checked)
            }
            QQC2.ComboBox {
                visible: row.modelData.type === "choice"
                model: row.modelData.choices ?? []
                currentIndex: row.modelData.type === "choice" ? row.value : 0
                onActivated: index => root.setThemeValue(row.modelData.key, index)
            }
        }
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true }

    QQC2.SpinBox {
        id: influenceRadius
        Kirigami.FormData.label: "Area around each icon (px):"
        from: 40
        to: 150
        stepSize: 5
    }

    QQC2.SpinBox {
        id: appearDelay
        Kirigami.FormData.label: root.themeEntry.terms.appear
        from: 0
        to: 10000
        stepSize: 250
    }

    QQC2.SpinBox {
        id: disappearDelay
        Kirigami.FormData.label: root.themeEntry.terms.disappear
        from: 0
        to: 10000
        stepSize: 250
    }

    QQC2.SpinBox {
        id: morphDuration
        Kirigami.FormData.label: root.themeEntry.terms.morph
        from: 200
        to: 5000
        stepSize: 100
    }

    QQC2.CheckBox {
        id: animate
        text: "Animate"
    }

    QQC2.CheckBox {
        id: includeWidgets
        text: root.themeEntry.terms.widgets
    }

    QQC2.SpinBox {
        id: fps
        Kirigami.FormData.label: "Frame rate limit (fps):"
        from: 5
        to: 60
        stepSize: 5
    }

    QQC2.SpinBox {
        id: renderScale
        Kirigami.FormData.label: "Render scale (%):"
        from: 50
        to: 100
        stepSize: 25
    }

    QQC2.ComboBox {
        id: pauseMode
        Kirigami.FormData.label: "Pause animation:"
        model: ["Never", "Under a maximized or full-screen window", "Under any window that covers most of the screen"]
    }

    QQC2.CheckBox {
        id: batterySaver
        text: "Save power on battery and in power-saver mode (15 fps, 75 % scale)"
    }

    QQC2.CheckBox {
        id: debugLog
        text: "Log icon tracking to the journal"
    }
}
