// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// One source's contribution to the influence field.
ShaderEffect {
    id: blob

    required property string key
    required property real bx
    required property real by
    required property real bw
    required property real bh
    required property bool present
    required property bool lifted
    required property real seed

    property bool animate: true
    property int appearDelay: 2000
    property int disappearDelay: 3000
    property int morphDuration: 1800

    signal expired(string key)

    // Shader uniforms.
    property real strength: 1            // amplitude: 1 at rest, 0.5 while lifted
    property real growth: 0              // 0..1 size
    property real sigma: 70
    property real sigmaWide: sigma * 2.5
    property vector2d halfRect: Qt.vector2d(bw * 0.25, bh * 0.25)
    property vector2d itemSize: Qt.vector2d(width, height)

    readonly property real reach: 2 * sigmaWide

    x: bx + bw / 2 - width / 2
    y: by + bh / 2 - height / 2
    width: 2 * (halfRect.x + reach)
    height: 2 * (halfRect.y + reach)
    visible: growth > 0.001
    fragmentShader: Qt.resolvedUrl("../shaders/field.frag.qsb")

    function apply() {
        grow.stop();
        shrink.stop();
        recover.stop();
        settle.stop();
        if (!present) {
            if (animate) {
                shrink.restart();
            } else {
                growth = 0;
                expired(key);
            }
            return;
        }
        if (!animate) {
            growth = 1;
            strength = lifted ? 0.5 : 1;
            return;
        }
        settle.to = lifted ? 0.5 : 1;     // picked up: the land thins to a shoal at once
        settle.restart();
        if (growth > 0.001) {
            recover.restart();            // revived before it sank: no delay
        } else {
            grow.restart();
        }
    }

    onPresentChanged: apply()
    onLiftedChanged: apply()
    Component.onCompleted: apply()

    NumberAnimation { id: settle; target: blob; property: "strength"; duration: 300; easing.type: Easing.OutCubic }
    NumberAnimation { id: recover; target: blob; property: "growth"; to: 1; duration: 300; easing.type: Easing.OutCubic }

    SequentialAnimation {
        id: grow
        PauseAnimation { duration: blob.appearDelay }
        NumberAnimation { target: blob; property: "growth"; to: 1; duration: blob.morphDuration; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: shrink
        PauseAnimation { duration: blob.disappearDelay }
        NumberAnimation { target: blob; property: "growth"; to: 0; duration: blob.morphDuration; easing.type: Easing.InOutSine }
        ScriptAction { script: blob.expired(blob.key) }
    }
}
