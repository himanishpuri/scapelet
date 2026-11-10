// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import "../../engine"

// Blueprint: the engine's state drawn as a technical plan. Reference for theme authors.
ThemeBase {
    id: theme

    accentColor: "#33ccff"

    ShaderEffect {
        anchors.fill: parent
        blending: false
        property var mask: theme.env.field
        property real time: theme.env.time
        property real grid: theme.settings.grid ?? 40
        property vector2d resolution: Qt.vector2d(width, height)
        fragmentShader: Qt.resolvedUrl("blueprint.frag.qsb")
    }

    // Steady state: one outline per source, one box per cluster of 2 or more.
    Repeater {
        model: theme.env.sources
        delegate: Rectangle {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h
            color: "transparent"
            border.color: modelData.kind === "widget" ? "#ffcc33" : "#33ccff"
            border.width: 1
            opacity: modelData.lifted ? 0.3 : 0.8
        }
    }

    Repeater {
        model: theme.env.clusters
        delegate: Rectangle {
            required property var modelData
            visible: modelData.size >= 2
            x: modelData.x - 8
            y: modelData.y - 8
            width: modelData.w + 16
            height: modelData.h + 16
            color: "transparent"
            border.color: "#66ffffff"
            border.width: 1
            Text {
                anchors { left: parent.left; bottom: parent.top }
                text: "\u00d7" + parent.modelData.size
                color: "white"
                font.pixelSize: 12
            }
        }
    }

    // Transitions: each core event flashes a label where it happened.
    Component {
        id: flash
        Text {
            id: label
            color: "white"
            font.pixelSize: 14
            font.bold: true
            SequentialAnimation {
                running: true
                NumberAnimation { target: label; property: "opacity"; from: 1; to: 0; duration: 2500 }
                ScriptAction { script: label.destroy() }
            }
        }
    }

    function note(text, x, y) {
        flash.createObject(theme, { text: text, x: x, y: y });
    }

    onIconAdded: source => note("added", source.x, source.y - 18)
    onIconRemoved: source => note("removed", source.x, source.y - 18)
    onIconsMoved: moves => {
        for (const m of moves) {
            note("moved", m.to.x, m.to.y - 18);
        }
    }
    onIconsGrouped: cluster => note("grouped \u00d7" + cluster.size, cluster.cx - 30, cluster.y - 36)
}
